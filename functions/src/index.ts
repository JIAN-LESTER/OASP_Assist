import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";

// Define secrets
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");
const FB_APP_ID = defineSecret("FB_APP_ID");
const FB_APP_SECRET = defineSecret("FB_APP_SECRET");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

const FB_API_VERSION = "v24.0";

// Configuration
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
// COHERE API UTILITIES
// ============================================================================

async function generateCohereEmbedding(
  text: string,
  apiKey: string,
  inputType: "search_document" | "search_query" = "search_document"
): Promise<number[]> {
  try {
    const response = await axios.post(
      "https://api.cohere.ai/v1/embed",
      {
        texts: [text],
        model: "embed-multilingual-v3.0",
        input_type: inputType,
      },
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      throw new Error(`Cohere Embed API error: ${response.statusText}`);
    }

    const data = response.data as {embeddings: number[][]};
    return data.embeddings[0];
  } catch (error) {
    console.error("Error generating Cohere embedding:", error);
    throw error;
  }
}

async function generateCohereResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  try {
    const response = await axios.post(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-r-08-2024",
        message: prompt,
        max_tokens: 1024,
        temperature: 0.3,
      },
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      throw new Error(`Cohere Chat API error: ${response.statusText}`);
    }

    const data = response.data as {text?: string};
    return data.text || "";
  } catch (error) {
    console.error("Error generating Cohere response:", error);
    throw error;
  }
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

function getContextualContent(chunks: any[], bestChunk: any): string {
  try {
    console.log(`📝 Processing ${chunks.length} chunk(s)`);
    console.log("📝 Best chunk metadata keys:", Object.keys(bestChunk.metadata || {}));

    if (chunks.length === 1) {
      const text =
        bestChunk.metadata?.text ||
        bestChunk.metadata?.content ||
        bestChunk.metadata?.chunk_text ||
        bestChunk.metadata?.body ||
        "";

      if (!text || text.trim().length === 0) {
        console.log("⚠️ Warning: No text content found in metadata");
        console.log("📝 Metadata keys available:", Object.keys(bestChunk.metadata || {}));
      }

      const cleanText = text.trim();
      console.log(`📝 Single chunk content length: ${cleanText.length}`);
      return cleanText;
    }

    const sortedChunks = chunks
      .slice()
      .sort(
        (a, b) =>
          (a.metadata?.chunkIndex ?? a.metadata?.chunk_index ?? 0) -
          (b.metadata?.chunkIndex ?? b.metadata?.chunk_index ?? 0)
      );

    const bestChunkIndex = bestChunk.metadata?.chunkIndex ??
                          bestChunk.metadata?.chunk_index ?? 0;

    const contextChunks = sortedChunks.filter((chunk) => {
      const chunkIndex = chunk.metadata?.chunkIndex ?? chunk.metadata?.chunk_index ?? 0;
      return Math.abs(chunkIndex - bestChunkIndex) <= 1;
    });

    contextChunks.sort(
      (a, b) =>
        (a.metadata?.chunkIndex ?? a.metadata?.chunk_index ?? 0) -
        (b.metadata?.chunkIndex ?? b.metadata?.chunk_index ?? 0)
    );

    const contentParts: string[] = [];
    for (const chunk of contextChunks) {
      const content =
        chunk.metadata?.text ||
        chunk.metadata?.content ||
        chunk.metadata?.chunk_text ||
        chunk.metadata?.body ||
        "";

      const cleanContent = content.trim();
      if (cleanContent.length > 0) {
        contentParts.push(cleanContent);
      } else {
        console.log(`⚠️ Empty content in chunk index ${chunk.metadata?.chunkIndex}`);
      }
    }

    if (contentParts.length === 0) {
      console.log(`❌ No content parts found across ${contextChunks.length} chunks`);
      return "";
    }

    const result = contentParts.join("\n\n").trim();
    console.log(`📝 Combined content length: ${result.length} from ${contentParts.length} chunks`);
    return result;
  } catch (error) {
    console.error("Error getting contextual content:", error);
    const fallback = bestChunk.metadata?.text ||
                     bestChunk.metadata?.content ||
                     "";
    console.log(`📝 Using fallback, length: ${fallback.length}`);
    return fallback;
  }
}

function cosineSimilarity(vecA: number[], vecB: number[]): number {
  if (vecA.length === 0 || vecB.length === 0 || vecA.length !== vecB.length) {
    return 0.0;
  }

  let dotProduct = 0.0;
  let magnitudeA = 0.0;
  let magnitudeB = 0.0;

  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    magnitudeA += vecA[i] * vecA[i];
    magnitudeB += vecB[i] * vecB[i];
  }

  if (magnitudeA === 0 || magnitudeB === 0) return 0.0;
  return dotProduct / (Math.sqrt(magnitudeA) * Math.sqrt(magnitudeB));
}

function buildConversationContext(
  conversationHistory: Array<{ sender: string; content: string }>
): string {
  if (!conversationHistory || conversationHistory.length === 0) return "";

  const recentHistory = conversationHistory.slice(-6);
  const contextParts: string[] = [];

  for (const message of recentHistory) {
    const role = message.sender === "user" ? "User" : "Assistant";
    const content =
      message.content.length > 500 ?
        message.content.substring(0, 500) + "..." :
        message.content;
    contextParts.push(`${role}: ${content}`);
  }

  return contextParts.join("\n");
}

async function enhanceQueryWithContext(
  query: string,
  conversationContext: string,
  cohereApiKey: string
): Promise<string> {
  if (!conversationContext) return query;

  try {
    const enhancementPrompt = `Based on the conversation history, enhance this query to include relevant context for better information retrieval.

Conversation History:
${conversationContext}

Current Query: "${query}"

Enhanced Query (keep it concise, focus on key concepts):`;

    const enhanced = await generateCohereResponse(
      enhancementPrompt,
      cohereApiKey
    );

    if (!enhanced || enhanced.trim().length === 0) {
      return query;
    }

    return `${query} ${enhanced.trim()}`;
  } catch (error) {
    console.error("Error enhancing query:", error);
    return query;
  }
}

function buildDocumentContext(
  results: Array<{
    ibID: string;
    ib_title: string;
    content: string;
    similarity_score: number;
  }>
): string {
  const sorted = results
    .slice()
    .sort((a, b) => b.similarity_score - a.similarity_score);
  const contextParts: string[] = [];

  for (let i = 0; i < Math.min(3, sorted.length); i++) {
    const doc = sorted[i];
    const relevance = Math.round(doc.similarity_score * 100);
    contextParts.push(
      `Document: ${doc.ib_title} (Relevance: ${relevance}%)\nContent: ${doc.content}`
    );
  }

  return contextParts.join("\n\n---\n\n");
}

function buildContextAwarePrompt(
  query: string,
  documentContext: string,
  conversationHistory: string
): string {
  return `You are OASP Assist, the official assistant for Central Mindanao University's Office of Admissions, Scholarships, and Placements.

CONTEXT AWARENESS INSTRUCTIONS:
- Consider the conversation history to understand the context and any follow-up questions
- If the user is asking a follow-up question (like "what are those?" or "how many?"), refer to the previous conversation to understand what they're asking about
- Maintain continuity in the conversation by referencing previous topics when relevant
- Only answer based on the provided document context below
- If the context doesn't contain enough information, say: "I don't have complete information about that. Please contact OASP staff for detailed assistance."

CONVERSATION HISTORY:
${conversationHistory}

CURRENT QUESTION: "${query}"

AVAILABLE DOCUMENT CONTEXT:
${documentContext}

Based on the conversation history and document context above, provide a helpful and contextually aware answer:`;
}

async function findMatchingFAQ(
  query: string,
  queryEmbedding: number[],
  cohereApiKey: string,
  similarityThreshold = 0.90
): Promise<{ question: string; answer: string; similarity: number } | null> {
  try {
    const faqSnapshot = await db
      .collection("faqs")
      .where("answer", "!=", "")
      .get();

    let bestMatch: {
      question: string;
      answer: string;
      similarity: number;
    } | null = null;
    let highestSimilarity = 0;

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const faqQuestion = data.question as string;
      const faqAnswer = data.answer as string;

      if (!faqQuestion || !faqAnswer) continue;

      let faqEmbedding: number[];
      if (data.embedding && Array.isArray(data.embedding)) {
        faqEmbedding = data.embedding;
      } else {
        faqEmbedding = await generateCohereEmbedding(
          faqQuestion,
          cohereApiKey,
          "search_document"
        );

        await doc.ref.update({embedding: faqEmbedding});
      }

      const similarity = cosineSimilarity(queryEmbedding, faqEmbedding);

      if (similarity > highestSimilarity && similarity >= similarityThreshold) {
        highestSimilarity = similarity;
        bestMatch = {
          question: faqQuestion,
          answer: faqAnswer,
          similarity: similarity,
        };
      }
    }

    if (bestMatch) {
      console.log(
        `Found FAQ match: "${bestMatch.question}" (similarity: ${bestMatch.similarity.toFixed(3)})`
      );

      const faqDoc = faqSnapshot.docs.find(
        (doc) => doc.data().question === bestMatch!.question
      );
      if (faqDoc) {
        await faqDoc.ref.update({
          similarityCount: admin.firestore.FieldValue.increment(1),
          lastAsked: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    }

    return bestMatch;
  } catch (error) {
    console.error("Error finding matching FAQ:", error);
    return null;
  }
}

async function retrieveRelevantDocuments(
  query: string,
  queryEmbedding: number[],
  pineconeIndex: any,
  topK = 5,
  minSimilarityScore = 0.3
): Promise<
  Array<{
    ibID: string;
    ib_title: string;
    content: string;
    source: string;
    categoryID: string;
    similarity_score: number;
    chunk_info: any;
  }>
> {
  try {
    console.log(`🔍 Starting retrieval for query: "${query}"`);
    console.log(`📊 Query embedding dimensions: ${queryEmbedding.length}`);
    console.log(`📊 Requesting topK: ${topK * 3} chunks`);

    const similarChunks = await pineconeIndex.query({
      vector: queryEmbedding,
      topK: topK * 3,
      includeMetadata: true,
    });

    console.log("📊 Pinecone response:", JSON.stringify({
      matchCount: similarChunks.matches?.length || 0,
      hasMatches: !!similarChunks.matches,
      namespace: similarChunks.namespace,
    }));

    if (!similarChunks.matches || similarChunks.matches.length === 0) {
      console.log("❌ No similar document chunks found in Pinecone");
      console.log("⚠️ Check if documents are indexed in Pinecone");
      return [];
    }

    console.log(`📊 Found ${similarChunks.matches.length} similar chunks`);

    if (similarChunks.matches.length > 0) {
      const firstMatch = similarChunks.matches[0];
      console.log(`📝 First match score: ${firstMatch.score}`);
      console.log("📝 First match metadata keys:", Object.keys(firstMatch.metadata || {}));
    }

    const filteredChunks = similarChunks.matches.filter(
      (chunk: any) => (chunk.score || 0) >= minSimilarityScore
    );

    console.log(`✅ Filtered chunks: ${filteredChunks.length} (threshold: ${minSimilarityScore})`);

    if (filteredChunks.length === 0) {
      console.log(`❌ No chunks meet minimum similarity threshold of ${minSimilarityScore}`);
      console.log(`⚠️ Best score found: ${similarChunks.matches[0]?.score || 0}`);
      return [];
    }

    const documentChunks: { [key: string]: any[] } = {};

    for (const chunk of filteredChunks) {
      const metadata = chunk.metadata || {};

      const originalDocId =
        metadata.docId ||
        metadata.originalDocId ||
        metadata.documentId ||
        metadata.id ||
        chunk.id?.split("_chunk_")[0];

      console.log(`📝 Chunk ${chunk.id}: docId = ${originalDocId}, score = ${chunk.score}`);

      if (originalDocId) {
        if (!documentChunks[originalDocId]) {
          documentChunks[originalDocId] = [];
        }
        documentChunks[originalDocId].push({
          ...chunk,
          metadata,
        });
      } else {
        console.log(`⚠️ Chunk ${chunk.id} has no identifiable document ID`);
      }
    }

    console.log(`📄 Grouped chunks into ${Object.keys(documentChunks).length} documents`);

    const results: Array<{
      ibID: string;
      ib_title: string;
      content: string;
      source: string;
      categoryID: string;
      similarity_score: number;
      chunk_info: any;
    }> = [];

    for (const docId of Object.keys(documentChunks)) {
      const chunks = documentChunks[docId];

      chunks.sort((a, b) => (b.score || 0) - (a.score || 0));

      const bestChunk = chunks[0];
      const bestScore = bestChunk.score || 0;

      const contextualContent = getContextualContent(chunks, bestChunk);

      if (!contextualContent || contextualContent.trim().length === 0) {
        console.log(`⚠️ Empty contextual content for document ${docId}, skipping`);
        continue;
      }

      const docMetadata = await getDocumentMetadata(docId);

      const result = {
        ibID: docMetadata?.ibID || docMetadata?.id || docId,
        ib_title:
          docMetadata?.ib_title ||
          docMetadata?.title ||
          bestChunk.metadata?.originalTitle ||
          bestChunk.metadata?.fileName ||
          bestChunk.metadata?.title ||
          "Untitled Document",
        content: contextualContent,
        source:
          docMetadata?.source ||
          bestChunk.metadata?.source ||
          bestChunk.metadata?.fileName ||
          "Unknown",
        categoryID:
          docMetadata?.category ||
          docMetadata?.categoryID ||
          bestChunk.metadata?.category ||
          "General",
        similarity_score: bestScore,
        chunk_info: {
          total_chunks_found: chunks.length,
          best_chunk_index: bestChunk.metadata?.chunkIndex || bestChunk.metadata?.chunk_index || 0,
          is_chunked_document: chunks.length > 1,
        },
      };

      results.push(result);
      console.log(
        `✅ Added result: ${result.ib_title} (score: ${bestScore.toFixed(3)})`
      );
    }

    results.sort((a, b) => b.similarity_score - a.similarity_score);

    const topResults = results.slice(0, topK);

    console.log(`🎯 Final results: ${topResults.length} documents retrieved`);
    return topResults;
  } catch (error) {
    console.error("❌ Error retrieving relevant documents:", error);
    return [];
  }
}

async function getDocumentMetadata(docId: string): Promise<any> {
  try {
    const safeDocId = docId.replace(/[/\\]/g, "-");
    const doc = await db
      .collection("information_bank")
      .doc(safeDocId)
      .get();

    if (doc.exists) {
      return doc.data();
    }

    return null;
  } catch (error) {
    console.error(`Error getting document metadata for ${docId}:`, error);
    return null;
  }
}

async function isAdmin(uid: string): Promise<boolean> {
  try {
    console.log(`🔍 Checking admin status for UID: ${uid}`);
    
    const userDoc = await db.collection("users").doc(uid).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const firestoreRole = userData?.role;
      console.log(`📊 Firestore role: ${firestoreRole}`);
      
      if (firestoreRole === "admin") {
        console.log("✅ User is admin (from Firestore)");
        return true;
      }
    }
    
    try {
      const userRecord = await admin.auth().getUser(uid);
      const customClaims = userRecord.customClaims;
      
      if (customClaims?.admin === true) {
        console.log("✅ User is admin (from custom claims)");
        return true;
      }
    } catch (authError) {
      console.error("❌ Error checking custom claims:", authError);
    }
    
    console.log("❌ User is NOT admin");
    return false;
  } catch (error) {
    console.error("Error checking admin status:", error);
    return false;
  }
}

// ============================================================================
// CHATBOT FUNCTIONS
// ============================================================================

export const generateAnswer = onRequest(
  {
    secrets: [PINECONE_API_KEY, COHERE_API_KEY],
    cors: true,
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const {
        query,
        conversationHistory = [],
        topK = 5,
        minSimilarityScore = 0.3,
      } = req.body;

      if (!query || typeof query !== "string" || query.trim().length === 0) {
        res.status(400).json({
          answer: "Please provide a valid question.",
          source: "error",
        });
        return;
      }

      console.log(`🤖 Generating answer for: "${query}"`);

      const pineconeKey = PINECONE_API_KEY.value();
      const cohereKey = COHERE_API_KEY.value();

      const pineconeClient = new Pinecone({apiKey: pineconeKey});
      const pineconeIndex = pineconeClient.Index("oasp-assist");

      const contextHistory = buildConversationContext(conversationHistory);

      const queryEmbedding = await generateCohereEmbedding(
        query,
        cohereKey,
        "search_query"
      );

      console.log(`✅ Generated embedding with ${queryEmbedding.length} dimensions`);

      const faqMatch = await findMatchingFAQ(query, queryEmbedding, cohereKey, 0.90);

      if (faqMatch) {
        console.log("✅ Using FAQ answer");
        res.json({
          answer: faqMatch.answer,
          source: "faq",
          similarity: faqMatch.similarity,
        });
        return;
      }

      const contextualQuery = await enhanceQueryWithContext(
        query,
        contextHistory,
        cohereKey
      );

      console.log(`🔍 Contextual query: "${contextualQuery}"`);

      const results = await retrieveRelevantDocuments(
        contextualQuery,
        queryEmbedding,
        pineconeIndex,
        topK,
        minSimilarityScore
      );

      if (results.length === 0) {
        console.log("❌ No relevant documents found");
        res.json({
          answer:
            "Sorry, I couldn't find relevant information about that topic. Please contact OASP staff for assistance.",
          source: "no_documents",
          debug: {
            message: "Pinecone query returned no results",
            embeddingDimensions: queryEmbedding.length,
            minSimilarityScore: minSimilarityScore,
          },
        });
        return;
      }

      console.log(`📚 Using ${results.length} documents for context`);

      const documentContext = buildDocumentContext(results);

      const prompt = buildContextAwarePrompt(
        query,
        documentContext,
        contextHistory
      );

      const answer = await generateCohereResponse(prompt, cohereKey);

      if (!answer || answer.trim().length === 0) {
        console.log("❌ Cohere returned empty response");
        res.json({
          answer:
            "I'm having trouble processing your question right now. Please try again or contact OASP staff for assistance.",
          source: "empty_response",
        });
        return;
      }

      console.log("✅ Generated contextual answer");
      res.json({
        answer: answer.trim(),
        source: "knowledge_base",
        documentsUsed: results.length,
        documentTitles: results.map((r) => r.ib_title),
      });
    } catch (error) {
      console.error("❌ Error in generateAnswer:", error);

      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";
      console.error("Detailed error:", errorMessage);

      res.status(500).json({
        answer:
          "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.",
        source: "error",
        error: errorMessage,
      });
    }
  }
);

// ============================================================================
// ADMIN USER MANAGEMENT FUNCTIONS
// ============================================================================

export const createUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 createUser function called");
    console.log("📊 Request auth:", JSON.stringify(request.auth, null, 2));
    console.log("📊 Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      if (!request.auth) {
        console.error("❌ No auth context - user not authenticated");
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in as an admin."
        );
      }

      const callerUid = request.auth.uid;
      console.log(`✅ User is authenticated: ${callerUid}`);
      console.log(`📧 User email: ${request.auth.token.email || "unknown"}`);

      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        console.error(`❌ User ${callerUid} is not an admin`);
        throw new HttpsError(
          "permission-denied",
          "Only admins can create users."
        );
      }

      console.log(`✅ User ${callerUid} is confirmed admin`);

      const email = request.data.email as string;
      const password = request.data.password as string;
      const displayName = request.data.displayName as string | undefined;
      const affiliation = request.data.affiliation as string | undefined;
      const scholarship = request.data.scholarship as string | undefined;

      if (!email || !password) {
        throw new HttpsError(
          "invalid-argument",
          "Email and password are required."
        );
      }

      console.log(`🔄 Creating user with email: ${email}`);
      
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: displayName || "",
        emailVerified: true,
      });

      console.log(`✅ User created in Auth with UID: ${userRecord.uid}`);

      await db.collection("users").doc(userRecord.uid).set({
        uid: userRecord.uid,
        email: email,
        displayName: displayName || "",
        name: displayName || email.split("@")[0],
        role: "user",
        affiliation: affiliation || "",
        scholarship: scholarship || "",
        profileComplete: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: callerUid,
        isActive: true,
        isVerified: true,
        emailVerified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationEmailSent: false,
      });

      console.log(`✅ User document created in Firestore for UID: ${userRecord.uid}`);

      await db.collection("logs").add({
        user: displayName || email,
        action: "Admin created user account (auto-verified, no email sent)",
        time: admin.firestore.FieldValue.serverTimestamp(),
        userId: userRecord.uid,
        createdBy: callerUid,
      });

      console.log("✅ User creation complete - No verification email sent (admin-created)");

      return {
        success: true,
        uid: userRecord.uid,
        email: email,
        message: "User created successfully. Account is already verified and ready to use.",
      };
    } catch (error: any) {
      console.error("❌ Error creating user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      if (error.code === "auth/email-already-exists") {
        throw new HttpsError(
          "already-exists",
          "This email is already registered."
        );
      }
      
      if (error.code === "auth/invalid-email") {
        throw new HttpsError(
          "invalid-argument",
          "Invalid email address."
        );
      }
      
      if (error.code === "auth/weak-password") {
        throw new HttpsError(
          "invalid-argument",
          "Password must be at least 6 characters."
        );
      }
      
      console.error("❌ Unhandled error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to create user"
      );
    }
  }
);

export const deleteUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 deleteUser function called");
    console.log("📊 Request auth:", JSON.stringify(request.auth, null, 2));
    console.log("📊 Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can delete users."
        );
      }

      const uid = request.data.uid as string;
      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      console.log(`🔄 Deleting user: ${uid}`);

      await admin.auth().deleteUser(uid);
      console.log(`✅ User ${uid} deleted from Authentication`);

      try {
        await db.collection("users").doc(uid).delete();
        console.log(`✅ User ${uid} deleted from Firestore`);
      } catch (firestoreError) {
        console.warn("⚠️ Could not delete user from Firestore:", firestoreError);
      }

      return {
        success: true,
        message: `User ${uid} deleted successfully.`,
      };
    } catch (error: any) {
      console.error("❌ Error deleting user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to delete user");
    }
  }
);

export const updateUser = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("🔥 updateUser function called");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can update users."
        );
      }

      const uid = request.data.uid as string;
      const email = request.data.email as string | undefined;
      const password = request.data.password as string | undefined;
      const displayName = request.data.displayName as string | undefined;

      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      const updateData: admin.auth.UpdateRequest = {};
      if (email) {
        updateData.email = email;
        updateData.emailVerified = true;
      }
      if (password) updateData.password = password;
      if (displayName) updateData.displayName = displayName;

      await admin.auth().updateUser(uid, updateData);
      console.log(`✅ User ${uid} updated successfully`);
      
      return {
        success: true,
        message: `User ${uid} updated successfully.`,
      };
    } catch (error: any) {
      console.error("❌ Error updating user:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to update user");
    }
  }
);

export const setAdminRole = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("🔥 setAdminRole function called");
    
    try {
      if (!request.auth) {
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in."
        );
      }

      const callerUid = request.auth.uid;
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can change admin roles."
        );
      }

      const uid = request.data.uid as string;
      const makeAdmin = request.data.isAdmin as boolean;

      if (!uid) {
        throw new HttpsError(
          "invalid-argument",
          "User ID (uid) is required."
        );
      }

      await db.collection("users").doc(uid).update({
        role: makeAdmin ? "admin" : "user",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin.auth().setCustomUserClaims(uid, { 
        admin: makeAdmin 
      });

      console.log(`✅ User ${uid} role updated to ${makeAdmin ? "admin" : "user"}`);

      return {
        success: true,
        message: `User ${uid} ${makeAdmin ? "promoted to" : "removed from"} admin role.`,
      };
    } catch (error: any) {
      console.error("❌ Error setting admin role:", error);
      
      if (error instanceof HttpsError) {
        throw error;
      }
      
      throw new HttpsError("internal", error.message || "Failed to set admin role");
    }
  }
);

// ============================================================================
// FACEBOOK SYNC FUNCTIONS
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

async function downloadAndUploadImage(
  imageUrl: string,
  postId: string
): Promise<string> {
  try {
    console.log(`Downloading image for post ${postId}`);
    
    const response = await axios.get(imageUrl, {
      responseType: "arraybuffer",
      timeout: 30000,
    });
    
    const buffer = Buffer.from(response.data as Buffer);
    const contentType = response.headers["content-type"] || "image/jpeg";
    
    const ext = contentType.split("/")[1] || "jpg";
    const fileName = `announcements/${postId}.${ext}`;
    
    const bucket = storage.bucket();
    const file = bucket.file(fileName);
    
    await file.save(buffer, {
      metadata: {
        contentType: contentType,
        metadata: {
          postId: postId,
          uploadedAt: new Date().toISOString(),
        },
      },
    });
    
    await file.makePublic();
    
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;
    
    console.log(`Image uploaded successfully: ${publicUrl}`);
    return publicUrl;
    
  } catch (error: any) {
    console.error(`Error uploading image for post ${postId}:`, error.message);
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

export const healthCheck = onRequest(
  {
    cors: true,
  },
  (req, res) => {
    res.status(200).json({
      status: "healthy",
      timestamp: new Date().toISOString(),
      service: "Firebase Cloud Functions v2",
    });
  }
);

export const testSync = onCall(
  {
    cors: true,
  },
  async (request) => {
    console.log("🧪 Test function called");
    console.log("Auth:", request.auth ? "Yes" : "No");
    console.log("Data:", request.data);
    
    return {
      success: true,
      message: "Test function working!",
      receivedData: request.data,
      timestamp: new Date().toISOString(),
      hasAuth: !!request.auth,
    };
  }
);

// ============================================================================
// FACEBOOK TOKEN MANAGEMENT (v2)
// ============================================================================

async function exchangeShortForLong(
  shortToken: string,
  appId: string,
  appSecret: string
): Promise<{ access_token: string; expires_in?: number }> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/oauth/access_token`;
  const params = {
    grant_type: "fb_exchange_token",
    client_id: appId,
    client_secret: appSecret,
    fb_exchange_token: shortToken,
  };
  
  console.log('📡 Calling Facebook token exchange API...');
  console.log('📡 URL:', url);
  console.log('📡 Params:', { ...params, client_secret: '***', fb_exchange_token: '***' });
  
  try {
    const resp = await axios.get<{ access_token: string; expires_in?: number; token_type?: string }>(
      url, 
      { 
        params,
        timeout: 30000,
      }
    );
    
    console.log('✅ Facebook API response received');
    console.log('📊 Response status:', resp.status);
    console.log('📊 Response data:', {
      ...resp.data,
      access_token: resp.data.access_token ? '***' + resp.data.access_token.slice(-10) : undefined,
      expires_in: resp.data.expires_in,
      token_type: resp.data.token_type,
    });
    
    // Facebook returns expires_in in seconds
    if (resp.data.expires_in) {
      const days = Math.round(resp.data.expires_in / 86400);
      console.log(`📅 Token is valid for ${resp.data.expires_in} seconds (~${days} days)`);
    } else {
      console.warn('⚠️ WARNING: Facebook did not return expires_in!');
      console.warn('⚠️ This means the token might be short-lived or there was an error');
    }
    
    return resp.data;
  } catch (error: any) {
    console.error('❌ Facebook token exchange failed');
    console.error('❌ Status:', error.response?.status);
    console.error('❌ Error data:', JSON.stringify(error.response?.data, null, 2));
    throw error;
  }
}



async function getUserPages(longUserToken: string): Promise<any> {
  const url = `https://graph.facebook.com/${FB_API_VERSION}/me/accounts`;
  const resp = await axios.get(url, { params: { access_token: longUserToken } });
  return resp.data as any;
}


export const refreshTokensDaily = onSchedule(
  {
    schedule: "every 24 hours",
    timeZone: "Asia/Manila",
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (event) => {
    const REFRESH_BEFORE_MS = 5 * 24 * 60 * 60 * 1000;
    const now = Date.now();
    const cutoff = now + REFRESH_BEFORE_MS;

    const appId = FB_APP_ID.value();
    const appSecret = FB_APP_SECRET.value();

    const snapshot = await db.collection("fb_tokens")
      .where("provider", "==", "facebook")
      .where("expires_at", "<=", cutoff)
      .get();

    if (snapshot.empty) {
      console.log("No tokens need refreshing.");
      return;
    }

    const results = [];
    for (const doc of snapshot.docs) {
      const data = doc.data();
      const uid = doc.id;
      const currentLong = data.long_token;

      if (!currentLong) {
        console.log(`No long token for ${uid}, skipping`);
        continue;
      }

      try {
        const resp = await axios.get<{ access_token: string; expires_in?: number }>(
          `https://graph.facebook.com/${FB_API_VERSION}/oauth/access_token`, 
          {
            params: {
              grant_type: "fb_exchange_token",
              client_id: appId,
              client_secret: appSecret,
              fb_exchange_token: currentLong,
            },
          }
        );

        const newToken = resp.data.access_token;
        const newExpiresIn = resp.data.expires_in;
        const newExpiresAt = newExpiresIn ? (Date.now() + newExpiresIn * 1000) : null;

        let pagesObj = data.pages || {};
        try {
          const pagesResp = await getUserPages(newToken);
          const pages = pagesResp.data || [];
          for (const p of pages) {
            pagesObj[p.id] = {
              access_token: p.access_token,
              name: p.name,
              expires_at: null,
            };
          }
        } catch (err: any) {
          console.warn("pages refresh failed for", uid, err?.message || err);
        }

        await doc.ref.update({
          long_token: newToken,
          expires_at: newExpiresAt,
          pages: pagesObj,
          updated_at: Date.now(),
        });

        console.log(`Refreshed token for ${uid}`);
        results.push({ uid, ok: true });
      } catch (err: any) {
        console.error(`Failed to refresh token for ${uid}`, err?.response?.data || err.message || err);
        await doc.ref.update({ 
          needs_reauth: true, 
          reauth_reason: err?.response?.data || err.message || "" 
        });
        results.push({ uid, ok: false, error: err?.response?.data || err.message || "" });
      }
    }

    console.log("Token refresh summary:", { refreshed: results.length, details: results });
  }
);



export const exchangeTokenHttp = onRequest(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
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
      console.log("🔥 exchangeToken (HTTP) called");
      console.log("Headers:", JSON.stringify(req.headers, null, 2));
      console.log("Body:", JSON.stringify(req.body, null, 2));
      console.log("========================================");
      
      // Verify authentication
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
      
      // Extract data from request body
      const { data } = req.body;
      const { uid, short_token } = data || {};
      
      if (!uid || !short_token) {
        res.status(400).json({ 
          error: "invalid-argument",
          message: "uid and short_token are required"
        });
        return;
      }

      // Execute token exchange
      const result = await exchangeTokenLogic(uid, short_token);
      
      console.log("✅ Token exchange successful");
      res.json({ result });
      
    } catch (error: any) {
      console.error("❌ exchangeToken HTTP error:", error);
      
      // Return proper error format
      res.status(500).json({ 
        error: "internal",
        message: error.message || "Internal server error",
        details: error.toString()
      });
    }
  }
);


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

export const exchangeToken = onCall(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 exchangeToken (callable) called");
    console.log("Auth:", request.auth ? "Authenticated" : "Not authenticated");
    console.log("Data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      // Verify authentication
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const { uid, short_token } = request.data;
      
      if (!uid || !short_token) {
        throw new HttpsError("invalid-argument", "Missing uid or short_token");
      }

      // Execute token exchange
      const result = await exchangeTokenLogic(uid, short_token);
      
      console.log("✅ Token exchange successful");
      return result;
      
    } catch (error: any) {
      console.error("❌ exchangeToken error:", error);
      
      // Return error in a format the client can handle
      if (error instanceof HttpsError) {
        throw error;
      }
      
      // Wrap other errors
      throw new HttpsError(
        "internal", 
        error.message || "Failed to exchange token"
      );
    }
  }
);

async function exchangeTokenLogic(uid: string, shortToken: string): Promise<any> {
  try {
    console.log(`🔄 Exchanging token for uid: ${uid}`);

    const appId = FB_APP_ID.value();
    const appSecret = FB_APP_SECRET.value();

    if (!appId || !appSecret) {
      throw new Error("FB_APP_ID or FB_APP_SECRET not configured");
    }

    // Exchange short-lived token for long-lived token
    console.log("📡 Calling Facebook API...");
    const data = await exchangeShortForLong(shortToken, appId, appSecret);
    const longToken = data.access_token;
    const expiresIn = data.expires_in;

    console.log(`✅ Token exchanged successfully`);
    console.log(`📊 Expires in: ${expiresIn} seconds`);

    // Verify the token
    const me = await axios.get<{ id: string; name?: string }>(
      `https://graph.facebook.com/${FB_API_VERSION}/me`, 
      {
        params: { access_token: longToken, fields: "id,name" },
      }
    );

    const fbUserId = me.data.id;
    const now = Date.now();
    
    // CRITICAL FIX: Handle expires_at properly
    let expiresAt: number | null = null;
    
    if (expiresIn !== undefined && expiresIn !== null) {
      // Facebook returns expires_in in seconds, convert to milliseconds
      expiresAt = now + (Number(expiresIn) * 1000);
      console.log(`📅 Token will expire at: ${new Date(expiresAt).toISOString()}`);
      console.log(`📅 That's ${Math.round(Number(expiresIn) / 86400)} days from now`);
    } else {
      console.warn(`⚠️ No expires_in received from Facebook, setting to 60 days`);
      // Default to 60 days if Facebook doesn't return expires_in
      expiresAt = now + (60 * 24 * 60 * 60 * 1000);
    }

    // Get page access tokens
    let pagesObj: { [key: string]: any } = {};
    try {
      const pagesResp = await getUserPages(longToken);
      const pages = pagesResp.data || [];
      console.log(`📄 Found ${pages.length} page(s)`);
      
      for (const p of pages) {
        pagesObj[p.id] = {
          access_token: p.access_token,
          name: p.name,
          expires_at: null, // Page tokens typically don't expire
        };
      }
    } catch (err: any) {
      console.warn("⚠️ Could not fetch pages:", err?.message);
    }

    // Save to Firestore - use the uid as document ID
    const docRef = db.collection("fb_tokens").doc(uid);
    const saveData = {
      provider: "facebook",
      userId: fbUserId,
      long_token: longToken,
      short_token: shortToken,
      expires_at: expiresAt,
      expires_in: expiresIn || null,
      pages: pagesObj,
      updated_at: now,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    
    console.log(`💾 Saving token data:`, {
      ...saveData,
      long_token: "***",
      short_token: "***",
      expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
    });
    
    await docRef.set(saveData, { merge: true });

    console.log(`✅ Token saved to fb_tokens/${uid}`);

    const daysValid = expiresIn 
      ? Math.round(Number(expiresIn) / 86400)
      : 60; // Default to 60 if not provided

    return { 
      success: true,
      ok: true, 
      expires_in: expiresIn || (60 * 86400), // Return seconds
      expires_at: expiresAt, 
      fbUserId: fbUserId,
      pagesCount: Object.keys(pagesObj).length,
      message: `Token saved successfully. Valid for ~${daysValid} days.`,
    };
  } catch (error: any) {
    console.error("❌ exchangeTokenLogic error:", error);
    
    // Handle Facebook API errors specifically
    if (error.response?.data?.error) {
      const fbError = error.response.data.error;
      throw new Error(`Facebook API Error: ${fbError.message || fbError.type}`);
    }
    
    throw error;
  }
}


// ============================================================================
// IMPROVED getAccessToken with better error messages
// ============================================================================

async function getAccessToken(): Promise<string> {
  try {
    console.log("🔍 Looking for Facebook token...");
    
    // Get token document
    const tokenDoc = await db.collection('fb_tokens').doc('facebook_admin').get();
    
    if (!tokenDoc.exists) {
      console.log("❌ No token found at fb_tokens/facebook_admin");
      throw new Error('No Facebook token configured. Please configure token using the key (🔑) button');
    }
    
    const data = tokenDoc.data();
    
    if (!data) {
      throw new Error('Invalid token data in database');
    }
    
    // CRITICAL FIX: Use PAGE token instead of user token
    const pages = data.pages || {};
    const pageIds = Object.keys(pages);
    
    console.log(`📄 Found ${pageIds.length} page(s) in token data`);
    console.log(`🎯 Target PAGE_ID: ${PAGE_ID}`);
    
    // Try to find the specific page token
    if (pages[PAGE_ID] && pages[PAGE_ID].access_token) {
      console.log(`✅ Using page token for ${PAGE_ID}`);
      return pages[PAGE_ID].access_token;
    }
    
    // If specific page not found, use first available page token
    if (pageIds.length > 0) {
      const firstPageId = pageIds[0];
      const firstPageToken = pages[firstPageId].access_token;
      console.warn(`⚠️ Page ${PAGE_ID} not found in saved pages`);
      console.warn(`⚠️ Using first available page: ${firstPageId}`);
      return firstPageToken;
    }
    
    // Fallback to user token if no pages found (not recommended)
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

// ============================================================================
// IMPROVED manualSyncFacebookPosts with better error handling
// ============================================================================

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
      // Verify authentication
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentication required");
      }

      const result = await syncFacebookPostsLogic();
      return result;
      
    } catch (error: any) {
      console.error("❌ Sync error:", error);
      
      // Return error in proper format
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
      
      // Verify authentication
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
    
    // Return user-friendly error
    return {
      success: false,
      error: error.message,
      message: error.message,
    };
  }
}

// ============================================================================
// IMPROVED fetchFacebookPosts with better error handling
// ============================================================================

async function fetchFacebookPosts(): Promise<FacebookPost[]> {
  try {
    console.log("🔍 Fetching Facebook posts...");
    console.log("📍 Page ID:", PAGE_ID);
    console.log("📍 API Version:", FB_API_VERSION);
    
    // Get token from Firestore
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

export const testFacebookConnection = onCall(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
  },
  async (request) => {
    console.log("🧪 Testing Facebook connection...");
    
    try {
      // Check if token exists
      const tokenDoc = await db.collection('fb_tokens').doc('facebook_admin').get();
      
      if (!tokenDoc.exists) {
        return {
          success: false,
          error: "No token configured",
          message: "Please configure Facebook token first",
          tokenInfo: {
            hasToken: false,
          }
        };
      }
      
      const tokenData = tokenDoc.data();
      const expiresAt = tokenData?.expires_at || 0;
      const now = Date.now();
      const daysLeft = Math.round((expiresAt - now) / (1000 * 60 * 60 * 24));
      
      // Test the token by fetching page info
      try {
        const response = await axios.get(
          `https://graph.facebook.com/${FB_API_VERSION}/${PAGE_ID}`,
          {
            params: {
              access_token: tokenData?.long_token,
              fields: "id,name,about"
            }
          }
        );
        
        return {
          success: true,
          message: "Connection successful",
          tokenInfo: {
            hasToken: true,
            expiresAt: expiresAt,
            daysLeft: daysLeft,
            pages: tokenData?.pages || {},
            pagesCount: Object.keys(tokenData?.pages || {}).length,
          },
          pageInfo: response.data,
          targetPageId: PAGE_ID,
        };
      } catch (apiError: any) {
        return {
          success: false,
          error: apiError.response?.data?.error?.message || apiError.message,
          errorCode: apiError.response?.data?.error?.code,
          message: "Token exists but API call failed",
          tokenInfo: {
            hasToken: true,
            daysLeft: daysLeft,
          }
        };
      }
      
    } catch (error: any) {
      console.error("❌ Test failed:", error);
      return {
        success: false,
        error: error.message,
        message: "Test failed"
      };
    }
  }
);

// Add this function to your index.ts file

export const testFacebookConnectionHttp = onRequest(
  {
    cors: true,
    secrets: [FB_APP_ID, FB_APP_SECRET],
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
      console.log("🧪 Testing Facebook connection (HTTP)...");
      
      // Verify authentication
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
      
      // Check if token exists
      const tokenDoc = await db.collection('fb_tokens').doc('facebook_admin').get();
      
      if (!tokenDoc.exists) {
        res.json({
          success: false,
          error: "No token configured",
          message: "Please configure Facebook token first",
          tokenInfo: {
            hasToken: false,
          }
        });
        return;
      }
      
      const tokenData = tokenDoc.data();
      const expiresAt = tokenData?.expires_at || 0;
      const now = Date.now();
      const daysLeft = Math.round((expiresAt - now) / (1000 * 60 * 60 * 24));
      
      // Test the token by fetching page info
      try {
        const response = await axios.get(
          `https://graph.facebook.com/${FB_API_VERSION}/${PAGE_ID}`,
          {
            params: {
              access_token: tokenData?.long_token,
              fields: "id,name,about"
            },
            timeout: 10000,
          }
        );
        
        res.json({
          success: true,
          message: "Connection successful",
          tokenInfo: {
            hasToken: true,
            expiresAt: expiresAt,
            daysLeft: daysLeft,
            pages: tokenData?.pages || {},
            pagesCount: Object.keys(tokenData?.pages || {}).length,
          },
          pageInfo: response.data,
          targetPageId: PAGE_ID,
        });
      } catch (apiError: any) {
        console.error("❌ Facebook API test failed:", apiError.response?.data || apiError.message);
        
        res.json({
          success: false,
          error: apiError.response?.data?.error?.message || apiError.message,
          errorCode: apiError.response?.data?.error?.code,
          message: "Token exists but API call failed",
          tokenInfo: {
            hasToken: true,
            daysLeft: daysLeft,
          }
        });
      }
      
    } catch (error: any) {
      console.error("❌ Test failed:", error);
      res.status(500).json({
        success: false,
        error: error.message,
        message: "Test failed"
      });
    }
  }
);


