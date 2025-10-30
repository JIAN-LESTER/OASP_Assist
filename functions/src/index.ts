import * as admin from "firebase-admin";

// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
  admin.initializeApp();
}

// ============================================================================
// EXPORT ALL FUNCTIONS FROM MODULES
// ============================================================================

// RAG Chatbot Functions
export {
  generateAnswer,
  generateCohereEmbedding,
  generateCohereResponse,
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
} from "./notification";

// Health Check & Test Functions
export {
  healthCheck,
  testSync,
} from "./health";