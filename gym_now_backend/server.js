// server.js - Backend cho Render
const express = require("express");
const cors = require("cors");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin");

// --- Cấu hình ---
const PORT = process.env.PORT || 3000; // Render sẽ tự cung cấp PORT
const GEMINI_API_KEY = process.env.GEMINI_API_KEY; // Lấy API key từ biến môi trường

// Khởi tạo Firebase Admin SDK (Cần file serviceAccountKey.json)
// Tải file key từ Firebase Console > Project Settings > Service accounts > Generate new private key
const serviceAccount = require("./serviceAccountKey.json"); // Đặt file key vào cùng thư mục
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Khởi tạo Gemini
if (!GEMINI_API_KEY) {
  console.error("Lỗi: Biến môi trường GEMINI_API_KEY chưa được đặt.");
  process.exit(1); // Thoát nếu thiếu key
}
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
const model = genAI.getGenerativeModel({ model: "gemini-pro" });

// Khởi tạo Express App
const app = express();
app.use(cors()); // Cho phép gọi từ tên miền khác (app Flutter)
app.use(express.json()); // Xử lý request body dạng JSON

// --- Middleware Xác thực Token ---
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).send({ error: "Yêu cầu cần mã xác thực Bearer." });
  }
  const idToken = authHeader.split("Bearer ")[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.userId = decodedToken.uid; // Gắn userId vào request để hàm xử lý dùng
    next(); // Chuyển tiếp request đến hàm xử lý chính
  } catch (error) {
    console.error("Lỗi xác thực token:", error);
    return res.status(403).send({ error: "Mã xác thực không hợp lệ." });
  }
};

// --- Định nghĩa API Endpoint ---
app.post("/askPTAI", authenticateToken, async (req, res) => {
  const userMessage = req.body.message;
  const userId = req.userId; // Lấy userId từ middleware

  if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
    return res.status(400).send({ error: "Tin nhắn không được để trống." });
  }

  console.log(`Nhận tin nhắn từ user ${userId}: "${userMessage}"`);

  try {
    const prompt = `Bạn là một Huấn luyện viên Cá nhân (PT) AI thân thiện... (giống prompt cũ)...: "${userMessage}"`; // Viết lại prompt đầy đủ
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const aiText = response.text();
    console.log(`Phản hồi từ Gemini cho user ${userId}: "${aiText}"`);
    return res.status(200).send({ reply: aiText });
  } catch (error) {
    console.error(`Lỗi khi gọi Gemini API cho user ${userId}:`, error);
    return res.status(500).send({ error: "Lỗi giao tiếp với AI." });
  }
});

// --- Khởi động Server ---
app.listen(PORT, () => {
  console.log(`Server đang chạy tại cổng ${PORT}`);
});