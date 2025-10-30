import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";

// Define secrets
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");


const db = admin.firestore();
const storage = admin.storage();

const FB_API_VERSION = "v24.0";
const PAGE_ID = "730995450096065";

// ============================================================================
// INTERFACES
// ============================================================================

interface FacebookPost {
  id: string;
  message?: string;
  created_time: string;
  full_picture?: string;
  permalink_url?: string;
  attachments?: any;
}

interface CohereResult {
  category: string;
  deadline: string | null;
}

interface AnnouncementData {
  message: string;
  created_time: string;
  full_picture: string;
  original_image_url: string;
  permalink_url: string;
  category: string;
  deadline: string | null;
  deleted: boolean;
  fetched_at: admin.firestore.FieldValue;
  processed_by_cohere: boolean;
  stored_in_storage: boolean;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

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

async function getAccessToken(): Promise<string> {
  try {
    console.log("🔍 Looking for Facebook token...");
    
    const tokenDoc = await db.collection('fb_tokens').doc('facebook_admin').get();
    
    if (!tokenDoc.exists) {
      console.log("❌ No token found at fb_tokens/facebook_admin");
      throw new Error('No Facebook token configured. Please configure token using the key (🔑) button');
    }
    
    const data = tokenDoc.data();
    
    if (!data) {
      throw new Error('Invalid token data in database');
    }
    
    const pages = data.pages || {};
    const pageIds = Object.keys(pages);
    
    console.log(`📄 Found ${pageIds.length} page(s) in token data`);
    console.log(`🎯 Target PAGE_ID: ${PAGE_ID}`);
    
    if (pages[PAGE_ID] && pages[PAGE_ID].access_token) {
      console.log(`✅ Using page token for ${PAGE_ID}`);
      return pages[PAGE_ID].access_token;
    }
    
    if (pageIds.length > 0) {
      const firstPageId = pageIds[0];
      const firstPageToken = pages[firstPageId].access_token;
      console.warn(`⚠️ Page ${PAGE_ID} not found in saved pages`);
      console.warn(`⚠️ Using first available page: ${firstPageId}`);
      return firstPageToken;
    }
    
    if (data.long_token) {
      console.warn('⚠️⚠️⚠️ WARNING: No page tokens found!');
      console.warn('⚠️⚠️⚠️ Falling back to user token (may not work for page posts)');
      return data.long_token;
    }
    
    throw new Error('No valid access token found. Please refresh your token.');
    
  } catch (error: any) {
    console.error('❌ Error getting access token:', error.message);
    throw error;
  }
}

async function fetchFacebookPosts(): Promise<FacebookPost[]> {
  try {
    console.log("🔍 Fetching Facebook posts...");
    console.log("📍 Page ID:", PAGE_ID);
    console.log("📍 API Version:", FB_API_VERSION);
    
    const accessToken = await getAccessToken();
    console.log("✅ Access token retrieved");
    
    const url = `https://graph.facebook.com/${FB_API_VERSION}/${PAGE_ID}/posts`;
    const params = {
      fields: "message,created_time,full_picture,permalink_url,attachments",
      limit: 20,
      access_token: accessToken,
    };
    
    console.log("📡 Making request to:", url);
    console.log("📡 Request params:", { ...params, access_token: "***" });
    
    const response = await axios.get<{ data: FacebookPost[] }>(url, { 
      params,
      timeout: 30000,
    });
    
    console.log("✅ Facebook API response status:", response.status);
    console.log("✅ Posts received:", response.data.data?.length || 0);
    
    return response.data.data || [];
    
  } catch (error: any) {
    console.error("❌ Error fetching Facebook posts:");
    console.error("Error message:", error.message);
    
    if (error.response) {
      console.error("Response status:", error.response.status);
      console.error("Response data:", JSON.stringify(error.response.data, null, 2));
      
      const errorData = error.response.data;
      
      if (error.response.status === 400) {
        if (errorData?.error?.message) {
          throw new Error(`Facebook API Error: ${errorData.error.message}`);
        }
        throw new Error("Invalid request to Facebook API. Check your PAGE_ID and token.");
      }
      
      if (error.response.status === 190 || errorData?.error?.code === 190) {
        throw new Error("Facebook Access Token is invalid or expired. Please refresh your token.");
      }
      
      if (error.response.status === 403) {
        throw new Error("Access denied. Check if the token has permission to read page posts.");
      }
    }
    
    throw error;
  }
}

async function downloadAndUploadImage(
  imageUrl: string,
  postId: string
): Promise<string> {
  try {
    console.log(`📥 Downloading image for post ${postId}`);
    console.log(`🔗 Source URL: ${imageUrl.substring(0, 100)}...`);
    
    const response = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      timeout: 30000,
      maxBodyLength: 50 * 1024 * 1024,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; OASP-Bot/1.0)',
      },
    } as any);
    
    const buffer = Buffer.from(response.data as Buffer);
    const contentType = response.headers["content-type"] || "image/jpeg";
    
    console.log(`📊 Image size: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
    console.log(`📊 Content type: ${contentType}`);
    
    if (!contentType.startsWith('image/')) {
      throw new Error(`Invalid content type: ${contentType}`);
    }
    
    const ext = contentType.split("/")[1]?.split(';')[0] || "jpg";
    const fileName = `announcements/${postId}.${ext}`;
    
    const bucket = storage.bucket();
    const file = bucket.file(fileName);
    
    console.log(`⬆️ Uploading to: ${fileName}`);
    
    await file.save(buffer, {
      metadata: {
        contentType: contentType,
        cacheControl: 'public, max-age=31536000',
        metadata: {
          postId: postId,
          uploadedAt: new Date().toISOString(),
          originalUrl: imageUrl.substring(0, 500),
        },
      },
      public: true,
    });
    
    const [signedUrl] = await file.getSignedUrl({
      action: 'read',
      expires: '03-01-2500',
    });
    
    console.log(`✅ Image uploaded successfully`);
    console.log(`🔗 Signed URL: ${signedUrl.substring(0, 100)}...`);
    
    return signedUrl;
    
  } catch (error: any) {
    console.error(`❌ Error uploading image for post ${postId}:`, error.message);
    
    if (error.response) {
      console.error(`❌ HTTP Status: ${error.response.status}`);
      console.error(`❌ Response data:`, error.response.data);
    }
    
    if (error.code === 'ECONNABORTED') {
      console.error(`❌ Download timeout for ${postId}`);
    }
    
    return "";
  }
}

async function analyzeAnnouncement(message: string, cohereKey: string): Promise<CohereResult> {
  try {
    const prompt = `Analyze this announcement and categorize it. Also extract any deadlines mentioned.

Announcement: "${message}"

Categories:
- Admission: enrollment, registration, application, requirements, class schedule, semester, subjects, programs, exams, clearance
- Scholarship: scholarship, stipend, allowance, grantee, renewal, eligibility, screening, shortlisted, beneficiary, grant
- Placement: placement, hiring, job, employment, employer, resume, cv, interview, company, opportunity, deployment
- General: everything else

Respond in JSON format:
{
  "category": "category_name",
  "deadline": "extracted_date_or_null"
}

For deadlines, extract specific dates and times. Format them clearly. If no deadline found, use null.`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 200,
        temperature: 0.3,
      },
      {
        headers: {
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );
    
    if (response.status === 200) {
      const generatedText = String(response.data?.text ?? "").trim();
      
      try {
        const cleanedResponse = extractJsonFromResponse(generatedText);
        const result = JSON.parse(cleanedResponse);
        
        let category = result.category?.toString() || "General";
        let deadline = result.deadline?.toString() || null;
        
        category = cleanCategory(category);
        
        if (deadline && 
            (deadline.toLowerCase() === "null" || deadline.trim() === "")) {
          deadline = null;
        }
        
        return {category, deadline};
      } catch (e) {
        console.log("JSON parse error, using fallback analysis");
        return fallbackAnalysis(message);
      }
    } else {
      throw new Error(`Cohere API error: ${response.status}`);
    }
    
  } catch (error: any) {
    console.error("Cohere analysis error:", error.message);
    return fallbackAnalysis(message);
  }
}

function extractJsonFromResponse(text: string): string {
  const jsonMatch = text.match(/\{[\s\S]*\}/);
  if (jsonMatch) {
    return jsonMatch[0];
  }
  
  const categoryMatch = text.match(/"category"\s*:\s*"([^"]+)"/i);
  const deadlineMatch = text.match(/"deadline"\s*:\s*"([^"]+)"/i) || 
                        text.match(/"deadline"\s*:\s*null/i);
  
  if (categoryMatch) {
    const category = categoryMatch[1];
    const deadline = deadlineMatch ? 
      (deadlineMatch[1] || null) : null;
    return JSON.stringify({category, deadline});
  }
  
  throw new Error("Could not extract JSON from response");
}

function cleanCategory(category: string): string {
  const cleaned = category.toLowerCase().trim();
  
  if (cleaned.includes("admission") || cleaned.includes("enroll")) {
    return "Admission";
  } else if (cleaned.includes("scholarship") || 
             cleaned.includes("financial aid")) {
    return "Scholarship";
  } else if (cleaned.includes("placement") || 
             cleaned.includes("job") || 
             cleaned.includes("career")) {
    return "Placement";
  }
  
  return "General";
}

function fallbackAnalysis(message: string): CohereResult {
  const messageLower = message.toLowerCase();
  let category = "General";
  let deadline: string | null = null;
  
  if (messageLower.includes("enrollment") ||
      messageLower.includes("registration") ||
      messageLower.includes("application") ||
      messageLower.includes("requirements") ||
      messageLower.includes("class schedule") ||
      messageLower.includes("semester") ||
      messageLower.includes("subject") ||
      messageLower.includes("program") ||
      messageLower.includes("exam schedule") ||
      messageLower.includes("clearance") ||
      messageLower.includes("admission")) {
    category = "Admission";
  } else if (messageLower.includes("scholarship") ||
             messageLower.includes("stipend") ||
             messageLower.includes("allowance") ||
             messageLower.includes("grantee") ||
             messageLower.includes("renewal") ||
             messageLower.includes("eligibility") ||
             messageLower.includes("screening") ||
             messageLower.includes("shortlisted") ||
             messageLower.includes("beneficiary") ||
             messageLower.includes("grant")) {
    category = "Scholarship";
  } else if (messageLower.includes("placement") ||
             messageLower.includes("hiring") ||
             messageLower.includes("job") ||
             messageLower.includes("employment") ||
             messageLower.includes("employer") ||
             messageLower.includes("resume") ||
             messageLower.includes("cv") ||
             messageLower.includes("interview") ||
             messageLower.includes("company") ||
             messageLower.includes("opportunity") ||
             messageLower.includes("deployment")) {
    category = "Placement";
  }
  
  deadline = extractDeadlines(message);
  
  return {category, deadline};
}

function extractDeadlines(message: string): string | null {
  const deadlinePatterns = [
    /(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4}(?:,?\s+at\s+\d{1,2}:\d{2}\s?(?:AM|PM|am|pm))?)/gi,
    /(?<date>\d{1,2}:\d{2}\s?(?:AM|PM|am|pm))/gi,
    /by\s+(?<date>(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2},?\s+\d{4})/gi,
  ];
  
  const extractedDates: string[] = [];
  
  for (const pattern of deadlinePatterns) {
    const matches = message.matchAll(pattern);
    for (const match of matches) {
      const found = match.groups?.date?.trim();
      if (found && found.length > 0) {
        extractedDates.push(found);
      }
    }
  }
  
  if (extractedDates.length === 0) {
    return null;
  }
  
  return extractedDates.length === 1 ? 
    extractedDates[0] : 
    extractedDates.join(" & ");
}

async function processPost(post: FacebookPost, cohereKey: string): Promise<void> {
  const postId = post.id;
  const message = post.message || "";
  
  if (!message) {
    console.log(`Skipping post ${postId} - no message`);
    return;
  }
  
  const postRef = db.collection("announcements").doc(postId);
  const doc = await postRef.get();
  
  let imageUrl = "";
  if (post.full_picture) {
    imageUrl = await downloadAndUploadImage(post.full_picture, postId);
  }
  
  if (!doc.exists) {
    console.log(`Creating new post: ${postId}`);
    
    const cohereResult = await analyzeAnnouncement(message, cohereKey);
    
    const newData: AnnouncementData = {
      message: message,
      created_time: post.created_time,
      full_picture: imageUrl || post.full_picture || "",
      original_image_url: post.full_picture || "",
      permalink_url: post.permalink_url || "",
      category: cohereResult.category || "General",
      deadline: cohereResult.deadline || null,
      deleted: false,
      fetched_at: admin.firestore.FieldValue.serverTimestamp(),
      processed_by_cohere: true,
      stored_in_storage: !!imageUrl,
    };
    
    await postRef.set(newData);
  } else {
    const docData = doc.data();
    if (docData?.deleted) {
      console.log(`Skipping deleted post: ${postId}`);
      return;
    }
    
    console.log(`Updating existing post: ${postId}`);
    await postRef.update({
      message: message,
      full_picture: imageUrl || docData?.full_picture || post.full_picture || "",
      permalink_url: post.permalink_url || "",
      last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
      stored_in_storage: !!imageUrl || docData?.stored_in_storage || false,
    });
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================

export const syncFacebookPosts = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Asia/Manila",
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [COHERE_API_KEY],
  },
  async (event) => {
    try {
      console.log("Starting Facebook posts sync...");
      
      const posts = await fetchFacebookPosts();
      console.log(`Fetched ${posts.length} posts from Facebook`);
      
      for (const post of posts) {
        await processPost(post, COHERE_API_KEY.value());
      }
      
      console.log("Facebook sync completed successfully");
    } catch (error) {
      console.error("Error syncing Facebook posts:", error);
      throw error;
    }
  }
);

async function syncFacebookPostsLogic(): Promise<any> {
  try {
    console.log("📡 Starting Facebook sync...");
    
    console.log("📡 Fetching Facebook posts...");
    const posts = await fetchFacebookPosts();
    console.log(`✅ Fetched ${posts.length} posts from Facebook`);
    
    let processed = 0;
    let failed = 0;
    
    for (const post of posts) {
      try {
        console.log(`📝 Processing post: ${post.id}`);
        await processPost(post, COHERE_API_KEY.value());
        processed++;
      } catch (postError: any) {
        console.error(`❌ Error processing post ${post.id}:`, postError.message);
        failed++;
      }
    }
    
    console.log(`✅ Sync complete: ${processed} processed, ${failed} failed`);
    
    return {
      success: true,
      message: `Successfully synced ${processed} posts` + (failed > 0 ? ` (${failed} failed)` : ''),
      count: processed,
      failed: failed,
      total: posts.length,
    };
  } catch (error: any) {
    console.error("❌ syncFacebookPostsLogic error:", error);
    
    return {
      success: false,
      error: error.message,
      message: error.message,
    };
  }
}

export const manualSyncFacebookPosts = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [COHERE_API_KEY],
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 manualSyncFacebookPosts (callable) called");
    console.log("========================================");

    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const result = await syncFacebookPostsLogic();
      return result;
      
    } catch (error: any) {
      console.error("❌ Sync error:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError(
        "internal",
        error.message || "Sync failed"
      );
    }
  }
);

export const manualSyncFacebookPostsHttp = onRequest(
  {
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [COHERE_API_KEY],
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
      console.log("🔥 manualSyncFacebookPosts (HTTP) called");
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
      
      const result = await syncFacebookPostsLogic();
      
      res.json({ result });
      
    } catch (error: any) {
      console.error("❌ Sync HTTP error:", error);
      res.status(500).json({ 
        error: "internal",
        message: error.message || "Sync failed",
        details: error.toString()
      });
    }
  }
);

export const reprocessExistingAnnouncements = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    secrets: [COHERE_API_KEY],
  },
  async (request) => {
    try {
      console.log("Starting reprocessing of existing announcements...");
      
      const snapshot = await db.collection("announcements")
        .where("processed_by_cohere", "==", false)
        .get();
      
      let processed = 0;
      let failed = 0;
      
      for (const doc of snapshot.docs) {
        const docData = doc.data();
        const message = docData.message || "";
        
        if (message) {
          try {
            const cohereResult = await analyzeAnnouncement(
              message,
              COHERE_API_KEY.value()
            );
            
            await doc.ref.update({
              category: cohereResult.category,
              deadline: cohereResult.deadline,
              processed_by_cohere: true,
              reprocessed_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            
            processed++;
            console.log(`Reprocessed announcement ${doc.id}`);
          } catch (e) {
            failed++;
            console.error(`Error reprocessing announcement ${doc.id}:`, e);
          }
        }
      }
      
      console.log(`Reprocessing complete: ${processed} processed, ${failed} failed`);
      
      return {
        success: true,
        message: `Reprocessed ${processed} announcements, ${failed} failed`,
        processed,
        failed,
      };
    } catch (error: any) {
      console.error("Error reprocessing existing announcements:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

export const cleanupDeletedAnnouncement = onDocumentUpdated(
  {
    document: "announcements/{postId}",
    secrets: [],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    const postId = event.params.postId;
    
    if (!before || !after) return;
    
    if (!before.deleted && after.deleted && after.stored_in_storage) {
      try {
        console.log(`Cleaning up image for deleted post: ${postId}`);
        
        const bucket = storage.bucket();
        const [files] = await bucket.getFiles({
          prefix: `announcements/${postId}`,
        });
        
        for (const file of files) {
          await file.delete();
          console.log(`Deleted file: ${file.name}`);
        }
        
      } catch (error) {
        console.error(`Error cleaning up images for ${postId}:`, error);
      }
    }
  }
);

// Continuing in next artifact due to size...