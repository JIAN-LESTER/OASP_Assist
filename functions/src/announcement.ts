/* eslint-disable no-empty */
/* eslint-disable no-useless-catch */
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {defineSecret} from "firebase-functions/params";
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import axios from "axios";
import {logGeminiUsage} from "./geminiUsage";

// Define secrets
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const PINECONE_HOST = defineSecret("PINECONE_HOST");

const db = admin.firestore();
const storage = admin.storage();

const FB_API_VERSION = "v24.0";
// const PAGE_ID = "730995450096065";

interface CategoryToInfoBankConfig {
  includeInSearch: boolean;
  autoSync: boolean;
  generateSummary: boolean;
}
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


async function getAutoCreateSettings(): Promise<{
  enabled: boolean;
  categories: { admission: boolean; scholarship: boolean; placement: boolean };
}> {
  try {
    const settingsDoc = await db.collection("settings").doc("announcement_sync").get();
    if (!settingsDoc.exists) {
      // Default: everything enabled if setting doesn't exist yet
      return { enabled: true, categories: { admission: true, scholarship: true, placement: true } };
    }
    const data = settingsDoc.data()!;
    return {
      enabled: data.autoCreateDocuments !== false,
      categories: {
        admission: data.categories?.admission !== false,
        scholarship: data.categories?.scholarship !== false,
        placement: data.categories?.placement !== false,
      },
    };
  } catch (error) {
    return { enabled: true, categories: { admission: true, scholarship: true, placement: true } };
  }
}


function extractAllImagesFromPost(post: FacebookPost): string[] {
  const images: string[] = [];

  //   Simple extraction without deduplication
  console.log(" Extracting images from post...");

  // Extract from attachments FIRST (higher quality)
  if (post.attachments?.data) {
    for (let idx = 0; idx < post.attachments.data.length; idx++) {
      const attachment = post.attachments.data[idx];

      // Multiple images (subattachments - album/carousel)
      if (attachment.subattachments?.data) {
        for (
          let subIdx = 0;
          subIdx < attachment.subattachments.data.length;
          subIdx++
        ) {
          const sub = attachment.subattachments.data[subIdx];
          if (sub.media?.image?.src) {
            images.push(sub.media.image.src);
          }
        }
      }
      // Single image attachment
      else if (attachment.media?.image?.src) {
        images.push(attachment.media.image.src);
      }
    }
  }

  // Only add full_picture if we found NO images from attachments
  if (images.length === 0 && post.full_picture) {
    images.push(post.full_picture);
  }

  return images;
}

async function downloadAndUploadAllImages(
  imageUrls: string[],
  postId: string
): Promise<string[]> {
  const uploadedUrls: string[] = [];


  for (let i = 0; i < imageUrls.length; i++) {
    const imageUrl = imageUrls[i];
    try {
      const response = await axios.get(imageUrl, {
        responseType: "arraybuffer",
        timeout: 30000,
        maxBodyLength: 50 * 1024 * 1024,
        headers: { "User-Agent": "Mozilla/5.0 (compatible; OASP-Bot/1.0)" },
      } as any);

      const buffer = Buffer.from(response.data as Buffer);


      const rawContentType =
        response.headers["content-type"] || "image/jpeg";
      const contentType = rawContentType.split(";")[0].trim();
      const extMap: Record<string, string> = {
        "image/jpeg": "jpg",
        "image/jpg": "jpg",
        "image/png": "png",
        "image/gif": "gif",
        "image/webp": "webp",
        "image/bmp": "bmp",
      };
      const ext = extMap[contentType] || "jpg";

      const fileName =
        imageUrls.length > 1 ?
          `announcements/${postId}_${i}.${ext}` :
          `announcements/${postId}.${ext}`;

      const bucket = storage.bucket();
      const file = bucket.file(fileName);


      const downloadToken = generateToken();

      await file.save(buffer, {
        metadata: {
          contentType,
          cacheControl: "public, max-age=31536000",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            postId,
            imageIndex: i.toString(),
            totalImages: imageUrls.length.toString(),
          },
        },
      });


      const encodedFileName = encodeURIComponent(fileName);
      const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodedFileName}?alt=media&token=${downloadToken}`;

      uploadedUrls.push(publicUrl);
    } catch {
    }
  }

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


    const isGenericInCampus =
      lineLower === "in-campus" ||
      (lineLower.includes("in-campus") &&
        lineLower.includes("central mindanao"));

    if (isLocation && !isGenericInCampus) {
      // Clean up location
      const location = line.replace(/[()]/g, " ").trim();
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

  return schedules;
}

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
    return null;
  }
}

interface FacebookPost {
  id: string;
  message?: string;
  created_time: string;
  full_picture?: string;
  permalink_url?: string;
  attachments?: {
    data?: Array<{
      media?: {image?: {src?: string}};
      subattachments?: {
        data?: Array<{
          media?: {image?: {src?: string}};
        }>;
      };
    }>;
  };
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

    return pageId;
  } catch (error: any) {
    throw error;
  }
}

async function getAccessToken(): Promise<string> {
  try {
    const tokenDoc = await db
      .collection("fb_tokens")
      .doc("facebook_admin")
      .get();

    if (!tokenDoc.exists) {
      throw new Error(
        "No Facebook token configured. Please configure token using the settings."
      );
    }

    const data = tokenDoc.data();

    if (!data) {
      throw new Error("Invalid token data in database");
    }

    const pages = data.pages || {};
    const pageId = data.pageId;

    if (!pageId) {
      throw new Error("No Page ID configured. Please add your Page ID in settings.");
    }

    const pageIds = Object.keys(pages);


    if (pages[pageId] && pages[pageId].access_token) {
      return pages[pageId].access_token;
    }

    if (pageIds.length > 0) {
      const firstPageId = pageIds[0];
      const firstPageToken = pages[firstPageId].access_token;
      return firstPageToken;
    }

    if (data.long_token) {
      return data.long_token;
    }

    throw new Error("No valid access token found. Please refresh your token.");
  } catch (error: any) {
    throw error;
  }
}


async function fetchFacebookPosts(): Promise<FacebookPost[]> {
  try {
    const PAGE_ID = await getPageId();


    const accessToken = await getAccessToken();

    // Calculate start of the current month (midnight on the 1st)
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    startOfMonth.setHours(0, 0, 0, 0);

    // Convert to Unix timestamp (seconds since epoch)
    const sinceTimestamp = Math.floor(startOfMonth.getTime() / 1000);


    const url = `https://graph.facebook.com/${FB_API_VERSION}/${PAGE_ID}/posts`;
    const params = {
      fields: "message,created_time,full_picture,permalink_url,attachments",
      since: sinceTimestamp.toString(),
      limit: 100,
      access_token: accessToken,
    };


    const response = await axios.get<{ data: FacebookPost[] }>(url, {
      params,
      timeout: 30000,
    });


    // Filter out posts before the start of the current month (double-check on our side)
    const filteredPosts = (response.data.data || []).filter((post) => {
      const postDate = new Date(post.created_time);
      const isInCurrentMonthWindow = postDate >= startOfMonth;

      if (!isInCurrentMonthWindow) {
      }

      return isInCurrentMonthWindow;
    });

    return filteredPosts;
  } catch (error: any) {
    if (error.response) {
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

export const syncFacebookPosts = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Asia/Manila",
    timeoutSeconds: 540,
    memory: "1GiB",
    secrets: [
      COHERE_API_KEY, GEMINI_API_KEY,
      PINECONE_API_KEY,
      PINECONE_HOST,
    ],
  },
  async (event) => {
    try {
      const posts = await fetchFacebookPosts();

      for (const post of posts) {
        await processPost(post, COHERE_API_KEY.value());
      }
    } catch (error) {
      throw error;
    }
  }
);

async function syncFacebookPostsLogic(): Promise<any> {
  try {
    const posts = await fetchFacebookPosts();


    let processed = 0;
    let failed = 0;

    for (const post of posts) {
      try {
        await processPost(post, COHERE_API_KEY.value());

        processed++;
      } catch (postError: any) {
        failed++;
      }
    }


    return {
      success: true,
      message:
        `Successfully synced ${processed} posts from the start of the month` +
        (failed > 0 ? ` (${failed} failed)` : ""),
      count: processed,
      failed: failed,
      total: posts.length,
      dateFilter: "Start of current month",
    };
  } catch (error: any) {
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
      PINECONE_API_KEY,
      PINECONE_HOST,
    ],
  },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const result = await syncFacebookPostsLogic();
      return result;
    } catch (error: any) {
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
      PINECONE_API_KEY,
      PINECONE_HOST,
    ],
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
      const authHeader = req.headers.authorization as string | undefined;
      const userId = await verifyAuthToken(authHeader);

      if (!userId) {
        res.status(401).json({
          error: "unauthenticated",
          message: "Please log in first",
        });
        return;
      }


      const result = await syncFacebookPostsLogic();

      res.json({result});
    } catch (error: any) {
      res.status(500).json({
        error: "internal",
        message: error.message || "Sync failed",
        details: error.toString(),
      });
    }
  }
);

function parseDeadlineToTimestamp(
  deadline: string | null
): admin.firestore.Timestamp | null {
  if (!deadline || deadline.trim() === "") return null;

  try {
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
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }

    const relativeDatePatterns = [
      {pattern: /tomorrow/i, days: 1},
      {pattern: /in\s+(\d+)\s+days?/i, daysFromMatch: true},
      {pattern: /next\s+week/i, days: 7},
      {pattern: /(\d+)\s+days?\s+from\s+now/i, daysFromMatch: true},
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
        return admin.firestore.Timestamp.fromDate(parsedDate);
      }
    }

    const parsedDate = new Date(cleanedDeadline);
    if (!isNaN(parsedDate.getTime()) && parsedDate.getFullYear() > 2020) {
      parsedDate.setHours(23, 59, 59, 999);
      return admin.firestore.Timestamp.fromDate(parsedDate);
    }

    return null;
  } catch (error) {
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

        if (
          deadline &&
          (deadline.toLowerCase() === "null" || deadline.trim() === "")
        ) {
          deadline = null;
        }

        if (!deadline) {
          deadline = extractDeadlines(message);
          if (deadline) {
          }
        }


        return {category, deadline};
      } catch (e) {
        return fallbackAnalysis(message);
      }
    } else {
      throw new Error(`Cohere API error: ${response.status}`);
    }
  } catch (error: any) {
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
    return JSON.stringify({category, deadline});
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
    return null;
  }


  const datesWithYear = extractedDates.filter((d) => /\d{4}/.test(d));
  if (datesWithYear.length > 0) {
    return datesWithYear[0];
  }

  return extractedDates[0];
}

// ============================================================================

// ============================================================================

interface ExtractedAdmissionData {
  type: string | null;
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
  }

  try {
    const prompt = `Extract admission information from this announcement. The content includes text from ${
      imageCount || 0
    } schedule images. Return ONLY valid JSON.

Announcement: "${message}"
${
  ocrText ?
    `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` :
    ""
}

CRITICAL INSTRUCTIONS:
1. Determine the admission TYPE by looking for these keywords:
   - CMUCAT (Central Mindanao University College Admission Test)
   - GSAT (Graduate School Admission Test)
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
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);


    let admissionType = result.type || null;

    // Fallback: detect type from content if not provided by AI
    if (!admissionType) {
      const contentToCheck = `${message} ${ocrText || ""}`.toUpperCase();
      if (contentToCheck.includes("CMUCAT")) {
        admissionType = "CMUCAT";
      } else if (contentToCheck.includes("GSAT")) {
        admissionType = "GSAT";
      } else if (contentToCheck.includes("ULHSAT")) {
        admissionType = "ULHSAT";
      }
    }


    let finalSchedules = result.schedules || [];
    if (finalSchedules.length < extractedSchedules.length) {
      finalSchedules = extractedSchedules;
    }

    let enhancedContent = result.content || message;
    if (ocrText && !enhancedContent.includes(ocrText.substring(0, 50))) {
      enhancedContent = `${message}\n\n[Information from ${
        imageCount || 0
      } image(s)]:\n${ocrText}`;
    }

    return {
      type: admissionType,
      title: result.title || message.substring(0, 100),
      content: enhancedContent,
      steps: Array.isArray(result.steps) ? result.steps : [],
      requirements: Array.isArray(result.requirements) ?
        result.requirements :
        [],
      contacts: Array.isArray(result.contacts) ? result.contacts : [],
      academicYear: result.academicYear || null,
      schedules: finalSchedules,
    };
  } catch (error) {
    // Fallback type detection
    let detectedType = null;
    const fullText = `${message} ${ocrText || ""}`.toUpperCase();
    if (fullText.includes("CMUCAT")) {
      detectedType = "CMUCAT";
    } else if (fullText.includes("GSAT")) {
      detectedType = "GSAT";
    } else if (fullText.includes("ULHSAT")) {
      detectedType = "ULHSAT";
    }

    return {
      type: detectedType,
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
  ocrText ?
    `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` :
    ""
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
          "Authorization": `Bearer ${cohereKey}`,
          "Content-Type": "application/json",
        },
      }
    );

    const text = String(response.data?.text ?? "").trim();
    const jsonStr = extractJsonFromResponse(text);
    const result = JSON.parse(jsonStr);


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
      eligibilityRequirements: Array.isArray(result.eligibilityRequirements) ?
        result.eligibilityRequirements :
        [],
      privileges: Array.isArray(result.privileges) ? result.privileges : [],
      applicationLink: result.applicationLink || "",
    };
  } catch (error) {
    return {
      name: "Scholarship Announcement",
      description: ocrText ?
        `${message}\n\n[Image Text]:\n${ocrText}` :
        message,
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
  ocrText ?
    `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` :
    ""
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
        return;
      }

      // Check if Information Bank exists
      const infoBankId = `admission_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        return;
      }

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

      return;
    }

    // Both missing - create both

    const extractedData = await extractAdmissionData(
      message,
      cohereKey,
      ocrText,
      imageCount
    );

    await admissionRef.set({
      id: postId,
      announcementId: postId,
      type: extractedData.type,
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


    await createInfoBankFromCategory(
      postId,
      "admission",
      extractedData,
      cohereKey
    );
  } catch (error: any) {
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
        return;
      }


      const infoBankId = `scholarship_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        return;
      }


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

      return;
    }

    // Both missing - create both

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


    await createInfoBankFromCategory(
      postId,
      "scholarship",
      extractedData,
      cohereKey
    );
  } catch (error: any) {
    throw error;
  }
}
export const debugInfoBank = onCall(
  {cors: true, secrets: [COHERE_API_KEY]},
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

    if (existingDoc.exists) {
      const existingData = existingDoc.data();
      if (existingData?.deleted === true) {
        return;
      }


      const infoBankId = `placement_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (infoBankDoc.exists) {
        return;
      }


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

      return;
    }

    // Both placement and Info Bank are missing - create both

    const extractedData = await extractPlacementData(
      message,
      cohereKey,
      ocrText,
      imageCount
    );


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


    await createInfoBankFromCategory(
      postId,
      "placement",
      extractedData,
      cohereKey
    );
  } catch (error: any) {
    throw error; // Re-throw to make error visible
  }
}

async function createInfoBankFromCategory(
  documentId: string,
  categoryType: "admission" | "scholarship" | "placement",
  extractedData: any,
  cohereKey: string
): Promise<void> {
  const functionStart = Date.now();


  try {
    // ============================================================================
    // STEP 1: Check if this category item was extracted from a document upload
    // ============================================================================

    const categoryDoc = await db.collection(`${categoryType}s`).doc(documentId).get();

    if (!categoryDoc.exists) {
      throw new Error(`Category document ${documentId} not found`);
    }


    // ============================================================================
    // STEP 2: Validate inputs (rest of existing code)
    // ============================================================================

    if (!documentId || documentId.trim().length === 0) {
      throw new Error("documentId is empty or invalid");
    }

    if (!categoryType || !["admission", "scholarship", "placement"].includes(categoryType)) {
      throw new Error(`Invalid categoryType: ${categoryType}`);
    }

    if (!extractedData) {
      throw new Error("extractedData is null or undefined");
    }


    // ============================================================================
    // STEP 2: Create Information Bank ID and check for duplicates
    // ============================================================================
    const infoBankId = `${categoryType}_${documentId}`;


    const existingDoc = await db.collection("information_bank").doc(infoBankId).get();

    if (existingDoc.exists) {
      // Update timestamp and exit
      await db.collection("information_bank").doc(infoBankId).update({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastChecked: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }


    const possibleDuplicates = await db
      .collection("information_bank")
      .where("categoryDocumentId", "==", documentId)
      .where("category", "==", categoryType)
      .get();

    if (!possibleDuplicates.empty) {
      for (const dupDoc of possibleDuplicates.docs) {
        const dupData = dupDoc.data();
        const dupId = dupDoc.id;


        // If this has the wrong ID format, delete it
        if (dupId !== infoBankId) {
          try {
            // Delete old Pinecone vectors
            const oldChunkIds = dupData.chunkIds || [];
            if (oldChunkIds.length > 0) {
              // Delete from Pinecone
              const PINECONE_KEY = PINECONE_API_KEY.value();
              const PINECONE_URL = PINECONE_HOST.value();

              if (PINECONE_KEY && PINECONE_URL) {
                try {
                  await axios.post(
                    `${PINECONE_URL}/vectors/delete`,
                    {
                      ids: oldChunkIds,
                    },
                    {
                      headers: {
                        "Api-Key": PINECONE_KEY,
                        "Content-Type": "application/json",
                      },
                      timeout: 30000,
                    }
                  );
                } catch (pineconeError: any) {
                }
              } else {
              }
            }

            // Delete Firestore document
            await dupDoc.ref.delete();
          } catch (deleteError: any) {
          }
        }
      }
    } else {
    }

    // ============================================================================
    // STEP 3: Format content
    // ============================================================================
    const textContent = formatCategoryAsText(categoryType, extractedData);
    const title = getCategoryTitle(categoryType, extractedData);


    if (!textContent || textContent.trim().length === 0) {
      throw new Error("Formatted content is empty");
    }

    // ============================================================================
    // STEP 4: Split into chunks
    // ============================================================================
    const chunks = splitIntoChunks(textContent, title, `${categoryType}_category`);

    if (chunks.length === 0) {
      throw new Error("No chunks created from content");
    }

    let parentPineconeId: string | null = null;
    const chunkIds: string[] = [];

    // ============================================================================
    // STEP 5: Process each chunk with retries
    // ============================================================================

    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];

      // Generate embedding with retry
      let embedding: number[] | null = null;
      let retries = 3;

      while (retries > 0 && !embedding) {
        try {
          const embeddingResponse = await axios.post(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=" + GEMINI_API_KEY.value(),
            {
              model: "gemini-embedding-001",
              content: {
                parts: [
                  {text: chunk.text},
                ],
              },
            },
            {
              headers: {
                "Content-Type": "application/json",
              },
              timeout: 30000,
            }
          );

          const responseData = embeddingResponse.data as any;
          await logGeminiUsage({
            userId: null,
            conversationId: null,
            model: "gemini-embedding-001",
            inputTokens: responseData?.usageMetadata?.promptTokenCount ?? Math.ceil(chunk.text.length / 4),
            outputTokens: 0,
          }).catch(() => undefined);

          // Try multiple possible response structures
          if (responseData?.embedding?.values && Array.isArray(responseData.embedding.values)) {
            embedding = responseData.embedding.values;
          } else if (responseData?.embeddings?.[0]?.values && Array.isArray(responseData.embeddings[0].values)) {
            embedding = responseData.embeddings[0].values;
          } else if (Array.isArray(responseData?.values)) {
            embedding = responseData.values;
          }

          if (!embedding || embedding.length === 0) {
            throw new Error("Invalid embedding response");
          }
        } catch (error: any) {
          retries--;

          if (retries > 0) {
            const waitTime = (4 - retries) * 2000; // Exponential backoff
            await new Promise((resolve) => setTimeout(resolve, waitTime));
          } else {
            throw new Error(`Embedding generation failed after 3 attempts: ${error.message}`);
          }
        }
      }

      if (!embedding) {
        throw new Error("Embedding generation failed");
      }

      const chunkTitle = chunks.length > 1 ?
        `${title} (Part ${i + 1}/${chunks.length})` :
        title;


      const metadata = {
        // === PRIMARY IDENTIFIERS ===
        "docId": documentId,
        "originalDocId": documentId,
        "documentId": documentId,
        "categoryDocId": documentId,
        "categoryDocumentId": documentId, // For duplicate detection

        // === CONTENT (primary fields first) ===
        "text": chunk.text,
        "content": chunk.text,

        // === TITLES ===
        "title": chunkTitle,
        "originalTitle": title,
        "fileName": title,

        // === CHUNKING INFO (matching Flutter naming) ===
        "chunkIndex": i,
        "chunk_index": i,
        "totalChunks": chunks.length,
        "chunkCount": chunks.length,
        "chunkSize": chunk.text.length,
        "isFirstChunk": i === 0,
        "isLastChunk": i === chunks.length - 1,

        // === SOURCE & CATEGORY ===
        "source": `${categoryType}_category`,
        "category": categoryType,
        "categoryID": categoryType,
        "categoryType": categoryType,

        // === TIMESTAMPS & FLAGS ===
        "createdAt": new Date().toISOString(),
        "syncedFromCategory": true,
        "autoGeneratedFromAnnouncement": true,
        "uploadedViaFlutter": false,

        // === CATEGORY-SPECIFIC METADATA ===
        ...getCategorySpecificMetadata(categoryType, extractedData),
      };

      // Store in Pinecone with retry
      let stored = false;
      retries = 3;

      while (retries > 0 && !stored) {
        try {
          await storePineconeVector(chunk.id, embedding, metadata);
          stored = true;
        } catch (error: any) {
          retries--;

          if (retries > 0) {
            const waitTime = (4 - retries) * 2000;
            await new Promise((resolve) => setTimeout(resolve, waitTime));
          } else {
            throw new Error(`Pinecone storage failed after 3 attempts: ${error.message}`);
          }
        }
      }

      chunkIds.push(chunk.id);
      if (i === 0) parentPineconeId = chunk.id;
    }

    // ============================================================================
    // STEP 6: Save to Firestore (matching Flutter structure)
    // ============================================================================

    const firestoreData = {
      "ibID": infoBankId,
      "id": infoBankId,
      "originalId": documentId,
      "ib_title": title,
      "title": title,
      "content": textContent,
      "source": `${categoryType}_category`,
      "category": categoryType,
      "categoryID": categoryType,
      "categoryType": categoryType,
      "categoryDocumentId": documentId,
      "announcementId": documentId,
      "pinecone_id": parentPineconeId,
      "totalChunks": chunks.length,
      "chunkIds": chunkIds,
      "chunked": chunks.length > 1,
      "chunkSize": 1000,
      "chunkOverlap": 200,
      "syncedFromCategory": true,
      "autoGeneratedFromAnnouncement": true,
      "uploadedViaFlutter": false,
      "createdAt": admin.firestore.FieldValue.serverTimestamp(),
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),

      ...(categoryType === "admission" && extractedData.type && {
        "admissionType": extractedData.type,
        "testType": extractedData.type,
      }),
    };

    await db.collection("information_bank").doc(infoBankId).set(firestoreData);
  } catch (error: any) {
    const totalElapsed = Date.now() - functionStart;


    // Log to Firestore error collection for tracking
    try {
      await db.collection("info_bank_errors").add({
        categoryType,
        documentId,
        infoBankId: `${categoryType}_${documentId}`,
        errorType: error.constructor.name,
        errorMessage: error.message,
        errorStack: error.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        extractedDataKeys: extractedData ? Object.keys(extractedData) : [],
        functionDuration: totalElapsed,
      });
    } catch (logError: any) {
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
      academicYear: data.academicYear ?
        JSON.stringify(data.academicYear) :
        null,
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

    const proposedChunk = currentChunk ?
      `${currentChunk}. ${trimmedSentence}` :
      trimmedSentence;

    if (proposedChunk.length > maxChunkSize && currentChunk) {
      chunks.push({
        id: generateChunkId(),
        text: currentChunk.trim(),
      });

      // Start new chunk with overlap
      const overlapText = getOverlapText(currentChunk, chunkOverlap);
      currentChunk = overlapText ?
        `${overlapText}. ${trimmedSentence}` :
        trimmedSentence;
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
  const PINECONE_KEY = PINECONE_API_KEY.value();
  const PINECONE_URL = PINECONE_HOST.value();


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
  }

  try {
    const response = await axios.post(
      `${PINECONE_URL}/vectors/upsert`,
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
          "Accept": "application/json",
        },
        timeout: 30000,
        validateStatus: (status) => status < 500,
      }
    );

    if (response.status !== 200) {
      throw new Error(
        `Pinecone API returned status ${response.status}: ${JSON.stringify(
          response.data
        )}`
      );
    }
  } catch (error: any) {
    if (error.response) {
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
      throw new HttpsError("internal", error.message);
    }
  }
);

export const cleanupDeletedAnnouncement = functions
  .region("asia-southeast1")
  .firestore
  .document("announcements/{postId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const postId = context.params.postId;

    if (!before || !after) return;


    if (!before.deleted && after.deleted) {
      const category = after.category?.toLowerCase() || "";


      await softDeleteCategoryDocument(postId, category);


      if (after.stored_in_storage) {
        try {
          const bucket = storage.bucket();
          const [files] = await bucket.getFiles({
            prefix: `announcements/${postId}`,
          });

          for (const file of files) {
            await file.delete();
          }
        } catch {
        }
      }
    }
  });
// ============================================================================

// ============================================================================

async function processPost(
  post: FacebookPost,
  cohereKey: string
): Promise<void> {
  const postId = post.id;
  const originalMessage = post.message || "";


  const postRef = db.collection("announcements").doc(postId);
  const doc = await postRef.get();

  // Extract image URLs from the Facebook post
  const allImageUrls = extractAllImagesFromPost(post);


  if (doc.exists) {
    const docData = doc.data()!;

    if (docData?.deleted === true) {
      return;
    }


    const alreadyStoredImages: string[] = (docData?.images || []).filter(
      (url: string) =>
        typeof url === "string" &&
        url.includes("firebasestorage.googleapis.com")
    );

    const messageUnchanged = originalMessage === (docData?.message || "");
    const imagesAlreadyStored = alreadyStoredImages.length > 0 &&
      alreadyStoredImages.length >= allImageUrls.length;
    const permalinkUnchanged =
      (post.permalink_url || "") === (docData?.permalink_url || "");


    if (messageUnchanged && imagesAlreadyStored && permalinkUnchanged) {
      // Still check if category doc or info bank is missing
      const category = docData?.category?.toLowerCase() || "";
      if (["admission", "scholarship", "placement"].includes(category)) {
        const categoryDoc = await db
          .collection(`${category}s`)
          .doc(postId)
          .get();
        const infoBankId = `${category}_${postId}`;
        const infoBankDoc = await db
          .collection("information_bank")
          .doc(infoBankId)
          .get();

        if (!categoryDoc.exists || !infoBankDoc.exists) {
          const messageForAnalysis = docData?.ocr_text ?
            `${originalMessage}\n\n[Text from images]:\n${docData.ocr_text}` :
            originalMessage;

          await createCategoryAndInfoBank(
            postId,
            category.charAt(0).toUpperCase() + category.slice(1),
            messageForAnalysis,
            docData?.deadline || null,
            cohereKey,
            docData?.ocr_text || "",
            allImageUrls.length
          );
        } else {
        }
      }
      return;
    }


    let uploadedImageUrls: string[] = alreadyStoredImages;

    if (!imagesAlreadyStored && allImageUrls.length > 0) {
      uploadedImageUrls = await downloadAndUploadAllImages(
        allImageUrls,
        postId
      );
    } else {
    }


    const combinedOcrText = docData?.ocr_text || "";


    const updatePayload: Record<string, any> = {
      last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (!messageUnchanged) {
      updatePayload.message = originalMessage;
    }

    if (!permalinkUnchanged) {
      updatePayload.permalink_url = post.permalink_url || "";
    }

    if (!imagesAlreadyStored && uploadedImageUrls.length > 0) {
      updatePayload.images = uploadedImageUrls;
      updatePayload.image_count = uploadedImageUrls.length;
      updatePayload.full_picture = uploadedImageUrls[0] || "";
      updatePayload.stored_in_storage = true;
    }

    await postRef.update(updatePayload);


    const category = docData?.category?.toLowerCase() || "";
    if (["admission", "scholarship", "placement"].includes(category)) {
      const categoryDoc = await db
        .collection(`${category}s`)
        .doc(postId)
        .get();
      const infoBankId = `${category}_${postId}`;
      const infoBankDoc = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      const needsCategoryDoc = !categoryDoc.exists;
      const needsInfoBank = !infoBankDoc.exists;


      if (needsCategoryDoc || needsInfoBank) {
        const messageForAnalysis = originalMessage;

        await createCategoryAndInfoBank(
          postId,
          category.charAt(0).toUpperCase() + category.slice(1),
          messageForAnalysis,
          docData?.deadline || null,
          cohereKey,
          combinedOcrText,
          allImageUrls.length
        );
      } else {
      }
    }

    return;
  }


  const combinedOcrText = "";
  const hasImageText = false;
  const messageForAnalysis = originalMessage;

  if (!messageForAnalysis || messageForAnalysis.trim().length === 0) {
    return;
  }


  let uploadedImageUrls: string[] = [];
  if (allImageUrls.length > 0) {
    uploadedImageUrls = await downloadAndUploadAllImages(allImageUrls, postId);
  }

  const cohereResult = await analyzeAnnouncement(
    messageForAnalysis,
    cohereKey
  );
  const deadlineTimestamp = parseDeadlineToTimestamp(cohereResult.deadline);

  await postRef.set({
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
    ocr_processed_count: 0,
    ocr_success_count: 0,
    total_image_count: allImageUrls.length,
    ocr_skipped_by_settings: allImageUrls.length > 0,
  });


  await createCategoryAndInfoBank(
    postId,
    cohereResult.category,
    messageForAnalysis,
    deadlineTimestamp,
    cohereKey,
    combinedOcrText,
    allImageUrls.length
  );
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
  const settings = await getAutoCreateSettings();
  const categoryLower = category.toLowerCase() as "admission" | "scholarship" | "placement";

  if (!settings.enabled) {
    return;
  }

  if (
    ["admission", "scholarship", "placement"].includes(categoryLower) &&
    !settings.categories[categoryLower]
  ) {
    return;
  }

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
    } else if (categoryLower === "scholarship") {
      await createScholarshipFromAnnouncement(
        postId,
        messageForAnalysis,
        deadlineTimestamp,
        cohereKey,
        ocrText,
        imageCount
      );
    } else if (categoryLower === "placement") {
      await createPlacementFromAnnouncement(
        postId,
        messageForAnalysis,
        deadlineTimestamp,
        cohereKey,
        ocrText,
        imageCount
      );
    }
  } catch (categoryError: any) {
    try {
      await db.collection("category_creation_errors").add({
        postId,
        category: categoryLower,
        errorMessage: categoryError.message,
        errorStack: categoryError.stack,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch {
    }

    throw categoryError;
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
    }
  } catch {
  }
}

// ============================================================================
// EXPORTED FUNCTIONS
// ============================================================================


export const reprocessExistingAnnouncements = onCall(
  {
    cors: true,
    timeoutSeconds: 540,
    secrets: [COHERE_API_KEY, GEMINI_API_KEY],
  },
  async (request) => {
    try {
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
          } catch (e) {
            failed++;
          }
        }
      }


      return {
        success: true,
        message: `Reprocessed ${processed} announcements, ${failed} failed`,
        processed,
        failed,
      };
    } catch (error: any) {
      throw new HttpsError("internal", error.message);
    }
  }
);

function generateToken(): string {
  return (
    Math.random().toString(36).substring(2) +
    Math.random().toString(36).substring(2) +
    Date.now().toString(36)
  );
}

async function syncCategoryToInfoBank(
  categoryType: "admission" | "scholarship" | "placement",
  documentId: string,
  cohereKey: string,
  config: CategoryToInfoBankConfig = {
    includeInSearch: true,
    autoSync: true,
    generateSummary: true,
  }
): Promise<void> {
  try {
    // Fetch the category document
    const categoryDoc = await db.collection(`${categoryType}s`).doc(documentId).get();

    if (!categoryDoc.exists) {
      return;
    }

    const categoryData = categoryDoc.data()!;

    // Skip if deleted
    if (categoryData.deleted === true) {
      return;
    }

    // Convert category data to searchable text content
    const textContent = formatCategoryAsText(categoryType, categoryData);

    // Generate title for Information Bank
    const title = generateInfoBankTitle(categoryType, categoryData);

    // Split into chunks (for long content)
    const chunks = splitIntoChunks(textContent, title, `${categoryType}_category`);

    // Generate embeddings and store in Pinecone
    const chunkIds: string[] = [];
    let parentPineconeId: string | null = null;

    for (let i = 0; i < chunks.length; i++) {
      const chunk = chunks[i];

      // Generate embedding using Gemini
      const embeddingResponse = await axios.post(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=" + GEMINI_API_KEY.value(),
        {
          model: "gemini-embedding-001",
          content: {
            parts: [
              {text: chunk.text},
            ],
          },
        },
        {
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      //   Handle correct Gemini API response structure
      const responseData = embeddingResponse.data as any;
      await logGeminiUsage({
        userId: null,
        conversationId: null,
        model: "gemini-embedding-001",
        inputTokens: responseData?.usageMetadata?.promptTokenCount ?? Math.ceil(chunk.text.length / 4),
        outputTokens: 0,
      }).catch(() => undefined);
      let embedding: number[] | null = null;

      if (responseData?.embedding?.values && Array.isArray(responseData.embedding.values)) {
        embedding = responseData.embedding.values;
      } else if (responseData?.embeddings?.[0]?.values && Array.isArray(responseData.embeddings[0].values)) {
        embedding = responseData.embeddings[0].values;
      } else if (Array.isArray(responseData?.values)) {
        embedding = responseData.values;
      }

      if (!embedding || embedding.length === 0) {
        throw new Error("Invalid embedding response from Gemini API");
      }

      const chunkTitle = chunks.length > 1 ?
        `${title} (Part ${i + 1}/${chunks.length})` :
        title;


      const metadata = {
        // === DOCUMENT IDENTIFICATION ===
        "docId": documentId,
        "originalDocId": documentId,
        "documentId": documentId,
        "categoryDocId": documentId, // Link back to category document

        // === CONTENT ===
        "text": chunk.text,
        "content": chunk.text,

        // === TITLES ===
        "title": chunkTitle,
        "originalTitle": title,
        "fileName": title,

        // === CHUNKING INFO ===
        "chunkIndex": i,
        "chunk_index": i,
        "totalChunks": chunks.length,
        "chunkCount": chunks.length,
        "isFirstChunk": i === 0,
        "isLastChunk": i === chunks.length - 1,

        // === SOURCE & CATEGORY ===
        "source": `${categoryType}_category`,
        "category": categoryType,
        "categoryID": categoryType,
        "categoryType": categoryType, // admission, scholarship, or placement

        // === ADDITIONAL METADATA ===
        "chunkSize": chunk.text.length,
        "createdAt": new Date().toISOString(),
        "syncedFromCategory": true,

        // === CATEGORY-SPECIFIC DATA ===
        ...(categoryType === "admission" && {
          "academicYear": categoryData.academicYear || null,
          "hasSchedules": (categoryData.schedules?.length || 0) > 0,
          "scheduleCount": categoryData.schedules?.length || 0,
        }),
        ...(categoryType === "scholarship" && {
          "scholarshipProvider": categoryData.scholarshipProvider || "",
          "hasDeadline": !!categoryData.deadline,
        }),
        ...(categoryType === "placement" && {
          "partnerCompany": categoryData.partnerCompany || "",
          "isRecruiting": categoryData.isRecruiting || false,
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
    }

    // Save to Information Bank collection
    const infoBankId = `${categoryType}_${documentId}`;
    await db.collection("information_bank").doc(infoBankId).set({
      "ibID": infoBankId,
      "id": infoBankId,
      "ib_title": title,
      "title": title,
      "content": textContent,
      "source": `${categoryType}_category`,
      "category": categoryType,
      "categoryID": categoryType,
      "categoryType": categoryType,
      "categoryDocumentId": documentId, // Link to original category document
      "pinecone_id": parentPineconeId,
      "totalChunks": chunks.length,
      "chunkIds": chunkIds,
      "chunked": chunks.length > 1,
      "chunkSize": 1000, // maxChunkSize
      "chunkOverlap": 200, // chunkOverlap
      "syncedFromCategory": true,
      "createdAt": admin.firestore.FieldValue.serverTimestamp(),
      "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
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
      buffer.push("JOB PLACEMENT INFORMATION\n");
      buffer.push(`Company: ${data.partnerCompany || "Unknown"}\n`);
      buffer.push(
        `Status: ${
          data.isRecruiting ?
            "Currently Recruiting" :
            "Not Currently Recruiting"
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


    if (result.length === 0) {
      throw new Error("Formatted content is empty after processing");
    }

    return result;
  } catch (error: any) {
    throw error;
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

      const {announcementId} = request.data;

      if (!announcementId) {
        throw new HttpsError("invalid-argument", "announcementId is required");
      }


      // Get announcement
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

      // Prepare extracted data
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
      } else if (category === "scholarship") {
        extractedData = {
          name: categoryData.name || "Scholarship Information",
          description: categoryData.description || "",
          scholarshipProvider: categoryData.scholarshipProvider || "",
          eligibilityRequirements: categoryData.eligibilityRequirements || [],
          privileges: categoryData.privileges || [],
          applicationLink: categoryData.applicationLink || "",
        };
      } else if (category === "placement") {
        extractedData = {
          partnerCompany: categoryData.partnerCompany || "Company",
          positions: categoryData.positions || [],
          contacts: categoryData.contacts || [],
          isRecruiting: categoryData.isRecruiting !== false,
        };
      }

      // Check if Information Bank entry already exists
      const infoBankId = `${category}_${announcementId}`;
      const existingInfoBank = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (existingInfoBank.exists) {
        await db.collection("information_bank").doc(infoBankId).delete();
      }

      // Create Information Bank entry
      await createInfoBankFromCategory(
        announcementId,
        category as "admission" | "scholarship" | "placement",
        extractedData,
        COHERE_API_KEY.value()
      );

      // Verify creation
      const verifyInfoBank = await db
        .collection("information_bank")
        .doc(infoBankId)
        .get();

      if (!verifyInfoBank.exists) {
        throw new Error("Information Bank entry was not created");
      }

      const infoBankData = verifyInfoBank.data()!;

      const result = {
        success: true,
        message: "Information Bank entry created successfully",
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


      return result;
    } catch (error: any) {
      throw new HttpsError("internal", `Test failed: ${error.message}`, {
        originalError: error.toString(),
      });
    }
  }
);

// ============================================================================

// ============================================================================

export const listInfoBankEntries = onCall(
  {cors: true, secrets: []},
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }


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


      return {
        success: true,
        count: entries.length,
        entries: entries.sort((a, b) =>
          (b.createdAt || "").localeCompare(a.createdAt || "")
        ),
      };
    } catch (error: any) {
      throw new HttpsError("internal", error.message);
    }
  }
);

// ============================================================================

// ============================================================================

export const deleteInfoBankEntry = onCall(
  {cors: true, secrets: []},
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const {infoBankId} = request.data;

      if (!infoBankId) {
        throw new HttpsError("invalid-argument", "infoBankId is required");
      }


      const doc = await db.collection("information_bank").doc(infoBankId).get();

      if (!doc.exists) {
        throw new HttpsError("not-found", `Entry ${infoBankId} not found`);
      }

      const data = doc.data()!;
      const chunkIds = data.chunkIds || [];


      // TODO: Delete Pinecone vectors (requires Pinecone service)
      // await pineconeService.deleteVectors(chunkIds);

      await doc.ref.delete();


      return {
        success: true,
        message: `Deleted entry ${infoBankId}`,
        deletedChunks: chunkIds.length,
      };
    } catch (error: any) {
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


      const pineconeKey = PINECONE_API_KEY.value();
      const pineconeUrl = PINECONE_HOST.value();

      let totalFixed = 0;
      let totalSkipped = 0;
      let totalFailed = 0;

      // Get all announcement-based Info Bank entries
      const infoBankSnapshot = await db
        .collection("information_bank")
        .where("syncedFromCategory", "==", true)
        .get();


      for (const doc of infoBankSnapshot.docs) {
        const data = doc.data();
        const infoBankId = doc.id;
        const categoryType = data.categoryType as "admission" | "scholarship" | "placement";
        const documentId = data.categoryDocumentId || data.announcementId;


        if (!categoryType || !documentId) {
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
            totalSkipped++;
            continue;
          }

          const categoryData = categoryDoc.data()!;

          // Get existing chunks
          const chunkIds = data.chunkIds || [];

          if (chunkIds.length === 0) {
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
              "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=" + GEMINI_API_KEY.value(),
              {
                model: "gemini-embedding-001",
                content: {
                  parts: [
                    {text: chunk.text},
                  ],
                },
              },
              {
                headers: {
                  "Content-Type": "application/json",
                },
              }
            );

            const responseData = embeddingResponse.data as any;
            await logGeminiUsage({
              userId: null,
              conversationId: null,
              model: "gemini-embedding-001",
              inputTokens: responseData?.usageMetadata?.promptTokenCount ?? Math.ceil(chunk.text.length / 4),
              outputTokens: 0,
            }).catch(() => undefined);
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

            const chunkTitle = chunks.length > 1 ?
              `${title} (Part ${i + 1}/${chunks.length})` :
              title;


            const metadata = {
              // Primary identifiers
              "docId": documentId,
              "originalDocId": documentId,
              "documentId": documentId,
              "categoryDocId": documentId,

              // Content
              "text": chunk.text,
              "content": chunk.text,

              // Titles
              "title": chunkTitle,
              "originalTitle": title,
              "fileName": title,

              // Chunking info
              "chunkIndex": i,
              "chunk_index": i,
              "totalChunks": chunks.length,
              "chunkCount": chunks.length,
              "chunkSize": chunk.text.length,
              "isFirstChunk": i === 0,
              "isLastChunk": i === chunks.length - 1,

              // Source & category
              "source": `${categoryType}_category`,
              "category": categoryType,
              "categoryID": categoryType,
              "categoryType": categoryType,

              // Timestamps & flags
              "createdAt": new Date().toISOString(),
              "syncedFromCategory": true,
              "autoGeneratedFromAnnouncement": true,

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
                }],
              },
              {
                headers: {
                  "Api-Key": pineconeKey,
                  "Content-Type": "application/json",
                },
                timeout: 30000,
              }
            );

            console.log(`      ✓ Updated chunk ${i + 1}/${chunks.length}`);
          }

          // Update Firestore document
          await db.collection("information_bank").doc(infoBankId).update({
            "content": textContent,
            "ib_title": title,
            "title": title,
            "totalChunks": chunks.length,
            "updatedAt": admin.firestore.FieldValue.serverTimestamp(),
            "metadataFixed": true,
            "fixedAt": admin.firestore.FieldValue.serverTimestamp(),
          });

          totalFixed++;
          console.log(`   ✅ Fixed ${chunkIds.length} chunks`);
        } catch (error: any) {
          totalFailed++;
          console.error(`   ❌ Failed: ${error.message}`);

          // Log error
          await db.collection("info_bank_fix_errors").add({
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

      console.log("\n🔧 ========================================");
      console.log("🔧 FIX COMPLETE");
      console.log(`🔧 Fixed: ${totalFixed}`);
      console.log(`🔧 Skipped: ${totalSkipped}`);
      console.log(`🔧 Failed: ${totalFailed}`);
      console.log("🔧 ========================================\n");

      return summary;
    } catch (error: any) {
      console.error("\n❌ ========================================");
      console.error("❌ FIX OPERATION FAILED");
      console.error(`❌ Error: ${error.message}`);
      console.error("❌ ========================================\n");

      throw new HttpsError("internal", error.message);
    }
  }
);
