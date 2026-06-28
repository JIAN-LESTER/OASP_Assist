import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}


// RAG Chatbot Functions
export {
  generateAnswer,

  generateEmbedding,


} from "./ragChat";

export {
  deleteFromPinecone,
  queryPinecone,
  insertPineconeDocument,
  insertPineconeDocumentBatch,
  logPineconeUsage,

  deletePineconeDocuments,

  getPineconeStats,
  fetchPineconeVectors,
  deleteAllPineconeVectors,
  generateGeminiEmbedding,
  generateGeminiResponse,
  generateCohereEmbedding,
  generateCohereResponse,
  checkPineconeHealth,

} from "./documentCrud";

// User Management Functions
export {
  createUser,
  deleteUser,
  updateUser,
  setAdminRole,
} from "./userCrud";

// Announcement & Facebook Sync Functions
export {
  syncFacebookPosts,
  manualSyncFacebookPosts,
  manualSyncFacebookPostsHttp,
  reprocessExistingAnnouncements,
  cleanupDeletedAnnouncement,

  batchSyncCategoriesToInfoBank,

} from "./announcement";

// Facebook Token Management Functions
export {
  exchangeToken,
  exchangeTokenHttp,

} from "./facebookToken";

// Notification Functions
export {
  onAnnouncementCreated,
  checkUpcomingDeadlines,
  cleanupOldNotifications,
  onEscalationCreated,
  onEscalationReplied,
} from "./notification";

// Health Check & Test Functions
export {
  healthCheck,
  testSync,
} from "./health";

export {
  checkFacebookTokenExpiration,
  manualCheckFacebookToken,


} from "./fbTokenExpiry";

export {
  sendAppDistributionInvite,
} from "./appDistributionInvite";

export {
  sendCustomEmailVerification,
  sendCustomPasswordReset,
  sendCustomEmailChangeVerification,
} from "./authEmail";

export {
  logFirebaseRead,
  logTopLevelFirebaseUsage,
  logNestedFirebaseUsage,
} from "./firebaseUsage";
