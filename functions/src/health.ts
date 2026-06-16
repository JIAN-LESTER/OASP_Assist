import {onCall, onRequest} from "firebase-functions/v2/https";

export const healthCheck = onRequest(
  {
    cors: true,
  },
  (req, res) => {
    res.status(200).json({
      status: "healthy",
      timestamp: new Date().toISOString(),
      service: "Firebase Cloud Functions v2",
    });
  }
);

export const testSync = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log(" Test function called");
    console.log("Auth:", request.auth ? "Yes" : "No");
    console.log("Data:", request.data);

    return {
      success: true,
      message: "Test function working!",
      receivedData: request.data,
      timestamp: new Date().toISOString(),
      hasAuth: !!request.auth,
    };
  }
);
