import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

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
      const date = new Date(
        `${slashFormat[3]}-${slashFormat[1]}-${slashFormat[2]}`
      );
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

// ✅ FIXED: Get FCM tokens grouped by userId
async function getUserFCMTokens(
  userIds: string[]
): Promise<Map<string, string[]>> {
  try {
    const userTokensMap = new Map<string, string[]>();

    for (let i = 0; i < userIds.length; i += 10) {
      const batch = userIds.slice(i, i + 10);

      const tokensSnapshot = await db
        .collection("fcm_tokens")
        .where("userId", "in", batch)
        .get();

      tokensSnapshot.forEach((doc) => {
        const data = doc.data();
        const userId = data.userId;
        const tokens = data.tokens || [];

        const mobileTokens = tokens.filter(
          (token: string) => !token.startsWith("web_") && token.length > 10
        );

        if (mobileTokens.length > 0) {
          userTokensMap.set(userId, mobileTokens);
        }
      });
    }

    return userTokensMap;
  } catch (error) {
    console.error("❌ Error getting user FCM tokens:", error);
    return new Map();
  }
}

async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: { [key: string]: string }
): Promise<void> {
  try {
    const userTokensMap = await getUserFCMTokens(userIds);

    if (userTokensMap.size === 0) {
      console.log("ℹ️ No mobile FCM tokens found");
      return;
    }

    const allTokens: string[] = [];
    userTokensMap.forEach((tokens) => {
      allTokens.push(...tokens);
    });

    if (allTokens.length === 0) {
      console.log("ℹ️ No valid mobile FCM tokens");
      return;
    }

    console.log(
      `📱 Sending FCM to ${allTokens.length} mobile devices (${userTokensMap.size} users)`
    );

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      tokens: allTokens,
      android: {
        priority: "high" as const,
        notification: {
          channelId:
            data.type === "deadline_reminder"
              ? "deadline_reminders"
              : data.type === "escalation_reply" ||
                data.type === "new_escalation"
              ? "escalations"
              : "announcements",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log(
      `✅ FCM sent: ${response.successCount} successful, ${response.failureCount} failed`
    );

    if (response.failureCount > 0) {
      const tokensToRemove = new Map<string, string[]>();

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          console.error(
            `❌ Failed to send to token ${idx}:`,
            error?.code,
            error?.message
          );

          if (
            error?.code === "messaging/invalid-registration-token" ||
            error?.code === "messaging/registration-token-not-registered"
          ) {
            const failedToken = allTokens[idx];

            userTokensMap.forEach((tokens, userId) => {
              if (tokens.includes(failedToken)) {
                if (!tokensToRemove.has(userId)) {
                  tokensToRemove.set(userId, []);
                }
                tokensToRemove.get(userId)!.push(failedToken);
              }
            });
          }
        }
      });

      if (tokensToRemove.size > 0) {
        console.log(
          `🗑️ Removing invalid tokens from ${tokensToRemove.size} users`
        );
        const batch = db.batch();

        tokensToRemove.forEach((tokens, userId) => {
          const userTokenRef = db.collection("fcm_tokens").doc(userId);
          batch.update(userTokenRef, {
            tokens: admin.firestore.FieldValue.arrayRemove(...tokens),
          });
        });

        await batch.commit();
      }
    }
  } catch (error) {
    console.error("❌ Error sending FCM notifications:", error);
  }
}

// ✅ FIXED: Create only ONE notification per user
async function createNotificationsForUsers(
  userIds: string[],
  targetRole: string,
  title: string,
  body: string,
  type: string,
  data: { [key: string]: any }
): Promise<number> {
  try {
    console.log(
      `📝 Creating ${userIds.length} notifications for ${targetRole}`
    );

    const batch = db.batch();
    let count = 0;
    const notificationsToCreate: string[] = [];

    // ✅ Step 1: Check for existing notifications in bulk
    if (data.announcementId) {
      console.log(
        `🔍 Checking for existing notifications for announcement: ${data.announcementId}`
      );

      const existingNotifications = await db
        .collection("notifications")
        .where("data.announcementId", "==", data.announcementId)
        .where("type", "==", type)
        .select("userId") // Only fetch userId field for efficiency
        .get();

      const existingUserIds = new Set(
        existingNotifications.docs.map((doc) => doc.data().userId)
      );

      console.log(`ℹ️ Found ${existingUserIds.size} existing notifications`);

      // Filter out users who already have this notification
      for (const userId of userIds) {
        if (!existingUserIds.has(userId)) {
          notificationsToCreate.push(userId);
        }
      }

      console.log(
        `📝 Will create ${notificationsToCreate.length} new notifications`
      );
    } else {
      // If no announcementId, create for all users (escalations, etc.)
      notificationsToCreate.push(...userIds);
    }

    // ✅ Step 2: Create notifications only for users who don't have them
    for (const userId of notificationsToCreate) {
      const notificationRef = db.collection("notifications").doc();

      batch.set(notificationRef, {
        userId: userId,
        targetRole: targetRole,
        title: title,
        body: body,
        type: type,
        escalationId: data.escalationId || null,
        announcementId: data.announcementId || null,
        conversationId: data.conversationId || null,
        data: data,
        readBy: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      count++;

      // Commit in batches of 500 (Firestore limit)
      if (count % 500 === 0) {
        await batch.commit();
      }
    }

    // Commit remaining notifications
    if (count % 500 !== 0) {
      await batch.commit();
    }

    console.log(
      `✅ Created ${count} Firestore notifications (1 per user, no duplicates)`
    );
    return count;
  } catch (error) {
    console.error("❌ Error creating Firestore notifications:", error);
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
        console.log("Announcement is deleted or invalid, skipping");
        return;
      }

      // ✅ CRITICAL FIX: Check if we already sent notifications for this announcement
      const existingNotifications = await db
        .collection("notifications")
        .where("data.announcementId", "==", announcementId)
        .where("type", "==", "announcement")
        .limit(1)
        .get();

      if (!existingNotifications.empty) {
        console.log(
          `⚠️ Notifications already sent for announcement ${announcementId}, skipping`
        );
        return;
      }

      console.log(
        `📢 New announcement: ${announcementId} - Processing notifications`
      );

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

      const userIds = usersSnapshot.docs.map((doc) => doc.id);

      console.log(
        `📤 Creating notifications for ${userIds.length} active users`
      );

      const notificationsCreated = await createNotificationsForUsers(
        userIds,
        "user",
        notificationTitle,
        notificationBody,
        "announcement",
        {
          announcementId: announcementId,
          category: category,
          deadline: deadline,
          message: message,
        }
      );

      console.log(`✅ Created ${notificationsCreated} notifications`);

      // Send FCM after Firestore notifications are created
      await sendFCMNotifications(userIds, notificationTitle, notificationBody, {
        type: "announcement",
        announcementId: announcementId,
        category: category,
      });

      return { success: true, notificationsCreated };
    } catch (error) {
      console.error("Error creating announcement notification:", error);
      return { success: false, error: error };
    }
  }
);

export const checkUpcomingDeadlines = onSchedule(
  // 1. Correct Options Object (First Argument)
  {
    schedule: "0 9 * * *", // Run daily at 9AM Manila time
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  // 2. Correct Handler Function (Second Argument) - Must return Promise<void>
  async (event) => {
    let totalNotificationsCreated = 0;
    const processedAnnouncements = [];

    try {
      console.log("🔍 Checking for upcoming deadlines...");
      console.log(
        `📅 Current time: ${new Date().toLocaleString("en-PH", {
          timeZone: "Asia/Manila",
        })}`
      );

      // 🔹 Use Manila timezone date for today (not UTC)
      const now = new Date(
        new Date().toLocaleString("en-US", { timeZone: "Asia/Manila" })
      );
      now.setHours(0, 0, 0, 0);
      const reminderDateKey = now.toISOString().substring(0, 10); // e.g., '2025-11-12'

      // 1. Get all active users once
      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();
      const allUserIds = usersSnapshot.docs.map((doc) => doc.id);
      if (allUserIds.length === 0) {
        console.log("ℹ️ No active users found. Exiting.");
        return; // Return void/Promise<void>
      }
      console.log(`👤 Found ${allUserIds.length} active users.`);

      const announcementsSnapshot = await db
        .collection("announcements")
        .where("deleted", "==", false)
        .where("deadline", "!=", null)
        .get();

      console.log(
        `📋 Found ${announcementsSnapshot.size} announcements with deadlines`
      );

      // ✅ Use a single master batch for all writes
      let masterBatch = db.batch(); // Initialize the batch
      let batchCount = 0;

      for (const announcementDoc of announcementsSnapshot.docs) {
        const data = announcementDoc.data();
        const announcementId = announcementDoc.id;

        const { deadline, message = "", category = "General" } = data;
        const deadlineDate = parseDeadline(deadline);
        if (!deadlineDate) {
          console.log(
            `⚠️ Could not parse deadline for ${announcementId}: ${deadline}`
          );
          continue;
        }

        // 🔹 Convert to Manila timezone start of day
        const deadlineLocal = new Date(
          deadlineDate.toLocaleString("en-US", { timeZone: "Asia/Manila" })
        );
        deadlineLocal.setHours(0, 0, 0, 0);

        // 🔹 Compute days difference correctly
        const diffMs = deadlineLocal.getTime() - now.getTime();
        const daysUntilDeadline = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(
          `📅 ${announcementId}: ${daysUntilDeadline} days until ${deadlineLocal.toDateString()}`
        );

        // ✅ Send notification if exactly 3 days away
        if (daysUntilDeadline === 3) {
          console.log(`⏰ Deadline approaching in 3 days: ${announcementId}`);

          // 🔹 CRITICAL: Check for duplicates based on announcementId AND the specific reminder date
          const existingNotification = await db
            .collection("notifications")
            .where("data.announcementId", "==", announcementId)
            .where("type", "==", "deadline_reminder")
            .where("data.reminderDate", "==", reminderDateKey)
            .limit(1)
            .get();

          if (!existingNotification.empty) {
            console.log(
              `ℹ️ Reminder already sent for ${announcementId} on ${reminderDateKey}`
            );
            continue;
          }

          const title = `⏰ Deadline Reminder: ${category}`;
          const body = `${message.substring(0, 80)}${
            message.length > 80 ? "..." : ""
          } | Deadline in 3 days: ${deadlineLocal.toDateString()}`;

          // Add notifications to the master batch
          for (const uid of allUserIds) {
            const notifRef = db.collection("notifications").doc();

            masterBatch.set(notifRef, {
              userId: uid,
              role: "user",
              title,
              body,
              type: "deadline_reminder",
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              data: {
                announcementId,
                category,
                deadline: deadlineLocal.toISOString(),
                message,
                daysUntilDeadline: 3,
                reminderDate: reminderDateKey,
                reminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
              },
              read: false,
              deleted: false,
            });
            batchCount++;

            // Commit in batches of 500 (Firestore limit)
            if (batchCount % 500 === 0) {
              await masterBatch.commit();
              console.log(`➡️ Committed batch of ${batchCount} notifications.`);
              // Create a new batch for the remainder
              masterBatch = db.batch(); // Reinitialize the batch
            }
          }

          totalNotificationsCreated += allUserIds.length;
          processedAnnouncements.push({
            id: announcementId,
            category,
            deadline: deadlineLocal.toISOString(),
            notificationsSent: allUserIds.length,
          });

          // 🔹 Send FCM notifications
          if (typeof sendFCMNotifications === "function") {
            const fcmData = {
              type: "deadline_reminder",
              announcementId,
              category,
              daysUntilDeadline: "3",
            };

            await sendFCMNotifications(allUserIds, title, body, fcmData);
          }
        }
      }

      // Commit remaining notifications
      if (batchCount > 0 && batchCount % 500 !== 0) {
        await masterBatch.commit();
      }

      console.log(
        `✅ Done. Created ${totalNotificationsCreated} notifications in total.`
      );
      console.log("📊 Processed announcements:", processedAnnouncements);

      // Successfully complete the function (returns Promise<void>)
    } catch (error) {
      console.error("❌ Error checking deadlines:", error);
      // Throwing the error signals failure to the Cloud Functions runtime
      throw error;
    }
  }
);

export const cleanupDuplicateNotifications = onSchedule(
  {
    schedule: "0 3 * * *", // Run at 3 AM daily

    timeZone: "Asia/Manila",

    region: "us-central1",
  },

  async (event) => {
    try {
      console.log("🧹 Checking for duplicate notifications...");

      const notifications = await db

        .collection("notifications")

        .orderBy("createdAt", "desc")

        .get();

      const seen = new Map<string, string>(); // key: userId-announcementId-type, value: docId

      const toDelete: string[] = [];

      notifications.forEach((doc) => {
        const data = doc.data();

        const userId = data.userId;

        const announcementId = data.data?.announcementId || data.announcementId;

        const type = data.type;

        if (announcementId) {
          const key = `${userId}-${announcementId}-${type}`;

          if (seen.has(key)) {
            // This is a duplicate

            toDelete.push(doc.id);

            console.log(
              `🗑️ Duplicate found: ${doc.id} (user: ${userId}, announcement: ${announcementId})`
            );
          } else {
            seen.set(key, doc.id);
          }
        }
      });

      if (toDelete.length > 0) {
        console.log(`🗑️ Deleting ${toDelete.length} duplicate notifications`);

        const batch = db.batch();

        toDelete.forEach((docId) => {
          batch.delete(db.collection("notifications").doc(docId));
        });

        await batch.commit();

        console.log(`✅ Deleted ${toDelete.length} duplicates`);
      } else {
        console.log("✅ No duplicates found");
      }
    } catch (error) {
      console.error("❌ Error cleaning up duplicates:", error);
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
      oldNotificationsSnapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();

      console.log(
        `✅ Deleted ${oldNotificationsSnapshot.size} old notifications`
      );
    } catch (error) {
      console.error("Error cleaning up notifications:", error);
    }
  }
);

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

      console.log(`🆕 New escalation: ${escalationId}`);

      const question = escalationData.question || "New question";
      const userId = escalationData.userId;
      const conversationId = escalationData.conversationId || null;

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
      const notificationBody = `${userName} needs help: ${question.substring(
        0,
        80
      )}${question.length > 80 ? "..." : ""}`;

      const staffSnapshot = await db
        .collection("users")
        .where("role", "==", "staff")
        .get();

      const adminSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .get();

      if (staffSnapshot.empty) {
        console.log("⚠️ No staff members found");
        return;
      }

      if (adminSnapshot.empty) {
        console.log("⚠️ No admin found");
        return;
      }

      const staffIds = staffSnapshot.docs.map((doc) => doc.id);
      const adminIds = adminSnapshot.docs.map((doc) => doc.id);

      await createNotificationsForUsers(
        staffIds,
        "staff",
        notificationTitle,
        notificationBody,
        "new_escalation",
        {
          escalationId: escalationId,
          question: question,
          userId: userId,
          conversationId: conversationId,
        }
      );

      await createNotificationsForUsers(
        adminIds,
        "admin",
        notificationTitle,
        notificationBody,
        "new_escalation",
        {
          escalationId: escalationId,
          question: question,
          userId: userId,
          conversationId: conversationId,
        }
      );

      await sendFCMNotifications(
        staffIds,
        notificationTitle,
        notificationBody,
        {
          type: "new_escalation",
          escalationId: escalationId,
          conversationId: conversationId || "",
        }
      );

      await sendFCMNotifications(
        adminIds,
        notificationTitle,
        notificationBody,
        {
          type: "new_escalation",
          escalationId: escalationId,
          conversationId: conversationId || "",
        }
      );

      console.log(
        `✅ Notifications sent with escalationId: ${escalationId}, conversationId: ${conversationId}`
      );
      return { success: true };
    } catch (error) {
      console.error("Error creating escalation notification:", error);
      return { success: false, error: error };
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

      // Detect if a new reply or resolution has occurred
      const hasNewReply =
        (afterData.staffResponse && !beforeData.staffResponse) ||
        (afterData.status === "resolved" &&
          beforeData.status !== "resolved" &&
          afterData.staffResponse);

      if (!hasNewReply) {
        console.log("No new staff reply detected");
        return;
      }

      console.log(`💬 Staff or Admin replied to escalation: ${escalationId}`);

      const userId = afterData.userId;
      const question = afterData.question || "Your question";
      const staffResponse = afterData.staffResponse || null;
      const adminResponse = afterData.adminResponse || null;
      const conversationId = afterData.conversationId || null;
      const responderRole = afterData.respondedByRole || "staff"; // optional field to determine who replied

      if (!userId) {
        console.log("No userId found in escalation");
        return;
      }

      // Determine notification title and message based on responder
      const notificationTitle =
        responderRole === "admin"
          ? "Admin Response to Your Escalation"
          : "Staff Response to Your Escalation";

      let notificationBody = `Question: ${question.substring(0, 60)}`;
      if (question.length > 60) notificationBody += "...";

      const responseMessage =
        responderRole === "admin"
          ? adminResponse || "Admin has responded."
          : staffResponse || "Staff has responded.";

      // Create Firestore notification
      await createNotificationsForUsers(
        [userId],
        "user",
        notificationTitle,
        `${notificationBody}\n\n${responseMessage}`,
        "escalation_reply",
        {
          escalationId,
          question,
          staffResponse,
          adminResponse,
          conversationId,
        }
      );

      // Send FCM push notification
      await sendFCMNotifications(
        [userId],
        notificationTitle,
        `${notificationBody}\n\n${responseMessage}`,
        {
          type: "escalation_reply",
          escalationId,
          conversationId: conversationId || "",
        }
      );

      console.log(
        `✅ Reply notification sent (${responderRole}) with escalationId: ${escalationId}`
      );
      return { success: true, userId };
    } catch (error) {
      console.error("Error creating escalation reply notification:", error);
      return { success: false, error };
    }
  }
);
