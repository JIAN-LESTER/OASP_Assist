/* eslint-disable no-empty */
/* eslint-disable no-useless-catch */
import {onCall, onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {Pinecone} from "@pinecone-database/pinecone";
import axios from "axios";
import {onSchedule} from "firebase-functions/scheduler";
import {Firestore, FieldValue} from "@google-cloud/firestore";

type JsonResponse = Record<string, any>;

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

const GEMINI_MODEL = "gemini-2.5-flash";

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
  _inputType: "search_document" | "search_query" = "search_document"
): Promise<number[]> {
  const response = await axios.post<JsonResponse>(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${apiKey}`,
    {
      content: {
        parts: [{text}],
      },
      outputDimensionality: 768,
    },
    {
      headers: {"Content-Type": "application/json"},
      timeout: 30000,
    }
  );

  const embedding = response.data?.embedding?.values;
  if (!Array.isArray(embedding) || embedding.length === 0) {
    throw new Error("Invalid embedding response");
  }

  if (embedding.length !== 768) {
    throw new Error(`Unexpected embedding size: ${embedding.length} (expected 768)`);
  }

  await logGeminiUsage({
    userId: null,
    conversationId: null,
    model: "gemini-embedding-001",
    inputTokens: response.data?.usageMetadata?.promptTokenCount ?? Math.ceil(text.length / 4),
    outputTokens: 0,
  }).catch(() => undefined);

  return embedding;
}

export const generateEmbedding = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");
    const {text} = request.data;
    if (!text) throw new Error("Text required");

    try {
      const response = await axios.post<JsonResponse>(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY.value()}`,
        {
          content: {
            parts: [{text}],
          },
          outputDimensionality: 768,
        },
        {timeout: 30000}
      );

      const embedding = response.data?.embedding?.values;
      if (!Array.isArray(embedding) || embedding.length === 0) {
        throw new Error("Invalid Gemini embedding response");
      }
      if (embedding.length !== 768) {
        throw new Error(`Unexpected embedding dimension: ${embedding.length} (expected 768)`);
      }
      await logGeminiUsage({
        userId: request.auth.uid ?? null,
        conversationId: null,
        model: "gemini-embedding-001",
        inputTokens: response.data?.usageMetadata?.promptTokenCount ?? Math.ceil(text.length / 4),
        outputTokens: 0,
      }).catch(() => undefined);

      return {embedding};
    } catch (error: any) {
      throw new Error(`Embedding failed: ${error.message}`);
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
  similarityThreshold = 0.75
): Promise<{ question: string; answer: string; similarity: number; category: string } | null> {
  try {
    const faqSnapshot = await db
      .collection("faqs")
      .where("answer", "!=", "")
      .get();


    let bestMatch: any = null;
    let highestSimilarity = 0;

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const faqQuestion = data.question as string;
      const faqAnswer = data.answer as string;

      if (!faqQuestion || !faqAnswer) continue;

      let faqEmbedding: number[];
      const storedEmbedding = data.embedding ?? data.geminiEmbedding;

      if (storedEmbedding && Array.isArray(storedEmbedding) && storedEmbedding.length === 768) {
        faqEmbedding = storedEmbedding as number[];
      } else {
        faqEmbedding = await generateGeminiEmbedding(faqQuestion, geminiApiKey, "search_document");

        await doc.ref.update({
          embedding: faqEmbedding,
          geminiEmbedding: faqEmbedding,
          embeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      if (faqEmbedding.length !== queryEmbedding.length) {
        continue;
      }

      const similarity = cosineSimilarity(queryEmbedding, faqEmbedding);

      if (similarity > highestSimilarity && similarity >= similarityThreshold) {
        highestSimilarity = similarity;
        bestMatch = {
          question: faqQuestion,
          answer: faqAnswer,
          category: data.category || "General",
          similarity: similarity,
        };
      }
    }

    return bestMatch;
  } catch {
    return null;
  }
}

async function retrieveRelevantDocuments(
  _query: string,
  queryEmbedding: number[],
  pineconeIndex: any,
  topK = 8,
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

      const topChunks = chunks.slice(0, 3);
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
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed", answer: "Please use POST method"});
      return;
    }

    try {
      const {query, conversationHistory = [], topK = 8, minSimilarityScore = 0.30, stream = true} = req.body;

      if (!query || typeof query !== "string" || query.trim().length === 0) {
        res.status(400).json({
          error: "Invalid query",
          answer: "Please provide a valid question.",
          source: "error",
        });
        return;
      }


      const geminiKey = GEMINI_API_KEY.value();
      const pineconeKey = PINECONE_API_KEY.value();


      const [queryEmbedding, pineconeClient] = await Promise.all([
        generateGeminiEmbedding(query, geminiKey, "search_query"),
        Promise.resolve(new Pinecone({apiKey: pineconeKey})),
      ]);


      const [faqMatch, pineconeIndex] = await Promise.all([
        findMatchingFAQ(query, queryEmbedding, geminiKey),
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
        const now = new Date();
        const dateInfo = `Current Date: ${now.toLocaleDateString("en-US", {
          weekday: "long",
          year: "numeric",
          month: "long",
          day: "numeric",
        })}`;

        const fallbackPrompt = `You are OASP Assist for Central Mindanao University.

${dateInfo}

${conversationContext ? `Recent conversation:\n${conversationContext}\n\n` : ""}Question: "${query}"

IMPORTANT: My knowledge base doesn't have specific documents about this topic, but I should still try to help.

Instructions:
1. Use your general knowledge about universities, admissions, scholarships, and student services
2. Provide helpful, accurate general information when possible
3. Use the current date for time-sensitive queries
4. If this is truly specific to CMU OASP policies I cannot answer, politely suggest contacting OASP staff
5. Be helpful and professional
6. Don't say "I don't have information" - try to provide useful guidance first

Answer:`;

        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          try {
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
        const answer = await generateGeminiResponse(prompt, geminiKey);
        res.json({
          answer: answer.trim(),
          source: "information_bank",
          confidence,
          documentsFound: results.length,
        });
      }
    } catch (error: any) {
      res.status(500).json({
        error: error.message,
        answer: "I'm having trouble processing your request right now. Please try again or contact OASP staff directly.",
        source: "error",
      });
    }
  }
);

async function generateGeminiResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  try {
    const response = await axios.post<JsonResponse>(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`,
      {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 4096,
          topP: 0.95,
          topK: 40,
        },
      },
      {
        headers: {"Content-Type": "application/json"},
        timeout: 30000,
      }
    );


    if (response.status !== 200) {
      throw new Error(`Gemini API error: ${response.statusText}`);
    }

    const data: any = response.data;
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

    const usageMetadata = data?.usageMetadata;
    if (usageMetadata) {
      await logGeminiUsage({
        userId: null,
        conversationId: null,
        model: GEMINI_MODEL,
        inputTokens: usageMetadata.promptTokenCount ?? 0,
        outputTokens: usageMetadata.candidatesTokenCount ?? 0,
      }).catch(() => undefined);
    }

    if (!text) {
      throw new Error("Empty response from Gemini");
    }

    return text;
  } catch (error) {
    throw error;
  }
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
            maxOutputTokens: 4096,
            topP: 0.95,
            topK: 40,
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
          const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;

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
    .slice(0, 5)
    .map((doc) => ({
      content: doc.content,
      title: doc.ib_title,
      score: doc.similarity_score,
    }));


  return {contexts, confidence};
}

function buildConversationContext(
  conversationHistory: Array<{ sender: string; content: string }>
): string {
  if (!conversationHistory || conversationHistory.length === 0) return "";

  const recentHistory = conversationHistory.slice(-10);
  const contextParts: string[] = [];

  for (const message of recentHistory) {
    const role = message.sender === "user" ? "User" : "Assistant";
    const content = message.content.length > 500 ?
      message.content.substring(0, 500) + "..." :
      message.content;

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
    `Previous conversation context (use this to understand follow-up questions and maintain continuity):\n${conversationHistory}\n\n` :
    "";

  const now = new Date();
  const dateInfo = `Current Date and Time: ${now.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  })}, ${now.toLocaleTimeString("en-US")}`;

  return `You are OASP Assist, the official AI assistant for Central Mindanao University's Office of Admissions, Scholarships, and Placement (OASP).

${dateInfo}

${historySection}Current question: "${query}"

Knowledge Base Documents:
${knowledgeSection}

CRITICAL INSTRUCTIONS:
1. **Real-time Awareness**:
   - You know the current date and time shown above
   - Use this information to provide context-aware responses about deadlines, dates, and time-sensitive matters
   - Calculate relative dates (e.g., "in 2 weeks", "next month") based on current date

2. **Context Awareness**:
   - If this is a follow-up question (indicated by conversation history), reference previous discussion
   - Use pronouns and context clues from history to understand what "it", "that", "those" refer to
   - Maintain continuity in your responses based on what was discussed before

3. **Intelligent Fallback**:
   - If the knowledge base has SOME relevant information, provide it comprehensively
   - If the knowledge base lacks specific details but you can infer or provide general guidance, do so
   - ONLY suggest contacting OASP if the question requires truly specific information not available

4. **Comprehensiveness**: Provide detailed, thorough answers using ALL relevant information from the documents

5. **Accuracy**: Prioritize information from the knowledge base, but use general knowledge when appropriate for:
   - Date calculations and calendar information
   - General university processes and procedures
   - Common academic terminology and concepts

6. **Structure**: Organize complex answers with clear explanations, including:
   - Step-by-step procedures when applicable
   - Specific requirements, dates, and deadlines
   - All relevant details (fees, contacts, locations, etc.)

7. **Natural Language**: Write as a knowledgeable university assistant would - friendly but professional

8. **NO UNNECESSARY DISCLAIMERS**:
   - Don't say "I don't have information" if you can provide helpful general guidance
   - Don't suggest contacting OASP for information you can reasonably answer
   - Be helpful and resourceful with the information available

If this is a follow-up question, acknowledge the previous context naturally in your response.

Answer:`;
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

  const now = new Date();
  const dateInfo = `Current Date: ${now.toLocaleDateString("en-US", {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  })}`;

  return `You are OASP Assist for Central Mindanao University.

${dateInfo}

${historySection}Question: "${query}"

Available Information:
${knowledgeSection}

Instructions:
1. **Real-time Context**: You know today's date - use it to provide relevant time-based information
2. If this is a follow-up question, use conversation history to understand the full context
3. Provide whatever specific information IS available from the documents
4. Be thorough with what you CAN answer
5. If you can provide helpful general guidance even without specific details, do so
6. Use your knowledge of university processes to supplement available information when appropriate
7. Only suggest contacting OASP if truly critical specific information is genuinely unavailable
8. Maintain natural conversation flow if there's prior context

Answer:`;
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
