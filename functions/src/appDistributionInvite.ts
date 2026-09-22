import axios from "axios";
import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const appResourceName =
  "projects/13855273820/apps/1:13855273820:android:ea1cd67d149ffc5cd94799";
const appDistributionApiUrl =
  "https://firebaseappdistribution.googleapis.com/v1";

interface AppDistributionRelease {
  name: string;
}

interface ListReleasesResponse {
  releases?: AppDistributionRelease[];
}

export const sendAppDistributionInvite = onCall(
  {region: "us-central1"},
  async (request) => {
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

      const releasesResponse = await axios.get<ListReleasesResponse>(
        `${appDistributionApiUrl}/${appResourceName}/releases`,
        {
          headers: {Authorization: `Bearer ${token}`},
          params: {pageSize: 1},
        },
      );
      const latestReleaseName = releasesResponse.data.releases?.[0]?.name;

      if (!latestReleaseName) {
        console.error("No App Distribution releases found", {
          appResourceName,
        });
        throw new HttpsError(
          "failed-precondition",
          "No app release is available for distribution.",
        );
      }

      await axios.post(
        `${appDistributionApiUrl}/${latestReleaseName}:distribute`,
        {testerEmails: [email]},
        {headers: {Authorization: `Bearer ${token}`}},
      );

      console.info("App Distribution invite sent", {
        email,
        releaseName: latestReleaseName,
      });
      return {success: true};
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("Failed to send App Distribution invite", error);
      throw new HttpsError(
        "internal",
        "Failed to send app invite.",
      );
    }
  },
);
