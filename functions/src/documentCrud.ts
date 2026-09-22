import {HttpsError, onCall} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import axios from "axios";
import {Pinecone} from "@pinecone-database/pinecone";
import * as admin from "firebase-admin";
import {
  COHERE_EMBEDDING_DIMENSIONS,
  COHERE_EMBEDDING_MODEL,
  PINECONE_INDEX_NAME,
  createCohereEmbedding,
  normalizeCohereInputType,
} from "./cohereEmbedding";

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
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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
  { secrets: [COHERE_API_KEY], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Unauthorized");

    const { text, taskType } = request.data;
    if (typeof text !== "string" || text.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Text required");
    }

    try {
      const embedding = await createCohereEmbedding(
        text.trim(),
        COHERE_API_KEY.value(),
        normalizeCohereInputType(taskType)
      );

      console.warn(
        "Legacy generateGeminiEmbedding callable used; returned Cohere embedding"
      );
      console.info(`Embedding generated: ${embedding.length} dimensions`);
      return { embedding };
    } catch (error: any) {
      if (error instanceof HttpsError) throw error;

      const msg = error.response?.data?.error?.message ??
        error.message ??
        "Unknown error";
      console.error(" Cohere embedding error:", msg);
      console.error(
        " Full Cohere error:",
        JSON.stringify(error.response?.data ?? {})
      );
      throw new HttpsError("internal", `Cohere embedding failed: ${msg}`);
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
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${GEMINI_API_KEY.value()}`,
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

    const {text, taskType} = request.data;
    if (!text) throw new Error("Text required");

    try {
      const embedding = await createCohereEmbedding(
        text.trim(),
        COHERE_API_KEY.value(),
        normalizeCohereInputType(taskType)
      );
      console.info(
        `Cohere ${COHERE_EMBEDDING_MODEL} embedding generated: ` +
        `${embedding.length} dimensions`
      );
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

type PineconeUsageOperation = "upsert" | "delete" | "query" | "fetch";

async function writePineconeUsage({
  userId,
  operation,
  count,
  namespace,
  source,
}: {
  userId: string | null;
  operation: PineconeUsageOperation;
  count: number;
  namespace?: string | null;
  source?: string | null;
}) {
  const safeCount = Math.max(0, Number(count) || 0);

  await admin.firestore().collection("pinecone_usage").add({
    userId: userId ?? null,
    tool: "Pinecone",
    index: PINECONE_INDEX_NAME,
    operation,
    source: source ?? "document_upload",
    namespace: namespace ?? null,
    usageCount: safeCount,
    calls: 1,
    writes: operation === "upsert" ? safeCount : 0,
    upserts: operation === "upsert" ? safeCount : 0,
    deletes: operation === "delete" ? safeCount : 0,
    costUsd: 0,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    date: new Date().toISOString().substring(0, 10),
  });
}

export const logPineconeUsage = onCall(
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {
      operation = "upsert",
      count = 1,
      namespace,
      source = "document_upload",
    } = request.data ?? {};

    await writePineconeUsage({
      userId: request.auth.uid ?? null,
      operation,
      count,
      namespace,
      source,
    });

    return {success: true};
  }
);

export const queryPinecone = onCall(
  {secrets: [PINECONE_API_KEY]},
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {embedding, topK = 5, namespace, filter} = request.data;
    if (!embedding || !Array.isArray(embedding) ||
        embedding.length !== COHERE_EMBEDDING_DIMENSIONS) {
      throw new Error(
        `A ${COHERE_EMBEDDING_DIMENSIONS}-dimensional embedding is required`
      );
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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

    const {id, embedding, metadata, namespace} = request.data;
    if (!id || !Array.isArray(embedding) ||
        embedding.length !== COHERE_EMBEDDING_DIMENSIONS || !metadata) {
      throw new Error(
        `ID, metadata, and a ${COHERE_EMBEDDING_DIMENSIONS}-dimensional ` +
        "embedding are required"
      );
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index(PINECONE_INDEX_NAME);

      await index.upsert([{
        id,
        values: embedding,
        metadata,
      }]);

      await writePineconeUsage({
        userId: request.auth.uid ?? null,
        operation: "upsert",
        count: 1,
        namespace,
        source: "document_upload",
      }).catch(() => undefined);

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

    const {documents, namespace} = request.data;

    if (!documents || !Array.isArray(documents) || documents.length === 0) {
      throw new Error("Documents array required");
    }

    try {
      const pinecone = new Pinecone({apiKey: PINECONE_API_KEY.value()});
      const index = pinecone.Index(PINECONE_INDEX_NAME);

      const vectors = documents.map((doc) => {
        if (!doc.id || !doc.embedding || !doc.metadata) {
          throw new Error("Each document must have id, embedding, and metadata");
        }
        if (!Array.isArray(doc.embedding) ||
            doc.embedding.length !== COHERE_EMBEDDING_DIMENSIONS) {
          throw new Error(
            `Each embedding must have ${COHERE_EMBEDDING_DIMENSIONS} dimensions`
          );
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

      await writePineconeUsage({
        userId: request.auth.uid ?? null,
        operation: "upsert",
        count: totalInserted,
        namespace,
        source: "document_batch_upload",
      }).catch(() => undefined);

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
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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
      const index = pinecone.Index(PINECONE_INDEX_NAME);

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
