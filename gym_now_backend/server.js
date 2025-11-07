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
// Tăng giới hạn kích thước body request để chứa ảnh base64 (ví dụ: 10mb)
app.use(express.json({ limit: "10mb" }));

// --- Middleware Xác thực Token ---
const authenticateToken = async (req, res, next) => {
  // ... (code middleware giữ nguyên) ...
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

// --- Định nghĩa API Endpoint (ĐÃ CẬP NHẬT) ---
app.post("/askPTAI", authenticateToken, async (req, res) => {
  if (!model) {
     console.error("Lỗi: Mô hình Gemini chưa sẵn sàng.");
     return res.status(503).send({ error: "Dịch vụ AI hiện không sẵn sàng." });
  }

  // **NHẬN DỮ LIỆU MỚI TỪ FLUTTER**
  const userMessage = req.body.message || ""; // Lấy text (hoặc chuỗi rỗng nếu chỉ gửi ảnh)
  const imageBase64 = req.body.imageBase64;
  const imageMimeType = req.body.mimeType;
  const userId = req.userId;

  if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
    return res.status(400).send({ error: "Tin nhắn không được để trống." });
  }

  console.log(`Nhận tin nhắn từ user ${userId}: "${userMessage}"`);

  try {
    // **CẬP NHẬT PROMPT ĐỂ XỬ LÝ ẢNH**
    const promptText = `
Bạn là một Huấn luyện viên Cá nhân AI (PT AI) chuyên nghiệp, thân thiện và am hiểu.
Vai trò của bạn là đưa ra lời khuyên về fitness và dinh dưỡng.
* Trả lời bằng **tiếng Việt**, **ngắn gọn**, **không dùng Markdown** (*, #, \`).
* Nếu có ảnh, hãy phân tích ảnh đó trong ngữ cảnh câu hỏi. Ví dụ: ước tính calo món ăn, nhận xét tư thế tập, nhận diện thực phẩm.
* Nếu không có ảnh, chỉ trả lời câu hỏi văn bản.

**Câu hỏi/yêu cầu:** "${userMessage}"`;

    let contentToGenerate;

    if (imageBase64 && imageMimeType) {
      // **TẠO PROMPT ĐA PHƯƠNG TIỆN (TEXT + ẢNH)**
      const imagePart = {
        inlineData: {
          mimeType: imageMimeType,
          data: imageBase64,
        },
      };
      contentToGenerate = [promptText, imagePart]; // Gửi mảng gồm text và ảnh
    } else {
      // **TẠO PROMPT CHỈ TEXT**
      contentToGenerate = [promptText]; // Chỉ gửi text
    }
    
    // --- Gọi Gemini API ---
    const result = await model.generateContent(contentToGenerate); // Gửi nội dung đã chuẩn bị
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

// --- Phân tích ảnh món ăn, trả về JSON dinh dưỡng ---
app.post("/analyze-food-image", authenticateToken, async (req, res) => {
  if (!model) {
    return res.status(503).send({ error: "Dịch vụ AI hiện không sẵn sàng." });
  }

  const imageBase64 = req.body.imageBase64;
  const imageMimeType = req.body.mimeType;
  if (!imageBase64 || !imageMimeType) {
    return res.status(400).send({ error: "Thiếu ảnh (imageBase64, mimeType)." });
  }

  try {
    const prompt = `Bạn là chuyên gia dinh dưỡng. Hãy nhận diện món ăn trong ảnh và ước tính thông tin sau theo khẩu phần nhìn thấy.
Trả lời CHỈ DƯỚI DẠNG JSON hợp lệ, không kèm giải thích:
{
  "dishName": string,
  "ingredients": string[],
  "servingUnit": string, // ví dụ: 1 dĩa, 1 chén, 100g
  "calories": number, // kcal
  "protein": number, // gram
  "carbs": number, // gram
  "fat": number, // gram
  "fiber": number // gram (có thể 0 nếu không chắc)
}`;

    const imagePart = {
      inlineData: { mimeType: imageMimeType, data: imageBase64 },
    };

    const result = await model.generateContent([prompt, imagePart]);
    const response = await result.response;
    const text = (response && typeof response.text === 'function') ? response.text() : '';

    // Cố gắng trích JSON từ văn bản trả về
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      return res.status(500).send({ error: "AI không trả về JSON hợp lệ." });
    }

    let payload;
    try {
      payload = JSON.parse(jsonMatch[0]);
    } catch (e) {
      return res.status(500).send({ error: "Không thể phân tích JSON từ AI." });
    }

    // Chuẩn hóa giá trị số
    const toNum = (v) => (typeof v === 'number' ? v : parseFloat(v) || 0);
    payload.calories = toNum(payload.calories);
    payload.protein = toNum(payload.protein);
    payload.carbs = toNum(payload.carbs);
    payload.fat = toNum(payload.fat);
    payload.fiber = toNum(payload.fiber);
    if (!Array.isArray(payload.ingredients)) payload.ingredients = [];
    if (!payload.servingUnit) payload.servingUnit = '1 khẩu phần';

    return res.status(200).send(payload);
  } catch (error) {
    console.error('Lỗi /analyze-food-image:', error);
    return res.status(500).send({ error: "Đã xảy ra lỗi khi phân tích ảnh." });
  }
});

// --- Khởi động Server ---
app.listen(PORT, () => {
  console.log(`Server đang chạy tại cổng ${PORT}`);
});
