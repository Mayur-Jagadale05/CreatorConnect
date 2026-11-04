const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();
const db = admin.firestore();

// Retrieve secret Gemini API key configured in Firebase Environment or Secrets
// Set using: firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";

/**
 * HTTPS endpoint for CreatorConnect AI assistant
 */
exports.creatorConnectAI = functions.runWith({ secrets: ["GEMINI_API_KEY"] }).https.onRequest(async (req, res) => {
  // CORS configuration
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  // 1. Verify Firebase Auth Token
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({ error: "Unauthorized: Missing Bearer Token" });
    return;
  }

  const idToken = authHeader.split("Bearer ")[1];
  let decodedToken;
  try {
    decodedToken = await admin.auth().verifyIdToken(idToken);
  } catch (err) {
    res.status(401).json({ error: "Invalid or expired Firebase auth token" });
    return;
  }

  const userId = decodedToken.uid;
  const { systemInstruction, message, history } = req.body;

  if (!message || typeof message !== "string") {
    res.status(400).json({ error: "Invalid request: 'message' string is required" });
    return;
  }

  try {
    // 2. Fetch authenticated user document to verify genuine role
    const userDoc = await db.collection("users").doc(userId).get();
    const userData = userDoc.exists ? userDoc.data() : {};
    const role = (userData.role || "Influencer").trim();
    const name = userData.fullName || userData.name || userData.username || "Creator";

    // 3. Initialize Gemini
    const apiKey = GEMINI_API_KEY;
    if (!apiKey) {
      res.status(500).json({
        error: "Server configuration error: GEMINI_API_KEY is not configured.",
      });
      return;
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({
      model: "gemini-3.6-flash",
      systemInstruction: systemInstruction || `You are CreatorConnect AI assisting ${name}, a ${role}.`,
    });

    // 4. Build contents history
    const contents = [];
    if (Array.isArray(history)) {
      for (const h of history) {
        contents.push({
          role: h.role === "user" ? "user" : "model",
          parts: [{ text: h.content || "" }],
        });
      }
    }

    contents.push({
      role: "user",
      parts: [{ text: message }],
    });

    // 5. Call Gemini
    const result = await model.generateContent({
      contents,
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2048,
      },
    });

    const response = await result.response;
    const replyText = response.text();

    res.status(200).json({
      reply: replyText,
      role: role,
      userId: userId,
    });
  } catch (error) {
    console.error("CreatorConnect AI Execution Error:", error);
    res.status(500).json({
      error: error.message || "An error occurred while processing AI response.",
    });
  }
});
