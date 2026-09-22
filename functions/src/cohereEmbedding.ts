import axios from "axios";

export const COHERE_EMBEDDING_MODEL = "embed-multilingual-v3.0";
export const COHERE_EMBEDDING_DIMENSIONS = 1024;
export const PINECONE_INDEX_NAME = "oasp-assist";

export type CohereEmbeddingInputType = "search_document" | "search_query";

export function normalizeCohereInputType(taskType?: string): CohereEmbeddingInputType {
  return taskType === "search_query" || taskType === "RETRIEVAL_QUERY" ?
    "search_query" : "search_document";
}

export async function createCohereEmbedding(
  text: string,
  apiKey: string,
  inputType: CohereEmbeddingInputType = "search_document"
): Promise<number[]> {
  const response = await axios.post(
    "https://api.cohere.ai/v1/embed",
    {
      texts: [text],
      model: COHERE_EMBEDDING_MODEL,
      input_type: inputType,
      embedding_types: ["float"],
    },
    {
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      timeout: 30000,
    }
  );

  const embedding = response.data?.embeddings?.float?.[0] ??
    response.data?.embeddings?.[0];
  if (!Array.isArray(embedding)) {
    throw new Error("Invalid Cohere embedding response");
  }
  if (embedding.length !== COHERE_EMBEDDING_DIMENSIONS) {
    throw new Error(
      `Unexpected Cohere embedding dimension: ${embedding.length} ` +
      `(expected ${COHERE_EMBEDDING_DIMENSIONS})`
    );
  }

  return embedding;
}
