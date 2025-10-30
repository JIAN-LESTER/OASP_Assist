import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function parseDeadline(deadlineStr: string): Date | null {
  if (!deadlineStr) return null;

  try {
    const monthDayYear = deadlineStr.match(/(\w+)\s+(\d{1,2}),?\s+(\d{4})/);
    if (monthDayYear) {
      const dateString = `${monthDayYear[1]} ${monthDayYear[2]}, ${monthDayYear[3]}`;
      const date = new Date(dateString);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }

    const slashFormat = deadlineStr.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
    if (slashFormat) {
      const date = new Date(`${slashFormat[3]}-${slashFormat[1]}-${slashFormat[2]}`);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }

    const date = new Date(deadlineStr);
    if (!isNaN(date.getTime())) {
      return date;
    }

    return null;
  } catch (error) {
    console.error(`Error parsing deadline: ${deadlineStr}`, error);
    return null;
  }
}

async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: {[key: string]: string}
): Promise<void> {
  try {
    const tokensSnapshot = await db
      .collection("fcm_tokens")
      .where("userId", "in", userIds.slice(0, 10))
      .get();

    if (tokensSnapshot.empty) {
      console.log("ℹ️ No FCM tokens found for users");
      return;
    }

    const tokens: string[] = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    if (tokens.length === 0) {
      console.log("ℹ️ No valid FCM tokens to send to");
      return;
    }

    console.log(`📱 Sending FCM notifications to ${tokens.length} devices`);

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data,
      tokens: tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`✅ FCM notifications sent: ${response.successCount} successful, ${response.failureCount} failed`);

    if (response.failureCount > 0) {
      const tokensToDelete: string[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          if (
            error?.code === "messaging/invalid-registration-token" ||
            error?.code === "messaging/registration-token-not-registered"
          ) {
            tokensToDelete.push(tokens[idx]);
          }
        }
      });

      if (tokensToDelete.length > 0) {
        console.log(`🗑️ Deleting ${tokensToDelete.length} invalid tokens`);
        const batch = db.batch();
        const invalidTokensSnapshot = await db
          .collection("fcm_tokens")
          .where("token", "in", tokensToDelete.slice(0, 10))
          .get();

        invalidTokensSnapshot.forEach(doc => {
          batch.delete(doc.ref);
        });

        await batch.commit();
      }
    }
  } catch (error) {
    console.error("Error sending FCM notifications:", error);
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

export const onAnnouncementCreated = onDocumentCreated(
  {
    document: "announcements/{announcementId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const announcementData = event.data?.data();
      const announcementId = event.params.announcementId;

      if (!announcementData) {
        console.log("No announcement data found");
        return;
      }

      if (announcementData.deleted === true) {
        console.log("Announcement is deleted, skipping notification");
        return;
      }

      console.log(`📢 New announcement created: ${announcementId}`);

      const message = announcementData.message || "New announcement posted";
      const category = announcementData.category || "General";
      const deadline = announcementData.deadline || null;

      const notificationTitle = `New ${category} Announcement`;
      let notificationBody = message.substring(0, 100);
      if (message.length > 100) {
        notificationBody += "...";
      }

      if (deadline) {
        notificationBody += ` | Deadline: ${deadline}`;
      }

      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();

      console.log(`📤 Sending notification to ${usersSnapshot.size} users`);

      const batch = db.batch();
      let notificationCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;

        const notificationRef = db.collection("notifications").doc();
        batch.set(notificationRef, {
          userId: userId,
          title: notificationTitle,
          body: notificationBody,
          type: "announcement",
          category: category,
          announcementId: announcementId,
          data: {
            announcementId: announcementId,
            category: category,
            deadline: deadline,
            message: message,
          },
          read: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });

        notificationCount++;

        if (notificationCount % 500 === 0) {
          await batch.commit();
        }
      }

      if (notificationCount % 500 !== 0) {
        await batch.commit();
      }

      console.log(`✅ Created ${notificationCount} notification documents`);

      await sendFCMNotifications(
        usersSnapshot.docs.map(doc => doc.id),
        notificationTitle,
        notificationBody,
        {
          type: "announcement",
          announcementId: announcementId,
          category: category,
        }
      );

      return {success: true, notificationsSent: notificationCount};
    } catch (error) {
      console.error("Error creating announcement notification:", error);
      return {success: false, error: error};
    }
  }
);

export const checkUpcomingDeadlines = onSchedule(
  {
    schedule: "0 9 * * *",
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    try {
      console.log("🔍 Checking for upcoming deadlines...");

      const now = new Date();
      const threeDaysFromNow = new Date();
      threeDaysFromNow.setDate(now.getDate() + 3);

      const announcementsSnapshot = await db
        .collection("announcements")
        .where("deleted", "==", false)
        .where("deadline", "!=", null)
        .get();

      console.log(`📋 Found ${announcementsSnapshot.size} announcements with deadlines`);

      let notificationsCreated = 0;

      for (const announcementDoc of announcementsSnapshot.docs) {
        const data = announcementDoc.data();
        const announcementId = announcementDoc.id;
        const deadline = data.deadline;
        const message = data.message || "";
        const category = data.category || "General";

        const deadlineDate = parseDeadline(deadline);

        if (!deadlineDate) {
          console.log(`⚠️ Could not parse deadline for ${announcementId}: ${deadline}`);
          continue;
        }

        const daysUntilDeadline = Math.ceil(
          (deadlineDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        );

        console.log(`📅 Announcement ${announcementId}: ${daysUntilDeadline} days until deadline`);

        if (daysUntilDeadline === 3) {
          console.log(`⏰ Deadline approaching for announcement: ${announcementId}`);

          const existingNotification = await db
            .collection("notifications")
            .where("announcementId", "==", announcementId)
            .where("type", "==", "deadline_reminder")
            .get();

          if (!existingNotification.empty) {
            console.log(`ℹ️ Already sent deadline notification for ${announcementId}`);
            continue;
          }

          const notificationTitle = `⏰ Deadline Reminder: ${category}`;
          let notificationBody = `${message.substring(0, 80)}... | Deadline in 3 days: ${deadline}`;

          const usersSnapshot = await db
            .collection("users")
            .where("isActive", "==", true)
            .get();

          console.log(`📤 Sending deadline reminder to ${usersSnapshot.size} users`);

          const batch = db.batch();
          let batchCount = 0;

          for (const userDoc of usersSnapshot.docs) {
            const userId = userDoc.id;

            const notificationRef = db.collection("notifications").doc();
            batch.set(notificationRef, {
              userId: userId,
              title: notificationTitle,
              body: notificationBody,
              type: "deadline_reminder",
              category: category,
              announcementId: announcementId,
              data: {
                announcementId: announcementId,
                category: category,
                deadline: deadline,
                message: message,
                daysUntilDeadline: 3,
              },
              read: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              timestamp: admin.firestore.FieldValue.serverTimestamp(),
            });

            batchCount++;

            if (batchCount % 500 === 0) {
              await batch.commit();
            }
          }

          if (batchCount % 500 !== 0) {
            await batch.commit();
          }

          await sendFCMNotifications(
            usersSnapshot.docs.map(doc => doc.id),
            notificationTitle,
            notificationBody,
            {
              type: "deadline_reminder",
              announcementId: announcementId,
              category: category,
              daysUntilDeadline: "3",
            }
          );

          notificationsCreated += batchCount;
          console.log(`✅ Created ${batchCount} deadline reminder notifications for ${announcementId}`);
        }
      }

      console.log(`✅ Deadline check complete. Created ${notificationsCreated} notifications.`);
      return;
    } catch (error) {
      console.error("Error checking deadlines:", error);
      return;
    }
  }
);

export const cleanupOldNotifications = onSchedule(
  {
    schedule: "0 2 * * *",
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    try {
      console.log("🧹 Cleaning up old notifications...");

      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotificationsSnapshot = await db
        .collection("notifications")
        .where("createdAt", "<", thirtyDaysAgo)
        .limit(500)
        .get();

      if (oldNotificationsSnapshot.empty) {
        console.log("ℹ️ No old notifications to delete");
        return;
      }

      const batch = db.batch();
      oldNotificationsSnapshot.forEach(doc => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(`✅ Deleted ${oldNotificationsSnapshot.size} old notifications`);
    } catch (error) {
      console.error("Error cleaning up notifications:", error);
    }
  }
);

export const onEscalationReplied = onDocumentUpdated(
  {
    document: "escalations/{escalationId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();
      const escalationId = event.params.escalationId;

      if (!beforeData || !afterData) {
        console.log("No escalation data found");
        return;
      }

      // Check if staff has replied (status changed to 'resolved' or staffReply field was added)
      const hasNewReply = 
        (afterData.staffReply && !beforeData.staffReply) ||
        (afterData.status === 'resolved' && beforeData.status !== 'resolved' && afterData.staffReply);

      if (!hasNewReply) {
        console.log("No new staff reply detected");
        return;
      }

      console.log(`💬 Staff replied to escalation: ${escalationId}`);

      const userId = afterData.userId;
      const question = afterData.question || "Your question";
      const staffReply = afterData.staffReply || "Staff has responded to your escalation";

      if (!userId) {
        console.log("No userId found in escalation");
        return;
      }

      // Create notification title and body
      const notificationTitle = "Staff Response to Your Escalation";
      let notificationBody = `Re: ${question.substring(0, 60)}`;
      if (question.length > 60) {
        notificationBody += "...";
      }

      // Create notification document for the user
      const notificationRef = db.collection("notifications").doc();
      await notificationRef.set({
        userId: userId,
        title: notificationTitle,
        body: notificationBody,
        type: "escalation_reply",
        escalationId: escalationId,
        data: {
          escalationId: escalationId,
          question: question,
          staffReply: staffReply,
        },
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`✅ Created notification for user: ${userId}`);

      // Send FCM notification
      await sendFCMNotifications(
        [userId],
        notificationTitle,
        notificationBody,
        {
          type: "escalation_reply",
          escalationId: escalationId,
        }
      );

      return {success: true, userId: userId};
    } catch (error) {
      console.error("Error creating escalation reply notification:", error);
      return {success: false, error: error};
    }
  }
);