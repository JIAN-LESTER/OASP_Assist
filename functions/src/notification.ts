import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

//  Get FCM tokens grouped by userId
async function getUserFCMTokens(
  userIds: string[]
): Promise<Map<string, string[]>> {
  try {
    console.log(` Fetching FCM tokens for users: ${userIds.join(", ")}`);

    const userTokensMap = new Map<string, string[]>();
    const allSeenTokens = new Set<string>();

    for (let i = 0; i < userIds.length; i += 10) {
      const batch = userIds.slice(i, i + 10);
      console.log(` Fetching token batch: ${batch.join(", ")}`);

      const tokensSnapshot = await db
        .collection("fcm_tokens")
        .where("userId", "in", batch)
        .get();

      console.log(` Found ${tokensSnapshot.size} token documents for this batch`);

      tokensSnapshot.forEach((doc) => {
        const data = doc.data();
        const userId = data.userId;

        //  CRITICAL: Verify this userId is in our requested list
        if (!userIds.includes(userId)) {
          console.warn(` WARNING: Token for user ${userId} found but NOT in requested list [${userIds.join(", ")}]!`);
          return; // Skip this token
        }

        const rawTokens = Array.isArray(data.tokens) ? data.tokens : [];
        const tokens: string[] = rawTokens
          .map((t) => (typeof t === "string" ? t : String(t)))
          .filter((t) => t && t.length > 0);

        const mobileTokens = tokens.filter(
          (token: string) => !token.startsWith("web_") && token.length > 10
        );

        const uniqueTokens = [...new Set(mobileTokens)].filter(
          (token: string) => !allSeenTokens.has(token)
        );

        uniqueTokens.forEach((token) => allSeenTokens.add(token));

        if (uniqueTokens.length > 0) {
          console.log(` User ${userId}: ${uniqueTokens.length} mobile tokens`);
          userTokensMap.set(userId, uniqueTokens);
        }
      });
    }

    console.log(` Total: ${userTokensMap.size} users with ${allSeenTokens.size} unique tokens`);
    console.log(` Users with tokens: ${Array.from(userTokensMap.keys()).join(", ")}`);
    return userTokensMap;
  } catch (error) {
    console.error(" Error getting user FCM tokens:", error);
    return new Map();
  }
}

async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: { [key: string]: string },
  targetRole?: string,
  targetUserId?: string
): Promise<void> {
  try {
    console.log(" ===== sendFCMNotifications CALLED =====");
    console.log(`   Users: [${userIds.join(", ")}]`);
    console.log(`   Target Role: ${targetRole || "any"}`);
    console.log(`   Target User: ${targetUserId || "none"}`);
    console.log(`   Type: ${data.type}`);
    console.log(`   Title: ${title}`);

    //  FIX: Only get tokens for the SPECIFIC userIds provided
    // This is the critical fix - we were getting tokens for all users before
    const userTokensMap = await getUserFCMTokens(userIds);

    if (userTokensMap.size === 0) {
      console.log(" No mobile FCM tokens found for any user");
      console.log(`   Searched for users: [${userIds.join(", ")}]`);
      return;
    }

    console.log(` Found tokens for ${userTokensMap.size} users`);
    userTokensMap.forEach((tokens, userId) => {
      console.log(`   User ${userId}: ${tokens.length} tokens`);
    });

    //  ADDITIONAL FIX: Verify tokens belong to intended users
    const allTokens: string[] = [];
    const seenTokens = new Set<string>();

    userTokensMap.forEach((tokens, userId) => {
      // Double-check this userId is in our intended list
      if (!userIds.includes(userId)) {
        console.warn(` WARNING: Skipping tokens for user ${userId} - not in intended list`);
        return;
      }

      tokens.forEach((token) => {
        if (!seenTokens.has(token)) {
          seenTokens.add(token);
          allTokens.push(token);
        }
      });
    });

    if (allTokens.length === 0) {
      console.log(" No valid mobile FCM tokens");
      return;
    }

    console.log(
      ` Sending FCM to ${allTokens.length} unique mobile devices for ${userIds.length} specific users`
    );

    const notificationData: { [key: string]: string } = {
      ...data,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      targetRole: targetRole || "any",
    };

    if (targetUserId) {
      notificationData.targetUserId = targetUserId;
      console.log(` Added targetUserId to notification data: ${targetUserId}`);
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: notificationData,
      tokens: allTokens,
      android: {
        priority: "high" as const,
        notification: {
          channelId:
            data.type === "deadline_reminder" ?
              "deadline_reminders" :
              data.type === "escalation_reply" ||
                data.type === "new_escalation" ?
                "escalations" :
                "announcements",
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
      ` FCM sent: ${response.successCount} successful, ${response.failureCount} failed`
    );
    console.log(`   Intended for ${userIds.length} specific users`);

    if (response.failureCount > 0) {
      const tokensToRemove = new Map<string, string[]>();

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;
          console.error(
            ` Failed to send to token ${idx}:`,
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
          ` Removing invalid tokens from ${tokensToRemove.size} users`
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
    console.error(" Error sending FCM notifications:", error);
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
      `Creating notifications for ${userIds.length} ${targetRole} users`
    );

    let uniqueKey = `${type}`;
    if (data.announcementId) {
      uniqueKey += `-${data.announcementId}`;
    } else if (data.escalationId) {
      uniqueKey += `-${data.escalationId}`;
    } else if (data.scholarshipId) {
      uniqueKey += `-${data.scholarshipId}`;
    } else if (data.placementId) {
      uniqueKey += `-${data.placementId}`;
    }

    if (type === "deadline_reminder") {
      const reminderDate = data.reminderDate || new Date().toISOString().substring(0, 10);
      uniqueKey += `-${reminderDate}`;
    }

    if (data.eventId) {
      uniqueKey += `-${data.eventId}`;
    }

    console.log(` Using unique key: ${uniqueKey}`);

    let batch = db.batch();
    let batchCount = 0;
    let totalCreated = 0;

    for (const userId of userIds) {
      const notificationId = `${userId}_${uniqueKey}`;
      const notificationRef = db.collection("notifications").doc(notificationId);

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
          scholarshipId: data.scholarshipId || null,
          placementId: data.placementId || null,
          conversationId: data.conversationId || null,
          data: data,
          readBy: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      totalCreated++;
      batchCount++;

      if (batchCount >= 500) {
        await batch.commit();
        console.log(` Committed batch of ${batchCount} notifications`);
        batch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
      console.log(` Committed final batch of ${batchCount} notifications`);
    }

    console.log(
      ` Processed ${totalCreated} notifications`
    );
    return totalCreated;
  } catch (error) {
    console.error(" Error creating Firestore notifications:", error);
    return 0;
  }
}

export const checkFacebookTokenExpiry = onSchedule(
  {
    schedule: "0 8 * * *", // runs daily at 8am Manila time
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    console.log(" Checking Facebook token expiry...");

    try {
      // Get the Facebook token config from Firestore
      const configDoc = await db.collection("config").doc("facebook").get();

      if (!configDoc.exists) {
        console.log(" No Facebook config found, skipping");
        return;
      }

      const configData = configDoc.data();
      const tokenExpiresAt = configData?.tokenExpiresAt; // Firestore Timestamp

      if (!tokenExpiresAt || typeof tokenExpiresAt.toDate !== "function") {
        console.log(" No token expiry date found, skipping");
        return;
      }

      const now = new Date(
        new Date().toLocaleString("en-US", { timeZone: "Asia/Manila" })
      );
      now.setHours(0, 0, 0, 0);

      const expiryDate = tokenExpiresAt.toDate();
      const expiryLocal = new Date(
        expiryDate.toLocaleString("en-US", { timeZone: "Asia/Manila" })
      );
      expiryLocal.setHours(0, 0, 0, 0);

      const diffMs = expiryLocal.getTime() - now.getTime();
      const daysLeft = Math.round(diffMs / (1000 * 60 * 60 * 24));

      console.log(` Facebook token expires in: ${daysLeft} days`);

      // Get all admin users (only admins manage the token)
      const adminSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .where("isActive", "==", true)
        .get();

      const adminIds = adminSnapshot.docs.map((doc) => doc.id);

      if (adminIds.length === 0) {
        console.log(" No active admins found, skipping");
        return;
      }

      const expiryDateKey = expiryLocal.toISOString().substring(0, 10); // e.g. "2026-05-01"

      // ─────────────────────────────────────────────────────────────
      // CASE 1: EXPIRING SOON — fire ONCE at 5 days left, ONCE at 3 days left
      // Key includes daysLeft (5 or 3) + expiryDate → never repeats
      // ─────────────────────────────────────────────────────────────
      if (daysLeft === 5 || daysLeft === 3) {
        const reminderKey = `fb_token_expiring_${expiryDateKey}_${daysLeft}d`;

        // Check if this exact warning was already sent
        const alreadySentDoc = await db
          .collection("scheduled_runs")
          .doc(reminderKey)
          .get();

        if (alreadySentDoc.exists) {
          console.log(` FB token ${daysLeft}-day warning already sent, skipping`);
          return;
        }

        // Lock it immediately
        await db.collection("scheduled_runs").doc(reminderKey).set({
          type: "fb_token_expiry_warning",
          daysLeft: daysLeft,
          expiryDate: expiryDateKey,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const title = " Facebook Token Expiring Soon";
        const body = `Your Facebook API token will expire in ${daysLeft} days. Please renew it soon to avoid interruption.`;

        await createNotificationsForUsers(
          adminIds,
          "admin",
          title,
          body,
          "fb_token_expiration",
          {
            status: "expiring",
            daysLeft: String(daysLeft),
            expiryDate: expiryDateKey,
            reminderDate: reminderKey, // unique key → fires only once
          }
        );

        await sendFCMNotifications(
          adminIds,
          title,
          body,
          {
            type: "fb_token_expiration",
            status: "expiring",
            daysLeft: String(daysLeft),
          },
          "admin"
        );

        console.log(` Sent FB token ${daysLeft}-day expiry warning to ${adminIds.length} admins`);
      }

      // ─────────────────────────────────────────────────────────────
      // CASE 2: EXPIRED — fire every 3 days
      // Key includes a rolling 3-day bucket → repeats every 3 days
      // ─────────────────────────────────────────────────────────────
      if (daysLeft < 0) {
        // Calculate how many days since expiry
        const daysSinceExpiry = Math.abs(daysLeft);

        // Only fire on day 0, 3, 6, 9... after expiry
        if (daysSinceExpiry % 3 !== 0) {
          console.log(` FB token expired ${daysSinceExpiry} days ago — not a 3-day interval, skipping`);
          return;
        }

        const todayKey = now.toISOString().substring(0, 10);
        const expiredReminderKey = `fb_token_expired_${todayKey}`;

        // Idempotency: prevent double-firing on same calendar day
        const alreadySentDoc = await db
          .collection("scheduled_runs")
          .doc(expiredReminderKey)
          .get();

        if (alreadySentDoc.exists) {
          console.log(" FB token expired reminder already sent today, skipping");
          return;
        }

        await db.collection("scheduled_runs").doc(expiredReminderKey).set({
          type: "fb_token_expired_reminder",
          daysSinceExpiry: daysSinceExpiry,
          expiryDate: expiryDateKey,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const title = " Facebook Token Expired";
        const body = "Your Facebook API token has expired! Please renew it immediately to continue syncing posts.";

        // Use today's date in reminderDate so each 3-day reminder is a NEW notification
        await createNotificationsForUsers(
          adminIds,
          "admin",
          title,
          body,
          "fb_token_expiration",
          {
            status: "expired",
            daysLeft: String(daysLeft),
            expiryDate: expiryDateKey,
            reminderDate: todayKey, // changes every run → new notification each time
          }
        );

        await sendFCMNotifications(
          adminIds,
          title,
          body,
          {
            type: "fb_token_expiration",
            status: "expired",
            daysLeft: String(daysLeft),
          },
          "admin"
        );

        console.log(` Sent FB token expired reminder (day ${daysSinceExpiry} since expiry) to ${adminIds.length} admins`);
      }
    } catch (error) {
      console.error(" Error checking Facebook token expiry:", error);
    }
  }
);

function formatDeadlineForNotification(deadline: admin.firestore.Timestamp | null): string {
  if (!deadline || typeof deadline.toDate !== "function") {
    return "";
  }

  try {
    const deadlineDate = deadline.toDate();
    return deadlineDate.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch (error) {
    console.error("Error formatting deadline:", error);
    return "";
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

export const onAnnouncementCreated = onDocumentCreated(
  {
    document: "announcements/{announcementId}",
    region: "us-central1",
    retry: false,
  },
  async (event) => {
    const announcementId = event.params.announcementId;

    console.log(` onAnnouncementCreated triggered for: ${announcementId}`);
    console.log(` Event ID: ${event.id}`);

    await new Promise((resolve) => setTimeout(resolve, 1000));

    try {
      const announcementRef = db.collection("announcements").doc(announcementId);

      let announcementData: any;
      try {
        await db.runTransaction(async (transaction) => {
          const doc = await transaction.get(announcementRef);

          if (!doc.exists) {
            throw new Error("Announcement does not exist");
          }

          const data = doc.data();

          if (data?.deleted === true) {
            throw new Error("Announcement is deleted");
          }

          if (data?.notification_sent === true) {
            throw new Error("Notification already sent");
          }

          transaction.update(announcementRef, {
            notification_sent: true,
            notification_sent_at: admin.firestore.FieldValue.serverTimestamp(),
            notification_event_id: event.id,
          });

          announcementData = data;
        });

        console.log(` Acquired lock for announcement ${announcementId}`);
      } catch (error: any) {
        if (error.message === "Notification already sent") {
          console.log(` Notification already sent for ${announcementId}, skipping`);
          return {success: false, reason: "already_sent"};
        }
        if (error.message === "Announcement is deleted" || error.message === "Announcement does not exist") {
          console.log(` ${error.message}, skipping`);
          return {success: false, reason: "invalid_announcement"};
        }
        throw error;
      }

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
        ` Creating notifications for ${userIds.length} active users`
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
          eventId: event.id,
        }
      );

      console.log(` Created ${notificationsCreated} notifications`);

      if (notificationsCreated > 0) {
        await sendFCMNotifications(
          userIds,
          notificationTitle,
          notificationBody,
          {
            type: "announcement",
            announcementId: announcementId,
            category: category,
          },
          "user"
        );
      }

      return {success: true, notificationsCreated, eventId: event.id};
    } catch (error) {
      console.error("Error creating announcement notification:", error);
      return {success: false, error: error};
    }
  }
);

export const checkUpcomingDeadlines = onSchedule(
  {
    schedule: "0 6,18 * * *",

    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    const now = new Date(
      new Date().toLocaleString("en-US", {timeZone: "Asia/Manila"})
    );
    now.setHours(0, 0, 0, 0);
    const reminderDateKey = now.toISOString().substring(0, 10);

    console.log(" Checking for upcoming deadlines...");
    console.log(` Reminder date key: ${reminderDateKey}`);

    //  Idempotency check
    const runLogRef = db.collection("scheduled_runs").doc(`deadlines_${reminderDateKey}`);

    try {
      await runLogRef.create({
        runDate: reminderDateKey,
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
        status: "running",
        type: "deadline_check",
      });
      console.log(` Acquired lock for deadline check on ${reminderDateKey}`);
    } catch (error: any) {
      if (error.code === 6) {
        console.log(` Deadline check already ran today (${reminderDateKey})`);
        return;
      }
      throw error;
    }

    let totalNotificationsCreated = 0;
    const processedItems: any[] = [];

    try {
      console.log(
        ` Current time: ${new Date().toLocaleString("en-PH", {
          timeZone: "Asia/Manila",
        })}`
      );

      const targetDate = new Date(now);
      targetDate.setDate(targetDate.getDate() + 3);
      targetDate.setHours(23, 59, 59, 999);

      console.log(` Today (Manila): ${reminderDateKey}`);
      console.log(` Target deadline date: ${targetDate.toISOString()}`);

      const usersSnapshot = await db
        .collection("users")
        .where("isActive", "==", true)
        .get();
      const allUserIds = usersSnapshot.docs.map((doc) => doc.id);

      if (allUserIds.length === 0) {
        console.log(" No active users found. Exiting.");
        await runLogRef.update({
          status: "completed",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          notificationsSent: 0,
          reason: "no_active_users",
        });
        return;
      }
      console.log(` Found ${allUserIds.length} active users.`);

      //  Check Announcements
      const announcementsSnapshot = await db
        .collection("announcements")
        .where("deleted", "==", false)
        .where("deadline", "!=", null)
        .get();

      console.log(
        ` Found ${announcementsSnapshot.size} announcements with deadlines`
      );

      for (const announcementDoc of announcementsSnapshot.docs) {
        const data = announcementDoc.data();
        const announcementId = announcementDoc.id;
        const {deadline, message = "", category = "General"} = data;

        if (!deadline || typeof deadline.toDate !== "function") {
          console.log(` Skipping announcement ${announcementId}: invalid deadline`);
          continue;
        }

        const deadlineDate = deadline.toDate();
        const deadlineLocal = new Date(
          deadlineDate.toLocaleString("en-US", {timeZone: "Asia/Manila"})
        );
        deadlineLocal.setHours(0, 0, 0, 0);

        const diffMs = deadlineLocal.getTime() - now.getTime();
        const daysUntilDeadline = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(` Announcement ${announcementId}: ${daysUntilDeadline} days until deadline`);

        if (daysUntilDeadline === 3) {
          const title = ` Deadline Reminder: ${category} Announcement`;
          const formattedDate = deadlineLocal.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
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
              daysUntilDeadline: "3",
              reminderDate: reminderDateKey,
            }
          );

          totalNotificationsCreated += notificationsCreated;
          processedItems.push({
            type: "announcement",
            id: announcementId,
            category,
            deadline: deadlineLocal.toISOString(),
            notificationsSent: notificationsCreated,
          });

          //  FIX: Don't pass targetUserId for deadline reminders (they're for all users)
          if (notificationsCreated > 0) {
            await sendFCMNotifications(
              allUserIds,
              title,
              body,
              {
                type: "deadline_reminder",
                announcementId,
                category,
                daysUntilDeadline: "3",
              },
              "user"
              //  NO targetUserId parameter - this is for all users
            );
          }
        }
      }

      //  Check Scholarships
      const scholarshipsSnapshot = await db
        .collection("scholarships")
        .where("deadline", "!=", null)
        .get();

      console.log(
        ` Found ${scholarshipsSnapshot.size} scholarships with deadlines`
      );

      for (const scholarshipDoc of scholarshipsSnapshot.docs) {
        const data = scholarshipDoc.data();
        const scholarshipId = scholarshipDoc.id;
        const {deadline, name = "", scholarshipProvider = ""} = data;

        if (!deadline || typeof deadline.toDate !== "function") {
          console.log(` Skipping scholarship ${scholarshipId}: invalid deadline`);
          continue;
        }

        const deadlineDate = deadline.toDate();
        const deadlineLocal = new Date(
          deadlineDate.toLocaleString("en-US", {timeZone: "Asia/Manila"})
        );
        deadlineLocal.setHours(0, 0, 0, 0);

        const diffMs = deadlineLocal.getTime() - now.getTime();
        const daysUntilDeadline = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(` Scholarship ${scholarshipId} (${name}): ${daysUntilDeadline} days until deadline`);

        if (daysUntilDeadline === 3) {
          const title = " Scholarship Deadline Reminder";
          const formattedDate = deadlineLocal.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
          });
          const body = `${name} (${scholarshipProvider}) - Deadline in 3 days: ${formattedDate}`;

          const notificationsCreated = await createNotificationsForUsers(
            allUserIds,
            "user",
            title,
            body,
            "deadline_reminder",
            {
              scholarshipId,
              name,
              scholarshipProvider,
              deadline: deadlineLocal.toISOString(),
              daysUntilDeadline: "3",
              reminderDate: reminderDateKey,
            }
          );

          totalNotificationsCreated += notificationsCreated;
          processedItems.push({
            type: "scholarship",
            id: scholarshipId,
            name,
            deadline: deadlineLocal.toISOString(),
            notificationsSent: notificationsCreated,
          });

          if (notificationsCreated > 0) {
            await sendFCMNotifications(
              allUserIds,
              title,
              body,
              {
                type: "deadline_reminder",
                scholarshipId,
                name,
                daysUntilDeadline: "3",
              },
              "user"
              //  NO targetUserId parameter
            );
          }
        }
      }

      //  Check Placements
      const placementsSnapshot = await db
        .collection("placements")
        .where("deadline", "!=", null)
        .where("isRecruiting", "==", true)
        .get();

      console.log(
        ` Found ${placementsSnapshot.size} placements with deadlines`
      );

      for (const placementDoc of placementsSnapshot.docs) {
        const data = placementDoc.data();
        const placementId = placementDoc.id;
        const {deadline, partnerCompany = ""} = data;

        if (!deadline || typeof deadline.toDate !== "function") {
          console.log(` Skipping placement ${placementId}: invalid deadline`);
          continue;
        }

        const deadlineDate = deadline.toDate();
        const deadlineLocal = new Date(
          deadlineDate.toLocaleString("en-US", {timeZone: "Asia/Manila"})
        );
        deadlineLocal.setHours(0, 0, 0, 0);

        const diffMs = deadlineLocal.getTime() - now.getTime();
        const daysUntilDeadline = Math.round(diffMs / (1000 * 60 * 60 * 24));

        console.log(` Placement ${placementId} (${partnerCompany}): ${daysUntilDeadline} days until deadline`);

        if (daysUntilDeadline === 3) {
          const title = " Placement Deadline Reminder";
          const formattedDate = deadlineLocal.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
            year: "numeric",
          });
          const body = `${partnerCompany} placement - Deadline in 3 days: ${formattedDate}`;

          const notificationsCreated = await createNotificationsForUsers(
            allUserIds,
            "user",
            title,
            body,
            "deadline_reminder",
            {
              placementId,
              partnerCompany,
              deadline: deadlineLocal.toISOString(),
              daysUntilDeadline: "3",
              reminderDate: reminderDateKey,
            }
          );

          totalNotificationsCreated += notificationsCreated;
          processedItems.push({
            type: "placement",
            id: placementId,
            company: partnerCompany,
            deadline: deadlineLocal.toISOString(),
            notificationsSent: notificationsCreated,
          });

          if (notificationsCreated > 0) {
            await sendFCMNotifications(
              allUserIds,
              title,
              body,
              {
                type: "deadline_reminder",
                placementId,
                partnerCompany,
                daysUntilDeadline: "3",
              },
              "user"
              //  NO targetUserId parameter
            );
          }
        }
      }

      console.log(
        ` Done. Created ${totalNotificationsCreated} notifications in total.`
      );
      console.log(" Processed items:", JSON.stringify(processedItems, null, 2));

      await runLogRef.update({
        status: "completed",
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationsSent: totalNotificationsCreated,
        processedItems: processedItems,
      });

      return;
    } catch (error) {
      console.error(" Error checking deadlines:", error);

      await runLogRef.update({
        status: "failed",
        error: String(error),
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
        notificationsSent: totalNotificationsCreated,
      });

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
      console.log(" Checking for duplicate notifications...");

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
        const scholarshipId = data.data?.scholarshipId || data.scholarshipId;
        const placementId = data.data?.placementId || data.placementId;
        const type = data.type;
        const reminderDate = data.data?.reminderDate;

        let key = `${userId}-${type}`;
        if (announcementId) {
          key += `-${announcementId}`;
        } else if (escalationId) {
          key += `-${escalationId}`;
        } else if (scholarshipId) {
          key += `-${scholarshipId}`;
        } else if (placementId) {
          key += `-${placementId}`;
        }
        if (reminderDate) {
          key += `-${reminderDate}`;
        }

        if (seen.has(key)) {
          toDelete.push(doc.id);
          console.log(
            ` Duplicate found: ${doc.id} (user: ${userId}, type: ${type})`
          );
        } else {
          seen.set(key, doc.id);
        }
      });

      if (toDelete.length > 0) {
        console.log(` Deleting ${toDelete.length} duplicate notifications`);

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

        console.log(` Deleted ${toDelete.length} duplicates`);
      } else {
        console.log(" No duplicates found");
      }
    } catch (error) {
      console.error(" Error cleaning up duplicates:", error);
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
      console.log(" Cleaning up old notifications and records...");

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
          ` Deleted ${oldNotificationsSnapshot.size} old notifications`
        );
      } else {
        console.log(" No old notifications to delete");
      }

      //  Cleanup old scheduled run logs (7 days)
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

      const oldRunLogsSnapshot = await db
        .collection("scheduled_runs")
        .where("startedAt", "<", sevenDaysAgo)
        .limit(500)
        .get();

      if (!oldRunLogsSnapshot.empty) {
        const batch = db.batch();
        oldRunLogsSnapshot.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(
          ` Deleted ${oldRunLogsSnapshot.size} old scheduled run logs`
        );
      } else {
        console.log(" No old scheduled run logs to delete");
      }

      //  Cleanup old processing records (removed from original code)
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
          ` Deleted ${oldProcessingSnapshot.size} old processing records`
        );
      } else {
        console.log(" No old processing records to delete");
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
    retry: false, //  Already disabled retry
  },
  async (event) => {
    try {
      const escalationData = event.data?.data();
      const escalationId = event.params.escalationId;

      if (!escalationData) {
        console.log("No escalation data found");
        return {success: false, reason: "no_data"};
      }

      console.log(` New escalation: ${escalationId}`);
      console.log(` Event ID: ${event.id}`);

      //  CRITICAL: Idempotency check to prevent duplicate processing
      const idempotencyRef = db.collection("notification_processing")
        .doc(`escalation_created_${escalationId}_${event.id}`);

      try {
        await idempotencyRef.create({
          escalationId: escalationId,
          eventId: event.id,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "processing",
          type: "escalation_created",
        });
        console.log(` Idempotency lock acquired for escalation ${escalationId}`);
      } catch (error: any) {
        if (error.code === 6) { // ALREADY_EXISTS error
          console.log(` Notification already being processed for escalation ${escalationId} (event: ${event.id})`);
          return {success: false, reason: "already_processing"};
        }
        throw error;
      }

      const question = escalationData.question || "New question";
      const userId = escalationData.userId;
      const conversationId = escalationData.conversationId || null;

      const category: string | null = escalationData.category || null;
      console.log(` Raw category from escalation: ${category}`);

      const normalizedCategory = category ? normalizeCategory(category) : null;
      console.log(` Normalized category: ${normalizedCategory}`);

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
      const notificationBody = `${userName} needs help on their question: ${question.substring(
        0,
        80
      )}${question.length > 80 ? "..." : ""}`;

      let staffIds: string[] = [];
      let adminIds: string[] = [];

      console.log(" Routing escalation:");
      console.log(`   - Raw category: ${category}`);
      console.log(`   - Normalized category: ${normalizedCategory}`);

      //  Filter staff by serviceUnit for specific categories
      if (normalizedCategory && ["Admission", "Scholarship", "Placement"].includes(normalizedCategory)) {
        console.log(` Looking for staff with serviceUnit: ${normalizedCategory}`);

        const staffSnapshot = await db
          .collection("users")
          .where("role", "==", "staff")
          .where("isActive", "==", true)
          .where("serviceUnit", "==", normalizedCategory)
          .get();

        staffIds = staffSnapshot.docs.map((doc) => doc.id);

        console.log(` Found ${staffIds.length} staff with serviceUnit: ${normalizedCategory}`);
        console.log(` Staff IDs: ${staffIds.join(", ")}`);

        for (const doc of staffSnapshot.docs) {
          const data = doc.data();
          console.log(`   - ${doc.id}: ${data.name} (serviceUnit: ${data.serviceUnit})`);
        }

        if (staffIds.length === 0) {
          console.log(` No staff found for ${normalizedCategory}, falling back to all staff`);
          const allStaffSnapshot = await db
            .collection("users")
            .where("role", "==", "staff")
            .where("isActive", "==", true)
            .get();
          staffIds = allStaffSnapshot.docs.map((doc) => doc.id);
          console.log(` Fallback: Found ${staffIds.length} total staff`);
        }
      } else {
        const allStaffSnapshot = await db
          .collection("users")
          .where("role", "==", "staff")
          .where("isActive", "==", true)
          .get();
        staffIds = allStaffSnapshot.docs.map((doc) => doc.id);
        console.log(` All staff (no category filter): ${staffIds.length}`);
      }

      // Admins ALWAYS get all escalations
      const adminSnapshot = await db
        .collection("users")
        .where("role", "==", "admin")
        .where("isActive", "==", true)
        .get();
      adminIds = adminSnapshot.docs.map((doc) => doc.id);
      console.log(` All admins: ${adminIds.length}`);

      if (staffIds.length === 0 && adminIds.length === 0) {
        console.log(" No staff or admin found");
        await idempotencyRef.update({
          status: "completed",
          reason: "no_recipients",
          category: category,
          normalizedCategory: normalizedCategory,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {success: false, reason: "no_recipients"};
      }

      let staffNotifications = 0;
      let adminNotifications = 0;

      // Create notifications for staff
      if (staffIds.length > 0) {
        console.log(` Creating notifications for ${staffIds.length} staff members`);

        staffNotifications = await createNotificationsForUsers(
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
            eventId: event.id,
            category: category || "General",
            serviceUnit: normalizedCategory || "N/A",
          }
        );

        console.log(` Created ${staffNotifications} staff notifications`);

        if (staffNotifications > 0) {
          console.log(` Sending FCM to ONLY ${staffIds.length} filtered staff members`);
          //  FIX: Only send to the filtered staffIds
          await sendFCMNotifications(
            staffIds, // This now contains ONLY filtered staff
            notificationTitle,
            notificationBody,
            {
              type: "new_escalation",
              escalationId: escalationId,
              conversationId: conversationId || "",
              category: category || "General",
            },
            "staff"
          );
          console.log(" FCM sent to filtered staff only");
        }
      }

      // Create notifications for admins
      if (adminIds.length > 0) {
        console.log(` Creating notifications for ${adminIds.length} admins`);

        adminNotifications = await createNotificationsForUsers(
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
            eventId: event.id,
            category: category || "General",
            serviceUnit: normalizedCategory || "N/A",
          }
        );

        console.log(` Created ${adminNotifications} admin notifications`);

        if (adminNotifications > 0) {
          console.log(` Sending FCM to ${adminIds.length} admins`);
          await sendFCMNotifications(
            adminIds,
            notificationTitle,
            notificationBody,
            {
              type: "new_escalation",
              escalationId: escalationId,
              conversationId: conversationId || "",
              category: category || "General",
            },
            "admin"
          );
          console.log(" FCM sent to admins");
        }
      }

      console.log(` Total notifications: ${staffNotifications + adminNotifications}`);
      console.log(`   - Staff: ${staffNotifications}`);
      console.log(`   - Admin: ${adminNotifications}`);

      await idempotencyRef.update({
        status: "completed",
        notificationsCreated: staffNotifications + adminNotifications,
        staffNotifications: staffNotifications,
        adminNotifications: adminNotifications,
        category: category,
        normalizedCategory: normalizedCategory,
        staffIds: staffIds,
        adminIds: adminIds,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        staffNotifications,
        adminNotifications,
        category: category,
        normalizedCategory: normalizedCategory,
        staffCount: staffIds.length,
        adminCount: adminIds.length,
      };
    } catch (error) {
      console.error(" Error creating escalation notification:", error);

      try {
        const idempotencyRef = db.collection("notification_processing")
          .doc(`escalation_created_${event.params.escalationId}_${event.id}`);
        await idempotencyRef.update({
          status: "failed",
          error: String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (e) {
        console.error("Failed to update idempotency record:", e);
      }

      return {success: false, error: error};
    }
  }
);


export const onEscalationReplied = onDocumentUpdated(
  {
    document: "escalations/{escalationId}",
    region: "us-central1",
    retry: false,
  },
  async (event) => {
    try {
      const beforeData = event.data?.before.data();
      const afterData = event.data?.after.data();
      const escalationId = event.params.escalationId;

      if (!beforeData || !afterData) {
        console.log("No escalation data found");
        return {success: false, reason: "no_escalation_data"};
      }

      const hasNewReply =
        (afterData.staffResponse && !beforeData.staffResponse) ||
        (afterData.status === "resolved" &&
          beforeData.status !== "resolved" &&
          afterData.staffResponse);

      if (!hasNewReply) {
        console.log("No new staff reply detected");
        return {success: false, reason: "no_new_reply"};
      }

      console.log(` Staff or Admin replied to escalation: ${escalationId}`);
      console.log(` Event ID: ${event.id}`);

      const idempotencyRef = db.collection("notification_processing")
        .doc(`escalation_reply_${escalationId}_${event.id}`);

      try {
        await idempotencyRef.create({
          escalationId: escalationId,
          eventId: event.id,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: "processing",
          type: "escalation_reply",
        });
        console.log(` Idempotency lock acquired for escalation reply ${escalationId}`);
      } catch (error: any) {
        if (error.code === 6) {
          console.log(` Reply notification already being processed for escalation ${escalationId} (event: ${event.id})`);
          return {success: false, reason: "already_processing"};
        }
        throw error;
      }

      const userId = afterData.userId;
      const question = afterData.question || "Your question";
      const staffResponse = afterData.staffResponse || null;
      const adminResponse = afterData.adminResponse || null;
      const conversationId = afterData.conversationId || null;
      const responderRole = afterData.respondedByRole || "staff";

      if (!userId) {
        console.log("No userId found in escalation");
        await idempotencyRef.update({
          status: "completed",
          reason: "no_user_id",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {success: false, reason: "no_user_id"};
      }

      //  Verify user exists and is active
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        console.log(` User ${userId} not found, skipping notification`);
        await idempotencyRef.update({
          status: "completed",
          reason: "user_not_found",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {success: false, reason: "user_not_found"};
      }

      const userData = userDoc.data();
      if (!userData?.isActive) {
        console.log(` User ${userId} is not active, skipping notification`);
        await idempotencyRef.update({
          status: "completed",
          reason: "user_not_active",
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return {success: false, reason: "user_not_active"};
      }

      console.log(` Verified user ${userId} exists and is active`);

      const notificationTitle =
        responderRole === "admin" ?
          "Admin Response to Your Escalation" :
          "Staff Response to Your Escalation";

      let notificationBody = `Question: ${question.substring(0, 60)}`;
      if (question.length > 60) notificationBody += "...";

      const responseMessage =
        responderRole === "admin" ?
          adminResponse || "Admin has responded." :
          staffResponse || "Staff has responded.";

      const notificationsCreated = await createNotificationsForUsers(
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
          eventId: event.id,
          targetUserId: userId, //  Add for Firestore
        }
      );

      if (notificationsCreated > 0) {
        console.log(` Sending FCM to ONLY user ${userId}`);

        //  CRITICAL FIX: Pass targetUserId as 6th parameter
        await sendFCMNotifications(
          [userId],
          notificationTitle,
          `${notificationBody}\n\n${responseMessage}`,
          {
            type: "escalation_reply",
            escalationId,
            conversationId: conversationId || "",
          },
          "user",
          userId //  This is the critical fix - targetUserId parameter
        );
      }

      console.log(
        ` Reply notification sent (${responderRole}) to user ${userId}`
      );

      await idempotencyRef.update({
        status: "completed",
        notificationsCreated: notificationsCreated,
        targetUserId: userId,
        completedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {success: true, userId, notificationsCreated};
    } catch (error) {
      console.error("Error creating escalation reply notification:", error);

      try {
        const idempotencyRef = db.collection("notification_processing")
          .doc(`escalation_reply_${event.params.escalationId}_${event.id}`);
        await idempotencyRef.update({
          status: "failed",
          error: String(error),
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (e) {
        console.error("Failed to update idempotency record:", e);
      }

      return {success: false, error};
    }
  }
);

// async function getUsersByRoleAndCategory(
//   role: string,
//   category?: string
// ): Promise<string[]> {
//   try {
//     console.log(` Fetching ${role} users${category ? ` with category: ${category}` : ''}`);

//     let query = db
//       .collection("users")
//       .where("role", "==", role)
//       .where("isActive", "==", true);

//     //  For staff, filter by serviceUnit matching the category
//     if (role === "staff" && category) {
//       // Normalize category to match serviceUnit field
//       const serviceUnit = normalizeCategory(category);
//       query = query.where("serviceUnit", "==", serviceUnit);
//       console.log(` Filtering staff by serviceUnit: ${serviceUnit}`);
//     }

//     const usersSnapshot = await query.get();
//     const userIds = usersSnapshot.docs.map((doc) => doc.id);

//     console.log(` Found ${userIds.length} active ${role} users${category ? ` in ${category}` : ''}`);

//     return userIds;
//   } catch (error) {
//     console.error(` Error fetching ${role} users:`, error);
//     return [];
//   }
// }


function normalizeCategory(category: string): string {
  const normalized = category.toLowerCase().trim();

  // Map variations to exact serviceUnit values
  const categoryMap: { [key: string]: string } = {
    "admission": "Admission",
    "admissions": "Admission",
    "enrollment": "Admission",
    "scholarship": "Scholarship",
    "scholarships": "Scholarship",
    "financial aid": "Scholarship",
    "placement": "Placement",
    "placements": "Placement",
    "job placement": "Placement",
    "career": "Placement",
    "careers": "Placement",
    "general": "N/A",
    "n/a": "N/A",
  };

  const mapped = categoryMap[normalized];

  if (mapped) {
    console.log(` Mapped "${category}" → "${mapped}"`);
    return mapped;
  }

  // If not in map, capitalize first letter (for exact matches like "Admission")
  const capitalized = category.charAt(0).toUpperCase() + category.slice(1).toLowerCase();
  console.log(` Capitalized "${category}" → "${capitalized}"`);
  return capitalized;
}
