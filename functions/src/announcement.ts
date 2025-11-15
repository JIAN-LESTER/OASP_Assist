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
  deadline: admin.firestore.Timestamp | null;
  deleted: boolean;
  fetched_at: admin.firestore.FieldValue;
  processed_by_cohere: boolean;
  stored_in_storage: boolean;
  notification_sent: boolean;
}

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

// ✅ SIGNIFICANTLY IMPROVED: Multi-strategy deadline parsing with better accuracy
function parseDeadlineToTimestamp(deadline: string | null): admin.firestore.Timestamp | null {
  if (!deadline || deadline.trim() === '') return null;

  try {
    console.log(`🔍 Attempting to parse deadline: "${deadline}"`);
    const cleanedDeadline = deadline.trim();
    
    // Strategy 1: Full date formats (Month DD, YYYY or Mon DD, YYYY)
    const fullDatePatterns = [
      /(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/i,
      /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/i,
    ];
    
    for (const pattern of fullDatePatterns) {
      const match = cleanedDeadline.match(pattern);
      if (match) {
        const parsedDate = new Date(match[0].replace(/(\d+)(st|nd|rd|th)/, '$1'));
        if (!isNaN(parsedDate.getTime())) {
          parsedDate.setHours(23, 59, 59, 999);
          console.log(`✅ Parsed (full date pattern): ${parsedDate.toISOString()}`);
          return admin.firestore.Timestamp.fromDate(parsedDate);
        }
      }
    }
    
    // Strategy 2: MM/DD/YYYY or DD/MM/YYYY or MM-DD-YYYY formats
    const slashDateMatch = cleanedDeadline.match(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
    if (slashDateMatch) {
      // Try MM/DD/YYYY first (common US format)
      const month = parseInt(slashDateMatch[1]) - 1;
      const day = parseInt(slashDateMatch[2]);
      const year = parseInt(slashDateMatch[3]);
      
      let parsedDate = new Date(year, month, day);
      
      // Validate: if month > 12, it's probably DD/MM/YYYY
      if (month > 11 || day > 31) {
        parsedDate = new Date(year, parseInt(slashDateMatch[2]) - 1, parseInt(slashDateMatch[1]));
      }
      
      if (!isNaN(parsedDate.getTime()) && parsedDate.getFullYear() === year) {
        parsedDate.setHours(23, 59, 59, 999);
        console.log(`✅ Parsed (slash date): ${parsedDate.toISOString()}`);
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }
    
    // Strategy 3: Relative dates (e.g., "in 3 days", "next week", "tomorrow")
  const relativeDatePatterns = [
  { pattern: /tomorrow/i, days: 1 },
  { pattern: /in\s+(\d+)\s+days?/i, daysFromMatch: true },
  { pattern: /next\s+week/i, days: 7 },
  { pattern: /(\d+)\s+days?\s+from\s+now/i, daysFromMatch: true },
];

for (const entry of relativeDatePatterns) {
  const match = cleanedDeadline.match(entry.pattern);
  if (match) {
    // ✅ Safely determine how many days to add
    let daysToAdd = 0;
    if (entry.daysFromMatch && match[1]) {
      daysToAdd = parseInt(match[1]);
    } else if (typeof entry.days === 'number') {
      daysToAdd = entry.days;
    }

    if (!isNaN(daysToAdd) && daysToAdd > 0) {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + daysToAdd);
      futureDate.setHours(23, 59, 59, 999);
      console.log(`✅ Parsed (relative date): ${futureDate.toISOString()}`);
      return admin.firestore.Timestamp.fromDate(futureDate);
    }
  }
}
    
    // Strategy 4: Month and day without year (assume current or next year)
    const monthDayPattern = /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?/i;
    const monthDayMatch = cleanedDeadline.match(monthDayPattern);
    if (monthDayMatch) {
      const currentYear = new Date().getFullYear();
      let parsedDate = new Date(`${monthDayMatch[0]} ${currentYear}`);
      
      // If date is in the past, use next year
      if (parsedDate < new Date()) {
        parsedDate = new Date(`${monthDayMatch[0]} ${currentYear + 1}`);
      }
      
      if (!isNaN(parsedDate.getTime())) {
        parsedDate.setHours(23, 59, 59, 999);
        console.log(`✅ Parsed (month-day, inferred year): ${parsedDate.toISOString()}`);
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }
    
    // Strategy 5: Try native Date parsing as last resort
    let parsedDate = new Date(cleanedDeadline);
    if (!isNaN(parsedDate.getTime()) && parsedDate.getFullYear() > 2020) {
      parsedDate.setHours(23, 59, 59, 999);
      console.log(`✅ Parsed (native Date): ${parsedDate.toISOString()}`);
      return admin.firestore.Timestamp.fromDate(parsedDate);
    }

    console.warn(`⚠️ Could not parse deadline date: "${deadline}"`);
    return null;
  } catch (error) {
    console.error(`❌ Error parsing deadline: ${deadline}`, error);
    return null;
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

// ✅ IMPROVED: More aggressive deadline extraction with better patterns
async function analyzeAnnouncement(message: string, cohereKey: string): Promise<CohereResult> {
  try {
    const prompt = `Analyze this announcement and categorize it. Also extract any deadlines mentioned.

Announcement: "${message}"

Categories:
- Admission: enrollment, registration, application, requirements, class schedule, semester, subjects, programs, exams, clearance
- Scholarship: scholarship, stipend, allowance, grantee, renewal, eligibility, screening, shortlisted, beneficiary, grant
- Placement: placement, hiring, job, employment, employer, resume, cv, interview, company, opportunity, deployment
- General: everything else

CRITICAL for deadlines - Extract dates in these formats:
1. Full dates: "January 15, 2025", "Jan 15, 2025", "15 January 2025"
2. Slash dates: "01/15/2025", "1/15/2025", "15/01/2025"
3. Date ranges: "January 10-15, 2025" (use the END date)
4. Relative: "tomorrow", "in 3 days", "next week"
5. Month-day only: "January 15" (infer year)
6. Context phrases: "deadline:", "due by:", "submit by:", "until:", "before:", "on or before"

IMPORTANT:
- Look for the MOST SPECIFIC date in the text
- If multiple dates exist, choose the one associated with "deadline", "due", "submit"
- Extract COMPLETE date strings with month, day, and year when available
- For ranges, always use the END date
- If no explicit date, return null

Respond ONLY in JSON format:
{
  "category": "category_name",
  "deadline": "complete_date_string_or_null"
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 300,
        temperature: 0.1,
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
        
        // ✅ NEW: If Cohere didn't find deadline, try fallback extraction
        if (!deadline) {
          deadline = extractDeadlines(message);
          if (deadline) {
            console.log(`🔍 Cohere missed deadline, fallback found: "${deadline}"`);
          }
        }
        
        console.log(`🤖 Cohere analysis: Category="${category}", Deadline="${deadline}"`);
        
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

// ✅ SIGNIFICANTLY IMPROVED: More comprehensive deadline extraction
function extractDeadlines(message: string): string | null {
  const deadlinePatterns = [
    // Pattern 1: Full dates with year (highest priority)
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}/gi,
    
    // Pattern 2: Slash/dash dates with year
    /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}/g,
    
    // Pattern 3: Date ranges with year (extract end date)
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?\s*[-–]\s*\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}/gi,
    
    // Pattern 4: Contextual deadline phrases with dates
    /(?:deadline|due|submit|until|before|on or before)[:\s]+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?/gi,
    
    // Pattern 5: Month and day without year
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?/gi,
    
    // Pattern 6: Relative dates
    /(?:tomorrow|in\s+\d+\s+days?|next\s+week|\d+\s+days?\s+from\s+now)/gi,
  ];
  
  const extractedDates: string[] = [];
  
  for (const pattern of deadlinePatterns) {
    const matches = message.matchAll(pattern);
    for (const match of matches) {
      let found = match[0].trim();
      
      // Clean up contextual phrases
      found = found.replace(/^(?:deadline|due|submit|until|before|on or before)[:\s]+/i, '');
      
      // For date ranges, extract the end date
      const rangeMatch = found.match(/(\d{1,2})(?:st|nd|rd|th)?\s*[-–]\s*(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/i);
      if (rangeMatch) {
        const month = found.match(/(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/i)?.[0];
        found = `${month} ${rangeMatch[2]}, ${rangeMatch[3]}`;
      }
      
      if (found && found.length > 0 && !extractedDates.includes(found)) {
        extractedDates.push(found);
      }
    }
  }
  
  if (extractedDates.length === 0) {
    console.log('⚠️ No deadline found in message');
    return null;
  }
  
  console.log(`📅 Extracted ${extractedDates.length} potential deadline(s): ${extractedDates.join(', ')}`);
  
  // Prioritize dates with years
  const datesWithYear = extractedDates.filter(d => /\d{4}/.test(d));
  if (datesWithYear.length > 0) {
    return datesWithYear[0];
  }
  
  return extractedDates[0];
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
    const deadlineTimestamp = parseDeadlineToTimestamp(cohereResult.deadline);
    
    const newData: AnnouncementData = {
      message: message,
      created_time: post.created_time,
      full_picture: imageUrl || post.full_picture || "",
      original_image_url: post.full_picture || "",
      permalink_url: post.permalink_url || "",
      category: cohereResult.category || "General",
      deadline: deadlineTimestamp || null,
      deleted: false,
      fetched_at: admin.firestore.FieldValue.serverTimestamp(),
      processed_by_cohere: true,
      stored_in_storage: !!imageUrl,
      notification_sent: false,
    };
    
    await postRef.set(newData);
  } else {
    const docData = doc.data();
    if (docData?.deleted) {
      console.log(`Skipping deleted post: ${postId}`);
      return;
    }
    
    console.log(`Updating existing post: ${postId}`);
    
    // ✅ NEW: Re-analyze if deadline is missing but message contains potential deadline
    let updatedDeadline = docData?.deadline;
    if (!updatedDeadline && message) {
      console.log(`🔍 Re-analyzing post ${postId} for missing deadline`);
      const cohereResult = await analyzeAnnouncement(message, cohereKey);
      updatedDeadline = parseDeadlineToTimestamp(cohereResult.deadline);
      if (updatedDeadline) {
        console.log(`✅ Found missing deadline: ${updatedDeadline.toDate().toISOString()}`);
      }
    }
    
    await postRef.update({
      message: message,
      full_picture: imageUrl || docData?.full_picture || post.full_picture || "",
      permalink_url: post.permalink_url || "",
      deadline: updatedDeadline || docData?.deadline || null,
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
            const deadlineTimestamp = parseDeadlineToTimestamp(cohereResult.deadline);
            
            await doc.ref.update({
              category: cohereResult.category,
              deadline: deadlineTimestamp,
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