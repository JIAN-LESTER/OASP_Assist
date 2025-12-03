

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { Pinecone } from "@pinecone-database/pinecone";
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
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      throw new Error(`Cohere Embed API error: ${response.statusText}`);
    }

    const data = response.data as { embeddings: number[][] };
    return data.embeddings[0];
  } catch (error) {
    console.error("Error generating Cohere embedding:", error);
    throw error;
  }
}

async function* generateCohereResponseStream(
  prompt: string,
  apiKey: string
): AsyncGenerator<string, void, unknown> {
  try {
    const response = await fetch("https://api.cohere.ai/v1/chat", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "command-a-03-2025",
        message: prompt,
        max_tokens: 1024,
        temperature: 0.3,
        stream: true,
      }),
    });

    if (!response.ok) {
      throw new Error(`Cohere Chat API error: ${response.statusText}`);
    }

    if (!response.body) {
      throw new Error("Response body is null");
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");

      // Keep the last incomplete line in buffer
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmedLine = line.trim();

        // Skip empty lines and comments
        if (!trimmedLine || trimmedLine.startsWith(":")) continue;

        // Remove "data: " prefix
        const jsonStr = trimmedLine.startsWith("data: ")
          ? trimmedLine.substring(6).trim()
          : trimmedLine;

        // Skip DONE signal or empty data
        if (jsonStr === "[DONE]" || !jsonStr) continue;

        try {
          const data = JSON.parse(jsonStr);

          console.log("📦 Stream event:", data.event_type || data.type);

          // Handle different Cohere streaming event types
          if (data.event_type === "text-generation" && data.text) {
            yield data.text;
          } else if (data.event_type === "stream-start") {
            console.log("🌊 Stream started");
          } else if (data.event_type === "search-queries-generation") {
            console.log("🔍 Search queries generated");
          } else if (data.event_type === "search-results") {
            console.log("📚 Search results received");
          } else if (data.event_type === "stream-end") {
            console.log("✅ Stream ended");
            if (data.response && data.response.text) {
              // Some models return final text in stream-end
              yield data.response.text;
            }
            break;
          }
          // Handle alternative format (some Cohere versions use 'type' instead of 'event_type')
          else if (
            data.type === "content-delta" &&
            data.delta?.message?.content?.text
          ) {
            yield data.delta.message.content.text;
          } else if (data.type === "message-end") {
            console.log("✅ Message ended");
            break;
          }
          // Handle error events
          else if (data.event_type === "error" || data.error) {
            throw new Error(data.error || "Stream error occurred");
          }
        } catch (parseError) {
          console.error("⚠️ Error parsing streaming chunk:", parseError);
          console.error("⚠️ Problematic line:", trimmedLine);
          // Continue processing other chunks instead of breaking
          continue;
        }
      }
    }

    console.log("✅ Streaming complete");
  } catch (error) {
    console.error("❌ Error generating Cohere streaming response:", error);
    throw error;
  }
}

/**
 * Non-streaming version (kept for backward compatibility)
 */
export async function generateCohereResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  try {
    const response = await axios.post(
      "https://api.cohere.ai/v1/chat",
      {
        model: "command-a-03-2025",
        message: prompt,
        max_tokens: 1024,
        temperature: 0.3,
      },
      {
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      throw new Error(`Cohere Chat API error: ${response.statusText}`);
    }

    const data = response.data as { text?: string };
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
    console.log(`\n📝 getContextualContent called:`);
    console.log(`   Total chunks: ${chunks.length}`);
    console.log(`   Best chunk ID: ${bestChunk.id}`);

    if (chunks.length === 1) {
      // 🔥 Single chunk - try all possible field names in priority order
      const metadata = bestChunk.metadata || {};

      console.log(`   Metadata keys: ${Object.keys(metadata).join(", ")}`);

      const text =
        metadata.text || // Priority 1: Primary field
        metadata.content || // Priority 2: Fallback
        metadata.chunk_text || // Priority 3: Alternative naming
        metadata.body || // Priority 4: Another alternative
        metadata.message || // Priority 5: For announcements
        "";

      if (!text || text.trim().length === 0) {
        console.log(`⚠️ WARNING: No text content found!`);
        console.log(
          `   Available metadata:`,
          JSON.stringify(metadata, null, 2)
        );
        return "";
      }

      const cleanText = text.trim();
      console.log(`   ✅ Single chunk content: ${cleanText.length} chars`);
      console.log(`   Preview: ${cleanText.substring(0, 150)}...`);
      return cleanText;
    }

    // 🔥 Multiple chunks - combine contextual chunks
    console.log(`   Processing ${chunks.length} chunks for context...`);

    // Sort by chunk index
    const sortedChunks = chunks.slice().sort((a, b) => {
      const aIndex = a.metadata?.chunkIndex ?? a.metadata?.chunk_index ?? 0;
      const bIndex = b.metadata?.chunkIndex ?? b.metadata?.chunk_index ?? 0;
      return aIndex - bIndex;
    });

    const bestChunkIndex =
      bestChunk.metadata?.chunkIndex ?? bestChunk.metadata?.chunk_index ?? 0;

    console.log(`   Best chunk index: ${bestChunkIndex}`);

    // Get surrounding chunks (±1 from best chunk)
    const contextChunks = sortedChunks.filter((chunk) => {
      const chunkIndex =
        chunk.metadata?.chunkIndex ?? chunk.metadata?.chunk_index ?? 0;
      return Math.abs(chunkIndex - bestChunkIndex) <= 1;
    });

    console.log(`   Context chunks selected: ${contextChunks.length}`);

    // Sort context chunks by index
    contextChunks.sort((a, b) => {
      const aIndex = a.metadata?.chunkIndex ?? a.metadata?.chunk_index ?? 0;
      const bIndex = b.metadata?.chunkIndex ?? b.metadata?.chunk_index ?? 0;
      return aIndex - bIndex;
    });

    const contentParts: string[] = [];

    for (let i = 0; i < contextChunks.length; i++) {
      const chunk = contextChunks[i];
      const chunkIndex =
        chunk.metadata?.chunkIndex ?? chunk.metadata?.chunk_index ?? 0;

      // 🔥 Try all possible content field names
      const content =
        chunk.metadata?.text ||
        chunk.metadata?.content ||
        chunk.metadata?.chunk_text ||
        chunk.metadata?.body ||
        chunk.metadata?.message ||
        "";

      const cleanContent = content.trim();

      if (cleanContent.length > 0) {
        contentParts.push(cleanContent);
        console.log(`   ✅ Chunk ${chunkIndex}: ${cleanContent.length} chars`);
      } else {
        console.log(`   ⚠️ Chunk ${chunkIndex}: Empty content`);
        console.log(
          `      Metadata keys: ${Object.keys(chunk.metadata || {}).join(", ")}`
        );
      }
    }

    if (contentParts.length === 0) {
      console.log(
        `❌ No content parts found across ${contextChunks.length} chunks`
      );

      // 🔥 DEBUG: Log first chunk's full metadata
      if (contextChunks.length > 0) {
        console.log(
          `   Sample chunk metadata:`,
          JSON.stringify(contextChunks[0]?.metadata, null, 2)
        );
      }

      return "";
    }

    const result = contentParts.join("\n\n").trim();
    console.log(
      `   ✅ Combined content: ${result.length} chars from ${contentParts.length} chunks`
    );
    console.log(`   Preview: ${result.substring(0, 200)}...`);

    return result;
  } catch (error) {
    console.error("❌ Error in getContextualContent:", error);

    // 🔥 Fallback with detailed logging
    const fallback =
      bestChunk.metadata?.text ||
      bestChunk.metadata?.content ||
      bestChunk.metadata?.message ||
      "";

    console.log(`   Using fallback: ${fallback.length} chars`);
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
      message.content.length > 500
        ? message.content.substring(0, 500) + "..."
        : message.content;
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

// Replace the findMatchingFAQ function in your Cloud Function with this:

async function findMatchingFAQ(
  query: string,
  queryEmbedding: number[],
  cohereApiKey: string,
  similarityThreshold = 0.85 // ✅ LOWERED from 0.85
): Promise<{ question: string; answer: string; similarity: number } | null> {
  try {
    console.log(`🔍 ===========================================`);
    console.log(`🔍 FAQ MATCHING START`);
    console.log(`🔍 Query: "${query}"`);
    console.log(`🔍 Threshold: ${similarityThreshold}`);
    console.log(`🔍 Query embedding dimensions: ${queryEmbedding.length}`);
    console.log(`🔍 ===========================================`);

    // ✅ Only fetch FAQs with non-empty answers
    const faqSnapshot = await db
      .collection("faqs")
      .where("answer", "!=", "")
      .get();

    console.log(
      `📚 Total FAQs retrieved from Firestore: ${faqSnapshot.docs.length}`
    );

    if (faqSnapshot.docs.length === 0) {
      console.log(`❌ No FAQs found in database!`);
      return null;
    }

    let bestMatch: {
      question: string;
      answer: string;
      similarity: number;
    } | null = null;
    let highestSimilarity = 0;
    let processedCount = 0;
    let skippedCount = 0;
    const allSimilarities: Array<{
      id: string;
      question: string;
      similarity: number;
      hasAnswer: boolean;
      hasEmbedding: boolean;
    }> = [];

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const faqQuestion = data.question as string;
      const faqAnswer = data.answer as string;

      // ✅ CRITICAL: Validate all required fields
      if (!faqQuestion || faqQuestion.trim().length === 0) {
        console.log(`⚠️ [${doc.id}] Skipping: No question`);
        skippedCount++;
        continue;
      }

      if (!faqAnswer || faqAnswer.trim().length === 0) {
        console.log(
          `⚠️ [${doc.id}] Skipping: Empty answer for "${faqQuestion.substring(
            0,
            50
          )}..."`
        );
        skippedCount++;
        continue;
      }

      let faqEmbedding: number[];

      // Check if embedding exists
      if (
        data.embedding &&
        Array.isArray(data.embedding) &&
        data.embedding.length > 0
      ) {
        faqEmbedding = data.embedding;
        console.log(
          `✅ [${doc.id}] Using existing embedding (${faqEmbedding.length} dimensions)`
        );
      } else {
        console.log(
          `🔧 [${
            doc.id
          }] Generating new embedding for: "${faqQuestion.substring(0, 50)}..."`
        );

        try {
          // ✅ IMPORTANT: Use "search_document" for FAQs to match the query type
          faqEmbedding = await generateCohereEmbedding(
            faqQuestion,
            cohereApiKey,
            "search_document"
          );

          // Save the embedding
          await doc.ref.update({
            embedding: faqEmbedding,
            embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          console.log(
            `✅ [${doc.id}] Embedding generated and saved (${faqEmbedding.length} dimensions)`
          );
        } catch (embError) {
          console.error(
            `❌ [${doc.id}] Failed to generate embedding:`,
            embError
          );
          skippedCount++;
          continue;
        }
      }

      // ✅ Verify embedding dimensions match
      if (faqEmbedding.length !== queryEmbedding.length) {
        console.log(
          `⚠️ [${doc.id}] Dimension mismatch: FAQ=${faqEmbedding.length}, Query=${queryEmbedding.length}`
        );
        skippedCount++;
        continue;
      }

      // Calculate similarity
      const similarity = cosineSimilarity(queryEmbedding, faqEmbedding);
      processedCount++;

      // Store for analysis
      allSimilarities.push({
        id: doc.id,
        question: faqQuestion.substring(0, 60),
        similarity: similarity,
        hasAnswer: !!faqAnswer,
        hasEmbedding: !!data.embedding,
      });

      console.log(`📊 [${doc.id}]`);
      console.log(`   Question: "${faqQuestion.substring(0, 60)}..."`);
      console.log(`   Answer: ${faqAnswer.length} chars`);
      console.log(
        `   Similarity: ${similarity.toFixed(4)} ${
          similarity >= similarityThreshold
            ? "✅ ABOVE THRESHOLD"
            : "❌ BELOW THRESHOLD"
        }`
      );

      if (similarity > highestSimilarity && similarity >= similarityThreshold) {
        highestSimilarity = similarity;
        bestMatch = {
          question: faqQuestion,
          answer: faqAnswer,
          similarity: similarity,
        };
        console.log(
          `🎯 [${doc.id}] NEW BEST MATCH! Similarity: ${similarity.toFixed(4)}`
        );
      }
    }

    // Summary
    console.log(`📊 ===========================================`);
    console.log(`📊 FAQ MATCHING SUMMARY`);
    console.log(`📊 Total FAQs in DB: ${faqSnapshot.docs.length}`);
    console.log(`📊 Processed: ${processedCount}`);
    console.log(`📊 Skipped: ${skippedCount}`);
    console.log(`📊 Highest Similarity: ${highestSimilarity.toFixed(4)}`);
    console.log(`📊 Threshold: ${similarityThreshold}`);
    console.log(`📊 ===========================================`);

    // Show top 5 matches with more details
    console.log(`🏆 TOP 5 CLOSEST MATCHES:`);
    allSimilarities
      .sort((a, b) => b.similarity - a.similarity)
      .slice(0, 5)
      .forEach((item, index) => {
        const status = item.hasAnswer ? "✅" : "❌";
        const embStatus = item.hasEmbedding ? "✅" : "❌";
        console.log(
          `   ${index + 1}. [${item.similarity.toFixed(
            4
          )}] ${status}Answer ${embStatus}Emb - ${item.question}`
        );
      });

    if (bestMatch) {
      console.log(`✅ ===========================================`);
      console.log(`✅ FAQ MATCH FOUND!`);
      console.log(`✅ Question: "${bestMatch.question}"`);
      console.log(`✅ Similarity: ${bestMatch.similarity.toFixed(4)}`);
      console.log(`✅ Answer length: ${bestMatch.answer.length} chars`);
      console.log(
        `✅ Answer preview: "${bestMatch.answer.substring(0, 100)}..."`
      );
      console.log(`✅ ===========================================`);

      // Update FAQ stats
      const faqDoc = faqSnapshot.docs.find(
        (doc) => doc.data().question === bestMatch!.question
      );
      if (faqDoc) {
        await faqDoc.ref.update({
          similarityCount: admin.firestore.FieldValue.increment(1),
          lastAsked: admin.firestore.FieldValue.serverTimestamp(),
        });
        console.log(`✅ Updated FAQ stats`);
      }
    } else {
      console.log(`❌ ===========================================`);
      console.log(`❌ NO FAQ MATCH FOUND`);
      console.log(`❌ Best similarity: ${highestSimilarity.toFixed(4)}`);
      console.log(`❌ Required: ${similarityThreshold}`);
      console.log(
        `❌ Gap: ${(similarityThreshold - highestSimilarity).toFixed(4)}`
      );
      console.log(`❌ ===========================================`);
    }

    return bestMatch;
  } catch (error) {
    console.error("❌ Error in findMatchingFAQ:", error);
    console.error(
      "Error stack:",
      error instanceof Error ? error.stack : "No stack trace"
    );
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

    console.log(
      "📊 Pinecone response:",
      JSON.stringify({
        matchCount: similarChunks.matches?.length || 0,
        hasMatches: !!similarChunks.matches,
        namespace: similarChunks.namespace,
      })
    );

    if (!similarChunks.matches || similarChunks.matches.length === 0) {
      console.log("❌ No similar document chunks found in Pinecone");
      return [];
    }

    console.log(`📊 Found ${similarChunks.matches.length} similar chunks`);

    // 🔥 NEW: Log first match details for debugging
    if (similarChunks.matches.length > 0) {
      const firstMatch = similarChunks.matches[0];
      console.log(`📝 First match details:`);
      console.log(`   ID: ${firstMatch.id}`);
      console.log(`   Score: ${firstMatch.score}`);
      console.log(
        `   Metadata keys: ${Object.keys(firstMatch.metadata || {}).join(", ")}`
      );
      console.log(`   Has 'text': ${!!firstMatch.metadata?.text}`);
      console.log(`   Has 'content': ${!!firstMatch.metadata?.content}`);
      console.log(`   Text length: ${firstMatch.metadata?.text?.length || 0}`);
      console.log(
        `   Content length: ${firstMatch.metadata?.content?.length || 0}`
      );
    }

    const filteredChunks = similarChunks.matches.filter(
      (chunk: any) => (chunk.score || 0) >= minSimilarityScore
    );

    console.log(
      `✅ Filtered chunks: ${filteredChunks.length} (threshold: ${minSimilarityScore})`
    );

    if (filteredChunks.length === 0) {
      console.log(
        `❌ No chunks meet minimum similarity threshold of ${minSimilarityScore}`
      );
      return [];
    }

    // 🔥 CRITICAL FIX: Better document grouping
    const documentChunks: { [key: string]: any[] } = {};

    for (const chunk of filteredChunks) {
      const metadata = chunk.metadata || {};

      // 🔥 PRIORITY ORDER for docId extraction
      const originalDocId =
        metadata.docId || // Primary
        metadata.originalDocId || // Secondary
        metadata.categoryDocId || // For category-synced docs
        metadata.documentId || // Fallback
        chunk.id?.split("_chunk_")[0]; // Last resort

      console.log(`📝 Processing chunk: ${chunk.id}`);
      console.log(`   docId: ${originalDocId}`);
      console.log(`   score: ${chunk.score?.toFixed(3)}`);
      console.log(
        `   text length: ${
          metadata.text?.length || metadata.content?.length || 0
        }`
      );

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

    console.log(
      `📄 Grouped chunks into ${Object.keys(documentChunks).length} documents`
    );

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

      // Sort by score
      chunks.sort((a, b) => (b.score || 0) - (a.score || 0));

      const bestChunk = chunks[0];
      const bestScore = bestChunk.score || 0;

      console.log(`\n📄 Processing document: ${docId}`);
      console.log(`   Chunks: ${chunks.length}`);
      console.log(`   Best score: ${bestScore.toFixed(3)}`);

      // 🔥 CRITICAL: Get contextual content
      const contextualContent = getContextualContent(chunks, bestChunk);

      if (!contextualContent || contextualContent.trim().length === 0) {
        console.log(
          `⚠️ Empty contextual content for document ${docId}, skipping`
        );
        console.log(
          `   Best chunk metadata:`,
          JSON.stringify(bestChunk.metadata, null, 2)
        );
        continue;
      }

      console.log(`   ✅ Content extracted: ${contextualContent.length} chars`);

      // Try to get metadata from Firestore
      const docMetadata = await getDocumentMetadata(docId);

      const result = {
        ibID: docMetadata?.ibID || docMetadata?.id || docId,
        ib_title:
          docMetadata?.ib_title ||
          docMetadata?.title ||
          bestChunk.metadata?.originalTitle ||
          bestChunk.metadata?.title ||
          bestChunk.metadata?.fileName ||
          "Untitled Document",
        content: contextualContent,
        source: docMetadata?.source || bestChunk.metadata?.source || "Unknown",
        categoryID:
          docMetadata?.category ||
          docMetadata?.categoryID ||
          bestChunk.metadata?.category ||
          bestChunk.metadata?.categoryID ||
          "General",
        similarity_score: bestScore,
        chunk_info: {
          total_chunks_found: chunks.length,
          best_chunk_index:
            bestChunk.metadata?.chunkIndex ||
            bestChunk.metadata?.chunk_index ||
            0,
          is_chunked_document: chunks.length > 1,
        },
      };

      results.push(result);
      console.log(
        `✅ Added result: "${result.ib_title}" (${bestScore.toFixed(3)})`
      );
    }

    // Sort by similarity score
    results.sort((a, b) => b.similarity_score - a.similarity_score);

    const topResults = results.slice(0, topK);

    console.log(`\n🎯 Final results: ${topResults.length} documents retrieved`);
    topResults.forEach((r, i) => {
      console.log(
        `   ${i + 1}. "${r.ib_title}" - ${r.similarity_score.toFixed(3)}`
      );
      console.log(`      Content: ${r.content.substring(0, 100)}...`);
    });

    return topResults;
  } catch (error) {
    console.error("❌ Error retrieving relevant documents:", error);
    return [];
  }
}

async function getDocumentMetadata(docId: string): Promise<any> {
  try {
    const safeDocId = docId.replace(/[/\\]/g, "-");
    const doc = await db.collection("information_bank").doc(safeDocId).get();

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
        minSimilarityScore = 0.2,
        stream = true,
      } = req.body;

      if (!query || typeof query !== "string" || query.trim().length === 0) {
        res.status(400).json({
          answer: "Please provide a valid question.",
          source: "error",
        });
        return;
      }

      console.log(`\n🤖 ========================================`);
      console.log(`🤖 Query: "${query}"`);
      console.log(`🤖 Streaming: ${stream}`);
      console.log(`🤖 Settings: topK=${topK}, minSimilarity=${minSimilarityScore}`);
      console.log(`🤖 ========================================\n`);

      const pineconeKey = PINECONE_API_KEY.value();
      const cohereKey = COHERE_API_KEY.value();

      // Generate embedding
      console.log("🔧 Generating query embedding...");
      const queryEmbedding = await generateCohereEmbedding(
        query,
        cohereKey,
        "search_query"
      );

      console.log(`✅ Embedding: ${queryEmbedding.length} dimensions`);

      // Check FAQ first
      console.log("\n🔍 Checking FAQ database...");
      const faqMatch = await findMatchingFAQ(
        query,
        queryEmbedding,
        cohereKey,
        0.75
      );

      if (faqMatch) {
        console.log(`✅ Using FAQ answer`);

        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");
          res.setHeader("X-Accel-Buffering", "no");

          const answer = faqMatch.answer;
          const chunkSize = 10;

          for (let i = 0; i < answer.length; i += chunkSize) {
            const chunk = answer.substring(
              i,
              Math.min(i + chunkSize, answer.length)
            );
            
            res.write(
              `data: ${JSON.stringify({
                type: "content-delta",
                delta: { message: { content: { text: chunk } } },
              })}\n\n`
            );

            await new Promise((resolve) => setTimeout(resolve, 30));
          }

          res.write(
            `data: ${JSON.stringify({
              type: "message-end",
              metadata: {
                source: "faq",
                faqQuestion: faqMatch.question,
                similarity: faqMatch.similarity,
              },
            })}\n\n`
          );
          res.write("data: [DONE]\n\n");
          res.end();
        } else {
          res.json({
            answer: faqMatch.answer,
            source: "faq",
            faqQuestion: faqMatch.question,
            similarity: faqMatch.similarity,
          });
        }
        return;
      }

      console.log("ℹ️ No FAQ match, proceeding with document retrieval...");

      // Initialize Pinecone
      const pineconeClient = new Pinecone({ apiKey: pineconeKey });
      const pineconeIndex = pineconeClient.Index("oasp-assist");

      // Build conversation context
      const contextHistory = buildConversationContext(conversationHistory);

      // Enhance query
      const contextualQuery = await enhanceQueryWithContext(
        query,
        contextHistory,
        cohereKey
      );

      console.log(`🔍 Enhanced query: "${contextualQuery}"`);

      // ✅ PROGRESSIVE THRESHOLD RETRIEVAL
      console.log(`\n📊 ========================================`);
      console.log(`📊 PROGRESSIVE THRESHOLD SEARCH`);
      console.log(`📊 ========================================`);
      
      const thresholds = [0.35, 0.25, 0.18, 0.12];
      let results: any[] = [];
      let usedThreshold = minSimilarityScore;

      for (const threshold of thresholds) {
        if (threshold < minSimilarityScore) {
          console.log(`⏭️ Skip threshold ${threshold} (below minimum ${minSimilarityScore})`);
          continue;
        }
        
        console.log(`\n🔍 Attempting threshold: ${threshold}`);
        
        results = await retrieveRelevantDocuments(
          contextualQuery,
          queryEmbedding,
          pineconeIndex,
          topK,
          threshold
        );
        
        if (results.length > 0) {
          usedThreshold = threshold;
          console.log(`✅ SUCCESS! Found ${results.length} documents`);
          console.log(`📊 Used threshold: ${threshold}`);
          break;
        }
        
        console.log(`⚠️ No results at ${threshold}, trying lower...`);
      }

      console.log(`\n📊 ========================================`);
      if (results.length === 0) {
        console.log(`❌ FINAL: No documents found (tried all thresholds)`);
      } else {
        console.log(`✅ FINAL: ${results.length} documents (threshold: ${usedThreshold})`);
      }
      console.log(`📊 ========================================\n`);

      let prompt: string;
      let documentContext = "";

      if (results.length === 0) {
        console.log("⚠️ Using general knowledge mode");
        
        prompt = `You are OASP Assist, the official assistant for Central Mindanao University's Office of Admissions, Scholarships, and Placements.

CONTEXT:
The user asked a question but no specific documents were found in the knowledge base.

CONVERSATION HISTORY:
${contextHistory}

CURRENT QUESTION: "${query}"

INSTRUCTIONS:
- Provide a helpful, general answer based on your knowledge about university admissions, scholarships, and placements
- Be honest if you don't have specific information about CMU's policies
- Suggest contacting OASP staff for specific details when appropriate
- Keep your response conversational and helpful

Please provide a helpful response:`;

      } else {
        console.log(`📚 Using ${results.length} documents (threshold: ${usedThreshold})`);
        
        documentContext = buildDocumentContext(results);
        prompt = buildContextAwarePrompt(query, documentContext, contextHistory);
      }

      // Generate response
      if (stream) {
        res.setHeader("Content-Type", "text/event-stream");
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Connection", "keep-alive");
        res.setHeader("X-Accel-Buffering", "no");

        console.log("🌊 Starting streaming response...");

        let hasContent = false;
        let fullResponse = "";

        try {
          for await (const chunk of generateCohereResponseStream(
            prompt,
            cohereKey
          )) {
            if (chunk && chunk.length > 0) {
              hasContent = true;
              fullResponse += chunk;

              res.write(
                `data: ${JSON.stringify({
                  type: "content-delta",
                  delta: { message: { content: { text: chunk } } },
                })}\n\n`
              );
            }
          }

          if (!hasContent) {
            const fallbackMsg =
              "I'm having trouble processing your question right now. Please try again or contact OASP staff for assistance.";
            res.write(
              `data: ${JSON.stringify({
                type: "content-delta",
                delta: { message: { content: { text: fallbackMsg } } },
              })}\n\n`
            );
            fullResponse = fallbackMsg;
          }

          res.write(
            `data: ${JSON.stringify({
              type: "message-end",
              metadata: {
                source: "knowledge_base",
                documentsUsed: results.length,
                documentTitles: results.map((r) => r.ib_title),
                usedThreshold: usedThreshold,
                responseLength: fullResponse.length,
              },
            })}\n\n`
          );
          res.write("data: [DONE]\n\n");
          res.end();

          console.log(`✅ Streaming complete (${fullResponse.length} chars)`);
        } catch (streamError) {
          console.error("❌ Streaming error:", streamError);

          // Send error message to client
          const errorMsg =
            "An error occurred while generating the response. Please try again.";
          res.write(
            `data: ${JSON.stringify({
              type: "content-delta",
              delta: { message: { content: { text: errorMsg } } },
            })}\n\n`
          );
          res.write(
            `data: ${JSON.stringify({
              type: "error",
              error:
                streamError instanceof Error
                  ? streamError.message
                  : "Unknown error",
            })}\n\n`
          );
          res.write("data: [DONE]\n\n");
          res.end();
        }
      } else {
        // Non-streaming response
        console.log("📝 Generating non-streaming response...");

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

        console.log(`✅ Generated answer (${answer.length} chars)`);

        res.json({
          answer: answer.trim(),
          source: "knowledge_base",
          documentsUsed: results.length,
          documentTitles: results.map((r) => r.ib_title),
          topDocumentScores: results.slice(0, 3).map((r) => ({
            title: r.ib_title,
            score: r.similarity_score,
          })),
        });
      }
    } catch (error) {
      console.error("❌ Error in generateAnswer:", error);

      const errorMessage =
        error instanceof Error ? error.message : "Unknown error";

      console.error("Error details:", {
        message: errorMessage,
        stack: error instanceof Error ? error.stack : undefined,
      });

      if (req.body.stream) {
        try {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          const errorMsg =
            "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.";

          res.write(
            `data: ${JSON.stringify({
              type: "content-delta",
              delta: { message: { content: { text: errorMsg } } },
            })}\n\n`
          );
          res.write(
            `data: ${JSON.stringify({
              type: "error",
              error: errorMessage,
            })}\n\n`
          );
          res.write("data: [DONE]\n\n");
          res.end();
        } catch (writeError) {
          console.error("❌ Error writing error response:", writeError);
          if (!res.headersSent) {
            res.status(500).json({
              answer:
                "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.",
              source: "error",
              error: errorMessage,
            });
          }
        }
      } else {
        if (!res.headersSent) {
          res.status(500).json({
            answer:
              "I encountered an error while processing your question. Please try again or contact OASP staff for assistance.",
            source: "error",
            error: errorMessage,
          });
        }
      }
    }
  }
);

export const debugFAQs = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    try {
      const db = admin.firestore();

      console.log("🔍 Checking FAQ collection...");

      const allFAQs = await db.collection("faqs").get();
      console.log(
        `📚 Total documents in 'faqs' collection: ${allFAQs.docs.length}`
      );

      const faqsWithAnswers = await db
        .collection("faqs")
        .where("answer", "!=", "")
        .get();
      console.log(
        `✅ FAQs with non-empty answers: ${faqsWithAnswers.docs.length}`
      );

      const report = {
        total: allFAQs.docs.length,
        withAnswers: faqsWithAnswers.docs.length,
        withoutAnswers: allFAQs.docs.length - faqsWithAnswers.docs.length,
        faqs: [] as any[],
      };

      for (const doc of allFAQs.docs) {
        const data = doc.data();
        const faqInfo = {
          id: doc.id,
          question: data.question || "NO QUESTION",
          hasAnswer: !!(data.answer && data.answer.trim().length > 0),
          answerLength: data.answer ? data.answer.length : 0,
          hasEmbedding: !!(
            data.embedding &&
            Array.isArray(data.embedding) &&
            data.embedding.length > 0
          ),
          embeddingDimensions: data.embedding ? data.embedding.length : 0,
          category: data.category || "NO CATEGORY",
          similarityCount: data.similarityCount || 0,
        };

        report.faqs.push(faqInfo);

        console.log(`
📄 FAQ: ${doc.id}
   Question: ${data.question ? data.question.substring(0, 60) : "MISSING"}...
   Has Answer: ${faqInfo.hasAnswer} (${faqInfo.answerLength} chars)
   Has Embedding: ${faqInfo.hasEmbedding} (${
          faqInfo.embeddingDimensions
        } dimensions)
   Category: ${faqInfo.category}
   Times Asked: ${faqInfo.similarityCount}
        `);
      }

      res.json(report);
    } catch (error) {
      console.error("Error debugging FAQs:", error);
      res
        .status(500)
        .json({
          error: error instanceof Error ? error.message : "Unknown error",
        });
    }
  }
);

export const reembedAllFAQsV3 = onRequest(
  {
    secrets: [COHERE_API_KEY],
    cors: true,
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (req, res) => {
    try {
      const cohereKey = COHERE_API_KEY.value();

      console.log("🔄 Re-embedding all FAQs with embed-multilingual-v3.0");

      const faqSnapshot = await db.collection("faqs").get();
      console.log(`📚 Found ${faqSnapshot.docs.length} FAQs`);

      let successCount = 0;
      let errorCount = 0;

      for (const doc of faqSnapshot.docs) {
        const data = doc.data();
        const question = data.question as string;

        if (!question) {
          errorCount++;
          continue;
        }

        try {
          console.log(
            `🔧 [${doc.id}] Embedding: "${question.substring(0, 50)}..."`
          );

          const response = await axios.post(
            "https://api.cohere.ai/v1/embed",
            {
              texts: [question],
              model: "embed-multilingual-v3.0",
              input_type: "search_document", // FAQs are documents
            },
            {
              headers: {
                Authorization: `Bearer ${cohereKey}`,
                "Content-Type": "application/json",
              },
              timeout: 30000,
            }
          );

          const embedding = (response.data as { embeddings: number[][] })
            .embeddings[0];

          await doc.ref.update({
            embedding: embedding,
            embeddingModel: "embed-multilingual-v3.0",
            embeddingDimensions: embedding.length,
            embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          successCount++;
          console.log(`✅ [${doc.id}] Done - ${embedding.length} dims`);

          // Rate limit protection
          await new Promise((resolve) => setTimeout(resolve, 100));
        } catch (error) {
          errorCount++;
          console.error(`❌ [${doc.id}] Failed:`, error);
        }
      }

      console.log(`✅ Complete: ${successCount} success, ${errorCount} errors`);

      res.json({
        success: true,
        model: "embed-multilingual-v3.0",
        total: faqSnapshot.docs.length,
        successCount,
        errorCount,
      });
    } catch (error) {
      console.error("❌ Error:", error);
      res.status(500).json({ error: String(error) });
    }
  }
);



export const debugPineconeVector = onRequest(
  {
    secrets: [PINECONE_API_KEY],
    cors: true,
  },
  async (req, res) => {
    try {
      const { vectorId, query } = req.body;

      const pineconeKey = PINECONE_API_KEY.value();
      const pineconeClient = new Pinecone({ apiKey: pineconeKey });
      const pineconeIndex = pineconeClient.Index("oasp-assist");

      if (vectorId) {
        // Fetch specific vector by ID
        const result = await pineconeIndex.fetch([vectorId]);

        res.json({
          success: true,
          vector: result.records?.[vectorId],
          metadata: result.records?.[vectorId]?.metadata,
          metadataKeys: Object.keys(result.records?.[vectorId]?.metadata || {}),
          hasText: !!result.records?.[vectorId]?.metadata?.text,
          hasContent: !!result.records?.[vectorId]?.metadata?.content,
          textLength:
            typeof result.records?.[vectorId]?.metadata?.text === "string"
              ? result.records?.[vectorId]?.metadata?.text.length
              : Array.isArray(result.records?.[vectorId]?.metadata?.text)
              ? result.records?.[vectorId]?.metadata?.text.length
              : 0,
          contentLength:
            typeof result.records?.[vectorId]?.metadata?.content === "string"
              ? result.records?.[vectorId]?.metadata?.content.length
              : Array.isArray(result.records?.[vectorId]?.metadata?.content)
              ? result.records?.[vectorId]?.metadata?.content.length
              : 0,
        });
      } else if (query) {
        // Query similar vectors
        const cohereKey = COHERE_API_KEY.value();
        const embedding = await generateCohereEmbedding(
          query,
          cohereKey,
          "search_query"
        );

        const queryResult = await pineconeIndex.query({
          vector: embedding,
          topK: 5,
          includeMetadata: true,
        });

        const matches = queryResult.matches?.map((match) => {
          const rawText = match.metadata?.text ?? match.metadata?.content ?? "";
          let textPreview = "";
          if (typeof rawText === "string") {
            textPreview = rawText.substring(0, 200);
          } else if (Array.isArray(rawText)) {
            textPreview = rawText.join(" ").substring(0, 200);
          } else {
            textPreview = String(rawText).substring(0, 200);
          }
          return {
            id: match.id,
            score: match.score,
            metadataKeys: Object.keys(match.metadata || {}),
            hasText: !!match.metadata?.text,
            hasContent: !!match.metadata?.content,
            textPreview,
            title: match.metadata?.title || match.metadata?.originalTitle,
            source: match.metadata?.source,
            category: match.metadata?.category,
          };
        });

        res.json({
          success: true,
          query,
          matchCount: matches?.length || 0,
          matches,
        });
      } else {
        res.status(400).json({ error: "Provide either vectorId or query" });
      }
    } catch (error: any) {
      console.error("Error:", error);
      res.status(500).json({ error: error.message });
    }
  }
);
