const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {defineSecret} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

initializeApp();

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const groqApiKey = defineSecret("GROQ_API_KEY");

const GEMINI_MODEL = "gemini-3.8-flash";
const GROQ_MODEL = "openai/gpt-oss-20b";
const REQUEST_TIMEOUT_MS = 5000;

exports.generateSmartSuggestion = onDocumentCreated(
  {
    document: "ai_requests/{requestId}",
    region: "europe-west1",
    secrets: [geminiApiKey, groqApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const request = snapshot.data();
    const summary = sanitizeSummary(request.summary);
    const prompt = buildPrompt(summary);
    let result;
    let geminiError;

    try {
      result = {
        content: await askGemini(prompt),
        provider: "Gemini",
        model: GEMINI_MODEL,
      };
    } catch (error) {
      geminiError = safeError(error);
      console.warn("Gemini failed; trying Groq", geminiError);
      try {
        result = {
          content: await askGroq(prompt),
          provider: "Groq",
          model: GROQ_MODEL,
        };
      } catch (groqError) {
        const message = safeError(groqError);
        console.error("Both AI providers failed", {geminiError, message});
        await snapshot.ref.set(
          {
            status: "failed",
            completedAt: FieldValue.serverTimestamp(),
            error: "AI providers are temporarily unavailable",
          },
          {merge: true},
        );
        return;
      }
    }

    await getFirestore().doc("ai_suggestions/latest").set({
      content: result.content,
      provider: result.provider,
      model: result.model,
      generatedAt: FieldValue.serverTimestamp(),
      sourceRequestId: snapshot.id,
      periodDays: summary.periodDays,
    });

    await snapshot.ref.set(
      {
        status: "complete",
        completedAt: FieldValue.serverTimestamp(),
        provider: result.provider,
      },
      {merge: true},
    );
  },
);

async function askGemini(prompt) {
  const response = await fetchWithTimeout(
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`,
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey.value(),
      },
      body: JSON.stringify({
        contents: [{role: "user", parts: [{text: prompt}]}],
        generationConfig: {
          temperature: 0.25,
          maxOutputTokens: 500,
        },
      }),
    },
  );
  const body = await readJson(response);
  if (!response.ok) throw new Error(`Gemini ${response.status}: ${body.error?.message || "request failed"}`);
  const text = body.candidates?.[0]?.content?.parts
    ?.map((part) => part.text || "")
    .join("\n")
    .trim();
  if (!text) throw new Error("Gemini returned an empty response");
  return text;
}

async function askGroq(prompt) {
  const response = await fetchWithTimeout(
    "https://api.groq.com/openai/v1/chat/completions",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${groqApiKey.value()}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        temperature: 0.25,
        max_completion_tokens: 500,
        messages: [
          {
            role: "system",
            content: "You are a concise sales advisor for a Lebanese sweet and juice shop.",
          },
          {role: "user", content: prompt},
        ],
      }),
    },
  );
  const body = await readJson(response);
  if (!response.ok) throw new Error(`Groq ${response.status}: ${body.error?.message || "request failed"}`);
  const text = body.choices?.[0]?.message?.content?.trim();
  if (!text) throw new Error("Groq returned an empty response");
  return text;
}

async function fetchWithTimeout(url, options) {
  return fetch(url, {
    ...options,
    signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
  });
}

async function readJson(response) {
  const text = await response.text();
  try {
    return JSON.parse(text);
  } catch (_) {
    return {error: {message: text.slice(0, 200)}};
  }
}

function sanitizeSummary(value) {
  const summary = value && typeof value === "object" ? value : {};
  return {
    periodDays: clampNumber(summary.periodDays, 1, 90, 30),
    totalOrders: clampNumber(summary.totalOrders, 0, 1000000, 0),
    totalRevenueLbp: clampNumber(summary.totalRevenueLbp, 0, 1e15, 0),
    topProducts: sanitizeRows(summary.topProducts, 10),
    weakProducts: sanitizeRows(summary.weakProducts, 5),
    commonPairs: sanitizeRows(summary.commonPairs, 5),
    peakHour: String(summary.peakHour || "غير متوفر").slice(0, 30),
  };
}

function sanitizeRows(value, limit) {
  if (!Array.isArray(value)) return [];
  return value.slice(0, limit).map((row) => ({
    name: String(row?.name || "").slice(0, 80),
    quantity: clampNumber(row?.quantity, 0, 1000000, 0),
    count: clampNumber(row?.count, 0, 1000000, 0),
  }));
}

function clampNumber(value, min, max, fallback) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(max, Math.max(min, parsed));
}

function buildPrompt(summary) {
  return `
حلل ملخص مبيعات محل Sweet Sip التالي وقدّم 3 اقتراحات عملية فقط باللغة العربية.
ركّز على عرض يجمع منتجات تُشترى معاً، دعم المنتج الضعيف، والاستعداد للمنتج الأكثر طلباً.
لا تخترع أرقاماً أو أسعاراً، ولا تقترح تغييراً تلقائياً. اجعل كل اقتراح سطراً واضحاً يبدأ بـ •.

البيانات:
${JSON.stringify(summary)}
`.trim();
}

function safeError(error) {
  return String(error?.message || error || "unknown error").slice(0, 300);
}
