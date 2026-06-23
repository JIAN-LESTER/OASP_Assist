import {onCall} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

type FirebaseOperation = "read" | "write" | "delete";

const ignoredCollections = new Set([
  "firebase_usage",
  "gemini_usage",
  "pinecone_usage",
  "genkit_usage",
]);

function today(): string {
  return new Date().toISOString().substring(0, 10);
}

async function logFirebaseUsage({
  userId,
  operation,
  collection,
  count,
  source,
  path,
}: {
  userId: string | null;
  operation: FirebaseOperation;
  collection: string;
  count: number;
  source: string;
  path?: string | null;
}) {
  if (ignoredCollections.has(collection)) return;

  const safeCount = Math.max(1, Number(count) || 1);

  await admin.firestore().collection("firebase_usage").add({
    userId: userId ?? null,
    collection,
    path: path ?? null,
    operation,
    source,
    usageCount: safeCount,
    readCount: operation === "read" || operation === "delete" ? safeCount : 0,
    writeCount: operation === "write" ? safeCount : 0,
    deleteCount: operation === "delete" ? safeCount : 0,
    reads: operation === "read" || operation === "delete" ? safeCount : 0,
    writes: operation === "write" ? safeCount : 0,
    deletes: operation === "delete" ? safeCount : 0,
    costUsd: 0,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    date: today(),
  });
}

async function handleFirestoreWrite(event: any, collection: string) {
  if (ignoredCollections.has(collection)) return;

  const beforeExists = event.data?.before?.exists ?? false;
  const afterExists = event.data?.after?.exists ?? false;

  if (!beforeExists && !afterExists) return;

  const operation: FirebaseOperation =
    beforeExists && !afterExists ? "delete" : "write";

  await logFirebaseUsage({
    userId: null,
    operation,
    collection,
    count: 1,
    source: operation === "delete" ? "delete" : "add_update",
    path: event.document ?? null,
  });
}

export const logFirebaseRead = onCall(
  async (request) => {
    if (!request.auth) throw new Error("Unauthorized");

    const {collection = "unknown", count = 1, source = "data_display"} =
      request.data ?? {};

    await logFirebaseUsage({
      userId: request.auth.uid ?? null,
      operation: "read",
      collection: collection.toString(),
      count,
      source: source.toString(),
    });

    return {success: true};
  }
);

export const logTopLevelFirebaseUsage = onDocumentWritten(
  "{collectionId}/{docId}",
  async (event) => {
    await handleFirestoreWrite(event, event.params.collectionId);
  }
);

export const logNestedFirebaseUsage = onDocumentWritten(
  "{collectionId}/{docId}/{subCollectionId}/{subDocId}",
  async (event) => {
    await handleFirestoreWrite(event, event.params.subCollectionId);
  }
);
