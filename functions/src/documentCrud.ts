import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import axios from "axios";
import {Pinecone} from "@pinecone-database/pinecone";
import * as admin from "firebase-admin";
import {logGeminiUsage} from "./geminiUsage";

type JsonResponse = Record<string, any>;

const PINECONE_HOST = defineSecret("PINECONE_HOST");
const PINECONE_API_KEY = defineSecret("PINECONE_API_KEY");
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const COHERE_API_KEY = defineSecret("COHERE_API_KEY");

export const checkPineconeHealth = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      // Try to get index stats as a health check
      await index.describeIndexStats();

      return {
        healthy: true,
        message: "Pinecone is operational",
      };
    } catch (error: any) {
      console.error(" Pinecone health check failed:", error.message);
      return {
        healthy: false,
        error: error.message,
      };
    }
  }
);

export const generateGeminiEmbedding = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");

    const { text } = request.data;
    if (!text) throw new HttpsError("invalid-argument", "Text required");

    try {
      const response = await axios.post<JsonResponse>(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY.value()}`,
        {
          model: "models/gemini-embedding-001",
          content: { parts: [{ text }] },
          outputDimensionality: 768,
        },
        { timeout: 30000 }
      );

      const embedding = response.data?.embedding?.values;

      await logGeminiUsage({
        userId: request.auth.uid ?? null,
        conversationId: null,
        model: "gemini-embedding-001",
        inputTokens: response.data?.usageMetadata?.promptTokenCount ?? Math.ceil(text.length / 4),
        outputTokens: 0,
      }).catch(() => undefined);

      if (!Array.isArray(embedding) || embedding.length === 0) {
        console.error(" Unexpected Gemini response:", JSON.stringify(response.data));
        throw new HttpsError("internal", "No embedding returned from Gemini");
      }

      console.log(` Embedding generated: ${embedding.length} dimensions`);
      return { embedding };
    } catch (error: any) {
      if (error instanceof HttpsError) throw error;

      const msg = error.response?.data?.error?.message ?? error.message;
      console.error(" Gemini embedding error:", msg);
      console.error(" Full Gemini error:", JSON.stringify(error.response?.data ?? {}));
      throw new HttpsError("internal", `Gemini embedding failed: ${msg}`);
    }
  }
);

export const generateGeminiResponse = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {prompt} = request.data;
    if (!prompt) throw new Error("Prompt required");

    try {
      const response = await axios.post<JsonResponse>(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY.value()}`,
        {
          contents: [{parts: [{text: prompt}]}],
          generationConfig: {
            temperature: 0.3,
            maxOutputTokens: 1024,
          },
        },
        {timeout: 30000}
      );

      const text = response.data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!text) throw new Error("No response generated");

      return {text};
    } catch (error: any) {
      console.error(" Gemini response error:", error.message);
      throw new Error(`Failed to generate response: ${error.message}`);
    }
  }
);


export const generateCohereEmbedding = onCall(
  {secrets: [COHERE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {text} = request.data;
    if (!text) throw new Error("Text required");

    try {
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
    } catch (error: any) {
      console.error(" Cohere embedding error:", error.message);
      throw new Error(`Failed to generate embedding: ${error.message}`);
    }
  }
);

export const generateCohereResponse = onCall(
  {secrets: [COHERE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {prompt} = request.data;
    if (!prompt) throw new Error("Prompt required");

    try {
      const response = await axios.post<JsonResponse>(
        "https://api.cohere.ai/v1/chat",
        {
          model: "command-r-08-2024",
          message: prompt,
          max_tokens: 1024,
          temperature: 0.3,
        },
        {
          headers: {
            "Authorization": `Bearer ${COHERE_API_KEY.value()}`,
            "Content-Type": "application/json",
          },
          timeout: 30000,
        }
      );

      const text = response.data?.text;
      if (!text) throw new Error("No response generated");

      return {text};
    } catch (error: any) {
      console.error(" Cohere response error:", error.message);
      throw new Error(`Failed to generate response: ${error.message}`);
    }
  }
);

// ============================================================================
// PINECONE FUNCTIONS
// ============================================================================

export const queryPinecone = onCall(
  {secrets: [PINECONE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {embedding, topK = 5, namespace, filter} = request.data;
    if (!embedding || !Array.isArray(embedding)) {
      throw new Error("Valid embedding array required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      const results = await index.query({
        vector: embedding,
        topK,
        includeMetadata: true,
        ...(namespace && {namespace}),
        ...(filter && {filter}),
      });

      if (!results.matches || results.matches.length === 0) {
        return {success: false, matches: []};
      }

      const matches = results.matches.map((match: any) => ({
        id: match.id,
        score: match.score,
        similarity_score: match.score,
        ...match.metadata,
      }));

      return {success: true, matches};
    } catch (error: any) {
      console.error(" Pinecone query error:", error.message);
      throw new Error(`Failed to query Pinecone: ${error.message}`);
    }
  }
);

export const insertPineconeDocument = onCall(
  {secrets: [PINECONE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {id, embedding, metadata} = request.data;
    if (!id || !embedding || !metadata) {
      throw new Error("ID, embedding, and metadata required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      await index.upsert([{
        id,
        values: embedding,
        metadata,
      }]);

      return {success: true, id};
    } catch (error: any) {
      console.error(" Pinecone insert error:", error.message);
      throw new Error(`Failed to insert document: ${error.message}`);
    }
  }
);

export const insertPineconeDocumentBatch = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {documents} = request.data;

    if (!documents || !Array.isArray(documents) || documents.length === 0) {
      throw new Error("Documents array required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      const vectors = documents.map((doc) => {
        if (!doc.id || !doc.embedding || !doc.metadata) {
          throw new Error("Each document must have id, embedding, and metadata");
        }
        return {
          id: doc.id,
          values: doc.embedding,
          metadata: doc.metadata,
        };
      });

      const batchSize = 100;
      let totalInserted = 0;

      for (let i = 0; i < vectors.length; i += batchSize) {
        const batch = vectors.slice(i, i + batchSize);
        await index.upsert(batch);
        totalInserted += batch.length;
        console.log(` Inserted batch: ${totalInserted}/${vectors.length}`);
      }

      return {
        success: true,
        inserted: totalInserted,
        message: `Successfully inserted ${totalInserted} vectors`,
      };
    } catch (error: any) {
      console.error(" Pinecone batch insert error:", error.message);
      throw new Error(`Failed to batch insert documents: ${error.message}`);
    }
  }
);

export const deletePineconeDocuments = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 60,
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {ids} = request.data;

    if (!ids || !Array.isArray(ids) || ids.length === 0) {
      throw new Error("IDs array required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      await index.deleteMany(ids);

      console.log(` Deleted ${ids.length} vectors from Pinecone`);

      return {
        success: true,
        deleted: ids.length,
        message: `Successfully deleted ${ids.length} vectors`,
      };
    } catch (error: any) {
      console.error(" Pinecone batch delete error:", error.message);
      throw new Error(`Failed to delete documents: ${error.message}`);
    }
  }
);

export const fetchPineconeVectors = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {ids} = request.data;

    if (!ids || !Array.isArray(ids) || ids.length === 0) {
      throw new Error("IDs array required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      const results = await index.fetch(ids);

      return {
        success: true,
        vectors: results.records || {},
        count: Object.keys(results.records || {}).length,
      };
    } catch (error: any) {
      return {
        success: false,
        error: error.message,
      };
    }
  }
);

export const deleteFromPinecone = onCall(
  {secrets: [PINECONE_API_KEY, PINECONE_HOST]},
  async (request) => {
    if (!request.auth) {
      throw new Error("Unauthorized");
    }

    const {chunkIds, namespace} = request.data;

    if (!Array.isArray(chunkIds) || chunkIds.length === 0) {
      throw new Error("chunkIds must be a non-empty array");
    }

    try {
      const response = await axios.post<JsonResponse>(
        `${PINECONE_HOST.value()}/vectors/delete`,
        {
          ids: chunkIds,
          ...(namespace ? {namespace} : {}),
        },
        {
          headers: {
            "Api-Key": PINECONE_API_KEY.value(),
            "Content-Type": "application/json",
          },
          timeout: 30000,
        }
      );

      return {
        success: true,
        deleted: chunkIds.length,
        pineconeStatus: response.status,
      };
    } catch (error: any) {
      throw new Error("Failed to delete vectors from Pinecone");
    }
  }
);

export const getPineconeStats = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {namespace} = request.data;

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      const stats = await index.describeIndexStats();

      const response: any = {
        success: true,
        stats: {
          totalVectors: stats.totalRecordCount || 0,
          dimension: stats.dimension || 0,
        },
      };

      if (stats.namespaces && namespace) {
        const namespaceStats = stats.namespaces[namespace];
        if (namespaceStats) {
          response.stats.namespaceVectors = namespaceStats.recordCount || 0;
        }
      }

      return response;
    } catch (error: any) {
      console.error(" Pinecone stats error:", error.message);
      return {
        success: false,
        error: error.message,
      };
    }
  }
);


export const deleteAllPineconeVectors = onCall(
  {
    secrets: [PINECONE_API_KEY],
    timeoutSeconds: 120,
  },
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const userDoc = await admin.firestore().collection("users").doc(request.auth.uid).get();
    if (!userDoc.data()?.isAdmin) throw new Error("Admin access required");

    const {namespace, confirm} = request.data;

    if (confirm !== "DELETE_ALL") {
      throw new Error("Must pass confirm: \"DELETE_ALL\" to proceed");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index("oasp-assist-gemini");

      if (namespace) {
        await index.deleteAll();
        console.log(` Deleted all vectors in namespace: ${namespace}`);
        return {
          success: true,
          message: `Deleted all vectors in namespace: ${namespace}`,
        };
      } else {
        await index.deleteAll();
        console.log(" Deleted all vectors in index");
        return {
          success: true,
          message: "Deleted all vectors in index",
        };
      }
    } catch (error: any) {
      console.error(" Pinecone delete all error:", error.message);
      throw new Error(`Failed to delete all vectors: ${error.message}`);
    }
  }
);
