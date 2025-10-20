// server.js - Backend cho Render
const express = require("express");
const cors = require("cors");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin"); // Import Firebase Admin

// --- Cấu hình ---
const PORT = process.env.PORT || 3000; // Render sẽ tự cung cấp PORT
const GEMINI_API_KEY = process.env.GEMINI_API_KEY; // Lấy API key từ biến môi trường

// Khởi tạo Firebase Admin SDK (KHÔNG cần require file key ở đây)
// Firebase Admin SDK sẽ tự động tìm biến môi trường GOOGLE_APPLICATION_CREDENTIALS
// const serviceAccount = require("./serviceAccountKey.json"); // <<< DÒNG NÀY ĐÃ BỊ XÓA/COMMENT

admin.initializeApp({
  // credential: admin.credential.cert(serviceAccount), // <<< DÒNG NÀY ĐÃ BỊ XÓA/COMMENT
}); // <<< KHỞI TẠO KHÔNG CẦN THAM SỐ

// Khởi tạo Gemini
if (!GEMINI_API_KEY) {
  console.error("Lỗi: Biến môi trường GEMINI_API_KEY chưa được đặt.");
  // Nên thoát ra để tránh lỗi không mong muốn
  // process.exit(1); // Bạn có thể bỏ comment dòng này nếu muốn server dừng hẳn khi thiếu key Gemini
}
// Chỉ khởi tạo Gemini nếu có API key
let genAI;
let model;
if (GEMINI_API_KEY) {
  genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  model = genAI.getGenerativeModel({ model: "gemini-1.0-pro" });
} else {
   console.warn("Cảnh báo: GEMINI_API_KEY không được cung cấp. Chức năng AI sẽ không hoạt động.");
}


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
    // Phân biệt lỗi token hết hạn và token không hợp lệ
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).send({ error: "Mã xác thực đã hết hạn." });
    }
    return res.status(403).send({ error: "Mã xác thực không hợp lệ." });
  }
};

// --- Định nghĩa API Endpoint ---
app.post("/askPTAI", authenticateToken, async (req, res) => {
  // Kiểm tra xem model Gemini đã được khởi tạo chưa
  if (!model) {
     console.error("Lỗi: Mô hình Gemini chưa sẵn sàng (thiếu API key?).");
     return res.status(503).send({ error: "Dịch vụ AI hiện không sẵn sàng." });
  }

  const userMessage = req.body.message;
  const userId = req.userId; // Lấy userId từ middleware

  if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
    return res.status(400).send({ error: "Tin nhắn không được để trống." });
  }

  console.log(`Nhận tin nhắn từ user ${userId}: "${userMessage}"`);

  try {
    const prompt = `Bạn là một Huấn luyện viên Cá nhân (PT) AI thân thiện và hiểu biết về fitness và dinh dưỡng. Hãy trả lời câu hỏi sau của người dùng một cách ngắn gọn, hữu ích và tạo động lực: "${userMessage}"`;
    const result = await model.generateContent(prompt);
    const response = await result.response;

    // Kiểm tra kỹ hơn phản hồi từ Gemini
    if (!response || typeof response.text !== 'function') {
       console.error(`Lỗi Gemini cho user ${userId}: Phản hồi không hợp lệ từ API.`);
       return res.status(500).send({ error: "AI không tạo được phản hồi hợp lệ." });
    }

    const aiText = response.text();
    console.log(`Phản hồi từ Gemini cho user ${userId}: "${aiText}"`);
    return res.status(200).send({ reply: aiText });

  } catch (error) {
    console.error(`Lỗi khi gọi Gemini API cho user ${userId}:`, error);
    // Gửi lỗi chung chung hơn cho client
    return res.status(500).send({ error: "Đã xảy ra lỗi khi giao tiếp với AI." });
  }
});

// --- Khởi động Server ---
app.listen(PORT, () => {
  console.log(`Server đang chạy tại cổng ${PORT}`);
});