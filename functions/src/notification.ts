import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

// Initialize if not already done
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ============================================================================
// SEND NOTIFICATION WHEN NEW ANNOUNCEMENT IS CREATED
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

      // Skip if announcement is marked as deleted
      if (announcementData.deleted === true) {
        console.log("Announcement is deleted, skipping notification");
        return;
      }

      console.log(`📢 New announcement created: ${announcementId}`);

      const message = announcementData.message || "New announcement posted";
      const category = announcementData.category || "General";
      const deadline = announcementData.deadline || null;

      // Create notification title and body
      const notificationTitle = `New ${category} Announcement`;
      let notificationBody = message.substring(0, 100);
      if (message.length > 100) {
        notificationBody += "...";
      }

      // Add deadline info if available
      if (deadline) {
        notificationBody += ` | Deadline: ${deadline}`;
      }

      // Get all users to send notification to
      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();

      console.log(`📤 Sending notification to ${usersSnapshot.size} users`);

      // Create notification documents for each user
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

        // Commit in batches of 500 (Firestore limit)
        if (notificationCount % 500 === 0) {
          await batch.commit();
        }
      }

      // Commit remaining notifications
      if (notificationCount % 500 !== 0) {
        await batch.commit();
      }

      console.log(`✅ Created ${notificationCount} notification documents`);

      // Send FCM notifications to devices
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

// ============================================================================
// CHECK FOR UPCOMING DEADLINES (Runs daily at 9 AM Manila time)
// ============================================================================

export const checkUpcomingDeadlines = onSchedule(
  {
    schedule: "0 9 * * *", // Every day at 9:00 AM
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    try {
      console.log("🔍 Checking for upcoming deadlines...");

      // Get current date
      const now = new Date();
      const threeDaysFromNow = new Date();
      threeDaysFromNow.setDate(now.getDate() + 3);

      // Get all active announcements with deadlines
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

        // Parse deadline
        const deadlineDate = parseDeadline(deadline);

        if (!deadlineDate) {
          console.log(`⚠️ Could not parse deadline for ${announcementId}: ${deadline}`);
          continue;
        }

        // Check if deadline is exactly 3 days away (within a 24-hour window)
        const daysUntilDeadline = Math.ceil(
          (deadlineDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)
        );

        console.log(`📅 Announcement ${announcementId}: ${daysUntilDeadline} days until deadline`);

        // Send notification if deadline is in 3 days
        if (daysUntilDeadline === 3) {
          console.log(`⏰ Deadline approaching for announcement: ${announcementId}`);

          // Check if we already sent a notification for this deadline
          const existingNotification = await db
            .collection("notifications")
            .where("announcementId", "==", announcementId)
            .where("type", "==", "deadline_reminder")
            .get();

          if (!existingNotification.empty) {
            console.log(`ℹ️ Already sent deadline notification for ${announcementId}`);
            continue;
          }

          // Create notification
          const notificationTitle = `⏰ Deadline Reminder: ${category}`;
          let notificationBody = `${message.substring(0, 80)}... | Deadline in 3 days: ${deadline}`;

          // Get all users
          const usersSnapshot = await db
            .collection("users")
            .where("isActive", "==", true)
            .get();

          console.log(`📤 Sending deadline reminder to ${usersSnapshot.size} users`);

          // Create notification documents
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

          // Send FCM notifications
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

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Parse deadline string into Date object
 */
function parseDeadline(deadlineStr: string): Date | null {
  if (!deadlineStr) return null;

  try {
    // Try to parse common date formats
    // Format: "December 15, 2024" or "Dec 15, 2024"
    const monthDayYear = deadlineStr.match(/(\w+)\s+(\d{1,2}),?\s+(\d{4})/);
    if (monthDayYear) {
      const dateString = `${monthDayYear[1]} ${monthDayYear[2]}, ${monthDayYear[3]}`;
      const date = new Date(dateString);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }

    // Format: "15/12/2024" or "12/15/2024"
    const slashFormat = deadlineStr.match(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
    if (slashFormat) {
      // Assume MM/DD/YYYY format (US standard)
      const date = new Date(`${slashFormat[3]}-${slashFormat[1]}-${slashFormat[2]}`);
      if (!isNaN(date.getTime())) {
        return date;
      }
    }

    // Try direct Date parsing as last resort
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

/**
 * Send FCM push notifications to user devices
 */
async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: {[key: string]: string}
): Promise<void> {
  try {
    // Get FCM tokens for all users
    const tokensSnapshot = await db
      .collection("fcm_tokens")
      .where("userId", "in", userIds.slice(0, 10)) // Firestore 'in' limit is 10
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

    // Send multicast message
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

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const tokensToDelete: string[] = [];

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          // Check if the error is due to invalid token
          if (
            error?.code === "messaging/invalid-registration-token" ||
            error?.code === "messaging/registration-token-not-registered"
          ) {
            tokensToDelete.push(tokens[idx]);
          }
        }
      });

      // Delete invalid tokens
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
// OPTIONAL: CLEAN UP OLD NOTIFICATIONS (Runs daily)
// ============================================================================

export const cleanupOldNotifications = onSchedule(
  {
    schedule: "0 2 * * *", // Every day at 2:00 AM
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    try {
      console.log("🧹 Cleaning up old notifications...");

      // Delete notifications older than 30 days
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotificationsSnapshot = await db
        .collection("notifications")
        .where("createdAt", "<", thirtyDaysAgo)
        .limit(500) // Process in batches
        .get();

      if (oldNotificationsSnapshot.empty) {
        console.log("ℹ️ No old notifications to delete");
        return {success: true, deleted: 0};
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