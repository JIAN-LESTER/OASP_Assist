import * as admin from "firebase-admin";
import {HttpsError} from "firebase-functions/v2/https";

export type AppRole = "user" | "staff" | "admin";

export async function requireAuthenticated(
  auth: {uid: string; token?: Record<string, unknown>} | undefined
): Promise<string> {
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  return auth.uid;
}

export async function getUserRole(
  auth: {uid: string; token?: Record<string, unknown>} | undefined
): Promise<AppRole> {
  const uid = await requireAuthenticated(auth);
  if (auth?.token?.admin === true) return "admin";

  const userDoc = await admin.firestore().collection("users").doc(uid).get();
  const role = userDoc.data()?.role;
  if (role === "admin" || role === "staff" || role === "user") return role;

  throw new HttpsError("permission-denied", "No valid application role found.");
}

export async function requireRole(
  auth: {uid: string; token?: Record<string, unknown>} | undefined,
  allowedRoles: AppRole[]
): Promise<AppRole> {
  const role = await getUserRole(auth);
  if (!allowedRoles.includes(role)) {
    throw new HttpsError("permission-denied", "You do not have permission for this action.");
  }
  return role;
}

export async function requireAdmin(
  auth: {uid: string; token?: Record<string, unknown>} | undefined
): Promise<void> {
  await requireRole(auth, ["admin"]);
}

export async function requireAiQuota(
  auth: {uid: string; token?: Record<string, unknown>} | undefined,
  dailyLimit = 50
): Promise<void> {
  const role = await getUserRole(auth);
  if (role === "staff" || role === "admin") return;

  const uid = auth!.uid;
  const today = new Date().toISOString().substring(0, 10);
  const ref = admin.firestore().collection("ai_rate_limits").doc(uid);
  const allowed = await admin.firestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const data = snapshot.data() ?? {};
    const count = data.date === today && typeof data.count === "number" ? data.count : 0;
    if (count >= dailyLimit) return false;
    transaction.set(ref, {
      uid,
      date: today,
      count: count + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
    return true;
  });

  if (!allowed) {
    throw new HttpsError("resource-exhausted", "Daily AI operation limit reached.");
  }
}
