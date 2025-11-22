import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";

// Define secrets
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");
const GOOGLE_VISION_API_KEY = defineSecret("GOOGLE_VISION_API_KEY"); // ✅ NEW: For OCR

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
  announcementId: string; // ✅ Unique ID field
  message: string;
  created_time: string;
  full_picture: string;
  original_image_url: string;
  permalink_url: string;
  category: string;
  deadline: admin.firestore.Timestamp | null;
  deleted: boolean; // ✅ Soft delete flag
  fetched_at: admin.firestore.FieldValue;
  processed_by_cohere: boolean;
  stored_in_storage: boolean;
  notification_sent: boolean;
  ocr_text?: string;
  has_image_text: boolean;
}

// ============================================================================
// ✅ NEW: OCR FUNCTIONS FOR IMAGE TEXT EXTRACTION
// ============================================================================

/**
 * Extract text from image using Google Cloud Vision API
 */
async function extractTextFromImage(imageUrl: string): Promise<string> {
  try {
    console.log(`🔍 Extracting text from image: ${imageUrl.substring(0, 100)}...`);
    
    const visionApiKey = GOOGLE_VISION_API_KEY.value();
    
    // Download image
    const imageResponse = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      timeout: 30000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; OASP-Bot/1.0)',
      },
    });
    
    const imageBuffer = Buffer.from(new Uint8Array(imageResponse.data as ArrayBuffer));
    const base64Image = imageBuffer.toString('base64');
    
    // Call Google Cloud Vision API
    const visionResponse = await axios.post(
      `https://vision.googleapis.com/v1/images:annotate?key=${visionApiKey}`,
      {
        requests: [
          {
            image: {
              content: base64Image,
            },
            features: [
              {
                type: "TEXT_DETECTION",
                maxResults: 1,
              },
            ],
          },
        ],
      },
      {
        headers: {
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );
    
    const visionData = (visionResponse.data as any);
    const annotations = visionData?.responses?.[0]?.textAnnotations;
    
    if (annotations && annotations.length > 0) {
      const extractedText = annotations[0].description;
      console.log(`✅ Extracted ${extractedText.length} characters from image`);
      console.log(`📝 Preview: ${extractedText.substring(0, 200)}...`);
      return extractedText;
    }
    
    console.log(`⚠️ No text found in image`);
    return "";
    
  } catch (error: any) {
    console.error(`❌ Error extracting text from image:`, error.message);
    
    if (error.response) {
      console.error(`❌ Vision API Status: ${error.response.status}`);
      console.error(`❌ Vision API Response:`, JSON.stringify(error.response.data));
    }
    
    return ""; // Return empty string on error, don't fail the entire process
  }
}

/**
 * Alternative: Extract text using Tesseract.js (if running in Node environment)
 * This is a fallback option if Google Vision API is not available
 */


// ============================================================================
// EXISTING HELPER FUNCTIONS (unchanged)
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

function parseDeadlineToTimestamp(deadline: string | null): admin.firestore.Timestamp | null {
  if (!deadline || deadline.trim() === '') return null;

  try {
    console.log(`🔍 Attempting to parse deadline: "${deadline}"`);
    const cleanedDeadline = deadline.trim();
    
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
    
    const slashDateMatch = cleanedDeadline.match(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
    if (slashDateMatch) {
      const month = parseInt(slashDateMatch[1]) - 1;
      const day = parseInt(slashDateMatch[2]);
      const year = parseInt(slashDateMatch[3]);
      
      let parsedDate = new Date(year, month, day);
      
      if (month > 11 || day > 31) {
        parsedDate = new Date(year, parseInt(slashDateMatch[2]) - 1, parseInt(slashDateMatch[1]));
      }
      
      if (!isNaN(parsedDate.getTime()) && parsedDate.getFullYear() === year) {
        parsedDate.setHours(23, 59, 59, 999);
        console.log(`✅ Parsed (slash date): ${parsedDate.toISOString()}`);
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }
    
    const relativeDatePatterns = [
      { pattern: /tomorrow/i, days: 1 },
      { pattern: /in\s+(\d+)\s+days?/i, daysFromMatch: true },
      { pattern: /next\s+week/i, days: 7 },
      { pattern: /(\d+)\s+days?\s+from\s+now/i, daysFromMatch: true },
    ];

    for (const entry of relativeDatePatterns) {
      const match = cleanedDeadline.match(entry.pattern);
      if (match) {
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
    
    const monthDayPattern = /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?/i;
    const monthDayMatch = cleanedDeadline.match(monthDayPattern);
    if (monthDayMatch) {
      const currentYear = new Date().getFullYear();
      let parsedDate = new Date(`${monthDayMatch[0]} ${currentYear}`);
      
      if (parsedDate < new Date()) {
        parsedDate = new Date(`${monthDayMatch[0]} ${currentYear + 1}`);
      }
      
      if (!isNaN(parsedDate.getTime())) {
        parsedDate.setHours(23, 59, 59, 999);
        console.log(`✅ Parsed (month-day, inferred year): ${parsedDate.toISOString()}`);
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }
    
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

function extractDeadlines(message: string): string | null {
  const deadlinePatterns = [
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}/gi,
    /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}/g,
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?\s*[-–]\s*\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}/gi,
    /(?:deadline|due|submit|until|before|on or before)[:\s]+(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?/gi,
    /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?/gi,
    /(?:tomorrow|in\s+\d+\s+days?|next\s+week|\d+\s+days?\s+from\s+now)/gi,
  ];
  
  const extractedDates: string[] = [];
  
  for (const pattern of deadlinePatterns) {
    const matches = message.matchAll(pattern);
    for (const match of matches) {
      let found = match[0].trim();
      
      found = found.replace(/^(?:deadline|due|submit|until|before|on or before)[:\s]+/i, '');
      
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
  
  const datesWithYear = extractedDates.filter(d => /\d{4}/.test(d));
  if (datesWithYear.length > 0) {
    return datesWithYear[0];
  }
  
  return extractedDates[0];
}

// ============================================================================
// ✅ ENHANCED: Category-specific extraction with image OCR support
// ============================================================================

interface ExtractedAdmissionData {
  title: string;
  content: string;
  steps: string[];
  requirements: string[];
  contacts: string[];
  academicYear: { start: number; end?: number } | null;
  schedules: Array<{ date: string; dayOfWeek: string; locations: string[] }>;
}

interface ExtractedScholarshipData {
  name: string;
  description: string;
  scholarshipProvider: string;
  eligibilityRequirements: string[];
  privileges: string[];
  applicationLink: string;
}

interface ExtractedPlacementData {
  partnerCompany: string;
  positions: string[];
  contacts: string[];
  isRecruiting: boolean;
}

async function extractAdmissionData(message: string, cohereKey: string): Promise<ExtractedAdmissionData> {
  try {
    const prompt = `Extract admission information from this announcement. Return ONLY valid JSON.

Announcement: "${message}"

Extract these fields:
- title: A short descriptive title for the admission (max 100 chars)
- content: The full announcement content
- steps: Array of enrollment/application steps mentioned
- requirements: Array of required documents or requirements
- contacts: Array of contact information (email, phone, office)
- academicYear: Object with "start" year and optionally "end" year (e.g., {"start": 2024, "end": 2025})
- schedules: Array of schedule objects with "date", "dayOfWeek", and "locations" array

Respond ONLY in this JSON format:
{
  "title": "string",
  "content": "string",
  "steps": ["step1", "step2"],
  "requirements": ["req1", "req2"],
  "contacts": ["contact1"],
  "academicYear": {"start": 2024, "end": 2025},
  "schedules": [{"date": "OCT 4, 2025", "dayOfWeek": "SATURDAY", "locations": ["Location 1"]}]
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1000,
        temperature: 0.1,
      },
      {
        headers: {
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);

    return {
      title: result.title || message.substring(0, 100),
      content: message,
      steps: Array.isArray(result.steps) ? result.steps : [],
      requirements: Array.isArray(result.requirements) ? result.requirements : [],
      contacts: Array.isArray(result.contacts) ? result.contacts : [],
      academicYear: result.academicYear || null,
      schedules: Array.isArray(result.schedules) ? result.schedules : [],
    };
  } catch (error) {
    console.error("Error extracting admission data:", error);
    return {
      title: message.substring(0, 100),
      content: message,
      steps: [],
      requirements: [],
      contacts: [],
      academicYear: null,
      schedules: [],
    };
  }
}

async function extractScholarshipData(message: string, cohereKey: string): Promise<ExtractedScholarshipData> {
  try {
    const prompt = `Extract scholarship information from this announcement. Return ONLY valid JSON.

Announcement: "${message}"

Extract these fields:
- name: The scholarship name/title
- description: Brief description of the scholarship
- scholarshipProvider: Organization or entity offering the scholarship
- eligibilityRequirements: Array of eligibility criteria
- privileges: Array of benefits (tuition, stipend, allowance, etc.)
- applicationLink: URL for application if mentioned

Respond ONLY in this JSON format:
{
  "name": "string",
  "description": "string",
  "scholarshipProvider": "string",
  "eligibilityRequirements": ["req1", "req2"],
  "privileges": ["benefit1", "benefit2"],
  "applicationLink": "string or empty"
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1000,
        temperature: 0.1,
      },
      {
        headers: {
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);

    return {
      name: result.name || "Scholarship Announcement",
      description: result.description || message,
      scholarshipProvider: result.scholarshipProvider || "",
      eligibilityRequirements: Array.isArray(result.eligibilityRequirements) ? result.eligibilityRequirements : [],
      privileges: Array.isArray(result.privileges) ? result.privileges : [],
      applicationLink: result.applicationLink || "",
    };
  } catch (error) {
    console.error("Error extracting scholarship data:", error);
    return {
      name: "Scholarship Announcement",
      description: message,
      scholarshipProvider: "",
      eligibilityRequirements: [],
      privileges: [],
      applicationLink: "",
    };
  }
}

async function extractPlacementData(message: string, cohereKey: string): Promise<ExtractedPlacementData> {
  try {
    const prompt = `Extract job placement/hiring information from this announcement. Return ONLY valid JSON.

Announcement: "${message}"

Extract these fields:
- partnerCompany: Company name that is hiring
- positions: Array of job positions/titles available
- contacts: Array of contact information for application
- isRecruiting: Boolean indicating if currently accepting applications (default true)

Respond ONLY in this JSON format:
{
  "partnerCompany": "string",
  "positions": ["position1", "position2"],
  "contacts": ["contact1"],
  "isRecruiting": true
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1000,
        temperature: 0.1,
      },
      {
        headers: {
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);

    return {
      partnerCompany: result.partnerCompany || "Company",
      positions: Array.isArray(result.positions) ? result.positions : [],
      contacts: Array.isArray(result.contacts) ? result.contacts : [],
      isRecruiting: result.isRecruiting !== false,
    };
  } catch (error) {
    console.error("Error extracting placement data:", error);
    return {
      partnerCompany: "Company",
      positions: [],
      contacts: [],
      isRecruiting: true,
    };
  }
}

async function createAdmissionFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string
): Promise<void> {
  try {
    const admissionRef = db.collection("admissions").doc(postId);
    const existingDoc = await admissionRef.get();
    
    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      
      // ✅ If deleted, don't recreate or restore
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping admission for post ${postId} - it was deleted by user`);
        return;
      }
      
      console.log(`Admission already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractAdmissionData(message, cohereKey);

    await admissionRef.set({
      id: postId,
      announcementId: postId, // ✅ Link to announcement
      title: extractedData.title,
      content: extractedData.content,
      source: "Facebook Announcement",
      academicYear: extractedData.academicYear,
      contact: extractedData.contacts,
      steps: extractedData.steps,
      requirements: extractedData.requirements,
      links: [],
      schedules: extractedData.schedules,
      deadline: deadline,
      deleted: false, // ✅ Soft delete flag
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
    });

    console.log(`✅ Created admission from announcement ${postId}`);
  } catch (error) {
    console.error(`❌ Error creating admission from announcement ${postId}:`, error);
  }
}

async function createScholarshipFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string
): Promise<void> {
  try {
    const scholarshipRef = db.collection("scholarships").doc(postId);
    const existingDoc = await scholarshipRef.get();
    
    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      
      // ✅ If deleted, don't recreate or restore
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping scholarship for post ${postId} - it was deleted by user`);
        return;
      }
      
      console.log(`Scholarship already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractScholarshipData(message, cohereKey);

    await scholarshipRef.set({
      scholarshipID: postId,
      sourceId: postId,
      announcementId: postId, // ✅ Link to announcement
      name: extractedData.name,
      description: extractedData.description,
      scholarshipProvider: extractedData.scholarshipProvider,
      eligibilityRequirements: extractedData.eligibilityRequirements,
      privileges: extractedData.privileges,
      deadline: deadline ? deadline.toDate() : null,
      applicationLink: extractedData.applicationLink,
      deleted: false, // ✅ Soft delete flag
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
    });

    console.log(`✅ Created scholarship from announcement ${postId}`);
  } catch (error) {
    console.error(`❌ Error creating scholarship from announcement ${postId}:`, error);
  }
}

async function createPlacementFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string
): Promise<void> {
  try {
    const placementRef = db.collection("placements").doc(postId);
    const existingDoc = await placementRef.get();
    
    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      
      // ✅ If deleted, don't recreate or restore
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping placement for post ${postId} - it was deleted by user`);
        return;
      }
      
      console.log(`Placement already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractPlacementData(message, cohereKey);

    await placementRef.set({
      placementID: postId,
      announcementId: postId, // ✅ Link to announcement
      partnerCompany: extractedData.partnerCompany,
      positions: extractedData.positions,
      contacts: extractedData.contacts,
      isRecruiting: extractedData.isRecruiting,
      deadline: deadline ? deadline.toDate() : null,
      deleted: false, // ✅ Soft delete flag
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
    });

    console.log(`✅ Created placement from announcement ${postId}`);
  } catch (error) {
    console.error(`❌ Error creating placement from announcement ${postId}:`, error);
  }
}

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
    
    // ✅ CASCADE DELETE: When announcement is soft-deleted, also soft-delete category document
    if (!before.deleted && after.deleted) {
      console.log(`🗑️ Announcement ${postId} was soft-deleted, cascading to category document...`);
      
      const category = after.category?.toLowerCase() || "";
      
      // ✅ Soft delete the linked category document
      await softDeleteCategoryDocument(postId, category);
      
      // ✅ Optionally clean up images if stored in storage
      if (after.stored_in_storage) {
        try {
          console.log(`🖼️ Cleaning up images for deleted post: ${postId}`);
          
          const bucket = storage.bucket();
          const [files] = await bucket.getFiles({
            prefix: `announcements/${postId}`,
          });
          
          for (const file of files) {
            await file.delete();
            console.log(`✅ Deleted file: ${file.name}`);
          }
        } catch (error) {
          console.error(`❌ Error cleaning up images for ${postId}:`, error);
        }
      }
      
      console.log(`✅ Cascade delete complete for ${postId}`);
    }
    
    // ✅ REMOVED: No restoration logic - once deleted, stays deleted
  }
);
// ============================================================================
// ✅ ENHANCED: processPost with IMAGE OCR SUPPORT
// ============================================================================

async function processPost(post: FacebookPost, cohereKey: string): Promise<void> {
  const postId = post.id;
  const originalMessage = post.message || "";
  
  const postRef = db.collection("announcements").doc(postId);
  const doc = await postRef.get();
  
  // ✅ Extract text from image if present
  let ocrText = "";
  let hasImageText = false;
  
  if (post.full_picture) {
    console.log(`🖼️ Post ${postId} has an image, attempting OCR...`);
    
    try {
      ocrText = await extractTextFromImage(post.full_picture);
      
      if (ocrText && ocrText.trim().length > 0) {
        hasImageText = true;
        console.log(`✅ Extracted ${ocrText.length} characters from image`);
      } else {
        console.log(`⚠️ No text found in image for post ${postId}`);
      }
    } catch (ocrError: any) {
      console.error(`⚠️ OCR failed for post ${postId}:`, ocrError.message);
    }
  }
  
  // ✅ Combine original message + OCR text for AI analysis ONLY
  let messageForAnalysis = originalMessage;
  
  if (hasImageText && ocrText) {
    if (originalMessage.trim().length === 0) {
      messageForAnalysis = ocrText;
      console.log(`📝 Using OCR text for analysis (no caption)`);
    } else {
      messageForAnalysis = `${originalMessage}\n\n[Image Text]:\n${ocrText}`;
      console.log(`📝 Combined caption with OCR text for analysis`);
    }
  }
  
  // Skip if no content after OCR attempt
  if (!messageForAnalysis || messageForAnalysis.trim().length === 0) {
    console.log(`Skipping post ${postId} - no message or image text`);
    return;
  }
  
  // Download and upload image
  let imageUrl = "";
  if (post.full_picture) {
    imageUrl = await downloadAndUploadImage(post.full_picture, postId);
  }
  
  if (!doc.exists) {
    // ✅ NEW ANNOUNCEMENT
    console.log(`Creating new post: ${postId}`);
    
    const cohereResult = await analyzeAnnouncement(messageForAnalysis, cohereKey);
    const deadlineTimestamp = parseDeadlineToTimestamp(cohereResult.deadline);
    
    const newData: AnnouncementData = {
      announcementId: postId, // ✅ Unique announcement ID
      message: originalMessage,
      created_time: post.created_time,
      full_picture: imageUrl || post.full_picture || "",
      original_image_url: post.full_picture || "",
      permalink_url: post.permalink_url || "",
      category: cohereResult.category || "General",
      deadline: deadlineTimestamp || null,
      deleted: false, // ✅ Soft delete flag
      fetched_at: admin.firestore.FieldValue.serverTimestamp(),
      processed_by_cohere: true,
      stored_in_storage: !!imageUrl,
      notification_sent: false,
      ocr_text: ocrText || "",
      has_image_text: hasImageText,
    };
    
    await postRef.set(newData);

    // ✅ Create category-specific document with announcementId reference
    const category = cohereResult.category?.toLowerCase() || "general";
    
    if (category === "admission") {
      await createAdmissionFromAnnouncement(postId, messageForAnalysis, deadlineTimestamp, cohereKey);
    } else if (category === "scholarship") {
      await createScholarshipFromAnnouncement(postId, messageForAnalysis, deadlineTimestamp, cohereKey);
    } else if (category === "placement") {
      await createPlacementFromAnnouncement(postId, messageForAnalysis, deadlineTimestamp, cohereKey);
    }
    
    console.log(`✅ Post ${postId} processed with category: ${category}${hasImageText ? ' (with image OCR)' : ''}`);
    
  } else {
    // ✅ EXISTING ANNOUNCEMENT
    const docData = doc.data();
    
    // ✅ CRITICAL: If deleted, SKIP and don't restore
    if (docData?.deleted === true) {
      console.log(`⏭️ Skipping post ${postId} - user has deleted it (deleted: true)`);
      return; // ✅ Don't restore deleted posts
    }
    
    // ✅ REGULAR UPDATE (not deleted)
    console.log(`Updating existing post: ${postId}`);
    
    let updatedDeadline = docData?.deadline;
    if (!updatedDeadline && messageForAnalysis) {
      console.log(`🔍 Re-analyzing post ${postId} for missing deadline`);
      const cohereResult = await analyzeAnnouncement(messageForAnalysis, cohereKey);
      updatedDeadline = parseDeadlineToTimestamp(cohereResult.deadline);
    }
    
    await postRef.update({
      message: originalMessage,
      full_picture: imageUrl || docData?.full_picture || post.full_picture || "",
      permalink_url: post.permalink_url || "",
      deadline: updatedDeadline || docData?.deadline || null,
      last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
      stored_in_storage: !!imageUrl || docData?.stored_in_storage || false,
      ocr_text: ocrText || docData?.ocr_text || "",
      has_image_text: hasImageText || docData?.has_image_text || false,
    });
  }
}

async function softDeleteCategoryDocument(
  announcementId: string,
  category: string
): Promise<void> {
  try {
    let collectionName = "";
    
    if (category === "admission") {
      collectionName = "admissions";
    } else if (category === "scholarship") {
      collectionName = "scholarships";
    } else if (category === "placement") {
      collectionName = "placements";
    } else {
      return; // No category-specific document for "general"
    }
    
    const docRef = db.collection(collectionName).doc(announcementId);
    const doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        deleted: true,
        deletedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Soft-deleted ${collectionName} document for ${announcementId}`);
    }
  } catch (error) {
    console.error(`❌ Error soft-deleting category document for ${announcementId}:`, error);
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
    secrets: [COHERE_API_KEY, GOOGLE_VISION_API_KEY], // ✅ NEW: Add Vision API key
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
    let withOCR = 0;
    
    for (const post of posts) {
      try {
        console.log(`📝 Processing post: ${post.id}`);
        
        const hasImage = !!post.full_picture;
        await processPost(post, COHERE_API_KEY.value());
        
        if (hasImage) {
          const postDoc = await db.collection("announcements").doc(post.id).get();
          if (postDoc.exists && postDoc.data()?.has_image_text) {
            withOCR++;
          }
        }
        
        processed++;
      } catch (postError: any) {
        console.error(`❌ Error processing post ${post.id}:`, postError.message);
        failed++;
      }
    }
    
    console.log(`✅ Sync complete: ${processed} processed, ${failed} failed, ${withOCR} with OCR`);
    
    return {
      success: true,
      message: `Successfully synced ${processed} posts (${withOCR} with image text extraction)` + (failed > 0 ? ` (${failed} failed)` : ''),
      count: processed,
      failed: failed,
      withOCR: withOCR,
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
    secrets: [COHERE_API_KEY, GOOGLE_VISION_API_KEY], // ✅ NEW
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
    secrets: [COHERE_API_KEY, GOOGLE_VISION_API_KEY], // ✅ NEW
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
    secrets: [COHERE_API_KEY, GOOGLE_VISION_API_KEY], // ✅ NEW
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

