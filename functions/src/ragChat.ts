import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";

// Secrets
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");

// Firestore reference
const db = admin.firestore();


export async function generateCohereEmbedding(
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

export async function generateCohereResponse(
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

// ============================================================================
// MAIN FUNCTION
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