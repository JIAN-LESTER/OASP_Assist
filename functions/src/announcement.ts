import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";

// Define secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");
const GOOGLE_VISION_API_KEY = defineSecret("GOOGLE_VISION_API_KEY"); // ✅ NEW: For OCR
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const PINECONE_HOST = defineSecret("PINECONE_HOST");

const db = admin.firestore();
const storage = admin.storage();

const FB_API_VERSION = "v24.0";
// const PAGE_ID = "730995450096065";

interface FacebookPost {
  id: string;
  message?: string;
  created_time: string;
  full_picture?: string;
  permalink_url?: string;
  attachments?: any;
}

interface CategoryToInfoBankConfig {
  includeInSearch: boolean;
  autoSync: boolean;
  generateSummary: boolean;
}
// interface FacebookAttachment {
//   media?: { image?: { src: string } };
//   subattachments?: { data: Array<{ media?: { image?: { src: string } } }> };
// }

interface ScheduleEntry {
  date: string;
  dayOfWeek: string;
  year: string;
  locations: string[];
  time?: string;
}

interface CohereResult {
  category: string;
  deadline: string | null;
}


async function getPageId(): Promise<string> {
  try {
    const tokenDoc = await db
      .collection("fb_tokens")  
      .doc("facebook_admin")
      .get();

    if (!tokenDoc.exists) {
      throw new Error(
        "No Facebook configuration found. Please configure token using the settings."
      );
    }

    const data = tokenDoc.data();
    
    // Get the page ID from saved configuration
    const pageId = data?.pageId;
    
    if (!pageId) {
      throw new Error(
        "No Page ID configured. Please add your Facebook Page ID in settings."
      );
    }

    console.log(`✅ Using Page ID: ${pageId}`);
    return pageId;

  } catch (error: any) {
    console.error("❌ Error getting Page ID:", error.message);
    throw error;
  }
}

function extractAllImagesFromPost(post: FacebookPost): string[] {
  const images: string[] = [];

  // 🔥 FIX: Simple extraction without deduplication
  console.log(`📸 Extracting images from post...`);

  // Extract from attachments FIRST (higher quality)
  if (post.attachments?.data) {
    console.log(`  📎 Found ${post.attachments.data.length} attachment(s)`);

    for (let idx = 0; idx < post.attachments.data.length; idx++) {
      const attachment = post.attachments.data[idx];

      // Multiple images (subattachments - album/carousel)
      if (attachment.subattachments?.data) {
        console.log(
          `  📸 Album with ${attachment.subattachments.data.length} images`
        );
        for (
          let subIdx = 0;
          subIdx < attachment.subattachments.data.length;
          subIdx++
        ) {
          const sub = attachment.subattachments.data[subIdx];
          if (sub.media?.image?.src) {
            console.log(
              `    🖼️ Subattachment ${
                subIdx + 1
              }: ${sub.media.image.src.substring(0, 80)}...`
            );
            images.push(sub.media.image.src);
          }
        }
      }
      // Single image attachment
      else if (attachment.media?.image?.src) {
        console.log(
          `    🖼️ Single image: ${attachment.media.image.src.substring(
            0,
            80
          )}...`
        );
        images.push(attachment.media.image.src);
      }
    }
  }

  // Only add full_picture if we found NO images from attachments
  if (images.length === 0 && post.full_picture) {
    console.log(`  📸 Using full_picture (no attachments found)`);
    images.push(post.full_picture);
  }

  console.log(`✅ Extracted ${images.length} image(s) from post`);
  return images;
}

async function downloadAndUploadAllImages(
  imageUrls: string[],
  postId: string
): Promise<string[]> {
  const uploadedUrls: string[] = [];

  console.log(
    `📥 Starting download of ${imageUrls.length} image(s) for post ${postId}`
  );

  for (let i = 0; i < imageUrls.length; i++) {
    const imageUrl = imageUrls[i];
    try {
      console.log(`  📥 Downloading image ${i + 1}/${imageUrls.length}...`);

      const response = await axios.get(imageUrl, {
        responseType: "arraybuffer",
        timeout: 30000,
        maxBodyLength: 50 * 1024 * 1024,
        headers: { "User-Agent": "Mozilla/5.0 (compatible; OASP-Bot/1.0)" },
      } as any);

      const buffer = Buffer.from(response.data as Buffer);
      const contentType = response.headers["content-type"] || "image/jpeg";
      const ext = contentType.split("/")[1]?.split(";")[0] || "jpg";

      // 🔥 FIX: Use index suffix for multiple images
      const fileName =
        imageUrls.length > 1
          ? `announcements/${postId}_${i}.${ext}`
          : `announcements/${postId}.${ext}`;

      const bucket = storage.bucket();
      const file = bucket.file(fileName);

      await file.save(buffer, {
        metadata: {
          contentType,
          cacheControl: "public, max-age=31536000",
          metadata: {
            postId,
            imageIndex: i.toString(),
            totalImages: imageUrls.length.toString(),
          },
        },
        public: true,
      });

      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: "03-01-2500",
      });

      uploadedUrls.push(signedUrl);
      console.log(
        `  ✅ Uploaded image ${i + 1}/${imageUrls.length}: ${fileName}`
      );
    } catch (error: any) {
      console.error(`  ❌ Error uploading image ${i + 1}:`, error.message);
      // Add original URL as fallback
      uploadedUrls.push(imageUrl);
    }
  }

  console.log(
    `✅ Uploaded ${uploadedUrls.length}/${imageUrls.length} images for post ${postId}`
  );
  return uploadedUrls;
}

function extractSchedulesFromOCR(ocrText: string): ScheduleEntry[] {
  const schedules: ScheduleEntry[] = [];
  const lines = ocrText
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);

  // Pattern for dates like "OCT 26", "NOV 8", etc.
  const datePattern =
    /^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s*(\d{1,2})$/i;
  const dayPattern =
    /^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$/i;
  const yearPattern = /^(20\d{2})$/;
  const timePattern = /(\d{1,2}(?::\d{2})?\s*(?:am|pm))/gi;

  // ✅ NEW: Filter out header/common text that appears on all images
  const headerKeywords = [
    "central mindanao university",
    "academic paradise",
    "cmucat schedule",
    "the academic paradise of the south",
  ];

  let currentYear = "";
  let currentDate = "";
  let currentDay = "";
  let currentLocations: string[] = [];
  let currentTime = "";

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const lineLower = line.toLowerCase();

    // ✅ Skip header text that appears on all images
    if (headerKeywords.some((keyword) => lineLower.includes(keyword))) {
      continue;
    }

    // Check for year
    const yearMatch = line.match(yearPattern);
    if (yearMatch) {
      // Save previous entry if exists
      if (currentDate && currentLocations.length > 0) {
        schedules.push({
          date: currentDate,
          dayOfWeek: currentDay,
          year: currentYear || new Date().getFullYear().toString(),
          locations: [...currentLocations],
          time: currentTime,
        });
        currentLocations = [];
        currentTime = "";
      }
      currentYear = yearMatch[1];
      continue;
    }

    // Check for date (e.g., "OCT 26")
    const dateMatch = line.match(datePattern);
    if (dateMatch) {
      // Save previous entry
      if (currentDate && currentLocations.length > 0) {
        schedules.push({
          date: currentDate,
          dayOfWeek: currentDay,
          year: currentYear || new Date().getFullYear().toString(),
          locations: [...currentLocations],
          time: currentTime,
        });
        currentLocations = [];
        currentTime = "";
      }
      currentDate = `${dateMatch[1].toUpperCase()} ${dateMatch[2]}`;
      continue;
    }

    // Check for day of week
    const dayMatch = line.match(dayPattern);
    if (dayMatch) {
      currentDay = dayMatch[1].toUpperCase();
      continue;
    }

    // Check for time patterns
    const timeMatches = line.match(timePattern);
    if (timeMatches && (line.includes("|") || line.includes("-"))) {
      currentTime = line; // e.g., "9-11 am | 1-3 pm"
      continue;
    }

    // ✅ ENHANCED: Better location detection
    // Check for locations (contains city/place names)
    const locationKeywords = [
      "campus",
      "city",
      "butuan",
      "surigao",
      "gingoog",
      "bayugan",
      "university",
      "in-campus",
      "agusan",
      "davao",
      "kalilangan",
      "impasug",
      "quezon",
      "malaybalay",
      "san francisco",
      "elpa",
      "tandag",
      "luna",
      "kapalong",
      "norte",
      "sur",
      "del norte",
      "del sur",
      "zamboanga",
      "ozamiz",
      "misamis",
      "occidental",
      "oriental",
      "pagadian",
      "lapasan",
      "national high school",
      "nhs",
      "cagayan de oro",
      "college",
    ];

    const isLocation = locationKeywords.some((keyword) =>
      lineLower.includes(keyword)
    );

    // ✅ Exclude if it's just "In-Campus" without more specific info
    const isGenericInCampus =
      lineLower === "in-campus" ||
      (lineLower.includes("in-campus") &&
        lineLower.includes("central mindanao"));

    if (isLocation && !isGenericInCampus) {
      // Clean up location
      let location = line.replace(/[()]/g, " ").trim();
      if (location && location.length > 3) {
        currentLocations.push(location);
      }
    }
  }

  // Don't forget last entry
  if (currentDate && currentLocations.length > 0) {
    schedules.push({
      date: currentDate,
      dayOfWeek: currentDay,
      year: currentYear || new Date().getFullYear().toString(),
      locations: [...currentLocations],
      time: currentTime,
    });
  }

  console.log(`📅 Extracted ${schedules.length} schedule entries from OCR`);
  schedules.forEach((s, i) => {
    console.log(
      `   ${i + 1}. ${s.date} (${s.dayOfWeek}): ${s.locations.join(", ")}`
    );
  });

  return schedules;
}

async function extractTextFromImage(imageUrl: string): Promise<string> {
  try {
    console.log(
      `🔍 Extracting text from image: ${imageUrl.substring(0, 100)}...`
    );

    const visionApiKey = GOOGLE_VISION_API_KEY.value();

    // Download image
    const imageResponse = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      timeout: 30000,
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; OASP-Bot/1.0)",
      },
    });

    const imageBuffer = Buffer.from(
      new Uint8Array(imageResponse.data as ArrayBuffer)
    );
    const base64Image = imageBuffer.toString("base64");

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

    const visionData = visionResponse.data as any;
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
      console.error(
        `❌ Vision API Response:`,
        JSON.stringify(error.response.data)
      );
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

async function verifyAuthToken(
  authHeader: string | undefined
): Promise<string | null> {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const idToken = authHeader.split("Bearer ")[1];

  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    return decodedToken.uid;
  } catch (error) {
    console.error("Token verification failed:", error);
    return null;
  }
}

async function getAccessToken(): Promise<string> {
  try {
    console.log("🔍 Looking for Facebook token...");

    const tokenDoc = await db
      .collection("fb_tokens")
      .doc("facebook_admin")
      .get();

    if (!tokenDoc.exists) {
      console.log("❌ No token found at fb_tokens/facebook_admin");
      throw new Error(
        "No Facebook token configured. Please configure token using the key (🔑) button"
      );
    }

    const data = tokenDoc.data();

    if (!data) {
      throw new Error("Invalid token data in database");
    }

    const pages = data.pages || {};
    const pageId = data.pageId; // ✅ Get from saved config instead of hardcoded

    if (!pageId) {
      throw new Error("No Page ID configured. Please add your Page ID in settings.");
    }

    const pageIds = Object.keys(pages);

    console.log(`📄 Found ${pageIds.length} page(s) in token data`);
    console.log(`🎯 Target PAGE_ID: ${pageId}`);

    if (pages[pageId] && pages[pageId].access_token) {
      console.log(`✅ Using page token for ${pageId}`);
      return pages[pageId].access_token;
    }

    if (pageIds.length > 0) {
      const firstPageId = pageIds[0];
      const firstPageToken = pages[firstPageId].access_token;
      console.warn(`⚠️ Page ${pageId} not found in saved pages`);
      console.warn(`⚠️ Using first available page: ${firstPageId}`);
      return firstPageToken;
    }

    if (data.long_token) {
      console.warn("⚠️⚠️⚠️ WARNING: No page tokens found!");
      console.warn(
        "⚠️⚠️⚠️ Falling back to user token (may not work for page posts)"
      );
      return data.long_token;
    }

    throw new Error("No valid access token found. Please refresh your token.");
  } catch (error: any) {
    console.error("❌ Error getting access token:", error.message);
    throw error;
  }
}

async function fetchFacebookPosts(): Promise<FacebookPost[]> {
  try {
    console.log("🔍 Fetching Facebook posts...");
    
    // ✅ Get Page ID from config instead of hardcoded constant
    const PAGE_ID = await getPageId();
    
    console.log("📍 Page ID:", PAGE_ID);
    console.log("📍 API Version:", FB_API_VERSION);

    const accessToken = await getAccessToken();
    console.log("✅ Access token retrieved");

    // Calculate start of current month (midnight on the 1st)
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    startOfMonth.setHours(0, 0, 0, 0);

    // Convert to Unix timestamp (seconds since epoch)
    const sinceTimestamp = Math.floor(startOfMonth.getTime() / 1000);

    console.log("📅 Filtering posts:");
    console.log(`   Start date: ${startOfMonth.toISOString()}`);
    console.log(`   Unix timestamp: ${sinceTimestamp}`);
    console.log(`   Current time: ${now.toISOString()}`);

    const url = `https://graph.facebook.com/${FB_API_VERSION}/${PAGE_ID}/posts`;
    const params = {
      fields: "message,created_time,full_picture,permalink_url,attachments",
      since: sinceTimestamp.toString(),
      limit: 100,
      access_token: accessToken,
    };

    console.log("📡 Making request to:", url);
    console.log("📡 Request params:", {
      ...params,
      access_token: "***",
      since: `${params.since} (${startOfMonth.toISOString()})`,
    });

    const response = await axios.get<{ data: FacebookPost[] }>(url, {
      params,
      timeout: 30000,
    });

    console.log("✅ Facebook API response status:", response.status);
    console.log("✅ Posts received:", response.data.data?.length || 0);

    // Filter out posts before this month (double-check on our side)
    const filteredPosts = (response.data.data || []).filter((post) => {
      const postDate = new Date(post.created_time);
      const isThisMonth = postDate >= startOfMonth;

      if (!isThisMonth) {
        console.log(
          `⏭️ Skipping post ${
            post.id
          } from ${postDate.toISOString()} (before this month)`
        );
      }

      return isThisMonth;
    });

    console.log(
      `✅ Posts from this month: ${filteredPosts.length}/${
        response.data.data?.length || 0
      }`
    );

    // Log date range of fetched posts
    if (filteredPosts.length > 0) {
      const dates = filteredPosts.map((p) => new Date(p.created_time));
      const oldest = new Date(Math.min(...dates.map((d) => d.getTime())));
      const newest = new Date(Math.max(...dates.map((d) => d.getTime())));

      console.log(`📊 Post date range:`);
      console.log(`   Oldest: ${oldest.toISOString()}`);
      console.log(`   Newest: ${newest.toISOString()}`);
    }

    return filteredPosts;
  } catch (error: any) {
    console.error("❌ Error fetching Facebook posts:");
    console.error("Error message:", error.message);

    if (error.response) {
      console.error("Response status:", error.response.status);
      console.error(
        "Response data:",
        JSON.stringify(error.response.data, null, 2)
      );

      const errorData = error.response.data;

      if (error.response.status === 400) {
        if (errorData?.error?.message) {
          throw new Error(`Facebook API Error: ${errorData.error.message}`);
        }
        throw new Error(
          "Invalid request to Facebook API. Check your PAGE_ID and token."
        );
      }

      if (error.response.status === 190 || errorData?.error?.code === 190) {
        throw new Error(
          "Facebook Access Token is invalid or expired. Please refresh your token."
        );
      }

      if (error.response.status === 403) {
        throw new Error(
          "Access denied. Check if the token has permission to read page posts."
        );
      }
    }

    throw error;
  }
}

function parseDeadlineToTimestamp(
  deadline: string | null
): admin.firestore.Timestamp | null {
  if (!deadline || deadline.trim() === "") return null;

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
        const parsedDate = new Date(
          match[0].replace(/(\d+)(st|nd|rd|th)/, "$1")
        );
        if (!isNaN(parsedDate.getTime())) {
          parsedDate.setHours(23, 59, 59, 999);
          console.log(
            `✅ Parsed (full date pattern): ${parsedDate.toISOString()}`
          );
          return admin.firestore.Timestamp.fromDate(parsedDate);
        }
      }
    }

    const slashDateMatch = cleanedDeadline.match(
      /(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/
    );
    if (slashDateMatch) {
      const month = parseInt(slashDateMatch[1]) - 1;
      const day = parseInt(slashDateMatch[2]);
      const year = parseInt(slashDateMatch[3]);

      let parsedDate = new Date(year, month, day);

      if (month > 11 || day > 31) {
        parsedDate = new Date(
          year,
          parseInt(slashDateMatch[2]) - 1,
          parseInt(slashDateMatch[1])
        );
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
        } else if (typeof entry.days === "number") {
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

    const monthDayPattern =
      /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\.?\s+(\d{1,2})(?:st|nd|rd|th)?/i;
    const monthDayMatch = cleanedDeadline.match(monthDayPattern);
    if (monthDayMatch) {
      const currentYear = new Date().getFullYear();
      let parsedDate = new Date(`${monthDayMatch[0]} ${currentYear}`);

      if (parsedDate < new Date()) {
        parsedDate = new Date(`${monthDayMatch[0]} ${currentYear + 1}`);
      }

      if (!isNaN(parsedDate.getTime())) {
        parsedDate.setHours(23, 59, 59, 999);
        console.log(
          `✅ Parsed (month-day, inferred year): ${parsedDate.toISOString()}`
        );
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

async function analyzeAnnouncement(
  message: string,
  cohereKey: string
): Promise<CohereResult> {
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
          Authorization: `Bearer ${cohereKey}`,
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

        if (
          deadline &&
          (deadline.toLowerCase() === "null" || deadline.trim() === "")
        ) {
          deadline = null;
        }

        if (!deadline) {
          deadline = extractDeadlines(message);
          if (deadline) {
            console.log(
              `🔍 Cohere missed deadline, fallback found: "${deadline}"`
            );
          }
        }

        console.log(
          `🤖 Cohere analysis: Category="${category}", Deadline="${deadline}"`
        );

        return { category, deadline };
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
  const deadlineMatch =
    text.match(/"deadline"\s*:\s*"([^"]+)"/i) ||
    text.match(/"deadline"\s*:\s*null/i);

  if (categoryMatch) {
    const category = categoryMatch[1];
    const deadline = deadlineMatch ? deadlineMatch[1] || null : null;
    return JSON.stringify({ category, deadline });
  }

  throw new Error("Could not extract JSON from response");
}

function cleanCategory(category: string): string {
  const cleaned = category.toLowerCase().trim();

  if (cleaned.includes("admission") || cleaned.includes("enroll")) {
    return "Admission";
  } else if (
    cleaned.includes("scholarship") ||
    cleaned.includes("financial aid")
  ) {
    return "Scholarship";
  } else if (
    cleaned.includes("placement") ||
    cleaned.includes("job") ||
    cleaned.includes("career")
  ) {
    return "Placement";
  }

  return "General";
}

function fallbackAnalysis(message: string): CohereResult {
  const messageLower = message.toLowerCase();
  let category = "General";
  let deadline: string | null = null;

  if (
    messageLower.includes("enrollment") ||
    messageLower.includes("registration") ||
    messageLower.includes("application") ||
    messageLower.includes("requirements") ||
    messageLower.includes("class schedule") ||
    messageLower.includes("semester") ||
    messageLower.includes("subject") ||
    messageLower.includes("program") ||
    messageLower.includes("exam schedule") ||
    messageLower.includes("clearance") ||
    messageLower.includes("admission")
  ) {
    category = "Admission";
  } else if (
    messageLower.includes("scholarship") ||
    messageLower.includes("stipend") ||
    messageLower.includes("allowance") ||
    messageLower.includes("grantee") ||
    messageLower.includes("renewal") ||
    messageLower.includes("eligibility") ||
    messageLower.includes("screening") ||
    messageLower.includes("shortlisted") ||
    messageLower.includes("beneficiary") ||
    messageLower.includes("grant")
  ) {
    category = "Scholarship";
  } else if (
    messageLower.includes("placement") ||
    messageLower.includes("hiring") ||
    messageLower.includes("job") ||
    messageLower.includes("employment") ||
    messageLower.includes("employer") ||
    messageLower.includes("resume") ||
    messageLower.includes("cv") ||
    messageLower.includes("interview") ||
    messageLower.includes("company") ||
    messageLower.includes("opportunity") ||
    messageLower.includes("deployment")
  ) {
    category = "Placement";
  }

  deadline = extractDeadlines(message);

  return { category, deadline };
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

      found = found.replace(
        /^(?:deadline|due|submit|until|before|on or before)[:\s]+/i,
        ""
      );

      const rangeMatch = found.match(
        /(\d{1,2})(?:st|nd|rd|th)?\s*[-–]\s*(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/i
      );
      if (rangeMatch) {
        const month = found.match(
          /(?:January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/i
        )?.[0];
        found = `${month} ${rangeMatch[2]}, ${rangeMatch[3]}`;
      }

      if (found && found.length > 0 && !extractedDates.includes(found)) {
        extractedDates.push(found);
      }
    }
  }

  if (extractedDates.length === 0) {
    console.log("⚠️ No deadline found in message");
    return null;
  }

  console.log(
    `📅 Extracted ${
      extractedDates.length
    } potential deadline(s): ${extractedDates.join(", ")}`
  );

  const datesWithYear = extractedDates.filter((d) => /\d{4}/.test(d));
  if (datesWithYear.length > 0) {
    return datesWithYear[0];
  }

  return extractedDates[0];
}

// ============================================================================
// ✅ ENHANCED: Category-specific extraction with image OCR support
// ============================================================================

interface ExtractedAdmissionData {
  type: string | null; // ✅ NEW: "CMUCAT" | "GSAT" | "ULHSAT" | null
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

async function extractAdmissionData(
  message: string,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<ExtractedAdmissionData> {
  let extractedSchedules: ScheduleEntry[] = [];
  if (ocrText) {
    extractedSchedules = extractSchedulesFromOCR(ocrText);
    console.log(
      `📅 Extracted ${extractedSchedules.length} schedules from ${
        imageCount || 0
      } image(s)`
    );
  }

  try {
    const prompt = `Extract admission information from this announcement. The content includes text from ${
      imageCount || 0
    } schedule images. Return ONLY valid JSON.

Announcement: "${message}"
${
  ocrText
    ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"`
    : ""
}

CRITICAL INSTRUCTIONS:
1. Determine the admission TYPE by looking for these keywords:
   - CMUCAT (Central Mindanao University College Admission Test)
   - GSAT (Graduate School Admission Test)  
   - ULHSAT (University Laboratory High School Admission Test)
   - If no specific test is mentioned, set type to null

2. For schedules, ignore generic header text like "Central Mindanao University" and "CMUCAT Schedule"
3. Extract SPECIFIC location information for EACH date
4. Look for city names, school names, and venue details
5. For "In-Campus" entries, include the time information
6. Each date can have MULTIPLE locations - list them all

Extract these fields:
- type: "CMUCAT" | "GSAT" | "ULHSAT" | null (based on test type mentioned)
- title: A short descriptive title (max 100 chars)
- content: The full announcement content including image text
- steps: Array of enrollment/application steps
- requirements: Array of required documents (extract from BOTH text and images)
- contacts: Array of contact information (extract from BOTH text and images)
- academicYear: Object {"start": 2026, "end": 2027}
- schedules: Array of schedule objects with SPECIFIC locations for each date

Respond ONLY in this JSON format:
{
  "type": "CMUCAT",
  "title": "CMUCAT Schedule AY 2026-2027",
  "content": "string with image text",
  "steps": ["step1", "step2"],
  "requirements": ["req1", "req2"],
  "contacts": ["contact1", "email@example.com"],
  "academicYear": {"start": 2026, "end": 2027},
  "schedules": [
    {"date": "OCT 4", "dayOfWeek": "SATURDAY", "year": "2025", "locations": ["Kalilangan, Bukidnon", "Impasug-ong, Bukidnon"], "time": ""},
    {"date": "OCT 26", "dayOfWeek": "SUNDAY", "year": "2025", "locations": ["In-Campus (Central Mindanao University)"], "time": "9-11 am | 1-3 pm"}
  ]
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 2500,
        temperature: 0.1,
      },
      {
        headers: {
          Authorization: `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);

    // ✅ Extract type with fallback detection
    let admissionType = result.type || null;
    
    // Fallback: detect type from content if not provided by AI
    if (!admissionType) {
      const contentToCheck = `${message} ${ocrText || ''}`.toUpperCase();
      if (contentToCheck.includes('CMUCAT')) {
        admissionType = 'CMUCAT';
      } else if (contentToCheck.includes('GSAT')) {
        admissionType = 'GSAT';
      } else if (contentToCheck.includes('ULHSAT')) {
        admissionType = 'ULHSAT';
      }
    }

    console.log(`📋 Detected admission type: ${admissionType || 'Not specified'}`);

    let finalSchedules = result.schedules || [];
    if (finalSchedules.length < extractedSchedules.length) {
      console.log(
        `⚠️ Using OCR schedules: ${extractedSchedules.length} vs Cohere: ${finalSchedules.length}`
      );
      finalSchedules = extractedSchedules;
    }

    let enhancedContent = result.content || message;
    if (ocrText && !enhancedContent.includes(ocrText.substring(0, 50))) {
      enhancedContent = `${message}\n\n[Information from ${
        imageCount || 0
      } image(s)]:\n${ocrText}`;
    }

    return {
      type: admissionType, // ✅ NEW FIELD
      title: result.title || message.substring(0, 100),
      content: enhancedContent,
      steps: Array.isArray(result.steps) ? result.steps : [],
      requirements: Array.isArray(result.requirements)
        ? result.requirements
        : [],
      contacts: Array.isArray(result.contacts) ? result.contacts : [],
      academicYear: result.academicYear || null,
      schedules: finalSchedules,
    };
  } catch (error) {
    console.error("Error extracting admission data:", error);
    
    // Fallback type detection
    let detectedType = null;
    const fullText = `${message} ${ocrText || ''}`.toUpperCase();
    if (fullText.includes('CMUCAT')) {
      detectedType = 'CMUCAT';
    } else if (fullText.includes('GSAT')) {
      detectedType = 'GSAT';
    } else if (fullText.includes('ULHSAT')) {
      detectedType = 'ULHSAT';
    }
    
    return {
      type: detectedType, // ✅ NEW FIELD
      title: message.substring(0, 100),
      content: ocrText ? `${message}\n\n[Image Text]:\n${ocrText}` : message,
      steps: [],
      requirements: [],
      contacts: [],
      academicYear: null,
      schedules: extractedSchedules,
    };
  }
}

async function extractScholarshipData(
  message: string,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<ExtractedScholarshipData> {
  try {
    const prompt = `Extract scholarship information from this announcement. Content may include text from ${
      imageCount || 0
    } image(s). Return ONLY valid JSON.

Announcement: "${message}"
${
  ocrText
    ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"`
    : ""
}

Extract these fields (look in BOTH text and images):
- name: The scholarship name/title
- description: Brief description including info from images
- scholarshipProvider: Organization offering the scholarship
- eligibilityRequirements: Array of eligibility criteria (from text AND images)
- privileges: Array of benefits (tuition, stipend, allowance, etc.)
- applicationLink: URL for application if mentioned

Respond ONLY in this JSON format:
{
  "name": "string",
  "description": "string including image details",
  "scholarshipProvider": "string",
  "eligibilityRequirements": ["req from text", "req from image"],
  "privileges": ["benefit1", "benefit2"],
  "applicationLink": "string or empty"
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1500,
        temperature: 0.1,
      },
      {
        headers: {
          Authorization: `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);

    // ✅ Enhance description with OCR text
    let enhancedDescription = result.description || message;
    if (ocrText && !enhancedDescription.includes(ocrText.substring(0, 50))) {
      enhancedDescription = `${
        result.description || message
      }\n\n[Details from ${imageCount || 0} image(s)]:\n${ocrText}`;
    }

    return {
      name: result.name || "Scholarship Announcement",
      description: enhancedDescription,
      scholarshipProvider: result.scholarshipProvider || "",
      eligibilityRequirements: Array.isArray(result.eligibilityRequirements)
        ? result.eligibilityRequirements
        : [],
      privileges: Array.isArray(result.privileges) ? result.privileges : [],
      applicationLink: result.applicationLink || "",
    };
  } catch (error) {
    console.error("Error extracting scholarship data:", error);
    return {
      name: "Scholarship Announcement",
      description: ocrText
        ? `${message}\n\n[Image Text]:\n${ocrText}`
        : message,
      scholarshipProvider: "",
      eligibilityRequirements: [],
      privileges: [],
      applicationLink: "",
    };
  }
}

async function extractPlacementData(
  message: string,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<ExtractedPlacementData> {
  try {
    const prompt = `Extract job placement/hiring information from this announcement. Content may include text from ${
      imageCount || 0
    } image(s). Return ONLY valid JSON.

Announcement: "${message}"
${
  ocrText
    ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"`
    : ""
}

Extract these fields (look in BOTH text and images):
- partnerCompany: Company name that is hiring
- positions: Array of job positions/titles available (from text AND images)
- contacts: Array of contact information for application (from text AND images)
- isRecruiting: Boolean indicating if currently accepting applications (default true)

Respond ONLY in this JSON format:
{
  "partnerCompany": "string",
  "positions": ["position1 from text", "position2 from image"],
  "contacts": ["contact1", "email@example.com"],
  "isRecruiting": true
}`;

    const response = await axios.post<{ text?: string }>(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1500,
        temperature: 0.1,
      },
      {
        headers: {
          Authorization: `Bearer ${cohereKey}`,
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

/**
 * Create Admission document AND sync to Information Bank with Pinecone
 */
async function createAdmissionFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<void> {
  try {
    const admissionRef = db.collection("admissions").doc(postId);
    const existingDoc = await admissionRef.get();

    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping admission for post ${postId} - deleted`);
        return;
      }
      console.log(`✅ Admission already exists for post ${postId}`);
      
      // Check if Information Bank exists
      const infoBankId = `admission_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        console.log(`✅ Information Bank also exists - skipping`);
        return;
      }

      console.log(`📋 Creating Information Bank for existing admission...`);
      const extractedData = await extractAdmissionData(
        message,
        cohereKey,
        ocrText,
        imageCount
      );

      await createInfoBankFromCategory(
        postId,
        "admission",
        extractedData,
        cohereKey
      );

      console.log(`✅ Information Bank created for existing admission`);
      return;
    }

    // Both missing - create both
    console.log(`✨ Creating new admission and Information Bank...`);

    const extractedData = await extractAdmissionData(
      message,
      cohereKey,
      ocrText,
      imageCount
    );

    await admissionRef.set({
      id: postId,
      announcementId: postId,
      type: extractedData.type, // ✅ NEW FIELD
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
      deleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
      processedImageCount: imageCount || 0,
    });

    console.log(
      `✅ Created ${extractedData.type || 'general'} admission with ${extractedData.schedules.length} schedules`
    );

    await createInfoBankFromCategory(
      postId,
      "admission",
      extractedData,
      cohereKey
    );

    console.log(`✅ Admission + Information Bank synced to Pinecone`);
  } catch (error: any) {
    console.error(
      `❌ Error creating admission from announcement ${postId}:`,
      error
    );
    throw error;
  }
}
/**
 * Create Scholarship document AND sync to Information Bank with Pinecone
 */
async function createScholarshipFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<void> {
  try {
    const scholarshipRef = db.collection("scholarships").doc(postId);
    const existingDoc = await scholarshipRef.get();

    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping scholarship for post ${postId} - deleted`);
        return;
      }

      console.log(`✅ Scholarship already exists for post ${postId}`);

      // ✅ Check if Information Bank exists
      const infoBankId = `scholarship_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        console.log(`✅ Information Bank also exists - skipping`);
        return;
      }

      // ✅ Scholarship exists but Info Bank missing - create it
      console.log(`📋 Creating Information Bank for existing scholarship...`);

      const extractedData = await extractScholarshipData(
        message,
        cohereKey,
        ocrText,
        imageCount
      );

      await createInfoBankFromCategory(
        postId,
        "scholarship",
        extractedData,
        cohereKey
      );

      console.log(`✅ Information Bank created for existing scholarship`);
      return;
    }

    // Both missing - create both
    console.log(`✨ Creating new scholarship and Information Bank...`);

    const extractedData = await extractScholarshipData(
      message,
      cohereKey,
      ocrText,
      imageCount
    );

    await scholarshipRef.set({
      scholarshipID: postId,
      sourceId: postId,
      announcementId: postId,
      name: extractedData.name,
      description: extractedData.description,
      scholarshipProvider: extractedData.scholarshipProvider,
      eligibilityRequirements: extractedData.eligibilityRequirements,
      privileges: extractedData.privileges,
      deadline: deadline ? deadline.toDate() : null,
      applicationLink: extractedData.applicationLink,
      deleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
      processedImageCount: imageCount || 0,
    });

    console.log(`✅ Created scholarship from announcement ${postId}`);

    await createInfoBankFromCategory(
      postId,
      "scholarship",
      extractedData,
      cohereKey
    );

    console.log(`✅ Scholarship + Information Bank synced to Pinecone`);
  } catch (error: any) {
    console.error(
      `❌ Error creating scholarship from announcement ${postId}:`,
      error
    );
    throw error;
  }
}
export const debugInfoBank = onCall(
  { cors: true, secrets: [COHERE_API_KEY] },
  async (request) => {
    const announcementId = request.data.announcementId;

    const announcement = await db
      .collection("announcements")
      .doc(announcementId)
      .get();
    const category = announcement.data()?.category?.toLowerCase();

    const categoryDoc = await db
      .collection(`${category}s`)
      .doc(announcementId)
      .get();
    const infoBankDoc = await db
      .collection("information_bank")
      .doc(`${category}_${announcementId}`)
      .get();

    return {
      announcement: announcement.exists,
      categoryDoc: categoryDoc.exists,
      infoBankDoc: infoBankDoc.exists,
      details: {
        category,
        announcementData: announcement.data(),
        categoryData: categoryDoc.data(),
        infoBankData: infoBankDoc.data(),
      },
    };
  }
);

/**
 * Create Placement document AND sync to Information Bank with Pinecone
 */
async function createPlacementFromAnnouncement(
  postId: string,
  message: string,
  deadline: admin.firestore.Timestamp | null,
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<void> {
  try {
    const placementRef = db.collection("placements").doc(postId);
    const existingDoc = await placementRef.get();

    // ✅ NEW: Check if placement exists
    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping placement for post ${postId} - deleted`);
        return;
      }

      console.log(`✅ Placement already exists for post ${postId}`);

      // ✅ NEW: Check if Information Bank exists
      const infoBankId = `placement_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        console.log(`✅ Information Bank also exists - skipping`);
        return;
      }

      // ✅ NEW: Placement exists but Info Bank missing - create it
      console.log(`📋 Creating Information Bank for existing placement...`);

      const extractedData = await extractPlacementData(
        message,
        cohereKey,
        ocrText,
        imageCount
      );

      await createInfoBankFromCategory(
        postId,
        "placement",
        extractedData,
        cohereKey
      );

      console.log(`✅ Information Bank created for existing placement`);
      return;
    }

    // Both placement and Info Bank are missing - create both
    console.log(`✨ Creating new placement and Information Bank...`);

    const extractedData = await extractPlacementData(
      message,
      cohereKey,
      ocrText,
      imageCount
    );

    // 1️⃣ Save to Placements collection
    await placementRef.set({
      placementID: postId,
      announcementId: postId,
      partnerCompany: extractedData.partnerCompany,
      positions: extractedData.positions,
      contacts: extractedData.contacts,
      isRecruiting: extractedData.isRecruiting,
      deadline: deadline ? deadline.toDate() : null,
      deleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      autoGenerated: true,
      processedImageCount: imageCount || 0,
    });

    console.log(`✅ Created placement from announcement ${postId}`);

    // 2️⃣ Create Information Bank entry
    await createInfoBankFromCategory(
      postId,
      "placement",
      extractedData,
      cohereKey
    );

    console.log(`✅ Placement + Information Bank synced to Pinecone`);
  } catch (error: any) {
    console.error(
      `❌ Error creating placement from announcement ${postId}:`,
      error
    );
    throw error; // Re-throw to make error visible
  }
}

async function createInfoBankFromCategory(
  documentId: string,
  categoryType: 'admission' | 'scholarship' | 'placement',
  extractedData: any,
  cohereKey: string
): Promise<void> {
  const functionStart = Date.now();
  
  console.log(`\n🏦 ========================================`);
  console.log(`🏦 START: createInfoBankFromCategory`);
  console.log(`🏦 Category: ${categoryType}`);
  console.log(`🏦 Document ID: ${documentId}`);
  console.log(`🏦 ========================================`);
  
  try {
    // ✅ STEP 1: Validate inputs
    console.log(`\n📋 STEP 1: Validating inputs...`);
    
    if (!documentId || documentId.trim().length === 0) {
      throw new Error('documentId is empty or invalid');
    }
    
    if (!categoryType || !['admission', 'scholarship', 'placement'].includes(categoryType)) {
      throw new Error(`Invalid categoryType: ${categoryType}`);
    }
    
    if (!extractedData) {
      throw new Error('extractedData is null or undefined');
    }
    
    console.log(`   ✅ Inputs validated`);
    console.log(`   📊 extractedData keys: ${Object.keys(extractedData).join(', ')}`);

    // ✅ STEP 2: Create Information Bank ID
    const infoBankId = `${categoryType}_${documentId}`;
    console.log(`   📌 Info Bank ID: ${infoBankId}`);

    // ✅ STEP 3: Check if already exists
    console.log(`\n📋 STEP 3: Checking if entry exists...`);
    const existingDoc = await db.collection('information_bank').doc(infoBankId).get();

    if (existingDoc.exists) {
      console.log(`   ℹ️ Entry already exists - updating timestamp`);
      await db.collection('information_bank').doc(infoBankId).update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Timestamp updated`);
      return;
    }

    // ✅ STEP 4: Format content
    console.log(`\n📋 STEP 4: Formatting content...`);
    const textContent = formatCategoryAsText(categoryType, extractedData);
    const title = getCategoryTitle(categoryType, extractedData);

    console.log(`   📝 Title: "${title}"`);
    console.log(`   📝 Content: ${textContent.length} chars`);

    if (!textContent || textContent.trim().length === 0) {
      throw new Error('Formatted content is empty');
    }

    // ✅ STEP 5: Split into chunks
    console.log(`\n📋 STEP 5: Splitting into chunks...`);
    const chunks = splitIntoChunks(textContent, title, `${categoryType}_category`);
    console.log(`   📄 Created ${chunks.length} chunk(s)`);

    let parentPineconeId: string | null = null;
    const chunkIds: string[] = [];

    // ✅ STEP 6: Process each chunk with retries
    console.log(`\n📋 STEP 6: Processing ${chunks.length} chunks...`);
    
    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      console.log(`\n   📌 Chunk ${i + 1}/${chunks.length}`);
      console.log(`      Text: ${chunk.text.length} chars`);

      // Generate embedding with retry
      let embedding: number[] | null = null;
      let retries = 3;
      
      while (retries > 0 && !embedding) {
        try {
          console.log(`      🔄 Generating embedding (attempt ${4 - retries}/3)...`);
          
          const embeddingResponse = await axios.post(
            "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=" + GEMINI_API_KEY.value(),
            {
              model: "text-embedding-004",
              content: {
                parts: [
                  { text: chunk.text }
                ]
              }
            },
            {
              headers: {
                "Content-Type": "application/json"
              }
            }
          );

          // ✅ FIX: Correct response structure for Gemini API
          const responseData = embeddingResponse.data as any;

          // Log the actual response structure for debugging
          if (retries === 3) {
            console.log(`      📊 Response keys: ${Object.keys(responseData || {}).join(', ')}`);
          }

          // Try multiple possible response structures
          // Structure 1: embedding.values (most common)
          if (responseData?.embedding?.values && Array.isArray(responseData.embedding.values)) {
            embedding = responseData.embedding.values;
            console.log(`      ✅ Found embedding in .embedding.values`);
          }
          // Structure 2: embeddings[0].values (batch response)
          else if (responseData?.embeddings?.[0]?.values && Array.isArray(responseData.embeddings[0].values)) {
            embedding = responseData.embeddings[0].values;
            console.log(`      ✅ Found embedding in .embeddings[0].values`);
          }
          // Structure 3: Direct array
          else if (Array.isArray(responseData?.values)) {
            embedding = responseData.values;
            console.log(`      ✅ Found embedding in .values`);
          }

          if (!embedding || embedding.length === 0) {
            console.error(`      ❌ Unexpected response structure:`, JSON.stringify(responseData, null, 2));
            throw new Error("Invalid embedding response");
          }
          
          console.log(`      ✅ Embedding: ${embedding.length} dimensions`);
          
        } catch (error: any) {
          retries--;
          console.error(`      ❌ Attempt failed: ${error.message}`);
          
          if (retries > 0) {
            console.log(`      ⏳ Retrying in 2s...`);
            await new Promise(resolve => setTimeout(resolve, 2000));
          } else {
            throw new Error(`Failed after 3 attempts: ${error.message}`);
          }
        }
      }

      if (!embedding) {
        throw new Error("Embedding generation failed");
      }

      const chunkTitle = chunks.length > 1
        ? `${title} (Part ${i + 1}/${chunks.length})`
        : title;

      // 🔥 CRITICAL FIX: Match the exact structure from your working Flutter uploads
      const metadata = {
        // === PRIMARY IDENTIFIERS (exactly matching Flutter structure) ===
        'docId': documentId,
        'originalDocId': documentId,
        'documentId': documentId,
        
        // === CONTENT (primary fields first) ===
        'text': chunk.text,
        'content': chunk.text,
        
        // === TITLES ===
        'title': chunkTitle,
        'originalTitle': title,
        'fileName': title,
        
        // === CHUNKING INFO (matching Flutter naming) ===
        'chunkIndex': i,
        'chunk_index': i,
        'totalChunks': chunks.length,
        'chunkCount': chunks.length,
        'chunkSize': chunk.text.length,
        'isFirstChunk': i === 0,
        'isLastChunk': i === chunks.length - 1,
        
        // === SOURCE & CATEGORY ===
        'source': `${categoryType}_category`,
        'category': categoryType,
        'categoryID': categoryType,
        'categoryType': categoryType,
        
        // === TIMESTAMPS & FLAGS ===
        'createdAt': new Date().toISOString(),
        'syncedFromCategory': true,
        'autoGeneratedFromAnnouncement': true,
        
        // === CATEGORY-SPECIFIC METADATA ===
        ...getCategorySpecificMetadata(categoryType, extractedData),
      };

      // Store in Pinecone with retry
      console.log(`      🔄 Storing in Pinecone...`);
      let stored = false;
      retries = 3;
      
      while (retries > 0 && !stored) {
        try {
          await storePineconeVector(chunk.id, embedding, metadata);
          stored = true;
          console.log(`      ✅ Stored in Pinecone`);
        } catch (error: any) {
          retries--;
          console.error(`      ❌ Storage failed: ${error.message}`);
          
          if (retries > 0) {
            console.log(`      ⏳ Retrying in 2s...`);
            await new Promise(resolve => setTimeout(resolve, 2000));
          } else {
            throw new Error(`Pinecone storage failed: ${error.message}`);
          }
        }
      }

      chunkIds.push(chunk.id);
      if (i === 0) parentPineconeId = chunk.id;
    }

    // ✅ STEP 7: Save to Firestore (matching Flutter structure)
    console.log(`\n📋 STEP 7: Saving to Firestore...`);
    
    const firestoreData = {
      'ibID': infoBankId,
      'id': infoBankId,
      'ib_title': title,
      'title': title,
      'content': textContent,
      'source': `${categoryType}_category`,
      'category': categoryType,
      'categoryID': categoryType,
      'categoryType': categoryType,
      'categoryDocumentId': documentId,
      'announcementId': documentId,
      'pinecone_id': parentPineconeId,
      'totalChunks': chunks.length,
      'chunkIds': chunkIds,
      'chunked': chunks.length > 1,
      'chunkSize': 1000,
      'chunkOverlap': 200,
      'syncedFromCategory': true,
      'autoGeneratedFromAnnouncement': true,
      'createdAt': admin.firestore.FieldValue.serverTimestamp(),
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('information_bank').doc(infoBankId).set(firestoreData);
    console.log(`   ✅ Firestore write successful`);

    const totalElapsed = Date.now() - functionStart;
    
    console.log(`\n🏦 ========================================`);
    console.log(`🏦 SUCCESS: Info Bank Created`);
    console.log(`🏦 ID: ${infoBankId}`);
    console.log(`🏦 Chunks: ${chunks.length}`);
    console.log(`🏦 Time: ${totalElapsed}ms`);
    console.log(`🏦 ========================================\n`);

  } catch (error: any) {
    const totalElapsed = Date.now() - functionStart;
    
    console.error(`\n❌ ========================================`);
    console.error(`❌ FAILURE: Info Bank Creation Failed`);
    console.error(`❌ Category: ${categoryType}`);
    console.error(`❌ Document: ${documentId}`);
    console.error(`❌ Error: ${error.message}`);
    console.error(`❌ Stack:`);
    console.error(error.stack);
    console.error(`❌ Time: ${totalElapsed}ms`);
    console.error(`❌ ========================================\n`);
    
    // Log to Firestore error collection for tracking
    try {
      await db.collection('info_bank_errors').add({
        categoryType,
        documentId,
        infoBankId: `${categoryType}_${documentId}`,
        errorType: error.constructor.name,
        errorMessage: error.message,
        errorStack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        extractedDataKeys: extractedData ? Object.keys(extractedData) : [],
      });
      console.log(`   📝 Error logged to Firestore`);
    } catch (logError: any) {
      console.error(`   ❌ Failed to log error: ${logError.message}`);
    }
    
    throw new Error(`Info Bank creation failed for ${categoryType} ${documentId}: ${error.message}`);
  }
}

function getCategoryTitle(
  categoryType: "admission" | "scholarship" | "placement",
  data: any
): string {
  if (categoryType === "admission") {
    return data.title || "Admission Information";
  } else if (categoryType === "scholarship") {
    return data.name || "Scholarship Information";
  } else if (categoryType === "placement") {
    return `${data.partnerCompany || "Company"} - Job Placement`;
  }
  return "Category Information";
}

function getCategorySpecificMetadata(
  categoryType: "admission" | "scholarship" | "placement",
  data: any
): Record<string, any> {
  if (categoryType === "admission") {
    return {
      academicYear: data.academicYear
        ? JSON.stringify(data.academicYear)
        : null,
      hasSchedules: (data.schedules?.length || 0) > 0,
      scheduleCount: data.schedules?.length || 0,
    };
  } else if (categoryType === "scholarship") {
    return {
      scholarshipProvider: data.scholarshipProvider || "",
      hasApplicationLink: !!data.applicationLink,
      hasDeadline: !!data.deadline,
    };
  } else if (categoryType === "placement") {
    return {
      partnerCompany: data.partnerCompany || "",
      isRecruiting: data.isRecruiting || false,
      positionCount: data.positions?.length || 0,
    };
  }
  return {};
}

function splitIntoChunks(
  content: string,
  title: string,
  source: string
): Array<{ id: string; text: string }> {
  const maxChunkSize = 1000;
  const chunkOverlap = 200;
  const chunks: Array<{ id: string; text: string }> = [];

  // Clean content
  const cleanContent = content
    .replace(/\r\n|\r/g, "\n")
    .replace(/[ \t]+/g, " ")
    .replace(/\n[ \t]*\n/g, "\n\n")
    .trim();

  if (cleanContent.length <= maxChunkSize) {
    return [
      {
        id: generateChunkId(),
        text: cleanContent,
      },
    ];
  }

  // Split by sentences
  const sentences = cleanContent.split(/[.!?]+/).filter((s) => s.trim());

  let currentChunk = "";

  for (const sentence of sentences) {
    const trimmedSentence = sentence.trim();
    if (!trimmedSentence) continue;

    const proposedChunk = currentChunk
      ? `${currentChunk}. ${trimmedSentence}`
      : trimmedSentence;

    if (proposedChunk.length > maxChunkSize && currentChunk) {
      chunks.push({
        id: generateChunkId(),
        text: currentChunk.trim(),
      });

      // Start new chunk with overlap
      const overlapText = getOverlapText(currentChunk, chunkOverlap);
      currentChunk = overlapText
        ? `${overlapText}. ${trimmedSentence}`
        : trimmedSentence;
    } else {
      currentChunk = proposedChunk;
    }
  }

  if (currentChunk) {
    chunks.push({
      id: generateChunkId(),
      text: currentChunk.trim(),
    });
  }

  return chunks;
}

function getOverlapText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  const substring = text.substring(text.length - maxLength);
  const spaceIndex = substring.indexOf(" ");
  if (spaceIndex > 0) {
    return substring.substring(spaceIndex + 1).trim();
  }
  return substring.trim();
}

function generateChunkId(): string {
  return `chunk_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

async function storePineconeVector(
  id: string,
  embedding: number[],
  metadata: any
): Promise<void> {
  // ✅ Get both from secrets
  const PINECONE_KEY = PINECONE_API_KEY.value();
  const PINECONE_URL = PINECONE_HOST.value(); // ✅ Changed from process.env

  console.log(`🔍 Pinecone credentials check:`);
  console.log(`   API Key available: ${!!PINECONE_KEY}`);
  console.log(`   Host available: ${!!PINECONE_URL}`);
  console.log(`   Host value: ${PINECONE_URL || "NOT SET"}`);

  if (!PINECONE_KEY) {
    throw new Error(
      "Pinecone API Key not configured. Run: firebase functions:secrets:set PINECONE_API_KEY"
    );
  }

  if (!PINECONE_URL) {
    throw new Error(
      "Pinecone Host not configured. Run: firebase functions:secrets:set PINECONE_HOST"
    );
  }

  // Validate embedding
  if (!Array.isArray(embedding) || embedding.length === 0) {
    throw new Error(
      `Invalid embedding for vector ${id}: not an array or empty`
    );
  }

  // Validate metadata has required fields
  const requiredFields = ["docId", "text", "title"];
  const missingFields = requiredFields.filter((field) => !metadata[field]);

  if (missingFields.length > 0) {
    console.warn(
      `⚠️ Missing metadata fields for vector ${id}: ${missingFields.join(", ")}`
    );
  }

  try {
    console.log(`📤 Storing vector ${id} in Pinecone...`);
    console.log(`   Embedding dimensions: ${embedding.length}`);
    console.log(`   Metadata fields: ${Object.keys(metadata).length}`);

    const response = await axios.post(
      `${PINECONE_URL}/vectors/upsert`, // ✅ Use PINECONE_URL
      {
        vectors: [
          {
            id: id,
            values: embedding,
            metadata: metadata,
          },
        ],
      },
      {
        headers: {
          "Api-Key": PINECONE_KEY,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        timeout: 30000,
        validateStatus: (status) => status < 500,
      }
    );

    if (response.status !== 200) {
      console.error(`❌ Pinecone returned non-200 status: ${response.status}`);
      console.error(`   Response data:`, JSON.stringify(response.data));
      throw new Error(
        `Pinecone API returned status ${response.status}: ${JSON.stringify(
          response.data
        )}`
      );
    }

    console.log(`   ✅ Vector ${id} stored successfully`);
  } catch (error: any) {
    console.error(`❌ Pinecone storage error for vector ${id}:`);
    console.error(`   Error type: ${error.constructor.name}`);
    console.error(`   Error message: ${error.message}`);

    if (error.response) {
      console.error(`   HTTP Status: ${error.response.status}`);
      console.error(`   Response data:`, JSON.stringify(error.response.data));
    }

    if (error.code === "ENOTFOUND" || error.code === "ECONNREFUSED") {
      throw new Error(
        `Cannot connect to Pinecone. Check PINECONE_HOST: ${PINECONE_URL}`
      );
    }

    throw new Error(`Pinecone storage failed: ${error.message}`);
  }
}

export const batchSyncCategoriesToInfoBank = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [COHERE_API_KEY, GEMINI_API_KEY, PINECONE_API_KEY],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const categoryTypes: Array<"admission" | "scholarship" | "placement"> = [
        "admission",
        "scholarship",
        "placement",
      ];

      let totalSynced = 0;
      let totalFailed = 0;

      for (const categoryType of categoryTypes) {
        console.log(`🔄 Syncing all ${categoryType} documents...`);

        const snapshot = await db
          .collection(`${categoryType}s`)
          .where("deleted", "==", false)
          .get();

        for (const doc of snapshot.docs) {
          try {
            await syncCategoryToInfoBank(
              categoryType,
              doc.id,
              COHERE_API_KEY.value()
            );
            totalSynced++;
          } catch (error) {
            console.error(
              `❌ Failed to sync ${categoryType} ${doc.id}:`,
              error
            );
            totalFailed++;
          }
        }
      }

      return {
        success: true,
        message: `Synced ${totalSynced} category documents to Information Bank`,
        synced: totalSynced,
        failed: totalFailed,
      };
    } catch (error: any) {
      console.error("❌ Batch sync error:", error);
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

    // ✅ CASCADE DELETE: When announcement is soft-deleted, also soft-delete category document
    if (!before.deleted && after.deleted) {
      console.log(
        `🗑️ Announcement ${postId} was soft-deleted, cascading to category document...`
      );

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

async function processPost(
  post: FacebookPost,
  cohereKey: string
): Promise<void> {
  const postId = post.id;
  const originalMessage = post.message || "";

  console.log(`\n========================================`);
  console.log(`🔍 Processing post: ${postId}`);
  console.log(`========================================`);

  const postRef = db.collection("announcements").doc(postId);
  const doc = await postRef.get();

  // Extract ALL images
  const allImageUrls = extractAllImagesFromPost(post);
  console.log(`📸 Post has ${allImageUrls.length} image(s)`);

  // Process OCR for ALL images
  let combinedOcrText = "";
  const ocrResults: string[] = [];

  if (allImageUrls.length > 0) {
    console.log(`🔍 Running OCR on ${allImageUrls.length} image(s)...`);

    for (let i = 0; i < allImageUrls.length; i++) {
      console.log(`  🔍 Processing image ${i + 1}/${allImageUrls.length}...`);
      try {
        const ocrText = await extractTextFromImage(allImageUrls[i]);
        if (ocrText && ocrText.trim().length > 0) {
          ocrResults.push(ocrText);
          console.log(
            `  ✅ Extracted ${ocrText.length} chars from image ${i + 1}`
          );
        } else {
          console.log(`  ⚠️ No text found in image ${i + 1}`);
        }
      } catch (err: any) {
        console.error(`  ❌ OCR failed for image ${i + 1}:`, err.message);
      }
    }

    combinedOcrText = combineOcrResults(ocrResults);
    console.log(
      `📝 Total OCR: ${combinedOcrText.length} chars from ${ocrResults.length}/${allImageUrls.length} images`
    );
  }

  const hasImageText = ocrResults.length > 0;

  // Combine message with OCR text
  let messageForAnalysis = originalMessage;
  if (hasImageText) {
    messageForAnalysis = originalMessage
      ? `${originalMessage}\n\n[Text from ${ocrResults.length} image(s)]:\n${combinedOcrText}`
      : combinedOcrText;
  }

  if (!messageForAnalysis || messageForAnalysis.trim().length === 0) {
    console.log(`⏭️ Skipping post ${postId} - no content`);
    return;
  }

  // Upload ALL images to storage
  let uploadedImageUrls: string[] = [];
  if (allImageUrls.length > 0) {
    uploadedImageUrls = await downloadAndUploadAllImages(allImageUrls, postId);
    console.log(
      `✅ Stored ${uploadedImageUrls.length} images in Firebase Storage`
    );
  }

  // ============================================================================
  // ✅ NEW DOCUMENT PATH
  // ============================================================================
  if (!doc.exists) {
    console.log(`✨ Creating new announcement...`);

    // Analyze with Cohere
    const cohereResult = await analyzeAnnouncement(
      messageForAnalysis,
      cohereKey
    );
    const deadlineTimestamp = parseDeadlineToTimestamp(cohereResult.deadline);

    const newData = {
      announcementId: postId,
      message: originalMessage,
      created_time: post.created_time,
      images: uploadedImageUrls,
      image_count: uploadedImageUrls.length,
      full_picture: uploadedImageUrls[0] || "",
      original_image_urls: allImageUrls,
      permalink_url: post.permalink_url || "",
      category: cohereResult.category || "General",
      deadline: deadlineTimestamp || null,
      deleted: false,
      fetched_at: admin.firestore.FieldValue.serverTimestamp(),
      processed_by_cohere: true,
      stored_in_storage: uploadedImageUrls.length > 0,
      notification_sent: false,
      ocr_text: combinedOcrText || "",
      has_image_text: hasImageText,
      ocr_processed_count: ocrResults.length,
      ocr_success_count: ocrResults.length,
      total_image_count: allImageUrls.length,
    };

    await postRef.set(newData);
    console.log(`✅ Created announcement document`);

    // Create category-specific documents AND Information Bank
    await createCategoryAndInfoBank(
      postId,
      cohereResult.category,
      messageForAnalysis,
      deadlineTimestamp,
      cohereKey,
      combinedOcrText,
      allImageUrls.length
    );

    console.log(`✅ Post ${postId} processing complete\n`);

    // ============================================================================
    // ✅ EXISTING DOCUMENT PATH - NOW ALSO CREATES/UPDATES INFO BANK
    // ============================================================================
  } else {
    const docData = doc.data();

    if (docData?.deleted === true) {
      console.log(`⏭️ Skipping deleted post ${postId}`);
      return;
    }

    console.log(`🔄 Updating existing announcement...`);

    // Update announcement
    await postRef.update({
      message: originalMessage,
      images:
        uploadedImageUrls.length > 0
          ? uploadedImageUrls
          : docData?.images || [],
      image_count: uploadedImageUrls.length || docData?.image_count || 0,
      full_picture: uploadedImageUrls[0] || docData?.full_picture || "",
      permalink_url: post.permalink_url || "",
      last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
      stored_in_storage:
        uploadedImageUrls.length > 0 || docData?.stored_in_storage,
      ocr_text: combinedOcrText || docData?.ocr_text || "",
      has_image_text: hasImageText || docData?.has_image_text,
      ocr_processed_count:
        ocrResults.length || docData?.ocr_processed_count || 0,
      total_image_count: allImageUrls.length,
    });

    console.log(`✅ Updated announcement document`);

    // ✅ NEW: Create/update category documents and Information Bank if needed
    const category = docData?.category?.toLowerCase() || "";

    if (
      category &&
      ["admission", "scholarship", "placement"].includes(category)
    ) {
      console.log(`\n🔄 Checking category document and Information Bank...`);

      // Check if category document exists
      const categoryDoc = await db.collection(`${category}s`).doc(postId).get();

      // Check if Information Bank entry exists
      const infoBankId = `${category}_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      const needsCategoryDoc = !categoryDoc.exists;
      const needsInfoBank = !infoBankDoc.exists;

      console.log(`   📊 Category doc exists: ${categoryDoc.exists}`);
      console.log(`   📊 Info Bank exists: ${infoBankDoc.exists}`);

      if (needsCategoryDoc || needsInfoBank) {
        console.log(`   🔧 Creating missing documents...`);

        // Get deadline from announcement
        const deadlineTimestamp = docData?.deadline || null;

        // Create missing category/Info Bank documents
        await createCategoryAndInfoBank(
          postId,
          category.charAt(0).toUpperCase() + category.slice(1), // Capitalize
          messageForAnalysis,
          deadlineTimestamp,
          cohereKey,
          combinedOcrText,
          allImageUrls.length
        );

        console.log(`   ✅ Missing documents created`);
      } else {
        console.log(`   ℹ️ All documents already exist`);
      }
    }

    console.log(`✅ Update complete\n`);
  }
}

async function createCategoryAndInfoBank(
  postId: string,
  category: string,
  messageForAnalysis: string,
  deadlineTimestamp: admin.firestore.Timestamp | null,
  cohereKey: string,
  ocrText: string,
  imageCount: number
): Promise<void> {
  const categoryLower = category.toLowerCase();
  console.log(`📋 Creating ${category} document AND Information Bank...`);

  try {
    if (categoryLower === "admission") {
      await createAdmissionFromAnnouncement(
        postId,
        messageForAnalysis,
        deadlineTimestamp,
        cohereKey,
        ocrText,
        imageCount
      );
      console.log(`✅ Admission + Information Bank created`);
    } else if (categoryLower === "scholarship") {
      await createScholarshipFromAnnouncement(
        postId,
        messageForAnalysis,
        deadlineTimestamp,
        cohereKey,
        ocrText,
        imageCount
      );
      console.log(`✅ Scholarship + Information Bank created`);
    } else if (categoryLower === "placement") {
      await createPlacementFromAnnouncement(
        postId,
        messageForAnalysis,
        deadlineTimestamp,
        cohereKey,
        ocrText,
        imageCount
      );
      console.log(`✅ Placement + Information Bank created`);
    } else {
      console.log(`ℹ️ General category - no special processing`);
    }
  } catch (categoryError: any) {
    console.error(
      `❌ ERROR: Failed to create category/info bank: ${categoryError.message}`
    );
    console.error(`   Stack: ${categoryError.stack}`);

    // ✅ Log to error collection
    try {
      await db.collection("category_creation_errors").add({
        postId,
        category: categoryLower,
        errorMessage: categoryError.message,
        errorStack: categoryError.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (logError) {
      console.error(`   ❌ Failed to log error:`, logError);
    }

    // ✅ Re-throw to make error visible
    throw categoryError;
  }
}
function combineOcrResults(ocrResults: string[]): string {
  if (ocrResults.length === 0) return "";

  console.log(`📝 Combining ${ocrResults.length} OCR result(s)`);
  return ocrResults
    .filter((text) => text.trim().length > 0)
    .join("\n\n---IMAGE SEPARATOR---\n\n");
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
      console.log(
        `✅ Soft-deleted ${collectionName} document for ${announcementId}`
      );
    }
  } catch (error) {
    console.error(
      `❌ Error soft-deleting category document for ${announcementId}:`,
      error
    );
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
    secrets: [
      COHERE_API_KEY, GEMINI_API_KEY,
      GOOGLE_VISION_API_KEY,
      PINECONE_API_KEY,
      PINECONE_HOST,
    ], // ✅ Added
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

    // ✅ Use the updated function that filters by this month
    console.log("📡 Fetching Facebook posts from this month onwards...");
    const posts = await fetchFacebookPosts(); // Now filters by this month

    console.log(`✅ Fetched ${posts.length} posts from this month`);

    let processed = 0;
    let failed = 0;
    let withOCR = 0;

    for (const post of posts) {
      try {
        console.log(`📝 Processing post: ${post.id}`);

        const hasImage = !!post.full_picture;
        await processPost(post, COHERE_API_KEY.value());

        if (hasImage) {
          const postDoc = await db
            .collection("announcements")
            .doc(post.id)
            .get();
          if (postDoc.exists && postDoc.data()?.has_image_text) {
            withOCR++;
          }
        }

        processed++;
      } catch (postError: any) {
        console.error(
          `❌ Error processing post ${post.id}:`,
          postError.message
        );
        failed++;
      }
    }

    console.log(
      `✅ Sync complete: ${processed} processed, ${failed} failed, ${withOCR} with OCR`
    );

    return {
      success: true,
      message:
        `Successfully synced ${processed} posts from this month (${withOCR} with image text extraction)` +
        (failed > 0 ? ` (${failed} failed)` : ""),
      count: processed,
      failed: failed,
      withOCR: withOCR,
      total: posts.length,
      dateFilter: "This month onwards",
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
    secrets: [
      COHERE_API_KEY, GEMINI_API_KEY,
      GOOGLE_VISION_API_KEY,
      PINECONE_API_KEY,
      PINECONE_HOST,
    ], // ✅ Added
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

      throw new HttpsError("internal", error.message || "Sync failed");
    }
  }
);

export const manualSyncFacebookPostsHttp = onRequest(
  {
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [
      COHERE_API_KEY, GEMINI_API_KEY,
      GOOGLE_VISION_API_KEY,
      PINECONE_API_KEY,
      PINECONE_HOST,
    ], // ✅ Added
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
          message: "Please log in first",
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
        details: error.toString(),
      });
    }
  }
);

export const reprocessExistingAnnouncements = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    secrets: [COHERE_API_KEY, GEMINI_API_KEY, GOOGLE_VISION_API_KEY], // ✅ NEW
  },
  async (request) => {
    try {
      console.log("Starting reprocessing of existing announcements...");

      const snapshot = await db
        .collection("announcements")
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
            const deadlineTimestamp = parseDeadlineToTimestamp(
              cohereResult.deadline
            );

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

      console.log(
        `Reprocessing complete: ${processed} processed, ${failed} failed`
      );

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

async function syncCategoryToInfoBank(
  categoryType: 'admission' | 'scholarship' | 'placement',
  documentId: string,
  cohereKey: string,
  config: CategoryToInfoBankConfig = {
    includeInSearch: true,
    autoSync: true,
    generateSummary: true
  }
): Promise<void> {
  try {
    console.log(`🔄 Syncing ${categoryType} document ${documentId} to Information Bank...`);
    
    // Fetch the category document
    const categoryDoc = await db.collection(`${categoryType}s`).doc(documentId).get();
    
    if (!categoryDoc.exists) {
      console.warn(`⚠️ ${categoryType} document ${documentId} not found`);
      return;
    }
    
    const categoryData = categoryDoc.data()!;
    
    // Skip if deleted
    if (categoryData.deleted === true) {
      console.log(`⏭️ Skipping deleted ${categoryType} document ${documentId}`);
      return;
    }
    
    // Convert category data to searchable text content
    const textContent = formatCategoryAsText(categoryType, categoryData);
    
    // Generate title for Information Bank
    const title = generateInfoBankTitle(categoryType, categoryData);
    
    // Split into chunks (for long content)
    const chunks = splitIntoChunks(textContent, title, `${categoryType}_category`);
    console.log(`📄 Split ${categoryType} into ${chunks.length} chunks`);
    
    // Generate embeddings and store in Pinecone
    const chunkIds: string[] = [];
    let parentPineconeId: string | null = null;
    
    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];
      
      // Generate embedding using Gemini
      const embeddingResponse = await axios.post(
        "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=" + GEMINI_API_KEY.value(),
        {
          model: "text-embedding-004",
          content: {
            parts: [
              { text: chunk.text }
            ]
          }
        },
        {
          headers: {
            "Content-Type": "application/json"
          }
        }
      );

      // ✅ FIX: Handle correct Gemini API response structure
      const responseData = embeddingResponse.data as any;
      let embedding: number[] | null = null;

      if (responseData?.embedding?.values && Array.isArray(responseData.embedding.values)) {
        embedding = responseData.embedding.values;
      } else if (responseData?.embeddings?.[0]?.values && Array.isArray(responseData.embeddings[0].values)) {
        embedding = responseData.embeddings[0].values;
      } else if (Array.isArray(responseData?.values)) {
        embedding = responseData.values;
      }

      if (!embedding || embedding.length === 0) {
        console.error(`Unexpected embedding response:`, JSON.stringify(responseData, null, 2));
        throw new Error("Invalid embedding response from Gemini API");
      }
      
      const chunkTitle = chunks.length > 1 
        ? `${title} (Part ${i + 1}/${chunks.length})`
        : title;
      
      // 🔥 CRITICAL: Flat metadata structure for Pinecone (matching Flutter code)
      const metadata = {
        // === DOCUMENT IDENTIFICATION ===
        'docId': documentId,
        'originalDocId': documentId,
        'documentId': documentId,
        'categoryDocId': documentId, // Link back to category document
        
        // === CONTENT ===
        'text': chunk.text,
        'content': chunk.text,
        
        // === TITLES ===
        'title': chunkTitle,
        'originalTitle': title,
        'fileName': title,
        
        // === CHUNKING INFO ===
        'chunkIndex': i,
        'chunk_index': i,
        'totalChunks': chunks.length,
        'chunkCount': chunks.length,
        'isFirstChunk': i === 0,
        'isLastChunk': i === chunks.length - 1,
        
        // === SOURCE & CATEGORY ===
        'source': `${categoryType}_category`,
        'category': categoryType,
        'categoryID': categoryType,
        'categoryType': categoryType, // admission, scholarship, or placement
        
        // === ADDITIONAL METADATA ===
        'chunkSize': chunk.text.length,
        'createdAt': new Date().toISOString(),
        'syncedFromCategory': true,
        
        // === CATEGORY-SPECIFIC DATA ===
        ...(categoryType === 'admission' && {
          'academicYear': categoryData.academicYear || null,
          'hasSchedules': (categoryData.schedules?.length || 0) > 0,
          'scheduleCount': categoryData.schedules?.length || 0,
        }),
        ...(categoryType === 'scholarship' && {
          'scholarshipProvider': categoryData.scholarshipProvider || '',
          'hasDeadline': !!categoryData.deadline,
        }),
        ...(categoryType === 'placement' && {
          'partnerCompany': categoryData.partnerCompany || '',
          'isRecruiting': categoryData.isRecruiting || false,
        }),
      };
      
      // Store in Pinecone
      await storePineconeVector(
        chunk.id,
        embedding,
        metadata
      );
      
      chunkIds.push(chunk.id);
      
      if (i === 0) {
        parentPineconeId = chunk.id;
      }
      
      console.log(`  ✓ Chunk ${i + 1}/${chunks.length} embedded and stored`);
    }
    
    // Save to Information Bank collection
    const infoBankId = `${categoryType}_${documentId}`;
    await db.collection('information_bank').doc(infoBankId).set({
      'ibID': infoBankId,
      'id': infoBankId,
      'ib_title': title,
      'title': title,
      'content': textContent,
      'source': `${categoryType}_category`,
      'category': categoryType,
      'categoryID': categoryType,
      'categoryType': categoryType,
      'categoryDocumentId': documentId, // Link to original category document
      'pinecone_id': parentPineconeId,
      'totalChunks': chunks.length,
      'chunkIds': chunkIds,
      'chunked': chunks.length > 1,
      'chunkSize': 1000, // maxChunkSize
      'chunkOverlap': 200, // chunkOverlap
      'syncedFromCategory': true,
      'createdAt': admin.firestore.FieldValue.serverTimestamp(),
      'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
    });
    
    console.log(`✅ ${categoryType} document synced to Information Bank with ${chunks.length} Pinecone vectors`);
    
  } catch (error) {
    console.error(`❌ Error syncing ${categoryType} to Information Bank:`, error);
    throw error;
  }
}

function formatCategoryAsText(
  categoryType: "admission" | "scholarship" | "placement",
  data: any
): string {
  const buffer: string[] = [];

  try {
    if (categoryType === "admission") {
      buffer.push("ADMISSION INFORMATION\n");
      
      // ✅ Add type if present
      if (data.type) {
        buffer.push(`Test Type: ${data.type}\n`);
      }
      
      buffer.push(`Title: ${data.title || "Untitled"}\n`);
      buffer.push(`Content: ${data.content || "No content"}\n`);

      if (data.academicYear) {
        buffer.push(`Academic Year: ${data.academicYear.start || ""}`);
        if (data.academicYear.end) {
          buffer.push(`-${data.academicYear.end}`);
        }
        buffer.push("\n");
      }
      if (data.steps && Array.isArray(data.steps) && data.steps.length > 0) {
        buffer.push("Steps:\n");
        data.steps.forEach((step: string, i: number) => {
          buffer.push(`${i + 1}. ${step}\n`);
        });
      }

      if (
        data.requirements &&
        Array.isArray(data.requirements) &&
        data.requirements.length > 0
      ) {
        buffer.push("Requirements:\n");
        data.requirements.forEach((req: string) => {
          buffer.push(`- ${req}\n`);
        });
      }

      if (
        data.schedules &&
        Array.isArray(data.schedules) &&
        data.schedules.length > 0
      ) {
        buffer.push("Schedules:\n");
        data.schedules.forEach((schedule: any) => {
          buffer.push(`- ${schedule.date || ""} (${schedule.dayOfWeek || ""})`);
          if (schedule.year) buffer.push(` ${schedule.year}`);
          if (schedule.locations && Array.isArray(schedule.locations)) {
            buffer.push(`: ${schedule.locations.join(", ")}`);
          }
          if (schedule.time) {
            buffer.push(` at ${schedule.time}`);
          }
          buffer.push("\n");
        });
      }

      if (
        data.contacts &&
        Array.isArray(data.contacts) &&
        data.contacts.length > 0
      ) {
        buffer.push("Contact Information:\n");
        data.contacts.forEach((contact: string) => {
          buffer.push(`- ${contact}\n`);
        });
      }
    } else if (categoryType === "scholarship") {
      console.log(`   Processing scholarship data...`);
      console.log(`   - Name: ${data.name || "N/A"}`);
      console.log(
        `   - Description length: ${(data.description || "").length}`
      );

      buffer.push("SCHOLARSHIP INFORMATION\n");
      buffer.push(`Name: ${data.name || "Untitled"}\n`);
      buffer.push(`Description: ${data.description || "No description"}\n`);
      buffer.push(`Provider: ${data.scholarshipProvider || "Unknown"}\n`);

      if (
        data.eligibilityRequirements &&
        Array.isArray(data.eligibilityRequirements) &&
        data.eligibilityRequirements.length > 0
      ) {
        buffer.push("Eligibility Requirements:\n");
        data.eligibilityRequirements.forEach((req: string) => {
          buffer.push(`- ${req}\n`);
        });
      }

      if (
        data.privileges &&
        Array.isArray(data.privileges) &&
        data.privileges.length > 0
      ) {
        buffer.push("Privileges/Benefits:\n");
        data.privileges.forEach((priv: string) => {
          buffer.push(`- ${priv}\n`);
        });
      }

      if (data.applicationLink) {
        buffer.push(`Application Link: ${data.applicationLink}\n`);
      }
    } else if (categoryType === "placement") {
      console.log(`   Processing placement data...`);
      console.log(`   - Company: ${data.partnerCompany || "N/A"}`);
      console.log(`   - Positions: ${data.positions?.length || 0}`);
      console.log(`   - Contacts: ${data.contacts?.length || 0}`);

      buffer.push("JOB PLACEMENT INFORMATION\n");
      buffer.push(`Company: ${data.partnerCompany || "Unknown"}\n`);
      buffer.push(
        `Status: ${
          data.isRecruiting
            ? "Currently Recruiting"
            : "Not Currently Recruiting"
        }\n`
      );

      if (
        data.positions &&
        Array.isArray(data.positions) &&
        data.positions.length > 0
      ) {
        buffer.push("Available Positions:\n");
        data.positions.forEach((position: string) => {
          buffer.push(`- ${position}\n`);
        });
      }

      if (
        data.contacts &&
        Array.isArray(data.contacts) &&
        data.contacts.length > 0
      ) {
        buffer.push("Contact Information:\n");
        data.contacts.forEach((contact: string) => {
          buffer.push(`- ${contact}\n`);
        });
      }
    }

    const result = buffer.join("").trim();

    console.log(`\n📝 Formatted result:`);
    console.log(`   Total length: ${result.length} chars`);
    console.log(`   Preview (first 300 chars):`);
    console.log(`   ${result.substring(0, 300)}...`);
    console.log(`📝 ========================================\n`);

    if (result.length === 0) {
      throw new Error("Formatted content is empty after processing");
    }

    return result;
  } catch (error: any) {
    console.error(`\n❌ ERROR in formatCategoryAsText:`);
    console.error(`   Category: ${categoryType}`);
    console.error(`   Error: ${error.message}`);
    console.error(`   Stack: ${error.stack}`);
    console.error(`❌ ========================================\n`);

    throw error; // ✅ Re-throw instead of returning error message
  }
}

function generateInfoBankTitle(
  categoryType: "admission" | "scholarship" | "placement",
  data: any
): string {
  if (categoryType === "admission") {
    return data.title || "Admission Information";
  } else if (categoryType === "scholarship") {
    return data.name || "Scholarship Information";
  } else if (categoryType === "placement") {
    return `${data.partnerCompany || "Company"} - Job Placement`;
  }
  return "Category Information";
}

export const testCreateInfoBank = onCall(
  {
    cors: true,
    timeoutSeconds: 300,
    secrets: [COHERE_API_KEY, GEMINI_API_KEY, PINECONE_API_KEY],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const { announcementId } = request.data;

      if (!announcementId) {
        throw new HttpsError("invalid-argument", "announcementId is required");
      }

      console.log(`\n🧪 ========================================`);
      console.log(`🧪 TEST: Creating Information Bank for ${announcementId}`);
      console.log(`🧪 ========================================\n`);

      // Get announcement
      console.log(`📋 Step 1: Fetching announcement...`);
      const announcementDoc = await db
        .collection("announcements")
        .doc(announcementId)
        .get();

      if (!announcementDoc.exists) {
        throw new HttpsError(
          "not-found",
          `Announcement ${announcementId} not found`
        );
      }

      const announcementData = announcementDoc.data()!;
      console.log(`   ✅ Announcement found`);
      console.log(`   📊 Category: ${announcementData.category}`);
      console.log(
        `   📊 Message length: ${(announcementData.message || "").length} chars`
      );
      console.log(`   📊 Has OCR: ${announcementData.has_image_text || false}`);

      const category = announcementData.category?.toLowerCase();

      if (
        !category ||
        !["admission", "scholarship", "placement"].includes(category)
      ) {
        throw new HttpsError(
          "invalid-argument",
          `Invalid category: ${category}. Must be admission, scholarship, or placement`
        );
      }

      // Get category document
      console.log(`\n📋 Step 2: Fetching ${category} document...`);
      const categoryDoc = await db
        .collection(`${category}s`)
        .doc(announcementId)
        .get();

      if (!categoryDoc.exists) {
        throw new HttpsError(
          "not-found",
          `${category} document ${announcementId} not found`
        );
      }

      const categoryData = categoryDoc.data()!;
      console.log(`   ✅ Category document found`);
      console.log(`   📊 Fields: ${Object.keys(categoryData).join(", ")}`);

      // Prepare extracted data
      console.log(`\n📋 Step 3: Preparing extracted data...`);
      let extractedData: any = {};

      if (category === "admission") {
        extractedData = {
          title: categoryData.title || "Admission Information",
          content: categoryData.content || "",
          steps: categoryData.steps || [],
          requirements: categoryData.requirements || [],
          contacts: categoryData.contact || [],
          academicYear: categoryData.academicYear || null,
          schedules: categoryData.schedules || [],
        };
        console.log(`   ✅ Admission data prepared`);
        console.log(`      - Steps: ${extractedData.steps.length}`);
        console.log(
          `      - Requirements: ${extractedData.requirements.length}`
        );
        console.log(`      - Schedules: ${extractedData.schedules.length}`);
      } else if (category === "scholarship") {
        extractedData = {
          name: categoryData.name || "Scholarship Information",
          description: categoryData.description || "",
          scholarshipProvider: categoryData.scholarshipProvider || "",
          eligibilityRequirements: categoryData.eligibilityRequirements || [],
          privileges: categoryData.privileges || [],
          applicationLink: categoryData.applicationLink || "",
        };
        console.log(`   ✅ Scholarship data prepared`);
        console.log(
          `      - Eligibility: ${extractedData.eligibilityRequirements.length}`
        );
        console.log(`      - Privileges: ${extractedData.privileges.length}`);
      } else if (category === "placement") {
        extractedData = {
          partnerCompany: categoryData.partnerCompany || "Company",
          positions: categoryData.positions || [],
          contacts: categoryData.contacts || [],
          isRecruiting: categoryData.isRecruiting !== false,
        };
        console.log(`   ✅ Placement data prepared`);
        console.log(`      - Company: ${extractedData.partnerCompany}`);
        console.log(`      - Positions: ${extractedData.positions.length}`);
      }

      // Check if Information Bank entry already exists
      const infoBankId = `${category}_${announcementId}`;
      const existingInfoBank = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (existingInfoBank.exists) {
        console.log(
          `\n⚠️ Information Bank entry already exists: ${infoBankId}`
        );
        console.log(`   Deleting existing entry first...`);
        await db.collection("information_bank").doc(infoBankId).delete();
        console.log(`   ✅ Existing entry deleted`);
      }

      // Create Information Bank entry
      console.log(`\n📋 Step 4: Creating Information Bank entry...`);
      await createInfoBankFromCategory(
        announcementId,
        category as "admission" | "scholarship" | "placement",
        extractedData,
        COHERE_API_KEY.value()
      );

      // Verify creation
      console.log(`\n📋 Step 5: Verifying creation...`);
      const verifyInfoBank = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (!verifyInfoBank.exists) {
        throw new Error("Information Bank entry was not created");
      }

      const infoBankData = verifyInfoBank.data()!;
      console.log(`   ✅ Information Bank entry verified`);
      console.log(`   📊 Total chunks: ${infoBankData.totalChunks}`);
      console.log(`   📊 Pinecone ID: ${infoBankData.pinecone_id}`);
      console.log(
        `   📊 Content length: ${(infoBankData.content || "").length} chars`
      );

      const result = {
        success: true,
        message: `Information Bank entry created successfully`,
        announcementId,
        category,
        infoBankId,
        data: {
          totalChunks: infoBankData.totalChunks,
          pineconeId: infoBankData.pinecone_id,
          contentLength: (infoBankData.content || "").length,
          title: infoBankData.title,
        },
      };

      console.log(`\n🧪 ========================================`);
      console.log(`🧪 TEST SUCCESSFUL`);
      console.log(`🧪 ========================================\n`);

      return result;
    } catch (error: any) {
      console.error(`\n❌ ========================================`);
      console.error(`❌ TEST FAILED`);
      console.error(`❌ Error: ${error.message}`);
      console.error(`❌ ========================================\n`);

      throw new HttpsError("internal", `Test failed: ${error.message}`, {
        originalError: error.toString(),
      });
    }
  }
);

// ============================================================================
// ✅ LIST ALL INFORMATION BANK ENTRIES
// ============================================================================

export const listInfoBankEntries = onCall(
  { cors: true, secrets: [] },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      console.log("📋 Listing all Information Bank entries...");

      const snapshot = await db.collection("information_bank").get();

      const entries = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          title: data.title || data.ib_title,
          category: data.category,
          source: data.source,
          totalChunks: data.totalChunks,
          pineconeId: data.pinecone_id,
          contentLength: (data.content || "").length,
          createdAt: data.createdAt?.toDate?.()?.toISOString?.() || "Unknown",
          syncedFromCategory: data.syncedFromCategory || false,
        };
      });

      console.log(`✅ Found ${entries.length} Information Bank entries`);

      return {
        success: true,
        count: entries.length,
        entries: entries.sort((a, b) =>
          (b.createdAt || "").localeCompare(a.createdAt || "")
        ),
      };
    } catch (error: any) {
      console.error("❌ Error listing entries:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

// ============================================================================
// ✅ DELETE SPECIFIC INFORMATION BANK ENTRY
// ============================================================================

export const deleteInfoBankEntry = onCall(
  { cors: true, secrets: [] },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const { infoBankId } = request.data;

      if (!infoBankId) {
        throw new HttpsError("invalid-argument", "infoBankId is required");
      }

      console.log(`🗑️ Deleting Information Bank entry: ${infoBankId}`);

      const doc = await db.collection("information_bank").doc(infoBankId).get();

      if (!doc.exists) {
        throw new HttpsError("not-found", `Entry ${infoBankId} not found`);
      }

      const data = doc.data()!;
      const chunkIds = data.chunkIds || [];

      console.log(`   📄 Entry has ${chunkIds.length} Pinecone chunks`);

      // TODO: Delete Pinecone vectors (requires Pinecone service)
      // await pineconeService.deleteVectors(chunkIds);

      await doc.ref.delete();

      console.log(`✅ Deleted Information Bank entry: ${infoBankId}`);

      return {
        success: true,
        message: `Deleted entry ${infoBankId}`,
        deletedChunks: chunkIds.length,
      };
    } catch (error: any) {
      console.error("❌ Error deleting entry:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

export const fixAnnouncementInfoBankMetadata = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [COHERE_API_KEY, GEMINI_API_KEY, PINECONE_API_KEY, PINECONE_HOST],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      console.log(`\n🔧 ========================================`);
      console.log(`🔧 FIXING ANNOUNCEMENT-BASED INFO BANK ENTRIES`);
      console.log(`🔧 ========================================\n`);

   
      const pineconeKey = PINECONE_API_KEY.value();
      const pineconeUrl = PINECONE_HOST.value();

      let totalFixed = 0;
      let totalSkipped = 0;
      let totalFailed = 0;

      // Get all announcement-based Info Bank entries
      const infoBankSnapshot = await db
        .collection('information_bank')
        .where('syncedFromCategory', '==', true)
        .get();

      console.log(`📊 Found ${infoBankSnapshot.docs.length} announcement-based entries\n`);

      for (const doc of infoBankSnapshot.docs) {
        const data = doc.data();
        const infoBankId = doc.id;
        const categoryType = data.categoryType as 'admission' | 'scholarship' | 'placement';
        const documentId = data.categoryDocumentId || data.announcementId;

        console.log(`\n📄 Processing: ${infoBankId}`);
        console.log(`   Category: ${categoryType}`);
        console.log(`   Document ID: ${documentId}`);

        if (!categoryType || !documentId) {
          console.log(`   ⚠️ Missing required fields - skipping`);
          totalSkipped++;
          continue;
        }

        try {
          // Get the category document to extract data
          const categoryDoc = await db
            .collection(`${categoryType}s`)
            .doc(documentId)
            .get();

          if (!categoryDoc.exists) {
            console.log(`   ⚠️ Category document not found - skipping`);
            totalSkipped++;
            continue;
          }

          const categoryData = categoryDoc.data()!;

          // Get existing chunks
          const chunkIds = data.chunkIds || [];
          console.log(`   📊 Has ${chunkIds.length} chunks to update`);

          if (chunkIds.length === 0) {
            console.log(`   ⚠️ No chunks found - skipping`);
            totalSkipped++;
            continue;
          }

          // Get title and content
          const title = getCategoryTitle(categoryType, categoryData);
          const textContent = formatCategoryAsText(categoryType, categoryData);
          const chunks = splitIntoChunks(textContent, title, `${categoryType}_category`);

          // Update each chunk in Pinecone with correct metadata
          for (let i = 0; i < Math.min(chunkIds.length, chunks.length); i++) {
            const chunkId = chunkIds[i];
            const chunk = chunks[i];

            // Generate new embedding with correct model
            const embeddingResponse = await axios.post(
              "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=" + GEMINI_API_KEY.value(),
              {
                model: "text-embedding-004",
                content: {
                  parts: [
                    { text: chunk.text }
                  ]
                }
              },
              {
                headers: {
                  "Content-Type": "application/json"
                }
              }
            );

            // ✅ FIX: Handle correct response structure
            const responseData = embeddingResponse.data as any;
            let embedding: number[] | null = null;

            if (responseData?.embedding?.values && Array.isArray(responseData.embedding.values)) {
              embedding = responseData.embedding.values;
            } else if (responseData?.embeddings?.[0]?.values && Array.isArray(responseData.embeddings[0].values)) {
              embedding = responseData.embeddings[0].values;
            } else if (Array.isArray(responseData?.values)) {
              embedding = responseData.values;
            }

            if (!embedding) {
              throw new Error("Failed to generate embedding");
            }

            const chunkTitle = chunks.length > 1
              ? `${title} (Part ${i + 1}/${chunks.length})`
              : title;

            // 🔥 CRITICAL: Updated metadata structure matching Flutter
            const metadata = {
              // Primary identifiers
              'docId': documentId,
              'originalDocId': documentId,
              'documentId': documentId,
              'categoryDocId': documentId,
              
              // Content
              'text': chunk.text,
              'content': chunk.text,
              
              // Titles
              'title': chunkTitle,
              'originalTitle': title,
              'fileName': title,
              
              // Chunking info
              'chunkIndex': i,
              'chunk_index': i,
              'totalChunks': chunks.length,
              'chunkCount': chunks.length,
              'chunkSize': chunk.text.length,
              'isFirstChunk': i === 0,
              'isLastChunk': i === chunks.length - 1,
              
              // Source & category
              'source': `${categoryType}_category`,
              'category': categoryType,
              'categoryID': categoryType,
              'categoryType': categoryType,
              
              // Timestamps & flags
              'createdAt': new Date().toISOString(),
              'syncedFromCategory': true,
              'autoGeneratedFromAnnouncement': true,
              
              // Category-specific
              ...getCategorySpecificMetadata(categoryType, categoryData),
            };

            // Update in Pinecone using upsert
            await axios.post(
              `${pineconeUrl}/vectors/upsert`,
              {
                vectors: [{
                  id: chunkId,
                  values: embedding,
                  metadata: metadata,
                }]
              },
              {
                headers: {
                  'Api-Key': pineconeKey,
                  'Content-Type': 'application/json',
                },
                timeout: 30000,
              }
            );

            console.log(`      ✓ Updated chunk ${i + 1}/${chunks.length}`);
          }

          // Update Firestore document
          await db.collection('information_bank').doc(infoBankId).update({
            'content': textContent,
            'ib_title': title,
            'title': title,
            'totalChunks': chunks.length,
            'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
            'metadataFixed': true,
            'fixedAt': admin.firestore.FieldValue.serverTimestamp(),
          });

          totalFixed++;
          console.log(`   ✅ Fixed ${chunkIds.length} chunks`);

        } catch (error: any) {
          totalFailed++;
          console.error(`   ❌ Failed: ${error.message}`);
          
          // Log error
          await db.collection('info_bank_fix_errors').add({
            infoBankId,
            categoryType,
            documentId,
            error: error.message,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      const summary = {
        success: true,
        message: `Fixed ${totalFixed} Info Bank entries`,
        stats: {
          total: infoBankSnapshot.docs.length,
          fixed: totalFixed,
          skipped: totalSkipped,
          failed: totalFailed,
        },
      };

      console.log(`\n🔧 ========================================`);
      console.log(`🔧 FIX COMPLETE`);
      console.log(`🔧 Fixed: ${totalFixed}`);
      console.log(`🔧 Skipped: ${totalSkipped}`);
      console.log(`🔧 Failed: ${totalFailed}`);
      console.log(`🔧 ========================================\n`);

      return summary;

    } catch (error: any) {
      console.error(`\n❌ ========================================`);
      console.error(`❌ FIX OPERATION FAILED`);
      console.error(`❌ Error: ${error.message}`);
      console.error(`❌ ========================================\n`);
      
      throw new HttpsError("internal", error.message);
    }
  }
);
// 1. API Usage Split ✅

// Cohere: Text analysis (categorization, deadline extraction, structured data extraction)
// Gemini: Embeddings only (for vector search)

// 2. Fixed Field Names ✅
// Admissions Model:

// id (not admissionID)
// contact (not contacts) ← Key fix
// announcementId
// schedules array properly structured

// Scholarship Model:

// scholarshipID ✅ Correct
// sourceId
// deadline stored as Date not Timestamp

// Placement Model:

// placementID ✅ Correct
// contacts ✅ Correct (plural for placements)
// deadline stored as Date not Timestamp
