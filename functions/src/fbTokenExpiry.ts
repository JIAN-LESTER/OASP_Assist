import {onSchedule} from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/https";

const db = admin.firestore();

/**
 * Check Facebook token expiration and send notifications
 *
 * TESTING MODE: Runs every 3 days, notifies at 59-60 days
 * PRODUCTION MODE: Runs every 3 days, notifies at 14 days
 *
 * To switch to production:
 * 1. Change NOTIFICATION_THRESHOLD from 60 to 14
 * 2. Optionally change schedule to run more frequently (e.g., "0 9 * * *" for daily)
 */
export const checkFacebookTokenExpiration = onSchedule(
  {
    schedule: "0 9 */3 * *", // Every 3 days at 9 AM Manila time
    timeZone: "Asia/Manila",
    region: "us-central1",
  },
  async (event) => {
    console.log("========================================");
    console.log("🔍 Checking Facebook token expiration...");
    console.log(`📅 Current time: ${new Date().toLocaleString("en-PH", {timeZone: "Asia/Manila"})}`);
    console.log("========================================\n");

    try {
      // Get the token document
      const tokenDoc = await db
        .collection("fb_tokens")
        .doc("facebook_admin")
        .get();

      if (!tokenDoc.exists) {
        console.log("ℹ️ No Facebook token configured - skipping check");
        return;
      }

      const data = tokenDoc.data()!;
      const expiresAt = data.expires_at as number | null;

      if (!expiresAt) {
        console.log("⚠️ No expiration date found for token - skipping check");
        return;
      }

      const now = Date.now();
      const msUntilExpiry = expiresAt - now;
      const daysUntilExpiry = Math.ceil(msUntilExpiry / (1000 * 60 * 60 * 24));

      console.log("📊 Token Status:");
      console.log(`   Expires at: ${new Date(expiresAt).toLocaleString("en-PH", {timeZone: "Asia/Manila"})}`);
      console.log(`   Days until expiry: ${daysUntilExpiry}`);
      console.log(`   Hours until expiry: ${Math.ceil(msUntilExpiry / (1000 * 60 * 60))}`);

      // ✅ TESTING: 60 days threshold
      // 🚀 PRODUCTION: Change to 14 days
      const NOTIFICATION_THRESHOLD = 60; // Change to 14 for production

      console.log(`⚙️ Current threshold: ${NOTIFICATION_THRESHOLD} days`);
      console.log(`⚙️ Mode: ${NOTIFICATION_THRESHOLD === 60 ? "TESTING" : "PRODUCTION"}`);

      // Determine notification action
      if (daysUntilExpiry <= 0) {
        console.log("\n❌ TOKEN EXPIRED!");
        await sendExpirationNotifications(
          "expired",
          "Your Facebook API token has expired! Please renew it immediately to continue syncing posts.",
          daysUntilExpiry,
          expiresAt
        );
      } else if (daysUntilExpiry <= NOTIFICATION_THRESHOLD) {
        console.log(`\n⚠️ Token expiring in ${daysUntilExpiry} days - sending notifications`);
        await sendExpirationNotifications(
          "expiring_soon",
          `Your Facebook API token will expire in ${daysUntilExpiry} day${daysUntilExpiry !== 1 ? "s" : ""}. Please renew it soon to avoid interruption.`,
          daysUntilExpiry,
          expiresAt
        );
      } else {
        console.log(`\n✅ Token is still valid (${daysUntilExpiry} days remaining)`);
        console.log("   Next check will be in 3 days");
        console.log(`   Will notify when ≤ ${NOTIFICATION_THRESHOLD} days remain`);
      }
    } catch (error: any) {
      console.error("\n❌ ========================================");
      console.error("❌ Error checking token expiration");
      console.error(`❌ Error: ${error.message}`);
      console.error("❌ ========================================\n");

      throw error;
    }
  }
);

/**
 * Send expiration notifications to all admins
 * Creates both Firestore notifications and sends FCM push notifications
 */
async function sendExpirationNotifications(
  status: "expired" | "expiring_soon",
  message: string,
  daysLeft: number,
  expiresAt: number
): Promise<void> {
  try {
    console.log("\n📤 ========================================");
    console.log(`📤 Sending notifications for status: ${status}`);
    console.log(`📤 Days left: ${daysLeft}`);
    console.log("📤 ========================================\n");

    // Get all active admins
    const adminsSnapshot = await db
      .collection("users")
      .where("role", "==", "admin")
      .where("isActive", "==", true)
      .get();

    if (adminsSnapshot.empty) {
      console.log("⚠️ No active admins found - no notifications sent");
      return;
    }

    const adminIds = adminsSnapshot.docs.map((doc) => doc.id);
    console.log(`✅ Found ${adminIds.length} active admin(s):`);
    adminsSnapshot.docs.forEach((doc) => {
      const data = doc.data();
      console.log(`   - ${doc.id}: ${data.name || "Unknown"} (${data.email || "No email"})`);
    });

    // Create unique notification ID based on date and status
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD
    const notificationKey = `fb_token_${status}_${today}`;
    console.log(`\n🔑 Notification key: ${notificationKey}`);

    // Prepare notification content
    const title = status === "expired" ?
      "🔴 Facebook Token Expired" :
      "⚠️ Facebook Token Expiring Soon";

    const expirationDate = new Date(expiresAt).toLocaleString("en-PH", {
      timeZone: "Asia/Manila",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });

    // Create notifications in Firestore
    console.log("\n📝 Creating Firestore notifications...");
    const batch = db.batch();
    let notificationCount = 0;

    for (const adminId of adminIds) {
      const notificationId = `${adminId}_${notificationKey}`;
      const notificationRef = db.collection("notifications").doc(notificationId);

      batch.set(
        notificationRef,
        {
          notificationId: notificationId,
          userId: adminId,
          targetRole: "admin",
          title: title,
          body: message,
          type: "fb_token_expiration",
          status: status,
          daysLeft: daysLeft,
          data: {
            status: status,
            daysLeft: daysLeft,
            expiresAt: expiresAt,
            expirationDate: expirationDate,
            actionRequired: true,
            severity: status === "expired" ? "critical" : daysLeft <= 7 ? "high" : "medium",
          },
          readBy: [],
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );

      notificationCount++;
    }

    await batch.commit();
    console.log(`✅ Created ${notificationCount} Firestore notification(s)`);

    // Send FCM notifications
    console.log("\n📱 Preparing FCM notifications...");
    await sendFCMNotifications(
      adminIds,
      title,
      message,
      {
        type: "fb_token_expiration",
        status: status,
        daysLeft: daysLeft.toString(),
        expiresAt: expiresAt.toString(),
        expirationDate: expirationDate,
        actionRequired: "true",
        severity: status === "expired" ? "critical" : daysLeft <= 7 ? "high" : "medium",
        notificationKey: notificationKey,
      }
    );

    console.log("\n✅ ========================================");
    console.log("✅ Notifications sent successfully");
    console.log(`✅ Total admins notified: ${adminIds.length}`);
    console.log("✅ ========================================\n");
  } catch (error: any) {
    console.error("\n❌ ========================================");
    console.error("❌ Error sending notifications");
    console.error(`❌ Error: ${error.message}`);
    console.error("❌ ========================================\n");
    throw error;
  }
}

/**
 * Send FCM notifications to admins
 */
async function sendFCMNotifications(
  userIds: string[],
  title: string,
  body: string,
  data: { [key: string]: string }
): Promise<void> {
  try {
    console.log(`📱 Sending FCM to ${userIds.length} admin(s)...`);

    // Get FCM tokens for all admins
    const userTokensMap = await getUserFCMTokens(userIds);

    if (userTokensMap.size === 0) {
      console.log("⚠️ No FCM tokens found for admins");
      console.log("   Firestore notifications were still created");
      return;
    }

    // Collect all tokens
    const allTokens: string[] = [];
    userTokensMap.forEach((tokens) => {
      allTokens.push(...tokens);
    });

    if (allTokens.length === 0) {
      console.log("ℹ️ No valid FCM tokens available");
      return;
    }

    console.log(`📱 Sending to ${allTokens.length} device(s)`);
    console.log("   Token distribution:");
    userTokensMap.forEach((tokens, userId) => {
      console.log(`   - ${userId}: ${tokens.length} token(s)`);
    });

    // Send FCM message
    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: {
        ...data,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        targetRole: "admin",
      },
      tokens: allTokens,
      android: {
        priority: "high" as const,
        notification: {
          channelId: "fb_token_alerts",
          priority: "high" as const,
          defaultSound: true,
          defaultVibrateTimings: true,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          color: "#DC2626", // Red for critical notifications
        },
      },
      apns: {
        payload: {
          aps: {
            "alert": {
              title: title,
              body: body,
            },
            "sound": "default",
            "badge": 1,
            "content-available": 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    console.log("\n📊 FCM Results:");
    console.log(`   ✅ Successful: ${response.successCount}`);
    console.log(`   ❌ Failed: ${response.failureCount}`);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      console.log("\n🗑️ Cleaning up invalid tokens...");
      const tokensToRemove = new Map<string, string[]>();

      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const error = resp.error;

          console.log(`   ❌ Failed token ${idx + 1}: ${error?.code} - ${error?.message}`);

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
        console.log(`   🗑️ Removing ${tokensToRemove.size} invalid token(s)`);
        const batch = db.batch();

        tokensToRemove.forEach((tokens, userId) => {
          const userTokenRef = db.collection("fcm_tokens").doc(userId);
          batch.update(userTokenRef, {
            tokens: admin.firestore.FieldValue.arrayRemove(...tokens),
          });
          console.log(`      - Removed ${tokens.length} token(s) from ${userId}`);
        });

        await batch.commit();
        console.log("   ✅ Invalid tokens removed from Firestore");
      }
    }

    console.log("\n✅ FCM notifications sent successfully");
  } catch (error: any) {
    console.error("\n❌ Error sending FCM notifications:", error);
    console.error(`   ${error.message}`);
    // Don't throw - Firestore notifications were already created
  }
}

/**
 * Get FCM tokens for users
 */
async function getUserFCMTokens(
  userIds: string[]
): Promise<Map<string, string[]>> {
  try {
    console.log(`\n🔍 Fetching FCM tokens for ${userIds.length} user(s)...`);

    const userTokensMap = new Map<string, string[]>();
    const allSeenTokens = new Set<string>();

    // Process in batches of 10 (Firestore 'in' query limit)
    for (let i = 0; i < userIds.length; i += 10) {
      const batch = userIds.slice(i, i + 10);

      const tokensSnapshot = await db
        .collection("fcm_tokens")
        .where("userId", "in", batch)
        .get();

      tokensSnapshot.forEach((doc) => {
        const data = doc.data();
        const userId = data.userId;
        const rawTokens = Array.isArray(data.tokens) ? data.tokens : [];

        const tokens: string[] = rawTokens
          .map((t) => (typeof t === "string" ? t : String(t)))
          .filter((t) => t && t.length > 0);

        // Filter for mobile tokens only (exclude web tokens)
        const mobileTokens = tokens.filter(
          (token: string) => !token.startsWith("web_") && token.length > 10
        );

        // Remove duplicates
        const uniqueTokens = [...new Set(mobileTokens)].filter(
          (token: string) => !allSeenTokens.has(token)
        );

        uniqueTokens.forEach((token) => allSeenTokens.add(token));

        if (uniqueTokens.length > 0) {
          userTokensMap.set(userId, uniqueTokens);
        }
      });
    }

    console.log(`✅ Found tokens for ${userTokensMap.size} user(s)`);
    console.log(`   Total unique tokens: ${allSeenTokens.size}`);

    return userTokensMap;
  } catch (error: any) {
    console.error("❌ Error getting FCM tokens:", error);
    return new Map();
  }
}

/**
 * Manual trigger function for testing
 * Call this from Flutter or Firebase Console to test notifications
 */
export const manualCheckFacebookToken = onCall(
  {cors: true, secrets: []},
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      console.log("\n🧪 ========================================");
      console.log("🧪 MANUAL TOKEN CHECK TRIGGERED");
      console.log(`🧪 By user: ${request.auth.uid}`);
      console.log("🧪 ========================================\n");

      // Check if user is admin
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      const userData = userDoc.data();

      if (!userData || userData.role !== "admin") {
        throw new HttpsError(
          "permission-denied",
          "Only admins can trigger manual token checks"
        );
      }

      // Get token data
      const tokenDoc = await db
        .collection("fb_tokens")
        .doc("facebook_admin")
        .get();

      if (!tokenDoc.exists) {
        return {
          success: false,
          message: "No Facebook token configured",
        };
      }

      const data = tokenDoc.data()!;
      const expiresAt = data.expires_at as number | null;

      if (!expiresAt) {
        return {
          success: false,
          message: "No expiration date found for token",
        };
      }

      const now = Date.now();
      const msUntilExpiry = expiresAt - now;
      const daysUntilExpiry = Math.ceil(msUntilExpiry / (1000 * 60 * 60 * 24));

      console.log(`📊 Token expires in: ${daysUntilExpiry} days`);

      // Always send notification for manual check
      const status: "expired" | "expiring_soon" =
        daysUntilExpiry <= 0 ? "expired" : "expiring_soon";

      const message = daysUntilExpiry <= 0 ?
        "Your Facebook API token has expired!" :
        `Your Facebook API token will expire in ${daysUntilExpiry} day${daysUntilExpiry !== 1 ? "s" : ""}.`;

      await sendExpirationNotifications(status, message, daysUntilExpiry, expiresAt);

      console.log("\n✅ Manual check complete\n");

      return {
        success: true,
        message: "Test notification sent successfully",
        daysUntilExpiry,
        status,
      };
    } catch (error: any) {
      console.error("❌ Manual check error:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);
