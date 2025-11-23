

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { Pinecone } from "@pinecone-database/pinecone";
import axios from "axios";

// Secrets
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const db = admin.firestore();

// ============================================================================
// GEMINI FUNCTIONS
// ============================================================================

export async function generateGeminiEmbedding(
  text: string,
  apiKey: string,
  inputType: "search_document" | "search_query" = "search_document"
): Promise<number[]> {
  try {
    // ✅ FIXED: Use correct embedding model endpoint
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${apiKey}`,
      {
        model: "models/text-embedding-004",
        content: {
          parts: [{ text: text }]
        }
      },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      console.error(`❌ Gemini embedding error: ${response.status}`, response.data);
      throw new Error(`Gemini API error: ${response.statusText}`);
    }

    const data: any = response.data;
    const embedding = data?.embedding?.values as number[] | undefined;
    
    if (!Array.isArray(embedding) || embedding.length === 0) {
      console.error("❌ Invalid embedding structure:", JSON.stringify(data).substring(0, 200));
      throw new Error("Invalid embedding response from Gemini");
    }

    console.log(`✅ Generated embedding: ${embedding.length} dimensions`);
    return embedding;
  } catch (error: any) {
    console.error("❌ Gemini embedding error:", error.message);
    if (error.response) {
      console.error("   Response data:", error.response.data);
    }
    throw error;
  }
}

// async function* generateGeminiResponseStream(
//   prompt: string,
//   apiKey: string
// ): AsyncGenerator<string, void, unknown> {
//   try {
//     // ✅ FIXED: Use correct model version
//     const response = await fetch(
//       `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:streamGenerateContent?alt=sse&key=${apiKey}`,
//       {
//         method: "POST",
//         headers: { "Content-Type": "application/json" },
//         body: JSON.stringify({
//           contents: [{ parts: [{ text: prompt }] }],
//           generationConfig: {
//             temperature: 0.3,
//             maxOutputTokens: 1024,
//           }
//         }),
//       }
//     );

//     if (!response.ok) {
//       const errorText = await response.text();
//       console.error(`❌ Gemini API error response: ${errorText}`);
//       throw new Error(`Gemini Stream API error: ${response.status} ${response.statusText}`);
//     }

//     if (!response.body) {
//       throw new Error("Response body is null");
//     }

//     const reader = response.body.getReader();
//     const decoder = new TextDecoder();
//     let buffer = "";

//     while (true) {
//       const { done, value } = await reader.read();
//       if (done) break;

//       buffer += decoder.decode(value, { stream: true });
//       const lines = buffer.split("\n");
//       buffer = lines.pop() || "";

//       for (const line of lines) {
//         const trimmedLine = line.trim();
        
//         // Skip empty lines and metadata
//         if (!trimmedLine || trimmedLine.startsWith("event:") || trimmedLine === "data: [DONE]") {
//           continue;
//         }

//         // Remove "data: " prefix for SSE format
//         const jsonStr = trimmedLine.startsWith("data: ") 
//           ? trimmedLine.substring(6) 
//           : trimmedLine;

//         if (!jsonStr || jsonStr === "[DONE]") continue;

//         try {
//           const data = JSON.parse(jsonStr);
//           const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
          
//           if (text) {
//             yield text;
//           }
          
//           const finishReason = data?.candidates?.[0]?.finishReason;
//           if (finishReason === "STOP") {
//             return;
//           }
//         } catch (parseError) {
//           console.warn("⚠️ Failed to parse streaming chunk:", jsonStr.substring(0, 100));
//           continue;
//         }
//       }
//     }
//   } catch (error: any) {
//     console.error("❌ Gemini streaming error:", error);
//     throw error;
//   }
// }

// export async function generateGeminiResponse(
//   prompt: string,
//   apiKey: string
// ): Promise<string> {
//   try {
//     // ✅ FIXED: Use correct model version
//     const response = await axios.post(
//       `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
//       {
//         contents: [{ parts: [{ text: prompt }] }],
//         generationConfig: {
//           temperature: 0.3,
//           maxOutputTokens: 1024,
//         }
//       },
//       {
//         headers: { "Content-Type": "application/json" },
//         timeout: 30000,
//       }
//     );

//     if (response.status !== 200) {
//       console.error(`❌ Gemini API error: ${response.status}`, response.data);
//       throw new Error(`Gemini API error: ${response.statusText}`);
//     }

//     const data: any = response.data;
//     const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    
//     if (!text) {
//       console.error("❌ Empty response structure:", JSON.stringify(data).substring(0, 200));
//       throw new Error("Empty response from Gemini");
//     }

//     return text;
//   } catch (error: any) {
//     console.error("❌ Gemini response error:", error.message);
//     if (error.response) {
//       console.error("   Response data:", error.response.data);
//     }
//     throw error;
//   }
// }

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

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
  query: string,
  queryEmbedding: number[],
  geminiApiKey: string,
  similarityThreshold = 0.75
): Promise<{ question: string; answer: string; similarity: number; category: string } | null> {
  try {
    console.log(`🔍 FAQ MATCHING START for: "${query}"`);

    const faqSnapshot = await db
      .collection("faqs")
      .where("answer", "!=", "")
      .get();

    console.log(`📚 Checking ${faqSnapshot.docs.length} FAQs`);

    let bestMatch: any = null;
    let highestSimilarity = 0;

    for (const doc of faqSnapshot.docs) {
      const data = doc.data();
      const faqQuestion = data.question as string;
      const faqAnswer = data.answer as string;

      if (!faqQuestion || !faqAnswer) continue;

      let faqEmbedding: number[];

      if (data.geminiEmbedding && Array.isArray(data.geminiEmbedding)) {
        faqEmbedding = data.geminiEmbedding;
      } else {
        faqEmbedding = await generateGeminiEmbedding(faqQuestion, geminiApiKey, "search_document");
        await doc.ref.update({
          geminiEmbedding: faqEmbedding,
          geminiEmbeddingUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      if (faqEmbedding.length !== queryEmbedding.length) continue;

      const similarity = cosineSimilarity(queryEmbedding, faqEmbedding);

      if (similarity > highestSimilarity && similarity >= similarityThreshold) {
        highestSimilarity = similarity;
        bestMatch = {
          question: faqQuestion,
          answer: faqAnswer,
          category: data.category || 'General',
          similarity: similarity,
        };
      }
    }

    if (bestMatch) {
      console.log(`✅ FAQ MATCH: ${bestMatch.question.substring(0, 50)}... (${bestMatch.similarity.toFixed(3)})`);
    } else {
      console.log(`❌ No FAQ match above threshold ${similarityThreshold}`);
    }

    return bestMatch;
  } catch (error) {
    console.error("❌ Error in findMatchingFAQ:", error);
    return null;
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
  const sorted = results.slice().sort((a, b) => b.similarity_score - a.similarity_score);
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

function buildConversationContext(
  conversationHistory: Array<{ sender: string; content: string }>
): string {
  if (!conversationHistory || conversationHistory.length === 0) return "";

  const recentHistory = conversationHistory.slice(-6);
  const contextParts: string[] = [];

  for (const message of recentHistory) {
    const role = message.sender === "user" ? "User" : "Assistant";
    const content = message.content.length > 500
      ? message.content.substring(0, 500) + "..."
      : message.content;
    contextParts.push(`${role}: ${content}`);
  }

  return contextParts.join("\n");
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

async function retrieveRelevantDocuments(
  query: string,
  queryEmbedding: number[],
  pineconeIndex: any,
  topK = 5,
  minSimilarityScore = 0.3
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
    console.log(`🔍 Querying Pinecone for: "${query}"`);

    const similarChunks = await pineconeIndex.query({
      vector: queryEmbedding,
      topK: topK * 3,
      includeMetadata: true,
    });

    if (!similarChunks.matches || similarChunks.matches.length === 0) {
      console.log("❌ No documents found in Pinecone");
      return [];
    }

    console.log(`📊 Found ${similarChunks.matches.length} chunks`);

    const filteredChunks = similarChunks.matches.filter(
      (chunk: any) => (chunk.score || 0) >= minSimilarityScore
    );

    console.log(`✅ ${filteredChunks.length} chunks above threshold`);

    const documentChunks: { [key: string]: any[] } = {};

    for (const chunk of filteredChunks) {
      const metadata = chunk.metadata || {};
      const docId = metadata.docId || metadata.originalDocId || chunk.id?.split("_chunk_")[0];

      if (docId) {
        if (!documentChunks[docId]) {
          documentChunks[docId] = [];
        }
        documentChunks[docId].push({ ...chunk, metadata });
      }
    }

    const results: any[] = [];

    for (const docId of Object.keys(documentChunks)) {
      const chunks = documentChunks[docId];
      chunks.sort((a, b) => (b.score || 0) - (a.score || 0));
      const bestChunk = chunks[0];

      const content = bestChunk.metadata?.text || 
                     bestChunk.metadata?.content || 
                     bestChunk.metadata?.chunk_text || "";

      if (!content.trim()) continue;

      results.push({
        ibID: docId,
        ib_title: bestChunk.metadata?.title || "Untitled",
        content: content.trim(),
        source: bestChunk.metadata?.source || "Unknown",
        categoryID: bestChunk.metadata?.category || "General",
        similarity_score: bestChunk.score || 0,
        chunk_info: {
          total_chunks_found: chunks.length,
          best_chunk_index: bestChunk.metadata?.chunkIndex || 0,
        },
      });
    }

    results.sort((a, b) => b.similarity_score - a.similarity_score);
    return results.slice(0, topK);
  } catch (error) {
    console.error("❌ Error retrieving documents:", error);
    return [];
  }
}

// ============================================================================
// MAIN FUNCTION
// ============================================================================

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

    // ✅ FIX: Validate request method
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed", answer: "Please use POST method" });
      return;
    }

    try {
      const { query, conversationHistory = [], topK = 5, minSimilarityScore = 0.3, stream = true } = req.body;

      // ✅ FIX: Better validation
      if (!query || typeof query !== 'string' || query.trim().length === 0) {
        res.status(400).json({ 
          error: "Invalid query", 
          answer: "Please provide a valid question.",
          source: "error" 
        });
        return;
      }

      console.log(`📩 Received query: "${query}"`);

      const geminiKey = GEMINI_API_KEY.value();
      const pineconeKey = PINECONE_API_KEY.value();

      // Generate embedding
      console.log("🔧 Generating query embedding...");
      const queryEmbedding = await generateGeminiEmbedding(query, geminiKey, "search_query");
      console.log(`✅ Embedding generated: ${queryEmbedding.length} dimensions`);

      // Check FAQ
      const faqMatch = await findMatchingFAQ(query, queryEmbedding, geminiKey);

      if (faqMatch) {
        console.log("✅ Returning FAQ answer");
        
        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.setHeader("Cache-Control", "no-cache");
          res.setHeader("Connection", "keep-alive");

          const answer = faqMatch.answer;
          for (let i = 0; i < answer.length; i += 10) {
            const chunk = answer.substring(i, Math.min(i + 10, answer.length));
            res.write(`data: ${JSON.stringify({ 
              type: "content-delta", 
              delta: { message: { content: { text: chunk } } } 
            })}\n\n`);
            await new Promise(resolve => setTimeout(resolve, 30));
          }

          res.write(`data: ${JSON.stringify({ 
            type: "message-end", 
            metadata: { source: "faq", category: faqMatch.category } 
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } else {
          res.json({ 
            answer: faqMatch.answer, 
            source: "faq", 
            category: faqMatch.category 
          });
        }
        return;
      }

      // Retrieve from Pinecone
      console.log("🔧 Querying Pinecone...");
      const pineconeClient = new Pinecone({ apiKey: pineconeKey });
      const pineconeIndex = pineconeClient.Index("oasp-assist-gemini");

      const results = await retrieveRelevantDocuments(
        query,
        queryEmbedding,
        pineconeIndex,
        topK,
        minSimilarityScore
      );

      if (results.length === 0) {
        console.log("❌ No documents found");
        const errorMsg = "Sorry, I couldn't find relevant information. Please contact OASP staff.";
        
        if (stream) {
          res.setHeader("Content-Type", "text/event-stream");
          res.write(`data: ${JSON.stringify({ 
            type: "content-delta", 
            delta: { message: { content: { text: errorMsg } } } 
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } else {
          res.json({ answer: errorMsg, source: "no_documents" });
        }
        return;
      }

      console.log(`✅ Found ${results.length} relevant documents`);

      // Generate response
      const documentContext = buildDocumentContext(results);
      const conversationContext = buildConversationContext(conversationHistory);
      const prompt = buildContextAwarePrompt(query, documentContext, conversationContext);

      if (stream) {
        res.setHeader("Content-Type", "text/event-stream");
        res.setHeader("Cache-Control", "no-cache");
        res.setHeader("Connection", "keep-alive");

        let streamSucceeded = false;

        try {
          // ✅ Try streaming first
          for await (const chunk of generateGeminiResponseStream(prompt, geminiKey)) {
            if (chunk && chunk.length > 0) {
              streamSucceeded = true;
              res.write(`data: ${JSON.stringify({ 
                type: "content-delta", 
                delta: { message: { content: { text: chunk } } } 
              })}\n\n`);
            }
          }

          if (streamSucceeded) {
            res.write(`data: ${JSON.stringify({ 
              type: "message-end", 
              metadata: { source: "knowledge_base", streamMethod: "real" } 
            })}\n\n`);
            res.write("data: [DONE]\n\n");
            res.end();
            return;
          }
        } catch (streamError) {
          console.error("❌ Streaming failed, using fallback:", streamError);
        }

        // ✅ Fallback: Get full response and simulate streaming
        try {
          console.log("⚠️ Using fallback non-streaming mode");
          const fullAnswer = await generateGeminiResponse(prompt, geminiKey);
          
          // Send in chunks to simulate streaming
          const chunkSize = 15;
          for (let i = 0; i < fullAnswer.length; i += chunkSize) {
            const chunk = fullAnswer.substring(i, Math.min(i + chunkSize, fullAnswer.length));
            res.write(`data: ${JSON.stringify({ 
              type: "content-delta", 
              delta: { message: { content: { text: chunk } } } 
            })}\n\n`);
            await new Promise(resolve => setTimeout(resolve, 30));
          }

          res.write(`data: ${JSON.stringify({ 
            type: "message-end", 
            metadata: { source: "knowledge_base", streamMethod: "fallback" } 
          })}\n\n`);
          res.write("data: [DONE]\n\n");
          res.end();
        } catch (fallbackError) {
          console.error("❌ Fallback also failed:", fallbackError);
          res.write(`data: ${JSON.stringify({ 
            type: "error", 
            error: "Failed to generate response" 
          })}\n\n`);
          res.end();
        }
      } else {
        // Non-streaming mode
        const answer = await generateGeminiResponse(prompt, geminiKey);
        res.json({ 
          answer: answer.trim(), 
          source: "knowledge_base",
          documentsFound: results.length
        });
      }

    } catch (error: any) {
      console.error("❌ Error:", error);
      res.status(500).json({ 
        error: error.message,
        answer: "An error occurred while processing your request.",
        source: "error" 
      });
    }
  }
);

// Quick fix with multiple model fallbacks
// Add this to your Cloud Function

const GEMINI_MODELS = [
  'gemini-1.5-flash-002',  // Try newest version first
  'gemini-1.5-flash',       // Fallback to base version
  'gemini-1.5-pro',         // Fallback to pro
  'gemini-pro'              // Last resort fallback
];

async function findWorkingGeminiModel(apiKey: string): Promise<string> {
  for (const model of GEMINI_MODELS) {
    try {
      const response = await axios.post(
        `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
        {
          contents: [{ parts: [{ text: "test" }] }],
          generationConfig: { maxOutputTokens: 10 }
        },
        { timeout: 5000 }
      );
      
      if (response.status === 200) {
        console.log(`✅ Found working model: ${model}`);
        return model;
      }
    } catch (error) {
      console.log(`⚠️ Model ${model} not available`);
      continue;
    }
  }
  
  throw new Error('No working Gemini model found');
}

// Cache the working model
let cachedModel: string | null = null;

async function getGeminiModel(apiKey: string): Promise<string> {
  if (cachedModel) {
    return cachedModel;
  }
  
  cachedModel = await findWorkingGeminiModel(apiKey);
  return cachedModel;
}

// Modified generateGeminiResponse with auto-detection
export async function generateGeminiResponse(
  prompt: string,
  apiKey: string
): Promise<string> {
  try {
    const model = await getGeminiModel(apiKey);
    
    const response = await axios.post(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 1024,
        }
      },
      {
        headers: { "Content-Type": "application/json" },
        timeout: 30000,
      }
    );

    if (response.status !== 200) {
      console.error(`❌ Gemini API error: ${response.status}`, response.data);
      throw new Error(`Gemini API error: ${response.statusText}`);
    }

    const data: any = response.data;
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    
    if (!text) {
      console.error("❌ Empty response structure:", JSON.stringify(data).substring(0, 200));
      throw new Error("Empty response from Gemini");
    }

    return text;
  } catch (error: any) {
    console.error("❌ Gemini response error:", error.message);
    if (error.response) {
      console.error("   Response data:", error.response.data);
    }
    throw error;
  }
}

// Modified streaming function with auto-detection
async function* generateGeminiResponseStream(
  prompt: string,
  apiKey: string
): AsyncGenerator<string, void, unknown> {
  try {
    const model = await getGeminiModel(apiKey);
    
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:streamGenerateContent?alt=sse&key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 1024,
          }
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error(`❌ Gemini API error response: ${errorText}`);
      throw new Error(`Gemini Stream API error: ${response.status} ${response.statusText}`);
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
      buffer = lines.pop() || "";

      for (const line of lines) {
        const trimmedLine = line.trim();
        
        if (!trimmedLine || trimmedLine.startsWith("event:") || trimmedLine === "data: [DONE]") {
          continue;
        }

        const jsonStr = trimmedLine.startsWith("data: ") 
          ? trimmedLine.substring(6) 
          : trimmedLine;

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
        } catch (parseError) {
          console.warn("⚠️ Failed to parse streaming chunk:", jsonStr.substring(0, 100));
          continue;
        }
      }
    }
  } catch (error: any) {
    console.error("❌ Gemini streaming error:", error);
    throw error;
  }
}