const REDIS_INSTRUMENTATIONS = ["ioredis", "redis", "redis-4"];

try {
  const disabledInstrumentations = new Set(
    (process.env.OTEL_NODE_DISABLED_INSTRUMENTATIONS || "")
      .split(",")
      .map((name) => name.trim())
      .filter(Boolean)
  );

  for (const instrumentation of REDIS_INSTRUMENTATIONS) {
    disabledInstrumentations.add(instrumentation);
  }

  process.env.OTEL_NODE_DISABLED_INSTRUMENTATIONS =
    Array.from(disabledInstrumentations).join(",");

  console.info(
    "Integration controls applied: Redis instrumentation and " +
    "Google Cloud Vision OCR are disabled."
  );
} catch (error) {
  console.error("Failed to apply integration controls:", error);
  throw error;
}

export const GOOGLE_CLOUD_VISION_ENABLED = false;
