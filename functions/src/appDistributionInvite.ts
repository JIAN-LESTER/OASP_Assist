import axios from "axios";
import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const releaseName =
  "projects/1008880584715/apps/1:1008880584715:android:586d0981fcdb06057f5f0e/releases/0j25a9h2agmvo";

export const sendAppDistributionInvite = onCall(async (request) => {
  const email = request.auth?.token.email;
  const emailVerified = request.auth?.token.email_verified;

  if (!request.auth || !email) {
    throw new HttpsError(
      "unauthenticated",
      "You must be logged in to receive the invite.",
    );
  }

  if (emailVerified !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Please verify your email before requesting an invite.",
    );
  }

  try {
    const accessToken = await admin.credential
      .applicationDefault()
      .getAccessToken();
    const token = accessToken.access_token;

    if (!token) {
      throw new Error("Missing access token");
    }

    await axios.post(
      `https://firebaseappdistribution.googleapis.com/v1/${releaseName}:distribute`,
      {testerEmails: [email]},
      {headers: {Authorization: `Bearer ${token}`}},
    );

    return {success: true};
  } catch (error) {
    console.error("Failed to send App Distribution invite", error);
    throw new HttpsError(
      "internal",
      "Failed to send app invite.",
    );
  }
});
