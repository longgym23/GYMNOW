// server.js - Backend cho Render
const express = require("express");
const cors = require("cors");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin"); // Import Firebase Admin

// --- Cấu hình ---
const PORT = process.env.PORT || 3000;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Khởi tạo Firebase Admin SDK (Tự động đọc GOOGLE_APPLICATION_CREDENTIALS)
admin.initializeApp();

// Khởi tạo Gemini
let genAI;
let model;
if (!GEMINI_API_KEY) {
  console.error("Lỗi: Biến môi trường GEMINI_API_KEY chưa được đặt.");
} else {
  genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
  // **SỬ DỤNG MÔ HÌNH NHANH HƠN**
  model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });
  console.log("Đã khởi tạo mô hình Gemini: gemini-2.5-flash-lite");
}

// Khởi tạo Express App
const app = express();
app.use(cors());
app.use(express.json());

// --- Middleware Xác thực Token ---
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).send({ error: "Yêu cầu cần mã xác thực Bearer." });
  }
  const idToken = authHeader.split("Bearer ")[1];
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    req.userId = decodedToken.uid;
    next();
  } catch (error) {
    console.error("Lỗi xác thực token:", error);
    if (error.code === 'auth/id-token-expired') {
      return res.status(401).send({ error: "Mã xác thực đã hết hạn." });
    }
    return res.status(403).send({ error: "Mã xác thực không hợp lệ." });
  }
};

// --- Định nghĩa API Endpoint ---
app.post("/askPTAI", authenticateToken, async (req, res) => {
  if (!model) {
     console.error("Lỗi: Mô hình Gemini chưa sẵn sàng.");
     return res.status(503).send({ error: "Dịch vụ AI hiện không sẵn sàng." });
  }

  const userMessage = req.body.message;
  const userId = req.userId;

  if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
    return res.status(400).send({ error: "Tin nhắn không được để trống." });
  }

  console.log(`Nhận tin nhắn từ user ${userId}: "${userMessage}"`);

  try {
    // **PROMPT ĐÃ ĐƯỢC TỐI ƯU**
    const prompt = `
Bạn là một Huấn luyện viên Cá nhân AI (PT AI) chuyên nghiệp, thân thiện và am hiểu.
Vai trò của bạn là đưa ra lời khuyên về fitness và dinh dưỡng an toàn, thực tế.

**QUY TẮC TRẢ LỜI:**
* Trả lời bằng **tiếng Việt**.
* **Ngắn gọn, rõ ràng, đi thẳng vào vấn đề.**
* **KHÔNG sử dụng** định dạng Markdown như dấu sao (*), thăng (#), gạch ngang (- ở đầu dòng), hay ký tự backtick (\`). Sử dụng văn bản thuần túy. Nếu cần liệt kê, dùng dấu chấm tròn (•) hoặc số.
* Nếu đưa ra thực đơn hoặc lịch tập, trình bày dễ đọc.
* Luôn nhấn mạnh tầm quan trọng của việc tham khảo ý kiến chuyên gia y tế nếu cần.

**Câu hỏi của người dùng:** "${userMessage}"

Hãy trả lời câu hỏi trên dựa theo vai trò và quy tắc đã nêu.`;

    // --- Gọi Gemini API ---
    const result = await model.generateContent(prompt);
    const response = await result.response;

    if (!response || typeof response.text !== 'function') {
       console.error(`Lỗi Gemini cho user ${userId}: Phản hồi không hợp lệ từ API.`);
       return res.status(500).send({ error: "AI không tạo được phản hồi hợp lệ." });
    }

    let aiText = response.text(); // Lấy text gốc

    // **LÀM SẠCH MARKDOWN CƠ BẢN**
    aiText = aiText.replace(/[*#`]/g, ''); // Xóa các ký tự Markdown phổ biến
    aiText = aiText.replace(/^- /gm, '• '); // Thay gạch đầu dòng Markdown bằng dấu chấm tròn
    aiText = aiText.trim(); // Xóa khoảng trắng thừa ở đầu/cuối

    console.log(`Phản hồi (đã làm sạch) cho user ${userId}: "${aiText}"`);

    // --- Trả lời về cho app Flutter ---
    return res.status(200).send({ reply: aiText }); // Gửi text đã làm sạch

  } catch (error) {
    console.error(`Lỗi khi gọi Gemini API cho user ${userId}:`, error);
    return res.status(500).send({ error: "Đã xảy ra lỗi khi giao tiếp với AI." });
  }
});

// --- Khởi động Server ---
app.listen(PORT, () => {
  console.log(`Server đang chạy tại cổng ${PORT}`);
});

// **ĐOẠN CODE BỊ LẶP Ở CUỐI ĐÃ ĐƯỢC XÓA BỎ**