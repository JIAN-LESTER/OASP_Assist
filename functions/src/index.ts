import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";


// Define secrets
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");

if (!admin.apps.length) {
  admin.initializeApp();
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

/**
 * Generate response using Cohere Chat API
 * @param {string} prompt - Input prompt
 * @param {string} apiKey - Cohere API key
 * @return {Promise<string>} Generated response
 */
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


// Add this debug function to your Cloud Function before generateAnswer

async function debugPineconeState(
  pineconeIndex: any,
  queryEmbedding: number[]
): Promise<void> {
  try {
    console.log("🔍 ===== PINECONE DEBUG INFO =====");

    // 1. Check index stats
    console.log("📊 Fetching index statistics...");
    try {
      const stats = await pineconeIndex.describeIndexStats();
      console.log("📊 Index Stats:", JSON.stringify(stats, null, 2));
      console.log(`📊 Total vectors in index: ${stats.totalVectorCount || "unknown"}`);
      console.log(`📊 Namespaces: ${JSON.stringify(stats.namespaces || {})}`);
    } catch (statsError) {
      console.log("⚠️ Could not fetch stats:", statsError);
    }

    // 2. Try a simple query with very low threshold
    console.log("\n🔍 Testing query with low similarity threshold...");
    try {
      const testQuery = await pineconeIndex.query({
        vector: queryEmbedding,
        topK: 10,
        includeMetadata: true,
      });

      console.log(`📊 Query returned ${testQuery.matches?.length || 0} results`);

      if (testQuery.matches && testQuery.matches.length > 0) {
        console.log("✅ Query IS working - found matches!");

        // Log first few results
        for (let i = 0; i < Math.min(3, testQuery.matches.length); i++) {
          const match = testQuery.matches[i];
          console.log(`\n  Result ${i + 1}:`);
          console.log(`    ID: ${match.id}`);
          console.log(`    Score: ${match.score}`);
          console.log(`    Metadata keys: ${Object.keys(match.metadata || {}).join(", ")}`);

          // Log actual metadata values for debugging
          if (match.metadata) {
            console.log("    Metadata sample:", {
              docId: match.metadata.docId,
              title: match.metadata.title,
              text_preview: match.metadata.text ? match.metadata.text.substring(0, 100) + "..." : "MISSING",
              source: match.metadata.source,
            });
          }
        }
      } else {
        console.log("❌ Query returned NO results - documents not indexed or embedding incompatible");
      }
    } catch (queryError) {
      console.log("❌ Query failed:", queryError);
    }

    // 3. Check if index is completely empty
    console.log("\n🔍 Attempting to fetch any vector from index...");
    try {
      const stats = await pineconeIndex.describeIndexStats();
      if (stats.totalVectorCount === 0) {
        console.log("🚨 INDEX IS EMPTY - No vectors uploaded!");
        console.log("   Action items:");
        console.log("   1. Check if document upload completed successfully");
        console.log("   2. Verify Pinecone credentials are correct");
        console.log("   3. Check Pinecone dashboard - are documents visible there?");
      } else {
        console.log(`✅ Index has ${stats.totalVectorCount} vectors (data exists)`);
      }
    } catch (e) {
      console.log("⚠️ Could not verify index emptiness");
    }

    console.log("\n🔍 ===== END DEBUG INFO =====\n");
  } catch (error) {
    console.error("Error in debug function:", error);
  }
}

// In your generateAnswer function, add this right after initializing Pinecone:

export const generateAnswer = onRequest(
  {
    secrets: [PINECONE_API_KEY, COHERE_API_KEY],
    cors: true,
    invoker: "public",
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

      // 🔥 ADD DEBUG HERE
      console.log("🔥 STARTING DEBUG - First request only");
      await debugPineconeState(pineconeIndex, []);

      // Step 1: Build conversation context
      const contextHistory = buildConversationContext(conversationHistory);

      // Step 2: Generate query embedding
      const queryEmbedding = await generateCohereEmbedding(
        query,
        cohereKey,
        "search_query"
      );

      console.log(`✅ Generated embedding with ${queryEmbedding.length} dimensions`);

      // Step 3: Check FAQ first
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

      // Step 4: Enhance query with context
      const contextualQuery = await enhanceQueryWithContext(
        query,
        contextHistory,
        cohereKey
      );

      console.log(`🔍 Contextual query: "${contextualQuery}"`);

      // Step 5: Retrieve relevant documents
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
            message: "Pinecone query returned no results - check Cloud Function logs for details",
            embeddingDimensions: queryEmbedding.length,
            minSimilarityScore: minSimilarityScore,
          },
        });
        return;
      }

      console.log(`📚 Using ${results.length} documents for context`);

      // Step 6: Build document context
      const documentContext = buildDocumentContext(results);

      // Step 7: Create context-aware prompt
      const prompt = buildContextAwarePrompt(
        query,
        documentContext,
        contextHistory
      );

      // Step 8: Generate response
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

function getContextualContent(chunks: any[], bestChunk: any): string {
  try {
    // Log chunk structure for debugging
    console.log(`📝 Processing ${chunks.length} chunk(s)`);
    console.log("📝 Best chunk metadata keys:", Object.keys(bestChunk.metadata || {}));

    if (chunks.length === 1) {
      // Try multiple field names for the text content
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

    // Multiple chunks - need to combine them intelligently
    const sortedChunks = chunks
      .slice()
      .sort(
        (a, b) =>
          (a.metadata?.chunkIndex ?? a.metadata?.chunk_index ?? 0) -
          (b.metadata?.chunkIndex ?? b.metadata?.chunk_index ?? 0)
      );

    const bestChunkIndex = bestChunk.metadata?.chunkIndex ??
                          bestChunk.metadata?.chunk_index ?? 0;

    // Get context chunks (previous, current, and next)
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
    // Fallback: try to extract any text we can find
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
    const faqSnapshot = await admin
      .firestore()
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

    // Log first chunk details for debugging
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
      console.log("💡 Consider lowering minSimilarityScore or check if documents are properly indexed");
      return [];
    }

    const documentChunks: { [key: string]: any[] } = {};

    for (const chunk of filteredChunks) {
      const metadata = chunk.metadata || {};

      // Try multiple ways to extract document ID (flexible matching)
      const originalDocId =
        metadata.docId ||
        metadata.originalDocId ||
        metadata.documentId ||
        metadata.id ||
        chunk.id?.split("_chunk_")[0]; // Extract from chunk ID pattern

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
    const doc = await admin
      .firestore()
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
    
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    
    if (userDoc.exists) {
      const userData = userDoc.data();
      const firestoreRole = userData?.role;
      console.log(`📊 Firestore role: ${firestoreRole}`);
      
      if (firestoreRole === "admin") {
        console.log("✅ User is admin (from Firestore)");
        return true;
      }
    }
    
    // Fallback: Check custom claims
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

/**
 * ➕ Create a new user with auto-verified email (Admin-only)
 * FIXED: Proper error handling for Functions v2
 */
export const createUser = onCall(
  {
    // Add CORS configuration
    cors: true,
  },
  async (request) => {
    console.log("========================================");
    console.log("🔥 createUser function called");
    console.log("📊 Request auth:", JSON.stringify(request.auth, null, 2));
    console.log("📊 Request data:", JSON.stringify(request.data, null, 2));
    console.log("========================================");

    try {
      // Check 1: Is user authenticated?
      if (!request.auth) {
        console.error("❌ No auth context - user not authenticated");
        throw new HttpsError(
          "unauthenticated",
          "You must be logged in as an admin."
        );
      }

      const callerUid = request.auth.uid;
      console.log("✅ User is authenticated: ${callerUid}");
      console.log("📧 User email: ${request.auth.token.email || 'unknown'}");

      // Check 2: Is user an admin?
      const callerIsAdmin = await isAdmin(callerUid);
      
      if (!callerIsAdmin) {
        console.error(`❌ User ${callerUid} is not an admin`);
        throw new HttpsError(
          "permission-denied",
          "Only admins can create users."
        );
      }

      console.log(`✅ User ${callerUid} is confirmed admin`);

      // Validate input
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
      
      // Step 1: Create user in Firebase Authentication with verified email
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: displayName || "",
        emailVerified: true, // Auto-verify email for admin-created users
      });

      console.log(`✅ User created in Auth with UID: ${userRecord.uid}`);

      // Step 2: Create user document in Firestore
      await admin.firestore().collection("users").doc(userRecord.uid).set({
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
        // Since admin created this, mark as verified (no email verification needed)
        isVerified: true,
        emailVerified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        verificationEmailSent: false, // Admin-created users don't need verification emails
      });

      console.log(`✅ User document created in Firestore for UID: ${userRecord.uid}`);

      // Step 3: Log the action
      await admin.firestore().collection("logs").add({
        user: displayName || email,
        action: `Admin created user account (auto-verified, no email sent)`,
        time: admin.firestore.FieldValue.serverTimestamp(),
        userId: userRecord.uid,
        createdBy: callerUid,
      });

      console.log(`✅ User creation complete - No verification email sent (admin-created)`);

      return {
        success: true,
        uid: userRecord.uid,
        email: email,
        message: "User created successfully. Account is already verified and ready to use.",
      };
    } catch (error: any) {
      console.error("❌ Error creating user:", error);
      
      // If it's already an HttpsError, rethrow it
      if (error instanceof HttpsError) {
        throw error;
      }
      
      // Handle specific Firebase Auth errors
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
      
      // Generic error
      console.error("❌ Unhandled error:", error);
      throw new HttpsError(
        "internal",
        error.message || "Failed to create user"
      );
    }
  }
);

/**
 * 🗑️ Delete a user from Authentication and Firestore (Admin-only)
 * FIXED: Proper error handling for Functions v2
 */
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
        await admin.firestore().collection("users").doc(uid).delete();
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

/**
 * ✏️ Update a user's email, password, and display name (Admin-only)
 */
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
        updateData.emailVerified = true; // Keep email verified when admin updates
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

/**
 * 👑 Set or remove admin privileges for a user
 */
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

      // Update Firestore role
      await admin.firestore().collection("users").doc(uid).update({
        role: makeAdmin ? "admin" : "user",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Set custom claims
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