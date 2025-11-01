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

// ✅ UPDATED: Only send FCM to devices with valid tokens (mobile only)
async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: {[key: string]: string}
): Promise<void> {
  try {
    // ✅ Query tokens where platform is 'android' or 'ios' only
    const tokensSnapshot = await db
      .collection("fcm_tokens")
      .where("userId", "in", userIds.slice(0, 10))
      .where("platform", "in", ["android", "ios"]) // ✅ CRITICAL: Skip web tokens
      .get();

    if (tokensSnapshot.empty) {
      console.log("ℹ️ No mobile FCM tokens found (web/desktop users will see in-app notifications)");
      return;
    }

    const tokens: string[] = [];
    tokensSnapshot.forEach(doc => {
      const tokenData = doc.data();
      if (tokenData.token && !tokenData.token.startsWith('web_')) { // ✅ Double-check
        tokens.push(tokenData.token);
      }
    });

    if (tokens.length === 0) {
      console.log("ℹ️ No valid mobile FCM tokens to send to");
      return;
    }

    console.log(`📱 Sending FCM notifications to ${tokens.length} mobile devices`);

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: tokens,
      android: {
        priority: 'high' as const,
        notification: {
          channelId: data.type === 'deadline_reminder' ? 'deadline_reminders' : 
                     (data.type === 'escalation_reply' || data.type === 'new_escalation') ? 'escalations' : 
                     'announcements',
          priority: 'high' as const,
          defaultSound: true,
          defaultVibrateTimings: true,
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(`✅ FCM sent: ${response.successCount} successful, ${response.failureCount} failed`);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const tokensToDelete: string[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          console.error(`❌ Failed to send to token ${idx}:`, error?.code, error?.message);
          
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
    console.error("❌ Error sending FCM notifications:", error);
  }
}

// ✅ NEW: Create Firestore notifications (works for ALL platforms)
async function createFirestoreNotifications(
  targetRole: string,
  title: string,
  body: string,
  type: string,
  data: {[key: string]: any}
): Promise<number> {
  try {
    console.log(`📝 Creating Firestore notification for role: ${targetRole}`);

    // Create a single notification document that all users of this role will see
    const notificationRef = db.collection("notifications").doc();
    await notificationRef.set({
      targetRole: targetRole,
      title: title,
      body: body,
      type: type,
      data: data,
      readBy: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`✅ Created Firestore notification: ${notificationRef.id}`);
    return 1;
  } catch (error) {
    console.error("❌ Error creating Firestore notification:", error);
    return 0;
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

      if (!announcementData || announcementData.deleted === true) {
        console.log("Announcement is deleted or invalid, skipping notification");
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

      // ✅ Create Firestore notification (works for ALL platforms)
      await createFirestoreNotifications(
        'user',
        notificationTitle,
        notificationBody,
        'announcement',
        {
          announcementId: announcementId,
          category: category,
          deadline: deadline,
          message: message,
        }
      );

      // ✅ Get user IDs for mobile FCM (optional, only for push notifications)
      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();

      const userIds = usersSnapshot.docs.map(doc => doc.id);

      // ✅ Send FCM only to mobile devices
      await sendFCMNotifications(
        userIds,
        notificationTitle,
        notificationBody,
        {
          type: "announcement",
          announcementId: announcementId,
          category: category,
        }
      );

      return {success: true};
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

        if (daysUntilDeadline === 3) {
          console.log(`⏰ Deadline approaching for announcement: ${announcementId}`);

          const existingNotification = await db
            .collection("notifications")
            .where("data.announcementId", "==", announcementId)
            .where("type", "==", "deadline_reminder")
            .get();

          if (!existingNotification.empty) {
            console.log(`ℹ️ Already sent deadline notification for ${announcementId}`);
            continue;
          }

          const notificationTitle = `⏰ Deadline Reminder: ${category}`;
          const notificationBody = `${message.substring(0, 80)}... | Deadline in 3 days: ${deadline}`;

          // ✅ Create Firestore notification
          await createFirestoreNotifications(
            'user',
            notificationTitle,
            notificationBody,
            'deadline_reminder',
            {
              announcementId: announcementId,
              category: category,
              deadline: deadline,
              message: message,
              daysUntilDeadline: 3,
            }
          );

          // ✅ Send FCM to mobile devices
          const usersSnapshot = await db
            .collection("users")
            .where("isActive", "==", true)
            .get();

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

          notificationsCreated++;
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

// ✅ NEW: Notify staff when escalation is CREATED
export const onEscalationCreated = onDocumentCreated(
  {
    document: "escalations/{escalationId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const escalationData = event.data?.data();
      const escalationId = event.params.escalationId;

      if (!escalationData) {
        console.log("No escalation data found");
        return;
      }

      console.log(`🆕 New escalation created: ${escalationId}`);

      const question = escalationData.question || "New question";
      const userId = escalationData.userId;

      // Get user's name
      let userName = "A user";
      if (userId) {
        try {
          const userDoc = await db.collection("users").doc(userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            userName = userData?.name || userName;
          }
        } catch (e) {
          console.log("Could not fetch user name:", e);
        }
      }

      const notificationTitle = "New Escalated Question";
      const notificationBody = `${userName} needs help: ${question.substring(0, 80)}${question.length > 80 ? '...' : ''}`;

      // ✅ Create Firestore notification for ALL STAFF
      await createFirestoreNotifications(
        'staff',
        notificationTitle,
        notificationBody,
        'new_escalation',
        {
          escalationId: escalationId,
          question: question,
          userId: userId,
        }
      );

      // ✅ Send FCM to mobile staff devices
      const staffSnapshot = await db
        .collection("users")
        .where("role", "==", "staff")
        .get();

      if (!staffSnapshot.empty) {
        await sendFCMNotifications(
          staffSnapshot.docs.map(doc => doc.id),
          notificationTitle,
          notificationBody,
          {
            type: "new_escalation",
            escalationId: escalationId,
          }
        );
      }

      return {success: true};
    } catch (error) {
      console.error("Error creating escalation notification for staff:", error);
      return {success: false, error: error};
    }
  }
);

// ✅ UPDATED: Notify user when staff REPLIES to escalation
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

      // Check if staff has replied
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

      const notificationTitle = "Staff Response to Your Escalation";
      let notificationBody = `Re: ${question.substring(0, 60)}`;
      if (question.length > 60) {
        notificationBody += "...";
      }

      // ✅ Create Firestore notification for the USER
      await createFirestoreNotifications(
        'user',
        notificationTitle,
        notificationBody,
        'escalation_reply',
        {
          escalationId: escalationId,
          question: question,
          staffReply: staffReply,
        }
      );

      // ✅ Send FCM to user's mobile device
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