import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}


// RAG Chatbot Functions
export {
  generateAnswer,
  generateGeminiEmbedding,

  generateGeminiResponse,
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
  
  batchSyncCategoriesToInfoBank,


} from "./announcement";

// Facebook Token Management Functions
export {
  refreshTokensDaily,
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