import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}


// RAG Chatbot Functions
export {
  generateAnswer,
  generateCohereResponse,

  generateCohereEmbedding,
} from "./ragChat";

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
  // ✅ Information Bank diagnostic and sync functions
  debugInfoBank,
  batchSyncCategoriesToInfoBank,
  // ✅ Test and debugging functions
  testCreateInfoBank,
  listInfoBankEntries,
  deleteInfoBankEntry,
} from "./announcement";

// Facebook Token Management Functions
export {
  refreshTokensDaily,
  exchangeToken,
  exchangeTokenHttp,
  testFacebookConnection,
  testFacebookConnectionHttp,
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