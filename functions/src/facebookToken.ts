import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";

const FB_APP_ID = defineSecret("FB_APP_ID");
const FB_APP_SECRET = defineSecret("FB_APP_SECRET");

const db = admin.firestore();
const FB_API_VERSION = "v24.0";
// const PAGE_ID = "730995450096065";


async function verifyAuthToken(authHeader: string | undefined): Promise<string | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return null;
  }
  
  const idToken = authHeader.split('Bearer ')[1];
  
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken.uid;
  } catch (error) {
    console.error('Token verification failed:', error);
    return null;
  }
}

async function exchangeShortForLong(
  shortToken: string,
  appId: string,
  appSecret: string
): Promise<{ access_token: string; expires_in?: number }> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/oauth/access_token`;
  const params = {
    grant_type: "fb_exchange_token",
    client_id: appId,
    client_secret: appSecret,
    fb_exchange_token: shortToken,
  };
  
  console.log('📡 Calling Facebook token exchange API...');
  console.log('📡 URL:', url);
  console.log('📡 Params:', { ...params, client_secret: '***', fb_exchange_token: '***' });
  
  try {
    const resp = await axios.get<{ access_token: string; expires_in?: number; token_type?: string }>(
      url, 
      { 
        params,
        timeout: 30000,
      }
    );
    
    console.log('✅ Facebook API response received');
    console.log('📊 Response status:', resp.status);
    console.log('📊 Response data:', {
      ...resp.data,
      access_token: resp.data.access_token ? '***' + resp.data.access_token.slice(-10) : undefined,
      expires_in: resp.data.expires_in,
      token_type: resp.data.token_type,
    });
    
    if (resp.data.expires_in) {
      const days = Math.round(resp.data.expires_in / 86400);
      console.log(`📅 Token is valid for ${resp.data.expires_in} seconds (~${days} days)`);
    } else {
      console.warn('⚠️ WARNING: Facebook did not return expires_in!');
      console.warn('⚠️ This means the token might be short-lived or there was an error');
    }
    
    return resp.data;
  } catch (error: any) {
    console.error('❌ Facebook token exchange failed');
    console.error('❌ Status:', error.response?.status);
    console.error('❌ Error data:', JSON.stringify(error.response?.data, null, 2));
    throw error;
  }
}

async function getUserPages(longUserToken: string): Promise<any> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/me/accounts`;
  const resp = await axios.get(url, { params: { access_token: longUserToken } });
  return resp.data as any;
}

async function exchangeTokenLogic(
  uid: string, 
  shortToken: string, 
  pageId?: string  // ✅ NEW: Optional pageId parameter
): Promise<any> {
  try {
    console.log(`🔄 Exchanging token for uid: ${uid}`);
    if (pageId) {
      console.log(`📍 Page ID provided: ${pageId}`);
    }

    const appId = FB_APP_ID.value();
    const appSecret = FB_APP_SECRET.value();

    if (!appId || !appSecret) {
      throw new Error("FB_APP_ID or FB_APP_SECRET not configured");
    }

    console.log("📡 Calling Facebook API...");
    const data = await exchangeShortForLong(shortToken, appId, appSecret);
    const longToken = data.access_token;
    const expiresIn = data.expires_in;

    console.log(`✅ Token exchanged successfully`);
    console.log(`📊 Expires in: ${expiresIn} seconds`);

    const me = await axios.get<{ id: string; name?: string }>(
      `https://graph.facebook.com/${FB_API_VERSION}/me`, 
      {
        params: { access_token: longToken, fields: "id,name" },
      }
    );

    const fbUserId = me.data.id;
    const now = Date.now();
    
    let expiresAt: number | null = null;
    
    if (expiresIn !== undefined && expiresIn !== null) {
      expiresAt = now + (Number(expiresIn) * 1000);
      console.log(`📅 Token will expire at: ${new Date(expiresAt).toISOString()}`);
      console.log(`📅 That's ${Math.round(Number(expiresIn) / 86400)} days from now`);
    } else {
      console.warn(`⚠️ No expires_in received from Facebook, setting to 60 days`);
      expiresAt = now + (60 * 24 * 60 * 60 * 1000);
    }

    let pagesObj: { [key: string]: any } = {};
    try {
      const pagesResp = await getUserPages(longToken);
      const pages = pagesResp.data || [];
      console.log(`📄 Found ${pages.length} page(s)`);
      
      for (const p of pages) {
        pagesObj[p.id] = {
          access_token: p.access_token,
          name: p.name,
          expires_at: null,
        };
      }
    } catch (err: any) {
      console.warn("⚠️ Could not fetch pages:", err?.message);
    }

    const docRef = db.collection("fb_tokens").doc(uid);
    const saveData = {
      provider: "facebook",
      userId: fbUserId,
      long_token: longToken,
      short_token: shortToken,
      expires_at: expiresAt,
      expires_in: expiresIn || null,
      pages: pagesObj,
      pageId: pageId || null, // ✅ NEW: Store the provided Page ID
      updated_at: now,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    console.log(`💾 Saving token data:`, {
      ...saveData,
      long_token: "***",
      short_token: "***",
      pageId: pageId || "not provided",
      expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
    });
    
    await docRef.set(saveData, { merge: true });

    console.log(`✅ Token saved to fb_tokens/${uid}`);

    const daysValid = expiresIn 
      ? Math.round(Number(expiresIn) / 86400)
      : 60;

    return { 
      success: true,
      ok: true, 
      expires_in: expiresIn || (60 * 86400),
      expires_at: expiresAt, 
      fbUserId: fbUserId,
      pagesCount: Object.keys(pagesObj).length,
      pageId: pageId || null, // ✅ Return the Page ID in response
      message: `Token saved successfully. Valid for ~${daysValid} days.`,
    };
  } catch (error: any) {
    console.error("❌ exchangeTokenLogic error:", error);
    
    if (error.response?.data?.error) {
      const fbError = error.response.data.error;
      throw new Error(`Facebook API Error: ${fbError.message || fbError.type}`);
    }
    
    throw error;
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

export const refreshTokensDaily = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Manila",
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (event) => {
    const REFRESH_BEFORE_MS = 5 * 24 * 60 * 60 * 1000;
    const now = Date.now();
    const cutoff = now + REFRESH_BEFORE_MS;

    const appId = FB_APP_ID.value();
    const appSecret = FB_APP_SECRET.value();

    const snapshot = await db.collection("fb_tokens")
      .where("provider", "==", "facebook")
      .where("expires_at", "<=", cutoff)
      .get();

    if (snapshot.empty) {
      console.log("No tokens need refreshing.");
      return;
    }

    const results = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const uid = doc.id;
      const currentLong = data.long_token;

      if (!currentLong) {
        console.log(`No long token for ${uid}, skipping`);
        continue;
      }

      try {
        const resp = await axios.get<{ access_token: string; expires_in?: number }>(
          `https://graph.facebook.com/${FB_API_VERSION}/oauth/access_token`, 
          {
            params: {
              grant_type: "fb_exchange_token",
              client_id: appId,
              client_secret: appSecret,
              fb_exchange_token: currentLong,
            },
          }
        );

        const newToken = resp.data.access_token;
        const newExpiresIn = resp.data.expires_in;
        const newExpiresAt = newExpiresIn ? (Date.now() + newExpiresIn * 1000) : null;

        let pagesObj = data.pages || {};
        try {
          const pagesResp = await getUserPages(newToken);
          const pages = pagesResp.data || [];
          for (const p of pages) {
            pagesObj[p.id] = {
              access_token: p.access_token,
              name: p.name,
              expires_at: null,
            };
          }
        } catch (err: any) {
          console.warn("pages refresh failed for", uid, err?.message || err);
        }

        await doc.ref.update({
          long_token: newToken,
          expires_at: newExpiresAt,
          pages: pagesObj,
          updated_at: Date.now(),
        });

        console.log(`Refreshed token for ${uid}`);
        results.push({ uid, ok: true });
      } catch (err: any) {
        console.error(`Failed to refresh token for ${uid}`, err?.response?.data || err.message || err);
        await doc.ref.update({ 
          needs_reauth: true, 
          reauth_reason: err?.response?.data || err.message || "" 
        });
        results.push({ uid, ok: false, error: err?.response?.data || err.message || "" });
      }
    }

    console.log("Token refresh summary:", { refreshed: results.length, details: results });
  }
);

export const exchangeTokenHttp = onRequest(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      console.log("========================================");
      console.log("🔥 exchangeToken (HTTP) called");
      console.log("Headers:", JSON.stringify(req.headers, null, 2));
      console.log("Body:", JSON.stringify(req.body, null, 2));
      console.log("========================================");
      
      const authHeader = req.headers.authorization as string | undefined;
      const userId = await verifyAuthToken(authHeader);
      
      if (!userId) {
        res.status(401).json({ 
          error: "unauthenticated",
          message: "Please log in first"
        });
        return;
      }
      
      console.log(`✅ Authenticated as: ${userId}`);
      
      const { data } = req.body;
      const { uid, short_token, pageId } = data || {}; // ✅ Extract pageId
      
      if (!uid || !short_token) {
        res.status(400).json({ 
          error: "invalid-argument",
          message: "uid and short_token are required"
        });
        return;
      }

      // ✅ Pass pageId to exchangeTokenLogic
      const result = await exchangeTokenLogic(uid, short_token, pageId);
      
      console.log("✅ Token exchange successful");
      res.json({ result });
      
    } catch (error: any) {
      console.error("❌ exchangeToken HTTP error:", error);
      
      res.status(500).json({ 
        error: "internal",
        message: error.message || "Internal server error",
        details: error.toString()
      });
    }
  }
);

export const exchangeToken = onCall(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 exchangeToken (callable) called");
    console.log("Auth:", request.auth ? "Authenticated" : "Not authenticated");
    console.log("Data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const { uid, short_token, pageId } = request.data; // ✅ Extract pageId
      
      if (!uid || !short_token) {
        throw new HttpsError("invalid-argument", "Missing uid or short_token");
      }

      // ✅ Pass pageId to exchangeTokenLogic
      const result = await exchangeTokenLogic(uid, short_token, pageId);
      
      console.log("✅ Token exchange successful");
      return result;
      
    } catch (error: any) {
      console.error("❌ exchangeToken error:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError(
        "internal", 
        error.message || "Failed to exchange token"
      );
    }
  }
);


export const checkTokenExpiration = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Manila",
    secrets: [],
  },
  async (event) => {
    const now = Date.now();
    const twoMonthsInMs = 60 * 24 * 60 * 60 * 1000; // 60 days
    const warningThreshold = now + twoMonthsInMs;

    console.log("🔍 Checking token expiration...");

    const snapshot = await db.collection("fb_tokens")
      .where("provider", "==", "facebook")
      .get();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const expiresAt = data.expires_at;
      
      if (!expiresAt) continue;

      const daysLeft = Math.round((expiresAt - now) / (1000 * 60 * 60 * 24));
      
      // ✅ Create warning if expiring within 60 days
      if (expiresAt <= warningThreshold && expiresAt > now) {
        console.log(`⚠️ Token for ${doc.id} expires in ${daysLeft} days`);
        
        // Store warning in Firestore
        await db.collection("fb_tokens").doc(doc.id).update({
          expirationWarning: true,
          expirationWarningDate: now,
          daysUntilExpiration: daysLeft,
        });
        
        // ✅ Optional: Send notification (implement your notification system)
        // await sendNotificationToAdmin(`Facebook token expires in ${daysLeft} days`);
      } else if (expiresAt <= now) {
        console.log(`❌ Token for ${doc.id} has expired`);
        
        await db.collection("fb_tokens").doc(doc.id).update({
          expired: true,
          expiredAt: now,
          needs_reauth: true,
        });
      } else {
        // Clear warning if more than 60 days left
        if (data.expirationWarning) {
          await db.collection("fb_tokens").doc(doc.id).update({
            expirationWarning: false,
            expirationWarningDate: null,
            daysUntilExpiration: null,
          });
        }
      }
    }

    console.log("✅ Token expiration check complete");
  }
);

// ============================================================================
// ✅ NEW: Get Token Status (for frontend to check)
// ============================================================================

export const getTokenStatus = onCall(
  {
    cors: true,
    secrets: [],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const tokenDoc = await db.collection('fb_tokens').doc('facebook_admin').get();
      
      if (!tokenDoc.exists) {
        return {
          configured: false,
          message: "No Facebook token configured",
        };
      }
      
      const data = tokenDoc.data()!;
      const expiresAt = data.expires_at || 0;
      const now = Date.now();
      const daysLeft = Math.round((expiresAt - now) / (1000 * 60 * 60 * 24));
      
      return {
        configured: true,
        expiresAt: expiresAt,
        daysLeft: daysLeft,
        expired: expiresAt <= now,
        expirationWarning: data.expirationWarning || false,
        pageId: data.pageId || null,
        needsRenewal: daysLeft <= 60 && daysLeft > 0,
      };
    } catch (error: any) {
      console.error("❌ Error getting token status:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

