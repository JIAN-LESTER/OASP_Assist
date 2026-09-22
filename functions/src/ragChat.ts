/* eslint-disable no-empty */
/* eslint-disable no-useless-catch */
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";
import {onSchedule} from "firebase-functions/scheduler";
import {Firestore, FieldValue} from "@google-cloud/firestore";
import {
  COHERE_EMBEDDING_DIMENSIONS,
  COHERE_EMBEDDING_MODEL,
  PINECONE_INDEX_NAME,
  createCohereEmbedding,
  normalizeCohereInputType,
} from "./cohereEmbedding";

type JsonResponse = Record<string, any>;
type FAQMatch = {
  question: string;
  answer: string;
  similarity: number;
  category: string;
};

// Secrets
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");

const db = admin.firestore();

// ============================================================================
// GEMINI FUNCTIONS
// ============================================================================

const firestore = new Firestore();

async function logGeminiUsage({userId, conversationId, model, inputTokens, outputTokens}: {
  userId: string | null;
  conversationId: string | null;
  model: string;
  inputTokens: number;
  outputTokens: number;
}) {
  // Pricing per 1M tokens (USD) - update if Google changes pricing
  // https://ai.google.dev/pricing
  const PRICES: Record<string, {input: number; output: number}> = {
    "gemini-2.5-flash": {input: 0.30, output: 2.50},
    "gemini-2.5-flash-lite": {input: 0.10, output: 0.40},
    "gemini-embedding-001": {input: 0.15, output: 0.00},
    "gemini-2.0-flash": {input: 0.10, output: 0.40},
    "gemini-1.5-flash": {input: 0.075, output: 0.30},
    "gemini-1.5-pro": {input: 1.25, output: 5.00},
    "gemini-pro": {input: 0.50, output: 1.50},
  };

  const pricing = PRICES[model] ?? PRICES["gemini-2.0-flash"];
  const inputCostUsd = (inputTokens / 1_000_000) * pricing.input;
  const outputCostUsd = (outputTokens / 1_000_000) * pricing.output;
  const totalCostUsd = inputCostUsd + outputCostUsd;
  const USD_TO_PHP = parseFloat(process.env.USD_TO_PHP ?? "56");

  await firestore.collection("gemini_usage").add({
    userId: userId ?? null,
    conversationId: conversationId ?? null,
    model: model,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    totalTokens: inputTokens + outputTokens,
    costUsd: totalCostUsd,
    costPhp: totalCostUsd * USD_TO_PHP,
    timestamp: FieldValue.serverTimestamp(),
    date: new Date().toISOString().substring(0, 10), // "YYYY-MM-DD"
  });
}

const GEMINI_MODEL = "gemini-3.5-flash-lite";
const GEMINI_FALLBACK_MODEL = "gemini-3.5-flash";
const COHERE_MODEL = "command-r-08-2024";
const MAX_CONTEXT_CHARS = 2400;
const MAX_HISTORY_CHARS = 140;
const FAQ_SIMILARITY_THRESHOLD = 0.88;
const FAQ_STRONG_SIMILARITY = 0.92;
const FAQ_SIMILARITY_MARGIN = 0.03;
function getAxiosErrorMessage(error: any): string {
  return error.response?.data?.error?.message ??
    error.message ??
    "Unknown error";
}

function limitText(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return `${text.substring(0, maxChars).trim()}...`;
}

function buildFAQContext(question: string, answer: string): string {
  return limitText(`Q: ${question}\nA: ${answer}`, 700);
}

function normalizeFAQText(text: string): string {
  return text
    .trim()
    .toLowerCase()
    .replace(/[^\w\s]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export const generateCohereEmbedding = onCall(
  {secrets: [COHERE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {text, taskType} = request.data;
    if (!text) throw new Error("Text required");

    const embedding = await createCohereEmbedding(
      text,
      COHERE_API_KEY.value(),
      normalizeCohereInputType(taskType)
    );
    console.info(`Cohere embedding generated: ${embedding.length} dimensions`);
    return {embedding};
  }
);

export const generateEmbedding = onCall(
  {secrets: [COHERE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");
    const {text, taskType} = request.data;
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Text required");
    }

    try {
      const embedding = await createCohereEmbedding(
        text.trim(),
        COHERE_API_KEY.value(),
        normalizeCohereInputType(taskType)
      );
      console.info(`Cohere embedding generated: ${embedding.length} dimensions`);
      return {embedding};
    } catch (error: any) {
      const msg = getAxiosErrorMessage(error);
      console.error("Cohere embedding error:", msg);
      console.error(
        "Cohere embedding response:",
        JSON.stringify(error.response?.data ?? {})
      );
      throw new HttpsError("internal", `Embedding failed: ${msg}`);
    }
  }
);

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

async function findMatchingFAQ(
  _query: string,
  queryEmbedding: number[],
  cohereApiKey: string,
  similarityThreshold = FAQ_SIMILARITY_THRESHOLD
): Promise<FAQMatch | null> {
  try {
    const faqSnapshot = await db
      .collection("faqs")
      .where("answer", "!=", "")
      .get();


    let bestMatch: any = null;
    let highestSimilarity = 0;
    let secondHighestSimilarity = 0;
    let validFaqCount = 0;

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const faqQuestion = data.question as string;
      const faqAnswer = data.answer as string;

      if (!faqQuestion || !faqAnswer) continue;

      let faqEmbedding: number[];
      const storedEmbedding =
        data.cohereEmbedding ??
        data.contextEmbedding ??
        data.faqContextEmbedding ??
        data.embedding ??
        data.geminiEmbedding;

      if (storedEmbedding && Array.isArray(storedEmbedding) &&
          storedEmbedding.length === COHERE_EMBEDDING_DIMENSIONS) {
        faqEmbedding = storedEmbedding as number[];
      } else {
        faqEmbedding = await createCohereEmbedding(
          buildFAQContext(faqQuestion, faqAnswer),
          cohereApiKey,
          "search_document"
        );

        await doc.ref.update({
          embedding: faqEmbedding,
          cohereEmbedding: faqEmbedding,
          contextEmbedding: faqEmbedding,
          faqContextEmbedding: faqEmbedding,
          embeddingModel: COHERE_EMBEDDING_MODEL,
          embeddingDimensions: COHERE_EMBEDDING_DIMENSIONS,
          embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (faqEmbedding.length !== queryEmbedding.length) {
        continue;
      }

      const similarity = cosineSimilarity(queryEmbedding, faqEmbedding);
      validFaqCount++;

      if (similarity > highestSimilarity) {
        secondHighestSimilarity = highestSimilarity;
        highestSimilarity = similarity;
        if (similarity >= similarityThreshold) {
          bestMatch = {
            question: faqQuestion,
            answer: faqAnswer,
            category: data.category || "General",
            similarity: similarity,
          };
        }
      } else if (similarity > secondHighestSimilarity) {
        secondHighestSimilarity = similarity;
      }
    }

    if (
      bestMatch &&
      validFaqCount > 1 &&
      highestSimilarity < FAQ_STRONG_SIMILARITY &&
      highestSimilarity - secondHighestSimilarity < FAQ_SIMILARITY_MARGIN
    ) {
      return null;
    }

    return bestMatch;
  } catch {
    return null;
  }
}

async function findDirectFAQMatch(query: string): Promise<FAQMatch | null> {
  const trimmedQuery = query.trim();
  const normalizedQuery = normalizeFAQText(trimmedQuery);

  if (!normalizedQuery) return null;

  try {
    const exactSnapshot = await db
      .collection("faqs")
      .where("question", "==", trimmedQuery)
      .limit(1)
      .get();

    for (const doc of exactSnapshot.docs) {
      const data = doc.data();
      const answer = data.answer as string;
      const question = data.question as string;

      if (question && answer && answer.trim()) {
        return {
          question,
          answer,
          category: data.category || "General",
          similarity: 1,
        };
      }
    }

    const normalizedSnapshot = await db
      .collection("faqs")
      .where("questionNormalized", "==", normalizedQuery)
      .limit(1)
      .get();

    for (const doc of normalizedSnapshot.docs) {
      const data = doc.data();
      const answer = data.answer as string;
      const question = data.question as string;

      if (question && answer && answer.trim()) {
        return {
          question,
          answer,
          category: data.category || "General",
          similarity: 1,
        };
      }
    }

    const faqSnapshot = await db.collection("faqs").limit(200).get();

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const answer = data.answer as string;
      const question = data.question as string;
      const storedNormalizedQuestion =
        data.questionNormalized as string | undefined;
      const normalizedQuestion =
        storedNormalizedQuestion || normalizeFAQText(question || "");

      if (
        question &&
        answer &&
        answer.trim() &&
        normalizedQuestion === normalizedQuery
      ) {
        return {
          question,
          answer,
          category: data.category || "General",
          similarity: 1,
        };
      }
    }
  } catch (error) {
    console.warn("Direct FAQ lookup failed:", error);
  }

  return null;
}

async function retrieveRelevantDocuments(
  query: string,
  queryEmbedding: number[],
  pineconeIndex: any,
  topK = 5,
  minSimilarityScore = 0.30
): Promise<Array<{
  ibID: string;
  ib_title: string;
  content: string;
  source: string;
  categoryID: string;
  similarity_score: number;
  chunk_info: any;
}>> {
  try {
    const similarChunks = await pineconeIndex.query({
      vector: queryEmbedding,
      topK: topK * 8,
      includeMetadata: true,
    });

    if (!similarChunks.matches || similarChunks.matches.length === 0) {
      return [];
    }

    const filteredChunks = similarChunks.matches.filter(
      (chunk: any) => (chunk.score || 0) >= minSimilarityScore
    );

    const documentChunks: { [key: string]: any[] } = {};

    for (const chunk of filteredChunks) {
      const metadata = chunk.metadata || {};
      const docId = metadata.docId || metadata.originalDocId || chunk.id?.split("_chunk_")[0];

      if (docId) {
        if (!documentChunks[docId]) {
          documentChunks[docId] = [];
        }
        documentChunks[docId].push({...chunk, metadata});
      }
    }

    const queryTerms = getSearchTerms(query);
    const results: any[] = [];

    for (const docId of Object.keys(documentChunks)) {
      let chunks = documentChunks[docId];
      chunks.sort((a, b) => (b.score || 0) - (a.score || 0));

      const bestChunk = chunks[0];
      const bestChunkIndex = getChunkIndex(bestChunk);

      // Run a document-scoped query so the chunks immediately before and after
      // the best semantic match are available even when they were not global
      // top matches.
      if (bestChunkIndex !== null) {
        try {
          const documentMatches = await pineconeIndex.query({
            vector: queryEmbedding,
            topK: 100,
            includeMetadata: true,
            filter: {docId: {$eq: docId}},
          });
          if (documentMatches.matches?.length) {
            chunks = documentMatches.matches.map((chunk: any) => ({
              ...chunk,
              metadata: chunk.metadata || {},
            }));
          }
        } catch (error) {
          console.warn(`Adjacent chunk lookup failed for ${docId}:`, error);
        }
      }

      const contextualChunks = selectContextualChunks(
        chunks,
        bestChunk,
        bestChunkIndex
      );
      const combinedContent = contextualChunks
        .map((c) => c.metadata?.text || c.metadata?.content || c.metadata?.chunk_text || "")
        .filter((text) => text.trim())
        .join("\n\n");

      if (!combinedContent.trim()) continue;

      const title = bestChunk.metadata?.originalTitle ||
        bestChunk.metadata?.title || "Untitled";
      const vectorScore = bestChunk.score || 0;
      const lexicalScore = calculateLexicalScore(
        queryTerms,
        `${title}\n${combinedContent}`
      );

      results.push({
        ibID: docId,
        ib_title: title,
        content: combinedContent.trim(),
        source: bestChunk.metadata?.source || "Unknown",
        categoryID: bestChunk.metadata?.category || "General",
        similarity_score: vectorScore,
        ranking_score: (vectorScore * 0.8) + (lexicalScore * 0.2),
        chunk_info: {
          total_chunks_found: chunks.length,
          chunks_used: contextualChunks.length,
          best_chunk_index: bestChunkIndex,
        },
      });
    }

    results.sort((a, b) => b.ranking_score - a.ranking_score);
    console.info(
      `Retrieved ${results.length} documents for query; ` +
      `top score=${results[0]?.ranking_score?.toFixed(3) ?? "n/a"}`
    );
    return results.slice(0, topK);
  } catch (error) {
    console.error("Pinecone document retrieval failed:", error);
    return [];
  }
}

function getChunkIndex(chunk: any): number | null {
  const value = chunk?.metadata?.chunkIndex ?? chunk?.metadata?.chunk_index;
  return Number.isInteger(value) ? value : null;
}

function selectContextualChunks(
  chunks: any[],
  bestChunk: any,
  bestChunkIndex: number | null
): any[] {
  if (bestChunkIndex === null) return [bestChunk];

  const adjacent = chunks
    .filter((chunk) => {
      const index = getChunkIndex(chunk);
      return index !== null && Math.abs(index - bestChunkIndex) <= 1;
    })
    .sort((a, b) => (getChunkIndex(a) ?? 0) - (getChunkIndex(b) ?? 0));

  return adjacent.length > 0 ? adjacent : [bestChunk];
}

function getSearchTerms(text: string): string[] {
  const stopWords = new Set([
    "a", "an", "and", "are", "for", "how", "is", "of", "on", "the",
    "to", "what", "when", "where", "which", "who", "why",
  ]);
  return Array.from(new Set(
    normalizeFAQText(text).split(" ")
      .filter((term) => term.length > 1 && !stopWords.has(term))
  ));
}

function calculateLexicalScore(queryTerms: string[], text: string): number {
  if (queryTerms.length === 0) return 0;
  const searchableText = ` ${normalizeFAQText(text)} `;
  const matchedTerms = queryTerms.filter(
    (term) => searchableText.includes(` ${term} `)
  ).length;
  return matchedTerms / queryTerms.length;
}

export const generateAnswer = onRequest(
  {
    secrets: [PINECONE_API_KEY, GEMINI_API_KEY, COHERE_API_KEY],
    cors: true,
    timeoutSeconds: 60,
    memory: "1GiB",
  },
  async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set(
      "Access-Control-Allow-Headers",
      "Content-Type, Accept, Authorization, X-Requested-With"
    );
    res.set("Access-Control-Max-Age", "3600");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed", answer: "Please use POST method"});
      return;
    }

    let stage = "initializing";

    try {
      const {
        query,
        conversationHistory = [],
        topK = 5,
        minSimilarityScore = 0.30,
        stream = true,
      } = req.body;

      if (!query || typeof query !== "string" || query.trim().length === 0) {
        res.status(400).json({
          error: "Invalid query",
          answer: "Please provide a valid question.",
          source: "error",
        });
        return;
      }

      // Exact FAQ matching applies to both typed questions and FAQ selections.
      stage = "direct_faq_lookup";
      const directFAQMatch = await findDirectFAQMatch(query);
      if (directFAQMatch) {
        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");
          res.setHeader("X-Accel-Buffering", "no");

          const answer = directFAQMatch.answer;
          const chunkSize = 40;

          for (let i = 0; i < answer.length; i += chunkSize) {
            const chunk = answer.substring(i, Math.min(i + chunkSize, answer.length));
            res.write(`data: ${JSON.stringify({
              type: "content-delta",
              delta: {message: {content: {text: chunk}}},
            })}\n\n`);
          }

          res.write(`data: ${JSON.stringify({
            type: "message-end",
            metadata: {source: "faq", category: directFAQMatch.category},
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } else {
          res.json({
            answer: directFAQMatch.answer,
            source: "faq",
            category: directFAQMatch.category,
          });
        }
        return;
      }


      const geminiKey = GEMINI_API_KEY.value();
      const cohereKey = COHERE_API_KEY.value();
      const pineconeKey = PINECONE_API_KEY.value();

      stage = "query_embedding";
      const [queryEmbedding, pineconeClient] = await Promise.all([
        createCohereEmbedding(query, cohereKey, "search_query"),
        Promise.resolve(new Pinecone({apiKey: pineconeKey})),
      ]);

      stage = "semantic_faq_lookup";
      const [faqMatch, pineconeIndex] = await Promise.all([
        findMatchingFAQ(query, queryEmbedding, cohereKey),
        Promise.resolve(pineconeClient.Index(PINECONE_INDEX_NAME)),
      ]);

      // FAQ MATCH
      if (faqMatch) {
        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          const answer = faqMatch.answer;
          const chunkSize = 40;

          for (let i = 0; i < answer.length; i += chunkSize) {
            const chunk = answer.substring(i, Math.min(i + chunkSize, answer.length));
            res.write(`data: ${JSON.stringify({
              type: "content-delta",
              delta: {message: {content: {text: chunk}}},
            })}\n\n`);
          }

          res.write(`data: ${JSON.stringify({
            type: "message-end",
            metadata: {source: "faq", category: faqMatch.category},
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } else {
          res.json({
            answer: faqMatch.answer,
            source: "faq",
            category: faqMatch.category,
          });
        }
        return;
      }

      // RETRIEVE DOCUMENTS FROM PINECONE
      stage = "pinecone_retrieval";
      const results = await retrieveRelevantDocuments(
        query,
        queryEmbedding,
        pineconeIndex,
        topK,
        minSimilarityScore
      );

      // NO DOCUMENTS FOUND - AI FALLBACK
      if (results.length === 0) {
        const conversationContext = buildConversationContext(conversationHistory);
        const dateInfo = new Date().toISOString().substring(0, 10);

        const fallbackPrompt = `OASP Assist, CMU. Date: ${dateInfo}
${conversationContext ? `History:\n${conversationContext}\n` : ""}Q: ${query}
Rules: Start immediately with the answer. Never begin with "Based on" or refer to the document, policy, KB, context, or provided information. Include only supported answer content. Do not mention missing or unknown information, contacting staff, or escalation.
A:`;

        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          try {
            stage = "ai_fallback_stream";
            for await (const chunk of generateResponseStreamWithFallback(
              fallbackPrompt,
              geminiKey,
              cohereKey
            )) {
              if (chunk && chunk.length > 0) {
                res.write(`data: ${JSON.stringify({
                  type: "content-delta",
                  delta: {message: {content: {text: chunk}}},
                })}\n\n`);
              }
            }

            res.write(`data: ${JSON.stringify({
              type: "message-end",
              metadata: {source: "ai_fallback"},
            })}\n\n`);
            res.write("data: [DONE]\n\n");
            res.end();
          } catch {
            const errorMsg = "I'm having trouble processing your request. Please try again.";
            res.write(`data: ${JSON.stringify({
              type: "content-delta",
              delta: {message: {content: {text: errorMsg}}},
            })}\n\n`);
            res.write(`data: ${JSON.stringify({type: "message-end"})}\n\n`);
            res.write("data: [DONE]\n\n");
            res.end();
          }
        } else {
          try {
            stage = "ai_fallback_generate";
            const answer = await generateResponseWithFallback(
              fallbackPrompt,
              geminiKey,
              cohereKey
            );
            res.json({answer: answer.trim(), source: "ai_fallback"});
          } catch {
            res.json({
              answer: "I'm having trouble processing your request. Please try again.",
              source: "error",
            });
          }
        }
        return;
      }

      // DOCUMENTS FOUND - GENERATE RAG RESPONSE

      const {contexts, confidence} = filterAndRankContext(results);
      const conversationContext = buildConversationContext(conversationHistory);

      const prompt = confidence === "low" ?
        buildPartialInfoPrompt(query, contexts, conversationContext) :
        buildContextAwarePrompt(query, contexts, conversationContext, confidence);

      // STREAMING RESPONSE
      if (stream) {
        res.setHeader("Content-Type", "text/event-stream");
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Connection", "keep-alive");

        let streamSucceeded = false;

        try {
          stage = "rag_stream";
          for await (const chunk of generateResponseStreamWithFallback(
            prompt,
            geminiKey,
            cohereKey
          )) {
            if (chunk && chunk.length > 0) {
              streamSucceeded = true;
              res.write(`data: ${JSON.stringify({
                type: "content-delta",
                delta: {message: {content: {text: chunk}}},
              })}\n\n`);
            }
          }

          if (streamSucceeded) {
            res.write(`data: ${JSON.stringify({
              type: "message-end",
              metadata: {source: "information_bank", confidence, documentsUsed: contexts.length},
            })}\n\n`);
            res.write("data: [DONE]\n\n");
            res.end();
            return;
          }
        } catch (error: any) {
          console.error("RAG response stream failed:", getAxiosErrorMessage(error));
          if (streamSucceeded) {
            res.write(`data: ${JSON.stringify({
              type: "error",
              error: "The response stream ended unexpectedly",
            })}\n\n`);
            res.end();
            return;
          }
        }

        // FALLBACK IF STREAMING FAILS
        try {
          stage = "rag_generate_fallback";
          const fullAnswer = await generateResponseWithFallback(
            prompt,
            geminiKey,
            cohereKey
          );

          const chunkSize = 30;
          for (let i = 0; i < fullAnswer.length; i += chunkSize) {
            const chunk = fullAnswer.substring(i, Math.min(i + chunkSize, fullAnswer.length));
            res.write(`data: ${JSON.stringify({
              type: "content-delta",
              delta: {message: {content: {text: chunk}}},
            })}\n\n`);
            await new Promise((resolve) => setTimeout(resolve, 5));
          }

          res.write(`data: ${JSON.stringify({
            type: "message-end",
            metadata: {source: "information_bank", confidence},
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } catch {
          res.write(`data: ${JSON.stringify({
            type: "error",
            error: "Failed to generate response",
          })}\n\n`);
          res.end();
        }
      } else {
        stage = "rag_generate";
        const answer = await generateResponseWithFallback(
          prompt,
          geminiKey,
          cohereKey
        );
        res.json({
          answer: answer.trim(),
          source: "information_bank",
          confidence,
          documentsFound: results.length,
        });
      }
    } catch (error: any) {
      const errorMessage = getAxiosErrorMessage(error);
      console.error(`generateAnswer failed during ${stage}:`, errorMessage);
      if (error.response?.data) {
        console.error(
          "generateAnswer upstream response:",
          JSON.stringify(error.response.data)
        );
      }

      const answer =
        "I'm having trouble processing your request right now. Please try again.";

      if (req.body?.stream && !res.writableEnded) {
        if (!res.headersSent) {
          res.status(200);
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");
          res.setHeader("X-Accel-Buffering", "no");
        }

        res.write(`data: ${JSON.stringify({
          type: "content-delta",
          delta: {message: {content: {text: answer}}},
        })}\n\n`);
        res.write(`data: ${JSON.stringify({
          type: "error",
          error: errorMessage,
        })}\n\n`);
        res.write("data: [DONE]\n\n");
        res.end();
        return;
      }

      res.status(500).json({
        error: errorMessage,
        answer,
        source: "error",
      });
    }
  }
);

async function generateGeminiResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  let lastError: unknown;

  for (const model of [GEMINI_MODEL, GEMINI_FALLBACK_MODEL]) {
    try {
      const response = await axios.post<JsonResponse>(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {
            temperature: 0.3,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 1024,
          },
        },
        {
          headers: {"Content-Type": "application/json"},
          timeout: 30000,
        }
      );

      const data: any = response.data;
      const text = extractGeminiText(data);

      if (!text) {
        throw new Error(
          data?.promptFeedback?.blockReason ?
            `Gemini blocked the prompt: ${data.promptFeedback.blockReason}` :
            "Empty response from Gemini"
        );
      }

      const usageMetadata = data?.usageMetadata;
      if (usageMetadata) {
        await logGeminiUsage({
          userId: null,
          conversationId: null,
          model,
          inputTokens: usageMetadata.promptTokenCount ?? 0,
          outputTokens: usageMetadata.candidatesTokenCount ?? 0,
        }).catch(() => undefined);
      }

      return text;
    } catch (error: any) {
      lastError = error;
      console.error(`Gemini ${model} response failed:`, getAxiosErrorMessage(error));
    }
  }

  throw lastError instanceof Error ? lastError : new Error("Gemini response failed");
}

async function generateCohereResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  try {
    const response = await axios.post<JsonResponse>(
      "https://api.cohere.com/v2/chat",
      {
        model: COHERE_MODEL,
        messages: [{role: "user", content: prompt}],
        temperature: 0.3,
        max_tokens: 1024,
      },
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    const content = response.data?.message?.content;
    const text = Array.isArray(content) ? content
      .map((part: any) => typeof part?.text === "string" ? part.text : "")
      .filter((part: string) => part.length > 0)
      .join("") : "";

    if (!text) {
      throw new Error("Empty response from Cohere");
    }

    console.info(`Cohere fallback generation succeeded with ${COHERE_MODEL}`);
    return text;
  } catch (error: any) {
    console.error("Cohere fallback generation failed:", getAxiosErrorMessage(error));
    throw error;
  }
}

async function generateResponseWithFallback(
  prompt: string,
  geminiKey: string,
  cohereKey: string
): Promise<string> {
  try {
    return await generateGeminiResponse(prompt, geminiKey);
  } catch (error: any) {
    console.warn(
      "Gemini generation unavailable; switching to Cohere:",
      getAxiosErrorMessage(error)
    );
    return generateCohereResponse(prompt, cohereKey);
  }
}

function extractGeminiText(data: any): string {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return "";

  return parts
    .map((part: any) => typeof part?.text === "string" ? part.text : "")
    .filter((text: string) => text.length > 0)
    .join("");
}


async function* generateGeminiResponseStream(
  prompt: string,
  apiKey: string
): AsyncGenerator<string, void, unknown> {
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:streamGenerateContent?alt=sse&key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {
            temperature: 0.3,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 1024,
          },
        }),
      }
    );

    if (!response.ok) {
      throw new Error(`Gemini Stream API error: ${response.status} ${response.statusText}`);
    }

    if (!response.body) {
      throw new Error("Response body is null");
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const {done, value} = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, {stream: true});
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmedLine = line.trim();

        if (!trimmedLine || trimmedLine.startsWith("event:") || trimmedLine === "data: [DONE]") {
          continue;
        }

        const jsonStr = trimmedLine.startsWith("data: ") ?
          trimmedLine.substring(6) :
          trimmedLine;

        if (!jsonStr || jsonStr === "[DONE]") continue;

        try {
          const data = JSON.parse(jsonStr);
          const text = extractGeminiText(data);

          if (text) {
            yield text;
          }

          const finishReason = data?.candidates?.[0]?.finishReason;
          if (finishReason === "STOP") {
            return;
          }
        } catch {
          continue;
        }
      }
    }

    // A final SSE event may not end with a newline.
    const finalLine = buffer.trim();
    if (finalLine && !finalLine.startsWith("event:") && finalLine !== "data: [DONE]") {
      const jsonStr = finalLine.startsWith("data: ") ?
        finalLine.substring(6) : finalLine;
      if (jsonStr && jsonStr !== "[DONE]") {
        try {
          const data = JSON.parse(jsonStr);
          const text = extractGeminiText(data);
          if (text) yield text;
        } catch {
          // Ignore an incomplete final event.
        }
      }
    }
  } catch (error) {
    throw error;
  }
}

async function* generateCohereResponseStream(
  prompt: string,
  apiKey: string
): AsyncGenerator<string, void, unknown> {
  const response = await fetch("https://api.cohere.com/v2/chat", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: COHERE_MODEL,
      messages: [{role: "user", content: prompt}],
      temperature: 0.3,
      max_tokens: 1024,
      stream: true,
    }),
  });

  if (!response.ok) {
    throw new Error(
      `Cohere Stream API error: ${response.status} ${response.statusText}`
    );
  }
  if (!response.body) {
    throw new Error("Cohere response body is null");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const {done, value} = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, {stream: true});
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";

    for (const line of lines) {
      const trimmedLine = line.trim();
      if (!trimmedLine.startsWith("data:")) continue;

      const jsonText = trimmedLine.substring(5).trim();
      if (!jsonText || jsonText === "[DONE]") continue;

      try {
        const event = JSON.parse(jsonText);
        if (event?.type === "content-delta") {
          const text = event?.delta?.message?.content?.text;
          if (typeof text === "string" && text.length > 0) yield text;
        }
      } catch {
        // Ignore malformed or incomplete SSE events.
      }
    }
  }

  const finalLine = buffer.trim();
  if (finalLine.startsWith("data:")) {
    try {
      const event = JSON.parse(finalLine.substring(5).trim());
      const text = event?.type === "content-delta" ?
        event?.delta?.message?.content?.text : "";
      if (typeof text === "string" && text.length > 0) yield text;
    } catch {
      // Ignore an incomplete final event.
    }
  }
}

async function* generateResponseStreamWithFallback(
  prompt: string,
  geminiKey: string,
  cohereKey: string
): AsyncGenerator<string, void, unknown> {
  let geminiEmittedContent = false;

  try {
    for await (const chunk of generateGeminiResponseStream(prompt, geminiKey)) {
      geminiEmittedContent = true;
      yield chunk;
    }
    if (!geminiEmittedContent) throw new Error("Gemini returned an empty stream");
    return;
  } catch (error: any) {
    if (geminiEmittedContent) {
      console.error(
        "Gemini stream failed after emitting content; Cohere fallback skipped:",
        getAxiosErrorMessage(error)
      );
      throw error;
    }
    console.warn(
      "Gemini stream unavailable; switching to Cohere:",
      getAxiosErrorMessage(error)
    );
  }

  let cohereEmittedContent = false;
  try {
    for await (const chunk of generateCohereResponseStream(prompt, cohereKey)) {
      cohereEmittedContent = true;
      yield chunk;
    }
    if (!cohereEmittedContent) throw new Error("Cohere returned an empty stream");
    console.info(`Cohere fallback stream succeeded with ${COHERE_MODEL}`);
  } catch (error: any) {
    console.error("Cohere fallback stream failed:", getAxiosErrorMessage(error));
    throw error;
  }
}

function filterAndRankContext(
  results: Array<{
    ibID: string;
    ib_title: string;
    content: string;
    similarity_score: number;
  }>,
): {
  contexts: Array<{ content: string; title: string; score: number }>;
  confidence: "high" | "medium" | "low";
} {
  const topScore = results[0]?.similarity_score || 0;
  const avgScore = results.reduce((sum, r) => sum + r.similarity_score, 0) / results.length;

  let confidence: "high" | "medium" | "low" = "low";

  if (topScore > 0.70 && avgScore > 0.55) {
    confidence = "high";
  } else if (topScore > 0.55 && avgScore > 0.40) {
    confidence = "medium";
  }

  const qualityThreshold = topScore > 0.65 ? 0.50 : 0.40;
  const filtered = results.filter((r) => r.similarity_score >= qualityThreshold);

  const contexts = filtered
    .slice(0, 2)
    .map((doc) => ({
      content: limitText(doc.content, MAX_CONTEXT_CHARS),
      title: doc.ib_title,
      score: doc.similarity_score,
    }));


  return {contexts, confidence};
}

function buildConversationContext(
  conversationHistory: Array<{ sender: string; content: string }>
): string {
  if (!conversationHistory || conversationHistory.length === 0) return "";

  const recentHistory = conversationHistory.slice(-3);
  const contextParts: string[] = [];

  for (const message of recentHistory) {
    const role = message.sender === "user" ? "User" : "Assistant";
    const content = limitText(message.content, MAX_HISTORY_CHARS);

    contextParts.push(`${role}: ${content}`);
  }

  return contextParts.join("\n\n");
}

function buildContextAwarePrompt(
  query: string,
  contexts: Array<{ content: string; title: string; score: number }>,
  conversationHistory: string,
  confidence: "high" | "medium" | "low"
): string {
  let knowledgeSection = "";
  contexts.forEach((ctx, idx) => {
    knowledgeSection += `Document ${idx + 1}: ${ctx.title}\n${ctx.content}\n\n`;
  });

  const historySection = conversationHistory ?
    `Recent conversation:\n${conversationHistory}\n\n` :
    "";

  const dateInfo = new Date().toISOString().substring(0, 10);

  return `OASP Assist, CMU. Date: ${dateInfo}
${historySection}Q: ${query}
KB:
${knowledgeSection}
Rules: Start immediately with the answer. Never begin with "Based on" or refer to the document, policy, KB, context, or provided information. Use history only for follow-ups. Include only facts supported by the KB. Do not mention missing or unknown information, contacting staff, or escalation.
A:`;
}

function buildPartialInfoPrompt(
  query: string,
  contexts: Array<{ content: string; title: string; score: number }>,
  conversationHistory: string
): string {
  let knowledgeSection = "";
  contexts.forEach((ctx) => {
    knowledgeSection += `[${ctx.title}]\n${ctx.content}\n\n`;
  });

  const historySection = conversationHistory ?
    `Recent conversation (use for context):\n${conversationHistory}\n\n` :
    "";

  const dateInfo = new Date().toISOString().substring(0, 10);

  return `OASP Assist, CMU. Date: ${dateInfo}
${historySection}Q: ${query}
Info:
${knowledgeSection}
Rules: Start immediately with the answer. Never begin with "Based on" or refer to the document, policy, KB, context, or provided information. Include only supported facts. Do not mention missing or unknown information, contacting staff, or escalation.
A:`;
}


export const resetDailyMessageCounts = onSchedule(
  {
    schedule: "0 8 * * *",
    timeZone: "Asia/Manila",
    memory: "256MiB",
  },
  async () => {
    try {
      const now = new Date();

      const phNow = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Manila"}));
      const resetTime = new Date(phNow.getFullYear(), phNow.getMonth(), phNow.getDate(), 8, 0, 0);
      const resetTimestamp = admin.firestore.Timestamp.fromDate(resetTime);

      const usersSnapshot = await db.collection("users").get();

      const batchSize = 500;
      for (let i = 0; i < usersSnapshot.docs.length; i += batchSize) {
        const batch = db.batch();
        const batchDocs = usersSnapshot.docs.slice(i, i + batchSize);

        for (const doc of batchDocs) {
          const data = doc.data();
          const lastReset = data.lastMessageResetDate?.toDate();

          let shouldReset = false;

          if (!lastReset) {
            shouldReset = true;
          } else {
            const lastResetPH = new Date(lastReset.toLocaleString("en-US", {timeZone: "Asia/Manila"}));
            if (lastResetPH < resetTime) {
              shouldReset = true;
            }
          }

          if (shouldReset) {
            batch.update(doc.ref, {
              "dailyMessageCount": 0,
              "lastMessageResetDate": resetTimestamp,
            });
          }
        }

        await batch.commit();
      }
    } catch (error: unknown) {
      throw error;
    }
  }
);

export const manualResetMessageCounts = onRequest(
  {
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const now = new Date();
      const phNow = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Manila"}));
      const resetTime = new Date(phNow.getFullYear(), phNow.getMonth(), phNow.getDate(), 8, 0, 0);
      const resetTimestamp = admin.firestore.Timestamp.fromDate(resetTime);

      const usersSnapshot = await db.collection("users").get();

      const batchSize = 500;
      let resetCount = 0;

      for (let i = 0; i < usersSnapshot.docs.length; i += batchSize) {
        const batch = db.batch();
        const batchDocs = usersSnapshot.docs.slice(i, i + batchSize);

        for (const doc of batchDocs) {
          batch.update(doc.ref, {
            "dailyMessageCount": 0,
            "lastMessageResetDate": resetTimestamp,
          });
          resetCount++;
        }

        await batch.commit();
      }

      res.json({
        success: true,
        reset: resetCount,
        timestamp: now.toISOString(),
      });
    } catch (error: unknown) {
      throw error;
    }
  }
);

export const checkResetStatus = onRequest(
  {
    cors: true,
    memory: "256MiB",
  },
  async (req, res) => {
    try {
      const now = new Date();
      const phNow = new Date(now.toLocaleString("en-US", {timeZone: "Asia/Manila"}));

      const todayResetTime = new Date(phNow.getFullYear(), phNow.getMonth(), phNow.getDate(), 8, 0, 0);

      let nextResetTime: Date;
      if (phNow < todayResetTime) {
        nextResetTime = todayResetTime;
      } else {
        nextResetTime = new Date(phNow.getFullYear(), phNow.getMonth(), phNow.getDate() + 1, 8, 0, 0);
      }

      const usersSnapshot = await db.collection("users").limit(10).get();

      const userStatus = usersSnapshot.docs.map((doc) => {
        const data = doc.data();
        const lastReset = data.lastMessageResetDate?.toDate();
        const lastResetPH = lastReset ?
          new Date(lastReset.toLocaleString("en-US", {timeZone: "Asia/Manila"})) :
          null;

        return {
          userId: doc.id.substring(0, 8) + "...",
          messageCount: data.dailyMessageCount || 0,
          lastReset: lastResetPH ? lastResetPH.toISOString() : "never",
          needsReset: !lastResetPH || lastResetPH < todayResetTime,
        };
      });

      res.json({
        currentTime: now.toISOString(),
        philippineTime: phNow.toISOString(),
        nextResetTime: nextResetTime.toISOString(),
        sampleUsers: userStatus,
      });
    } catch (error: unknown) {
      throw error;
    }
  }
);
