import * as admin from "firebase-admin";

type GeminiUsageLog = {
  userId: string | null;
  conversationId: string | null;
  model: string;
  inputTokens: number;
  outputTokens: number;
};

const PRICES: Record<string, {input: number; output: number}> = {
  "gemini-2.5-flash": {input: 0.30, output: 2.50},
  "gemini-embedding-001": {input: 0.15, output: 0},
  "cloud-vision": {input: 1500, output: 0},
  "gemini-2.0-flash": {input: 0.10, output: 0.40},
  "gemini-1.5-flash": {input: 0.075, output: 0.30},
  "gemini-1.5-pro": {input: 1.25, output: 5.00},
  "gemini-pro": {input: 0.50, output: 1.50},
};

export async function logGeminiUsage({
  userId,
  conversationId,
  model,
  inputTokens,
  outputTokens,
}: GeminiUsageLog): Promise<void> {
  const pricing = PRICES[model] ?? PRICES["gemini-2.0-flash"];
  const safeInputTokens = Math.max(0, Number(inputTokens) || 0);
  const safeOutputTokens = Math.max(0, Number(outputTokens) || 0);
  const inputCostUsd = (safeInputTokens / 1_000_000) * pricing.input;
  const outputCostUsd = (safeOutputTokens / 1_000_000) * pricing.output;
  const totalCostUsd = inputCostUsd + outputCostUsd;
  const usdToPhp = parseFloat(process.env.USD_TO_PHP ?? "56");

  await admin.firestore().collection("gemini_usage").add({
    userId: userId ?? null,
    conversationId: conversationId ?? null,
    model,
    inputTokens: safeInputTokens,
    outputTokens: safeOutputTokens,
    totalTokens: safeInputTokens + safeOutputTokens,
    costUsd: totalCostUsd,
    costPhp: totalCostUsd * usdToPhp,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    date: new Date().toISOString().substring(0, 10),
  });
}
