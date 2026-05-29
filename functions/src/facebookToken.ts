import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import axios from "axios";

const db = admin.firestore();
const FB_API_VERSION = "v24.0";

//   Get app credentials from Firestore instead of secrets
async function getAppCredentials(appId?: string): Promise<{appId: string, appSecret: string}[]> {
  try {
    const doc = await db.collection("fb_app_credentials").doc("apps").get();

    if (!doc.exists) {
      throw new Error("No Facebook app credentials configured. Please add them in Firestore at fb_app_credentials/apps");
    }

    const data = doc.data()!;
    const apps: {appId: string, appSecret: string}[] = [];

    // If specific appId requested, return only that one
    if (appId) {
      if (data[appId] && data[appId].appSecret) {
        return [{
          appId: appId,
          appSecret: data[appId].appSecret,
        }];
      }
      throw new Error(`App ID ${appId} not found in credentials`);
    }

    // Otherwise return all configured apps
    for (const [id, config] of Object.entries(data)) {
      if (typeof config === "object" && (config as any).appSecret) {
        apps.push({
          appId: id,
          appSecret: (config as any).appSecret,
        });
      }
    }

    if (apps.length === 0) {
      throw new Error("No valid app credentials found in Firestore");
    }

    console.log(` Found ${apps.length} configured app(s)`);
    return apps;
  } catch (error: any) {
    console.error(" Error getting app credentials:", error);
    throw new Error(`Failed to get app credentials: ${error.message}`);
  }
}

async function verifyAuthToken(authHeader: string | undefined): Promise<string | null> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const idToken = authHeader.split("Bearer ")[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken.uid;
  } catch (error) {
    console.error("Token verification failed:", error);
    return null;
  }
}

//   Detect which app the token belongs to
async function detectAppFromToken(shortToken: string): Promise<{appId: string, appSecret: string} | null> {
  try {
    const apps = await getAppCredentials();

    // Try first app to debug the token
    const firstApp = apps[0];
    const response = await axios.get<{ data?: { app_id?: string } }>(
      `https://graph.facebook.com/${FB_API_VERSION}/debug_token`,
      {
        params: {
          input_token: shortToken,
          access_token: `${firstApp.appId}|${firstApp.appSecret}`,
        },
        timeout: 10000,
      }
    );

    const data = response.data?.data;
    const tokenAppId = data?.app_id;

    console.log(` Token belongs to app: ${tokenAppId}`);

    // Find matching app in our credentials
    const matchingApp = apps.find((app) => app.appId === tokenAppId);

    if (matchingApp) {
      console.log(` Found matching app credentials for ${tokenAppId}`);
      return matchingApp;
    }

    console.warn(` Token app ID ${tokenAppId} not in our configured apps`);
    return null;
  } catch (error: any) {
    console.error(" Error detecting app from token:", error.message);
    return null;
  }
}

//   Try to exchange with detected or all available apps
async function exchangeShortForLong(
  shortToken: string,
  appId?: string,
  appSecret?: string
): Promise<{ access_token: string; expires_in?: number; app_used?: string }> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/oauth/access_token`;

  // If specific app credentials provided, use them
  if (appId && appSecret) {
    console.log(` Trying exchange with provided app: ${appId}`);
    return await attemptExchange(url, shortToken, appId, appSecret);
  }

  // Otherwise, try detecting which app the token belongs to
  const detected = await detectAppFromToken(shortToken);

  if (detected) {
    console.log(` Using detected app: ${detected.appId}`);
    const result = await attemptExchange(url, shortToken, detected.appId, detected.appSecret);
    return {...result, app_used: detected.appId};
  }

  // If detection failed, try all configured apps sequentially
  console.log(" Detection failed, trying all configured apps...");

  const apps = await getAppCredentials();
  const errors: string[] = [];

  for (let i = 0; i < apps.length; i++) {
    const app = apps[i];
    try {
      console.log(` Trying app ${i + 1}/${apps.length} (${app.appId})...`);
      const result = await attemptExchange(url, shortToken, app.appId, app.appSecret);
      console.log(` Success with app ${app.appId}`);
      return {...result, app_used: app.appId};
    } catch (error: any) {
      console.log(` Failed with ${app.appId}: ${error.message}`);
      errors.push(`${app.appId}: ${error.message}`);
    }
  }

  // All apps failed
  throw new Error(`Token exchange failed with all ${apps.length} configured app(s):\n${errors.join("\n")}`);
}

async function attemptExchange(
  url: string,
  shortToken: string,
  appId: string,
  appSecret: string
): Promise<{ access_token: string; expires_in?: number }> {
  const params = {
    grant_type: "fb_exchange_token",
    client_id: appId,
    client_secret: appSecret,
    fb_exchange_token: shortToken,
  };

  const resp = await axios.get<{ access_token: string; expires_in?: number; token_type?: string }>(
    url,
    {
      params,
      timeout: 30000,
    }
  );

  if (resp.status !== 200 || !resp.data.access_token) {
    throw new Error(`Exchange failed with app ${appId}`);
  }

  console.log(` Token exchanged successfully with app ${appId}`);
  if (resp.data.expires_in) {
    const days = Math.round(resp.data.expires_in / 86400);
    console.log(` Token valid for ${resp.data.expires_in} seconds (~${days} days)`);
  }

  return resp.data;
}

async function getUserPages(longUserToken: string): Promise<any> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/me/accounts`;
  const resp = await axios.get(url, {params: {access_token: longUserToken}});
  return resp.data as any;
}

async function exchangeTokenLogic(
  uid: string,
  shortToken: string,
  pageId?: string,
  appId?: string
): Promise<any> {
  try {
    console.log(` Exchanging token for uid: ${uid}`);
    if (pageId) {
      console.log(` Page ID provided: ${pageId}`);
    }
    if (appId) {
      console.log(` Specific app requested: ${appId}`);
    }

    // Get app credentials from Firestore
    let appSecret: string | undefined;
    if (appId) {
      const apps = await getAppCredentials(appId);
      if (apps.length > 0) {
        appSecret = apps[0].appSecret;
      } else {
        throw new Error(`App ID ${appId} not configured in Firestore`);
      }
    }

    console.log(" Calling Facebook API...");
    const data = await exchangeShortForLong(shortToken, appId, appSecret);
    const longToken = data.access_token;
    const expiresIn = data.expires_in;
    const appUsed = data.app_used || appId;

    console.log(` Token exchanged successfully using app: ${appUsed}`);
    console.log(` Expires in: ${expiresIn} seconds`);

    const me = await axios.get<{ id: string; name?: string }>(
      `https://graph.facebook.com/${FB_API_VERSION}/me`,
      {
        params: {access_token: longToken, fields: "id,name"},
      }
    );

    const fbUserId = me.data.id;
    const now = Date.now();

    let expiresAt: number | null = null;

    if (expiresIn !== undefined && expiresIn !== null) {
      expiresAt = now + (Number(expiresIn) * 1000);
      console.log(` Token will expire at: ${new Date(expiresAt).toISOString()}`);
    } else {
      console.warn(" No expires_in received, setting to 60 days");
      expiresAt = now + (60 * 24 * 60 * 60 * 1000);
    }

    const pagesObj: { [key: string]: any } = {};
    try {
      const pagesResp = await getUserPages(longToken);
      const pages = pagesResp.data || [];
      console.log(` Found ${pages.length} page(s)`);

      for (const p of pages) {
        pagesObj[p.id] = {
          access_token: p.access_token,
          name: p.name,
          expires_at: null,
        };
      }
    } catch (err: any) {
      console.warn(" Could not fetch pages:", err?.message);
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
      pageId: pageId || null,
      appId: appUsed, //  Save the app ID used
      updated_at: now,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    console.log(` Saving token data for app: ${appUsed}`);
    await docRef.set(saveData, {merge: true});

    console.log(` Token saved to fb_tokens/${uid}`);

    const daysValid = expiresIn ?
      Math.round(Number(expiresIn) / 86400) :
      60;

    return {
      success: true,
      ok: true,
      expires_in: expiresIn || (60 * 86400),
      expires_at: expiresAt,
      fbUserId: fbUserId,
      pagesCount: Object.keys(pagesObj).length,
      pageId: pageId || null,
      appId: appUsed,
      message: `Token saved successfully using app ${appUsed}. Valid for ~${daysValid} days.`,
    };
  } catch (error: any) {
    console.error(" exchangeTokenLogic error:", error);

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

export const exchangeTokenHttp = onRequest(
  {
    cors: true,
    secrets: [], //  No secrets needed
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
      console.log(" exchangeToken (HTTP) called");
      console.log("========================================");

      const authHeader = req.headers.authorization as string | undefined;
      const userId = await verifyAuthToken(authHeader);

      if (!userId) {
        res.status(401).json({
          error: "unauthenticated",
          message: "Please log in first",
        });
        return;
      }

      console.log(` Authenticated as: ${userId}`);

      const {data} = req.body;
      const {uid, short_token, pageId, appId} = data || {};

      if (!uid || !short_token) {
        res.status(400).json({
          error: "invalid-argument",
          message: "uid and short_token are required",
        });
        return;
      }

      const result = await exchangeTokenLogic(uid, short_token, pageId, appId);

      console.log(" Token exchange successful");
      res.json({result});
    } catch (error: any) {
      console.error(" exchangeToken HTTP error:", error);

      res.status(500).json({
        error: "internal",
        message: error.message || "Internal server error",
        details: error.toString(),
      });
    }
  }
);

export const exchangeToken = onCall(
  {
    cors: true,
    secrets: [], //  No secrets needed
  },
  async (request) => {
    console.log("========================================");
    console.log(" exchangeToken (callable) called");
    console.log("========================================");

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const {uid, short_token, pageId, appId} = request.data;

      if (!uid || !short_token) {
        throw new HttpsError("invalid-argument", "Missing uid or short_token");
      }

      const result = await exchangeTokenLogic(uid, short_token, pageId, appId);

      console.log(" Token exchange successful");
      return result;
    } catch (error: any) {
      console.error(" exchangeToken error:", error);

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

//   Function to manage app credentials via API
export const manageAppCredentials = onCall(
  {
    cors: true,
    secrets: [],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const {action, appId, appSecret} = request.data;

      if (action === "add") {
        if (!appId || !appSecret) {
          throw new HttpsError("invalid-argument", "appId and appSecret are required");
        }

        await db.collection("fb_app_credentials").doc("apps").set({
          [appId]: {appSecret, addedAt: admin.firestore.FieldValue.serverTimestamp()},
        }, {merge: true});

        return {success: true, message: `App ${appId} added successfully`};
      }

      if (action === "remove") {
        if (!appId) {
          throw new HttpsError("invalid-argument", "appId is required");
        }

        await db.collection("fb_app_credentials").doc("apps").update({
          [appId]: admin.firestore.FieldValue.delete(),
        });

        return {success: true, message: `App ${appId} removed successfully`};
      }

      if (action === "list") {
        const doc = await db.collection("fb_app_credentials").doc("apps").get();
        if (!doc.exists) {
          return {success: true, apps: []};
        }

        const data = doc.data()!;
        const apps = Object.keys(data).map((appId) => ({
          appId,
          addedAt: data[appId].addedAt?.toDate?.()?.toISOString?.() || "Unknown",
        }));

        return {success: true, apps};
      }

      throw new HttpsError("invalid-argument", "Invalid action. Use 'add', 'remove', or 'list'");
    } catch (error: any) {
      console.error(" manageAppCredentials error:", error);

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", error.message);
    }
  }
);
