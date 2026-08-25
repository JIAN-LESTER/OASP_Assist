/* eslint-disable no-empty */
/* eslint-disable no-useless-catch */
import {HttpsError, onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";
import {onSchedule} from "firebase-functions/scheduler";
import {Firestore, FieldValue} from "@google-cloud/firestore";

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
const MAX_CONTEXT_CHARS = 600;
const MAX_HISTORY_CHARS = 140;
const FAQ_SIMILARITY_THRESHOLD = 0.88;
const FAQ_STRONG_SIMILARITY = 0.92;
const FAQ_SIMILARITY_MARGIN = 0.03;
const GEMINI_EMBEDDING_MODEL = "gemini-embedding-001";
const GEMINI_EMBEDDING_MODEL_RESOURCE = `models/${GEMINI_EMBEDDING_MODEL}`;
const GEMINI_EMBEDDING_DIMENSIONS = 768;

type GeminiEmbeddingTaskType =
  | "RETRIEVAL_QUERY"
  | "RETRIEVAL_DOCUMENT"
  | "SEMANTIC_SIMILARITY"
  | "CLASSIFICATION"
  | "CLUSTERING"
  | "QUESTION_ANSWERING"
  | "FACT_VERIFICATION"
  | "CODE_RETRIEVAL_QUERY";

function normalizeEmbeddingTaskType(taskType?: string): GeminiEmbeddingTaskType {
  switch (taskType) {
  case "search_query":
  case "RETRIEVAL_QUERY":
    return "RETRIEVAL_QUERY";
  case "search_document":
  case "RETRIEVAL_DOCUMENT":
    return "RETRIEVAL_DOCUMENT";
  case "SEMANTIC_SIMILARITY":
  case "CLASSIFICATION":
  case "CLUSTERING":
  case "QUESTION_ANSWERING":
  case "FACT_VERIFICATION":
  case "CODE_RETRIEVAL_QUERY":
    return taskType;
  default:
    return "RETRIEVAL_DOCUMENT";
  }
}

function buildGeminiEmbeddingRequest(
  text: string,
  taskType?: string
): JsonResponse {
  return {
    model: GEMINI_EMBEDDING_MODEL_RESOURCE,
    content: {
      parts: [{text}],
    },
    taskType: normalizeEmbeddingTaskType(taskType),
    outputDimensionality: GEMINI_EMBEDDING_DIMENSIONS,
    embedContentConfig: {
      taskType: normalizeEmbeddingTaskType(taskType),
      outputDimensionality: GEMINI_EMBEDDING_DIMENSIONS,
    },
  };
}

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

    const {text} = request.data;
    if (!text) throw new Error("Text required");

    const response = await axios.post<JsonResponse>(
      "https://api.cohere.ai/v1/embed",
      {
        texts: [text],
        model: "embed-multilingual-v3.0",
        input_type: "search_document",
      },
      {
        headers: {
          "Authorization": `Bearer ${COHERE_API_KEY.value()}`,
          "Content-Type": "application/json",
        },
        timeout: 30000,
      }
    );

    const embedding = response.data?.embeddings?.[0];
    if (!Array.isArray(embedding)) {
      throw new Error("Invalid Cohere embedding");
    }

    return {embedding};
  }
);

async function generateGeminiEmbedding(
  text: string,
  apiKey: string,
  inputType: "search_document" | "search_query" = "search_document"
): Promise<number[]> {
  const response = await axios.post<JsonResponse>(
    `https://generativelanguage.googleapis.com/v1beta/${GEMINI_EMBEDDING_MODEL_RESOURCE}:embedContent?key=${apiKey}`,
    buildGeminiEmbeddingRequest(text, inputType),
    {
      headers: {"Content-Type": "application/json"},
      timeout: 30000,
    }
  );

  const embedding = response.data?.embedding?.values;
  if (!Array.isArray(embedding) || embedding.length === 0) {
    throw new Error("Invalid embedding response");
  }

  if (embedding.length !== GEMINI_EMBEDDING_DIMENSIONS) {
    throw new Error(
      `Unexpected embedding size: ${embedding.length} ` +
      `(expected ${GEMINI_EMBEDDING_DIMENSIONS})`
    );
  }

  await logGeminiUsage({
    userId: null,
    conversationId: null,
    model: GEMINI_EMBEDDING_MODEL,
    inputTokens: response.data?.usageMetadata?.promptTokenCount ?? Math.ceil(text.length / 4),
    outputTokens: 0,
  }).catch(() => undefined);

  return embedding;
}

export const generateEmbedding = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");
    const {text, taskType} = request.data;
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Text required");
    }

    try {
      const response = await axios.post<JsonResponse>(
        `https://generativelanguage.googleapis.com/v1beta/${GEMINI_EMBEDDING_MODEL_RESOURCE}:embedContent?key=${GEMINI_API_KEY.value()}`,
        buildGeminiEmbeddingRequest(text.trim(), taskType),
        {
          headers: {"Content-Type": "application/json"},
          timeout: 30000,
        }
      );

      const embedding = response.data?.embedding?.values;
      if (!Array.isArray(embedding) || embedding.length === 0) {
        throw new Error("Invalid Gemini embedding response");
      }
      if (embedding.length !== GEMINI_EMBEDDING_DIMENSIONS) {
        throw new Error(
          `Unexpected embedding dimension: ${embedding.length} ` +
          `(expected ${GEMINI_EMBEDDING_DIMENSIONS})`
        );
      }
      await logGeminiUsage({
        userId: request.auth.uid ?? null,
        conversationId: null,
        model: GEMINI_EMBEDDING_MODEL,
        inputTokens: response.data?.usageMetadata?.promptTokenCount ?? Math.ceil(text.length / 4),
        outputTokens: 0,
      }).catch(() => undefined);

      return {embedding};
    } catch (error: any) {
      const msg = getAxiosErrorMessage(error);
      console.error("Gemini embedding error:", msg);
      console.error(
        "Gemini embedding response:",
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
  geminiApiKey: string,
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
        data.contextEmbedding ??
        data.faqContextEmbedding ??
        data.embedding ??
        data.geminiEmbedding;

      if (storedEmbedding && Array.isArray(storedEmbedding) && storedEmbedding.length === 768) {
        faqEmbedding = storedEmbedding as number[];
      } else {
        faqEmbedding = await generateGeminiEmbedding(
          buildFAQContext(faqQuestion, faqAnswer),
          geminiApiKey,
          "search_document"
        );

        await doc.ref.update({
          contextEmbedding: faqEmbedding,
          faqContextEmbedding: faqEmbedding,
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
  _query: string,
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
      topK: topK * 4,
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

    const results: any[] = [];

    for (const docId of Object.keys(documentChunks)) {
      const chunks = documentChunks[docId];
      chunks.sort((a, b) => (b.score || 0) - (a.score || 0));

      const topChunks = chunks.slice(0, 2);
      const combinedContent = topChunks
        .map((c) => c.metadata?.text || c.metadata?.content || c.metadata?.chunk_text || "")
        .filter((text) => text.trim())
        .join("\n\n");

      if (!combinedContent.trim()) continue;

      results.push({
        ibID: docId,
        ib_title: topChunks[0].metadata?.title || "Untitled",
        content: combinedContent.trim(),
        source: topChunks[0].metadata?.source || "Unknown",
        categoryID: topChunks[0].metadata?.category || "General",
        similarity_score: topChunks[0].score || 0,
        chunk_info: {
          total_chunks_found: chunks.length,
          chunks_used: topChunks.length,
        },
      });
    }

    results.sort((a, b) => b.similarity_score - a.similarity_score);
    return results.slice(0, topK);
  } catch {
    return [];
  }
}

export const generateAnswer = onRequest(
  {
    secrets: [PINECONE_API_KEY, GEMINI_API_KEY],
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
        isFAQSelection = false,
      } = req.body;

      if (!query || typeof query !== "string" || query.trim().length === 0) {
        res.status(400).json({
          error: "Invalid query",
          answer: "Please provide a valid question.",
          source: "error",
        });
        return;
      }

      // Free-typed messages must not be classified as FAQs. FAQ matching is
      // enabled only when the user selected an item from the FAQ section.
      stage = "direct_faq_lookup";
      const directFAQMatch = isFAQSelection ? await findDirectFAQMatch(query) : null;
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
      const pineconeKey = PINECONE_API_KEY.value();

      stage = "query_embedding";
      const [queryEmbedding, pineconeClient] = await Promise.all([
        generateGeminiEmbedding(query, geminiKey, "search_query"),
        Promise.resolve(new Pinecone({apiKey: pineconeKey})),
      ]);

      stage = "semantic_faq_lookup";
      const [faqMatch, pineconeIndex] = await Promise.all([
        isFAQSelection ? findMatchingFAQ(query, queryEmbedding, geminiKey) : Promise.resolve(null),
        Promise.resolve(pineconeClient.Index("oasp-assist-gemini")),
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
Rules: Use general guidance only. If OASP-specific info is missing, say contact OASP staff.
A:`;

        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          try {
            stage = "ai_fallback_stream";
            for await (const chunk of generateGeminiResponseStream(fallbackPrompt, geminiKey)) {
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
            const errorMsg = "I'm having trouble processing your request. Please contact OASP staff directly for assistance.";
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
            const answer = await generateGeminiResponse(fallbackPrompt, geminiKey);
            res.json({answer: answer.trim(), source: "ai_fallback"});
          } catch {
            res.json({
              answer: "I'm having trouble processing your request. Please contact OASP staff directly for assistance.",
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
          for await (const chunk of generateGeminiResponseStream(prompt, geminiKey)) {
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
        } catch {
        }

        // FALLBACK IF STREAMING FAILS
        try {
          stage = "rag_generate_fallback";
          const fullAnswer = await generateGeminiResponse(prompt, geminiKey);

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
        const answer = await generateGeminiResponse(prompt, geminiKey);
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
        "I'm having trouble processing your request right now. Please try again or contact OASP staff directly.";

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
Rules: Use KB first. Use history only for follow-ups. If OASP-specific details are missing, say contact OASP staff.
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
Rules: Use provided info first. If OASP-specific details are missing, say contact OASP staff.
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
