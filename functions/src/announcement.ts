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

  // interface AnnouncementData {
  //   announcementId: string; // ✅ Unique ID field
  //   message: string;
  //   created_time: string;
  //   full_picture: string;
  //   original_image_url: string;
  //   permalink_url: string;
  //   category: string;
  //   deadline: admin.firestore.Timestamp | null;
  //   deleted: boolean; // ✅ Soft delete flag
  //   fetched_at: admin.firestore.FieldValue;
  //   processed_by_cohere: boolean;
  //   stored_in_storage: boolean;
  //   notification_sent: boolean;
  //   ocr_text?: string;
  //   has_image_text: boolean;
  // }

  // ============================================================================
  // ✅ NEW: OCR FUNCTIONS FOR IMAGE TEXT EXTRACTION
  // ============================================================================

  /**
   * Extract text from image using Google Cloud Vision API
   */

  function normalizeImageUrl(url: string): string {
  try {
    const parsed = new URL(url);
    // Remove tracking params and get base image path
    // Facebook URLs often have different query params for same image
    const pathParts = parsed.pathname.split('/');
    // Get the image identifier (usually last meaningful segment)
    const imageId = pathParts.filter(p => p && !p.includes('_n') && p.length > 10).pop();
    return imageId || parsed.pathname;
  } catch {
    return url;
  }
}

  function extractAllImagesFromPost(post: FacebookPost): string[] {
  const images: string[] = [];
  const seenNormalized = new Set<string>();
  
  const addImage = (url: string) => {
    if (!url) return;
    const normalized = normalizeImageUrl(url);
    if (!seenNormalized.has(normalized)) {
      seenNormalized.add(normalized);
      images.push(url);
    }
  };
  
  // Extract from attachments FIRST (higher quality)
  if (post.attachments?.data) {
    for (const attachment of post.attachments.data) {
      // Multiple images (subattachments - album/carousel)
      if (attachment.subattachments?.data) {
        for (const sub of attachment.subattachments.data) {
          if (sub.media?.image?.src) {
            addImage(sub.media.image.src);
          }
        }
      }
      // Single image attachment
      else if (attachment.media?.image?.src) {
        addImage(attachment.media.image.src);
      }
    }
  }
  
  // Only add full_picture if we found NO images from attachments
  // (full_picture is usually a lower-res preview)
  if (images.length === 0 && post.full_picture) {
    addImage(post.full_picture);
  }
  
  console.log(`📸 Found ${images.length} unique image(s) in post`);
  return images;
}

function deduplicateOcrResults(ocrResults: string[]): string {
  const uniqueTexts: string[] = [];
  const seenNormalized = new Set<string>();
  
  for (const text of ocrResults) {
    // Normalize: lowercase, remove extra whitespace, remove special chars
    const normalized = text.toLowerCase()
      .replace(/\s+/g, ' ')
      .replace(/[^a-z0-9\s]/g, '')
      .trim();
    
    // Skip if we've seen very similar text (>80% overlap)
    let isDuplicate = false;
    for (const seen of seenNormalized) {
      if (similarity(normalized, seen) > 0.8) {
        isDuplicate = true;
        break;
      }
    }
    
    if (!isDuplicate && normalized.length > 20) {
      seenNormalized.add(normalized);
      uniqueTexts.push(text);
    }
  }
  
  return uniqueTexts.join('\n\n---\n\n');
}

function similarity(a: string, b: string): number {
  const wordsA = new Set(a.split(' '));
  const wordsB = new Set(b.split(' '));
  const intersection = [...wordsA].filter(w => wordsB.has(w)).length;
  const union = new Set([...wordsA, ...wordsB]).size;
  return union > 0 ? intersection / union : 0;
}

  async function downloadAndUploadAllImages(
    imageUrls: string[],
    postId: string
  ): Promise<string[]> {
    const uploadedUrls: string[] = [];
    
    for (let i = 0; i < imageUrls.length; i++) {
      const imageUrl = imageUrls[i];
      try {
        console.log(`📥 Downloading image ${i + 1}/${imageUrls.length} for post ${postId}`);
        
        const response = await axios.get(imageUrl, {
          responseType: "arraybuffer",
          timeout: 30000,
          headers: { 'User-Agent': 'Mozilla/5.0 (compatible; OASP-Bot/1.0)' },
        } as any);
        
        const buffer = Buffer.from(response.data as Buffer);
        const contentType = response.headers["content-type"] || "image/jpeg";
        const ext = contentType.split("/")[1]?.split(';')[0] || "jpg";
        
        // Use index suffix for multiple images
        const fileName = imageUrls.length > 1 
          ? `announcements/${postId}_${i}.${ext}`
          : `announcements/${postId}.${ext}`;
        
        const bucket = storage.bucket();
        const file = bucket.file(fileName);
        
        await file.save(buffer, {
          metadata: {
            contentType,
            cacheControl: 'public, max-age=31536000',
            metadata: { postId, imageIndex: i.toString() },
          },
          public: true,
        });
        
        const [signedUrl] = await file.getSignedUrl({
          action: 'read',
          expires: '03-01-2500',
        });
        
        uploadedUrls.push(signedUrl);
        console.log(`✅ Uploaded image ${i + 1}: ${fileName}`);
        
      } catch (error: any) {
        console.error(`❌ Error uploading image ${i + 1} for post ${postId}:`, error.message);
        // Still add original URL as fallback
        uploadedUrls.push(imageUrl);
      }
    }
    
    return uploadedUrls;
  }

  function extractSchedulesFromOCR(ocrText: string): ScheduleEntry[] {
  const schedules: ScheduleEntry[] = [];
  const lines = ocrText.split('\n').map(l => l.trim()).filter(Boolean);
  
  // Pattern for dates like "OCT 26", "NOV 8", etc.
  const datePattern = /^(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)\s*(\d{1,2})$/i;
  const dayPattern = /^(SUNDAY|MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY)$/i;
  const yearPattern = /^(20\d{2})$/;
  const timePattern = /(\d{1,2}(?::\d{2})?\s*(?:am|pm))/gi;
  
  // ✅ NEW: Filter out header/common text that appears on all images
  const headerKeywords = [
    'central mindanao university',
    'academic paradise',
    'cmucat schedule',
    'the academic paradise of the south'
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
    if (headerKeywords.some(keyword => lineLower.includes(keyword))) {
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
    if (timeMatches && (line.includes('|') || line.includes('-'))) {
      currentTime = line; // e.g., "9-11 am | 1-3 pm"
      continue;
    }
    
    // ✅ ENHANCED: Better location detection
    // Check for locations (contains city/place names)
    const locationKeywords = [
      'campus', 'city', 'butuan', 'surigao', 'gingoog', 'bayugan',
      'university', 'in-campus', 'agusan', 'davao', 'kalilangan',
      'impasug', 'quezon', 'malaybalay', 'san francisco', 'elpa',
      'tandag', 'luna', 'kapalong', 'norte', 'sur', 'del norte',
      'del sur', 'zamboanga', 'ozamiz', 'misamis', 'occidental',
      'oriental', 'pagadian', 'lapasan', 'national high school',
      'nhs', 'cagayan de oro', 'college'
    ];
    
    const isLocation = locationKeywords.some(keyword => lineLower.includes(keyword));
    
    // ✅ Exclude if it's just "In-Campus" without more specific info
    const isGenericInCampus = lineLower === 'in-campus' || 
                               (lineLower.includes('in-campus') && 
                                lineLower.includes('central mindanao'));
    
    if (isLocation && !isGenericInCampus) {
      // Clean up location
      let location = line.replace(/[()]/g, ' ').trim();
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
    console.log(`   ${i + 1}. ${s.date} (${s.dayOfWeek}): ${s.locations.join(', ')}`);
  });
  
  return schedules;
}


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

  // async function downloadAndUploadImage(
  //   imageUrl: string,
  //   postId: string
  // ): Promise<string> {
  //   try {
  //     console.log(`📥 Downloading image for post ${postId}`);
  //     console.log(`🔗 Source URL: ${imageUrl.substring(0, 100)}...`);
      
  //     const response = await axios.get(imageUrl, {
  //       responseType: "arraybuffer",
  //       timeout: 30000,
  //       maxBodyLength: 50 * 1024 * 1024,
  //       headers: {
  //         'User-Agent': 'Mozilla/5.0 (compatible; OASP-Bot/1.0)',
  //       },
  //     } as any);
      
  //     const buffer = Buffer.from(response.data as Buffer);
  //     const contentType = response.headers["content-type"] || "image/jpeg";
      
  //     console.log(`📊 Image size: ${(buffer.length / 1024 / 1024).toFixed(2)} MB`);
  //     console.log(`📊 Content type: ${contentType}`);
      
  //     if (!contentType.startsWith('image/')) {
  //       throw new Error(`Invalid content type: ${contentType}`);
  //     }
      
  //     const ext = contentType.split("/")[1]?.split(';')[0] || "jpg";
  //     const fileName = `announcements/${postId}.${ext}`;
      
  //     const bucket = storage.bucket();
  //     const file = bucket.file(fileName);
      
  //     console.log(`⬆️ Uploading to: ${fileName}`);
      
  //     await file.save(buffer, {
  //       metadata: {
  //         contentType: contentType,
  //         cacheControl: 'public, max-age=31536000',
  //         metadata: {
  //           postId: postId,
  //           uploadedAt: new Date().toISOString(),
  //           originalUrl: imageUrl.substring(0, 500),
  //         },
  //       },
  //       public: true,
  //     });
      
  //     const [signedUrl] = await file.getSignedUrl({
  //       action: 'read',
  //       expires: '03-01-2500',
  //     });
      
  //     console.log(`✅ Image uploaded successfully`);
  //     console.log(`🔗 Signed URL: ${signedUrl.substring(0, 100)}...`);
      
  //     return signedUrl;
      
  //   } catch (error: any) {
  //     console.error(`❌ Error uploading image for post ${postId}:`, error.message);
      
  //     if (error.response) {
  //       console.error(`❌ HTTP Status: ${error.response.status}`);
  //       console.error(`❌ Response data:`, error.response.data);
  //     }
      
  //     if (error.code === 'ECONNABORTED') {
  //       console.error(`❌ Download timeout for ${postId}`);
  //     }
      
  //     return "";
  //   }
  // }

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

 async function extractAdmissionData(
  message: string, 
  cohereKey: string,
  ocrText?: string,
  imageCount?: number
): Promise<ExtractedAdmissionData> {
  let extractedSchedules: ScheduleEntry[] = [];
  if (ocrText) {
    extractedSchedules = extractSchedulesFromOCR(ocrText);
    console.log(`📅 Extracted ${extractedSchedules.length} schedules from ${imageCount || 0} image(s)`);
  }
  
  try {
    const prompt = `Extract admission information from this announcement. The content includes text from ${imageCount || 0} schedule images. Return ONLY valid JSON.

Announcement: "${message}"
${ocrText ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` : ''}

CRITICAL INSTRUCTIONS FOR SCHEDULES:
1. Ignore generic header text like "Central Mindanao University" and "CMUCAT Schedule"
2. Extract SPECIFIC location information for EACH date
3. Look for city names, school names, and venue details
4. For "In-Campus" entries, include the time information
5. Each date can have MULTIPLE locations - list them all
6. Format: {"date": "OCT 4", "dayOfWeek": "SATURDAY", "year": "2025", "locations": ["Kalilangan, Bukidnon", "Impasug-ong, Bukidnon"], "time": ""}

Examples of what to extract:
- "OCT 4 SATURDAY" with "Kalilangan, Bukidnon" and "Impasug-ong, Bukidnon" → 2 separate locations
- "NOV 8 SATURDAY" with "Butuan, Agusan del Norte" and "Surigao, Surigao del Norte" → 2 separate locations  
- "OCT 26 SUNDAY In-Campus (Central Mindanao University) 9-11 am | 1-3 pm" → location: "In-Campus (Central Mindanao University)", time: "9-11 am | 1-3 pm"

Extract these fields:
- title: A short descriptive title (max 100 chars)
- content: The full announcement content including image text
- steps: Array of enrollment/application steps
- requirements: Array of required documents (extract from BOTH text and images)
- contacts: Array of contact information (extract from BOTH text and images)
- academicYear: Object {"start": 2026, "end": 2027}
- schedules: Array of schedule objects with SPECIFIC locations for each date

Respond ONLY in this JSON format:
{
  "title": "CMUCAT Schedule AY 2026-2027",
  "content": "string with image text",
  "steps": ["step1", "step2"],
  "requirements": ["req1", "req2"],
  "contacts": ["contact1", "email@example.com"],
  "academicYear": {"start": 2026, "end": 2027},
  "schedules": [
    {"date": "OCT 4", "dayOfWeek": "SATURDAY", "year": "2025", "locations": ["Kalilangan, Bukidnon", "Impasug-ong, Bukidnon"], "time": ""},
    {"date": "OCT 11", "dayOfWeek": "SATURDAY", "year": "2025", "locations": ["Quezon, Bukidnon", "Malaybalay City, Bukidnon"], "time": ""},
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

    let finalSchedules = result.schedules || [];
    if (finalSchedules.length < extractedSchedules.length) {
      console.log(`⚠️ Using OCR schedules: ${extractedSchedules.length} vs Cohere: ${finalSchedules.length}`);
      finalSchedules = extractedSchedules;
    }
    
    let enhancedContent = result.content || message;
    if (ocrText && !enhancedContent.includes(ocrText.substring(0, 50))) {
      enhancedContent = `${message}\n\n[Information from ${imageCount || 0} image(s)]:\n${ocrText}`;
    }

    return {
      title: result.title || message.substring(0, 100),
      content: enhancedContent,
      steps: Array.isArray(result.steps) ? result.steps : [],
      requirements: Array.isArray(result.requirements) ? result.requirements : [],
      contacts: Array.isArray(result.contacts) ? result.contacts : [],
      academicYear: result.academicYear || null,
      schedules: finalSchedules,
    };
  } catch (error) {
    console.error("Error extracting admission data:", error);
    return {
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
    const prompt = `Extract scholarship information from this announcement. Content may include text from ${imageCount || 0} image(s). Return ONLY valid JSON.

Announcement: "${message}"
${ocrText ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` : ''}

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

    // ✅ Enhance description with OCR text
    let enhancedDescription = result.description || message;
    if (ocrText && !enhancedDescription.includes(ocrText.substring(0, 50))) {
      enhancedDescription = `${result.description || message}\n\n[Details from ${imageCount || 0} image(s)]:\n${ocrText}`;
    }

    return {
      name: result.name || "Scholarship Announcement",
      description: enhancedDescription,
      scholarshipProvider: result.scholarshipProvider || "",
      eligibilityRequirements: Array.isArray(result.eligibilityRequirements) ? result.eligibilityRequirements : [],
      privileges: Array.isArray(result.privileges) ? result.privileges : [],
      applicationLink: result.applicationLink || "",
    };
  } catch (error) {
    console.error("Error extracting scholarship data:", error);
    return {
      name: "Scholarship Announcement",
      description: ocrText ? `${message}\n\n[Image Text]:\n${ocrText}` : message,
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
    const prompt = `Extract job placement/hiring information from this announcement. Content may include text from ${imageCount || 0} image(s). Return ONLY valid JSON.

Announcement: "${message}"
${ocrText ? `\nImage Text (OCR from ${imageCount || 0} image(s)):\n"${ocrText}"` : ''}

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
      console.log(`Admission already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractAdmissionData(message, cohereKey, ocrText, imageCount);

    await admissionRef.set({
      id: postId,
      announcementId: postId,
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
      processedImageCount: imageCount || 0, // ✅ Track how many images were processed
    });

    console.log(`✅ Created admission with ${extractedData.schedules.length} schedules from ${imageCount || 0} images`);
  } catch (error) {
    console.error(`❌ Error creating admission from announcement ${postId}:`, error);
  }
}

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
      
      // ✅ If deleted, don't recreate or restore
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping scholarship for post ${postId} - it was deleted by user`);
        return;
      }
      
      console.log(`Scholarship already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractScholarshipData(message, cohereKey, ocrText, imageCount);

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
      processedImageCount: imageCount || 0, // ✅ Track how many images were processed
    });

    console.log(`✅ Created scholarship from announcement ${postId} (${imageCount || 0} images processed)`);
  } catch (error) {
    console.error(`❌ Error creating scholarship from announcement ${postId}:`, error);
  }
}

// ✅ UPDATED: Placement creation with OCR text and image count
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
      
      // ✅ If deleted, don't recreate or restore
      if (existingData?.deleted === true) {
        console.log(`⏭️ Skipping placement for post ${postId} - it was deleted by user`);
        return;
      }
      
      console.log(`Placement already exists for post ${postId}`);
      return;
    }

    const extractedData = await extractPlacementData(message, cohereKey, ocrText, imageCount);

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
      processedImageCount: imageCount || 0, // ✅ Track how many images were processed
    });

    console.log(`✅ Created placement from announcement ${postId} (${imageCount || 0} images processed)`);
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
  
  const allImageUrls = extractAllImagesFromPost(post);
  console.log(`📸 Post ${postId} has ${allImageUrls.length} image(s)`);
  
  let combinedOcrText = "";
  const ocrResults: string[] = [];
  
  for (let i = 0; i < allImageUrls.length; i++) {
    console.log(`🔍 Running OCR on image ${i + 1}/${allImageUrls.length}...`);
    try {
      const ocrText = await extractTextFromImage(allImageUrls[i]);
      if (ocrText && ocrText.trim().length > 0) {
        ocrResults.push(ocrText);
      }
    } catch (err: any) {
      console.error(`⚠️ OCR failed for image ${i + 1}:`, err.message);
    }
  }
  
  combinedOcrText = deduplicateOcrResults(ocrResults);
  const hasImageText = ocrResults.length > 0;
  
  console.log(`📝 OCR: ${combinedOcrText.length} chars from ${ocrResults.length}/${allImageUrls.length} images`);
  
  let messageForAnalysis = originalMessage;
  if (hasImageText) {
    messageForAnalysis = originalMessage 
      ? `${originalMessage}\n\n[Image Text]:\n${combinedOcrText}`
      : combinedOcrText;
  }
  
  if (!messageForAnalysis || messageForAnalysis.trim().length === 0) {
    console.log(`Skipping post ${postId} - no content`);
    return;
  }
  
  let uploadedImageUrls: string[] = [];
  if (allImageUrls.length > 0) {
    uploadedImageUrls = await downloadAndUploadAllImages(allImageUrls, postId);
  }
  
  if (!doc.exists) {
    console.log(`Creating new post: ${postId} with ${uploadedImageUrls.length} images, ${ocrResults.length} with text`);
    
    const cohereResult = await analyzeAnnouncement(messageForAnalysis, cohereKey);
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
    };
    
    await postRef.set(newData);

    const category = cohereResult.category?.toLowerCase() || "general";
    
    if (category === "admission") {
      await createAdmissionFromAnnouncement(
        postId, 
        messageForAnalysis, 
        deadlineTimestamp, 
        cohereKey,
        combinedOcrText,
        allImageUrls.length
      );
    } else if (category === "scholarship") {
      await createScholarshipFromAnnouncement(
        postId, 
        messageForAnalysis, 
        deadlineTimestamp, 
        cohereKey,
        combinedOcrText,
        allImageUrls.length
      );
    } else if (category === "placement") {
      await createPlacementFromAnnouncement(
        postId, 
        messageForAnalysis, 
        deadlineTimestamp, 
        cohereKey,
        combinedOcrText,
        allImageUrls.length
      );
    }
    
    console.log(`✅ Post ${postId}: ${category}, ${uploadedImageUrls.length} images, ${ocrResults.length} OCR`);
    
  } else {
    const docData = doc.data();
    
    if (docData?.deleted === true) {
      console.log(`⏭️ Skipping deleted post ${postId}`);
      return;
    }
    
    await postRef.update({
      message: originalMessage,
      images: uploadedImageUrls.length > 0 ? uploadedImageUrls : docData?.images || [],
      image_count: uploadedImageUrls.length || docData?.image_count || 0,
      full_picture: uploadedImageUrls[0] || docData?.full_picture || "",
      permalink_url: post.permalink_url || "",
      last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
      stored_in_storage: uploadedImageUrls.length > 0 || docData?.stored_in_storage,
      ocr_text: combinedOcrText || docData?.ocr_text || "",
      has_image_text: hasImageText || docData?.has_image_text,
      ocr_processed_count: ocrResults.length || docData?.ocr_processed_count || 0,
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
  


  
