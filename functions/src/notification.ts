import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

// ✅ Get FCM tokens grouped by userId
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
      `📝 Creating notifications for ${userIds.length} ${targetRole} users`
    );

    // ✅ Build unique notification key
    let uniqueKey = `${type}`;
    if (data.announcementId) {
      uniqueKey += `-${data.announcementId}`;
    } else if (data.escalationId) {
      uniqueKey += `-${data.escalationId}`;
    }
    if (data.reminderDate) {
      uniqueKey += `-${data.reminderDate}`;
    }
    if (data.eventId) {
      uniqueKey += `-${data.eventId}`;
    }

    console.log(`🔑 Using unique key: ${uniqueKey}`);

    let batch = db.batch();
    let batchCount = 0;
    let totalCreated = 0;

    for (const userId of userIds) {
      // ✅ Create deterministic notification ID
      const notificationId = `${userId}_${uniqueKey}`;
      const notificationRef = db.collection("notifications").doc(notificationId);

      // ✅ Use set with merge to prevent duplicates (idempotent operation)
      batch.set(
        notificationRef,
        {
          notificationId: notificationId,
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
        },
        { merge: true }
      );

      totalCreated++;
      batchCount++;

      if (batchCount >= 500) {
        await batch.commit();
        console.log(`✅ Committed batch of ${batchCount} notifications`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
      console.log(`✅ Committed final batch of ${batchCount} notifications`);
    }

    console.log(
      `✅ Processed ${totalCreated} notifications (duplicates automatically prevented by document ID)`
    );
    return totalCreated;
  } catch (error) {
    console.error("❌ Error creating Firestore notifications:", error);
    return 0;
  }
}

function formatDeadlineForNotification(deadline: admin.firestore.Timestamp | null): string {
  if (!deadline || typeof deadline.toDate !== 'function') {
    return '';
  }

  try {
    const deadlineDate = deadline.toDate();
    return deadlineDate.toLocaleDateString("en-US", {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  } catch (error) {
    console.error('Error formatting deadline:', error);
    return '';
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

export const onAnnouncementCreated = onDocumentCreated(
  {
    document: "announcements/{announcementId}",
    region: "us-central1",
    retry: false, // ✅ Don't retry on failure to prevent duplicates
  },
  async (event) => {
    const announcementId = event.params.announcementId;
    
    console.log(`📢 onAnnouncementCreated triggered for: ${announcementId}`);
    console.log(`📢 Event ID: ${event.id}`);
    
    try {
      const announcementData = event.data?.data();

      if (!announcementData || announcementData.deleted === true) {
        console.log("Announcement is deleted or invalid, skipping");
        return;
      }

      // ✅ CRITICAL: Use idempotency key based on event ID
      const idempotencyRef = db.collection("notification_processing")
        .doc(`announcement_${announcementId}_${event.id}`);
      
      // ✅ Try to create idempotency record
      try {
        await idempotencyRef.create({
          announcementId: announcementId,
          eventId: event.id,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "processing"
        });
        console.log(`✅ Idempotency lock acquired for ${announcementId}`);
      } catch (error: any) {
        if (error.code === 6) { // ALREADY_EXISTS
          console.log(`⚠️ Notification already being processed for ${announcementId} (event: ${event.id})`);
          return { success: false, reason: "already_processing" };
        }
        throw error;
      }

      // ✅ Double-check notification_sent flag
      const announcementRef = db.collection("announcements").doc(announcementId);
      const currentDoc = await announcementRef.get();
      
      if (currentDoc.data()?.notification_sent === true) {
        console.log(`⚠️ Notification already sent for ${announcementId}, skipping`);
        await idempotencyRef.update({ status: "skipped_already_sent" });
        return { success: false, reason: "already_sent" };
      }

      // ✅ Mark as sent BEFORE creating notifications
      await announcementRef.update({
        notification_sent: true,
        notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
        notification_event_id: event.id,
      });
      
      console.log(`✅ Marked announcement ${announcementId} as notification_sent`);

      const message = announcementData.message || "New announcement posted";
      const category = announcementData.category || "General";
      const deadline = announcementData.deadline || null;

      const notificationTitle = `New ${category} Announcement`;
      let notificationBody = message.substring(0, 100);
      if (message.length > 100) {
        notificationBody += "...";
      }

      const formattedDeadline = formatDeadlineForNotification(deadline);
      if (formattedDeadline) {
        notificationBody += ` | Deadline: ${formattedDeadline}`;
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
          deadline: deadline ? deadline.toMillis().toString() : null,
          message: message,
          eventId: event.id, // ✅ Pass event ID for extra uniqueness
        }
      );

      console.log(`✅ Created ${notificationsCreated} notifications`);

      // ✅ Update idempotency record
      await idempotencyRef.update({ 
        status: "completed",
        notificationsCreated: notificationsCreated,
        completedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send FCM after Firestore notifications are created
      if (notificationsCreated > 0) {
        await sendFCMNotifications(userIds, notificationTitle, notificationBody, {
          type: "announcement",
          announcementId: announcementId,
          category: category,
        });
      }

      return { success: true, notificationsCreated, eventId: event.id };
    } catch (error) {
      console.error("Error creating announcement notification:", error);
      
      // ✅ Mark idempotency record as failed
      try {
        const idempotencyRef = db.collection("notification_processing")
          .doc(`announcement_${event.params.announcementId}_${event.id}`);
        await idempotencyRef.update({ 
          status: "failed",
          error: String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      } catch (e) {
        console.error("Failed to update idempotency record:", e);
      }
      
      return { success: false, error: error };
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
    let totalNotificationsCreated = 0;
    const processedAnnouncements = [];

    try {
      console.log("🔍 Checking for upcoming deadlines...");
      console.log(
        `📅 Current time: ${new Date().toLocaleString("en-PH", {
          timeZone: "Asia/Manila",
        })}`
      );

      const now = new Date(
        new Date().toLocaleString("en-US", { timeZone: "Asia/Manila" })
      );
      now.setHours(0, 0, 0, 0);
      const reminderDateKey = now.toISOString().substring(0, 10);

      console.log(`📅 Today (Manila): ${reminderDateKey}`);

      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();
      const allUserIds = usersSnapshot.docs.map((doc) => doc.id);
      if (allUserIds.length === 0) {
        console.log("ℹ️ No active users found. Exiting.");
        return;
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

      for (const announcementDoc of announcementsSnapshot.docs) {
        const data = announcementDoc.data();
        const announcementId = announcementDoc.id;

        const { deadline, message = "", category = "General" } = data;

        if (!deadline || typeof deadline.toDate !== 'function') {
          console.log(`⚠️ No valid Firestore Timestamp deadline for ${announcementId}`);
          continue;
        }

        const deadlineDate = deadline.toDate();
        const deadlineLocal = new Date(
          deadlineDate.toLocaleString("en-US", { timeZone: "Asia/Manila" })
        );
        deadlineLocal.setHours(0, 0, 0, 0);

        const diffMs = deadlineLocal.getTime() - now.getTime();
        const daysUntilDeadline = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(
          `📅 ${announcementId}: ${daysUntilDeadline} days until ${deadlineLocal.toDateString()}`
        );

        if (daysUntilDeadline === 3) {
          console.log(`⏰ Deadline approaching in 3 days: ${announcementId}`);

          const title = `⏰ Deadline Reminder: ${category}`;
          const formattedDate = deadlineLocal.toLocaleDateString("en-US", {
            month: 'short',
            day: 'numeric',
            year: 'numeric',
          });
          const body = `${message.substring(0, 80)}${
            message.length > 80 ? "..." : ""
          } | Deadline in 3 days: ${formattedDate}`;

          const notificationsCreated = await createNotificationsForUsers(
            allUserIds,
            "user",
            title,
            body,
            "deadline_reminder",
            {
              announcementId,
              category,
              deadline: deadlineLocal.toISOString(),
              message,
              daysUntilDeadline: 3,
              reminderDate: reminderDateKey,
            }
          );

          totalNotificationsCreated += notificationsCreated;
          processedAnnouncements.push({
            id: announcementId,
            category,
            deadline: deadlineLocal.toISOString(),
            notificationsSent: notificationsCreated,
          });

          if (notificationsCreated > 0) {
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

      console.log(
        `✅ Done. Created ${totalNotificationsCreated} notifications in total.`
      );
      console.log("📊 Processed announcements:", processedAnnouncements);
    } catch (error) {
      console.error("❌ Error checking deadlines:", error);
      throw error;
    }
  }
);

export const cleanupDuplicateNotifications = onSchedule(
  {
    schedule: "0 3 * * *",
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

      const seen = new Map<string, string>();
      const toDelete: string[] = [];

      notifications.forEach((doc) => {
        const data = doc.data();
        const userId = data.userId;
        const announcementId = data.data?.announcementId || data.announcementId;
        const escalationId = data.data?.escalationId || data.escalationId;
        const type = data.type;
        const reminderDate = data.data?.reminderDate;

        let key = `${userId}-${type}`;
        if (announcementId) {
          key += `-${announcementId}`;
        } else if (escalationId) {
          key += `-${escalationId}`;
        }
        if (reminderDate) {
          key += `-${reminderDate}`;
        }

        if (seen.has(key)) {
          toDelete.push(doc.id);
          console.log(
            `🗑️ Duplicate found: ${doc.id} (user: ${userId}, type: ${type})`
          );
        } else {
          seen.set(key, doc.id);
        }
      });

      if (toDelete.length > 0) {
        console.log(`🗑️ Deleting ${toDelete.length} duplicate notifications`);

        let batch = db.batch();
        let batchCount = 0;

        toDelete.forEach((docId) => {
          batch.delete(db.collection("notifications").doc(docId));
          batchCount++;

          if (batchCount >= 500) {
            batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        });

        if (batchCount > 0) {
          await batch.commit();
        }

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
      console.log("🧹 Cleaning up old notifications and idempotency records...");

      // Clean old notifications (30 days)
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      const oldNotificationsSnapshot = await db
        .collection("notifications")
        .where("createdAt", "<", thirtyDaysAgo)
        .limit(500)
        .get();

      if (!oldNotificationsSnapshot.empty) {
        const batch = db.batch();
        oldNotificationsSnapshot.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(
          `✅ Deleted ${oldNotificationsSnapshot.size} old notifications`
        );
      } else {
        console.log("ℹ️ No old notifications to delete");
      }

      // Clean old idempotency records (7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const oldProcessingSnapshot = await db
        .collection("notification_processing")
        .where("processedAt", "<", sevenDaysAgo)
        .limit(500)
        .get();

      if (!oldProcessingSnapshot.empty) {
        const batch = db.batch();
        oldProcessingSnapshot.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(
          `✅ Deleted ${oldProcessingSnapshot.size} old idempotency records`
        );
      } else {
        console.log("ℹ️ No old idempotency records to delete");
      }
    } catch (error) {
      console.error("Error cleaning up:", error);
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
      const responderRole = afterData.respondedByRole || "staff";

      if (!userId) {
        console.log("No userId found in escalation");
        return;
      }

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