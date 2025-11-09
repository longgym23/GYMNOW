// server.js - Backend cho Render
const express = require("express");
const cors = require("cors");
const { GoogleGenerativeAI } = require("@google/generative-ai");
const admin = require("firebase-admin"); // Import Firebase Admin
const nodemailer = require("nodemailer");

// --- Cấu hình ---
const PORT = process.env.PORT || 3000;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Cấu hình email (Gmail SMTP)
const EMAIL_USER = process.env.EMAIL_USER || ""; // Email gửi đi (ví dụ: your-email@gmail.com)
const EMAIL_PASS = process.env.EMAIL_PASS || ""; // App Password của Gmail (không phải mật khẩu thường)

// Tạo transporter cho nodemailer
let transporter = null;
if (EMAIL_USER && EMAIL_PASS) {
  transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
      user: EMAIL_USER,
      pass: EMAIL_PASS, // Sử dụng App Password, không phải mật khẩu thường
    },
  });
  console.log("✅ Email service đã được cấu hình");
} else {
  console.warn("⚠️ Email service chưa được cấu hình. Vui lòng set EMAIL_USER và EMAIL_PASS trong environment variables.");
}

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
  const userInfo = req.body.userInfo || {}; // Thông tin user (height, weight)
  const userId = req.userId;

  if (!userMessage || typeof userMessage !== "string" || userMessage.trim() === "") {
    return res.status(400).send({ error: "Tin nhắn không được để trống." });
  }

  console.log(`📨 Nhận tin nhắn từ user ${userId}: "${userMessage}"`);
  console.log(`📊 UserInfo nhận được:`, JSON.stringify(userInfo, null, 2));
  
  if (userInfo && userInfo.height && userInfo.weight) {
    const ageInfo = userInfo.age ? `, Tuổi ${userInfo.age}` : '';
    const genderInfo = userInfo.gender ? `, Giới tính: ${userInfo.gender === 'male' ? 'Nam' : 'Nữ'}` : '';
    const goalInfo = userInfo.goalType ? `, Mục tiêu: ${userInfo.goalType}` : '';
    console.log(`✅ Thông tin user đầy đủ: Chiều cao ${userInfo.height}cm, Cân nặng ${userInfo.weight}kg${ageInfo}${genderInfo}${goalInfo}`);
  } else {
    console.log(`⚠️ Thông tin user không đầy đủ hoặc chưa có`);
  }

  try {
    // Tạo thông tin chi tiết về user
    let userInfoText = "";
    if (userInfo.height && userInfo.weight && userInfo.height > 0 && userInfo.weight > 0) {
      const heightInMeters = userInfo.height / 100;
      const bmi = userInfo.weight / (heightInMeters * heightInMeters);
      let bmiCategory = "";
      if (bmi < 18.5) {
        bmiCategory = "Thiếu cân";
      } else if (bmi < 25) {
        bmiCategory = "Bình thường";
      } else if (bmi < 30) {
        bmiCategory = "Thừa cân";
      } else {
        bmiCategory = "Béo phì";
      }

      // Xây dựng thông tin user đầy đủ
      userInfoText = `\n\n**THÔNG TIN NGƯỜI DÙNG ĐÃ ĐIỀN TRONG APP:**
- Tên: ${userInfo.name || 'Người dùng'}
- Chiều cao: ${userInfo.height} cm
- Cân nặng: ${userInfo.weight} kg
- Tuổi: ${userInfo.age || 25} tuổi
- Giới tính: ${userInfo.gender === 'male' ? 'Nam' : userInfo.gender === 'female' ? 'Nữ' : 'Chưa cập nhật'}
- BMI: ${bmi.toFixed(1)} (${bmiCategory})`;

      // Thêm thông tin mục tiêu dinh dưỡng nếu có
      const goalTypeMap = {
        'loseWeight': 'Giảm cân giảm mỡ',
        'gainWeight': 'Tăng cân',
        'gainMuscle': 'Tăng cơ',
        'maintain': 'Duy trì cân nặng'
      };
      
      if (userInfo.goalType) {
        userInfoText += `\n- Mục tiêu: ${goalTypeMap[userInfo.goalType] || userInfo.goalType}`;
        if (userInfo.targetWeight) {
          userInfoText += `\n- Cân nặng mục tiêu: ${userInfo.targetWeight} kg`;
        }
      }

      if (userInfo.targetCalories && userInfo.targetCalories > 0) {
        userInfoText += `\n- Calo mục tiêu hàng ngày: ${userInfo.targetCalories.toFixed(0)} cal`;
        if (userInfo.targetProtein) {
          userInfoText += `\n- Protein mục tiêu: ${userInfo.targetProtein.toFixed(0)}g`;
        }
        if (userInfo.targetCarbs) {
          userInfoText += `\n- Carbs mục tiêu: ${userInfo.targetCarbs.toFixed(0)}g`;
        }
        if (userInfo.targetFat) {
          userInfoText += `\n- Fat mục tiêu: ${userInfo.targetFat.toFixed(0)}g`;
        }
      }

      if (userInfo.activityLevel) {
        userInfoText += `\n- Mức độ hoạt động: ${userInfo.activityLevel}`;
      }

      // Tạo ví dụ cụ thể với thông tin thực tế của user
      const exampleText = userInfo.goalType 
        ? `Ví dụ: Nếu user hỏi "Làm sao tôi có thể giảm cân?" → Trả lời dựa trên BMI ${bmi.toFixed(1)} (${bmiCategory}), tuổi ${userInfo.age || 25}, giới tính ${userInfo.gender === 'male' ? 'Nam' : 'Nữ'}, mục tiêu ${goalTypeMap[userInfo.goalType] || userInfo.goalType} của họ. KHÔNG hỏi lại về chiều cao, cân nặng, tuổi, giới tính.`
        : `Ví dụ: Nếu user hỏi "Làm sao tôi có thể giảm cân?" → Trả lời dựa trên BMI ${bmi.toFixed(1)} (${bmiCategory}), tuổi ${userInfo.age || 25}, giới tính ${userInfo.gender === 'male' ? 'Nam' : userInfo.gender === 'female' ? 'Nữ' : 'chưa cập nhật'} của họ. KHÔNG hỏi lại về chiều cao, cân nặng, tuổi, giới tính.`;
      
      userInfoText += `\n\n**QUY TẮC QUAN TRỌNG - ĐỌC KỸ VÀ TUÂN THỦ:**
1. Bạn ĐÃ CÓ ĐẦY ĐỦ thông tin về người dùng từ app (đã liệt kê ở trên).
2. TUYỆT ĐỐI KHÔNG được yêu cầu người dùng cung cấp lại bất kỳ thông tin nào đã có ở trên (chiều cao, cân nặng, tuổi, giới tính, BMI, mục tiêu).
3. Khi người dùng hỏi về sức khỏe, giảm cân, tăng cân, hoặc bất kỳ câu hỏi liên quan đến thể trạng, bạn PHẢI:
   - Sử dụng NGAY các thông tin đã có ở trên
   - Đưa ra lời khuyên CỤ THỂ dựa trên BMI ${bmi.toFixed(1)} (${bmiCategory}), tuổi ${userInfo.age || 25}, và các thông tin khác
   - Trả lời như một chuyên gia đã biết rõ về người dùng
4. ${exampleText}
5. Nếu user hỏi "Với các chỉ số sức khỏe của tôi thì có tăng cân nhanh được không?" → Phân tích dựa trên BMI ${bmi.toFixed(1)}, tuổi ${userInfo.age || 25}, giới tính ${userInfo.gender === 'male' ? 'Nam' : userInfo.gender === 'female' ? 'Nữ' : 'chưa cập nhật'}, và đưa ra lời khuyên cụ thể. KHÔNG yêu cầu cung cấp lại thông tin.
6. Hãy tự tin và chuyên nghiệp, trả lời như thể bạn đã biết rõ về người dùng từ trước.`;
    } else {
      // Nếu không có thông tin đầy đủ, vẫn có thể có một số thông tin cơ bản
      userInfoText = `\n\n**LƯU Ý:** Một số thông tin về người dùng có thể chưa được cập nhật đầy đủ trong app. Nếu cần thông tin cụ thể để đưa ra lời khuyên chính xác, bạn có thể hỏi người dùng.`;
    }

    // **CẬP NHẬT PROMPT ĐỂ XỬ LÝ ẢNH VÀ THÔNG TIN USER**
    const promptText = `
Bạn là một Huấn luyện viên Cá nhân AI (PT AI) chuyên nghiệp, thân thiện và am hiểu.
Vai trò của bạn là đưa ra lời khuyên về fitness và dinh dưỡng.

**QUY TẮC TRẢ LỜI:**
* Trả lời bằng tiếng Việt, ngắn gọn, không dùng Markdown (*, #, \`).
* Nếu có ảnh, hãy phân tích ảnh đó trong ngữ cảnh câu hỏi. Ví dụ: ước tính calo món ăn, nhận xét tư thế tập, nhận diện thực phẩm.
* Nếu không có ảnh, chỉ trả lời câu hỏi văn bản.

${userInfoText}

**Câu hỏi/yêu cầu của người dùng:** "${userMessage}"

**HƯỚNG DẪN TRẢ LỜI:**
- Nếu có thông tin đầy đủ về người dùng ở trên, hãy SỬ DỤNG NGAY các thông tin đó để trả lời.
- Đưa ra lời khuyên cụ thể, chi tiết dựa trên BMI, mục tiêu, và tình trạng hiện tại của người dùng.
- KHÔNG yêu cầu người dùng cung cấp lại thông tin đã có ở trên.
- Hãy trả lời như một chuyên gia đã biết rõ về người dùng.`;

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

// --- Endpoint gửi mã PIN qua email ---
app.post("/sendPinEmail", async (req, res) => {
  try {
    const { email, pin } = req.body;

    if (!email || !pin) {
      return res.status(400).send({ 
        success: false,
        message: "Thiếu email hoặc mã PIN" 
      });
    }

    // Log thông tin
    console.log('📧 Gửi mã PIN:');
    console.log(`   Email: ${email}`);
    console.log(`   Mã PIN: ${pin}`);
    console.log(`   Thời gian: ${new Date().toLocaleString('vi-VN')}`);

    // Gửi email thực tế nếu đã cấu hình
    if (transporter) {
      try {
        const mailOptions = {
          from: `"GymNow" <${EMAIL_USER}>`,
          to: email,
          subject: "Mã PIN đặt lại mật khẩu - GymNow",
          html: `
            <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
              <div style="background: linear-gradient(135deg, #1B263B 0%, #415A77 100%); padding: 30px; border-radius: 10px 10px 0 0; text-align: center;">
                <h1 style="color: white; margin: 0;">GymNow</h1>
              </div>
              <div style="background: #f5f5f5; padding: 30px; border-radius: 0 0 10px 10px;">
                <h2 style="color: #1B263B; margin-top: 0;">Mã PIN đặt lại mật khẩu</h2>
                <p style="color: #333; font-size: 16px;">Xin chào,</p>
                <p style="color: #333; font-size: 16px;">Bạn đã yêu cầu đặt lại mật khẩu cho tài khoản GymNow của mình.</p>
                <div style="background: white; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center; border: 2px solid #1B263B;">
                  <p style="color: #666; margin: 0 0 10px 0; font-size: 14px;">Mã PIN của bạn là:</p>
                  <h1 style="color: #1B263B; font-size: 36px; letter-spacing: 5px; margin: 0;">${pin}</h1>
                </div>
                <p style="color: #666; font-size: 14px; margin-top: 20px;">
                  <strong>Lưu ý:</strong> Mã PIN này có hiệu lực trong <strong>10 phút</strong> và chỉ có thể sử dụng một lần.
                </p>
                <p style="color: #666; font-size: 14px;">
                  Nếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.
                </p>
                <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
                <p style="color: #999; font-size: 12px; text-align: center; margin: 0;">
                  Email này được gửi tự động, vui lòng không trả lời.
                </p>
              </div>
            </div>
          `,
          text: `Mã PIN đặt lại mật khẩu của bạn là: ${pin}\n\nMã PIN có hiệu lực trong 10 phút và chỉ có thể sử dụng một lần.\n\nNếu bạn không yêu cầu đặt lại mật khẩu, vui lòng bỏ qua email này.`,
        };

        await transporter.sendMail(mailOptions);
        console.log(`✅ Email đã được gửi thành công đến ${email}`);
        
        return res.status(200).send({
          success: true,
          message: "Mã PIN đã được gửi đến email của bạn"
        });
      } catch (emailError) {
        console.error('❌ Lỗi khi gửi email:', emailError);
        // Vẫn trả về success nếu có lỗi email nhưng đã log ra console
        return res.status(200).send({
          success: true,
          message: "Mã PIN đã được tạo. Vui lòng kiểm tra email hoặc console log."
        });
      }
    } else {
      // Nếu chưa cấu hình email service, chỉ log ra console
      console.warn("⚠️ Email service chưa được cấu hình. Mã PIN chỉ được log ra console.");
      return res.status(200).send({
        success: true,
        message: "Mã PIN đã được tạo. Vui lòng kiểm tra console log của server."
      });
    }
  } catch (error) {
    console.error('❌ Lỗi khi xử lý yêu cầu gửi email:', error);
    return res.status(500).send({
      success: false,
      message: "Không thể gửi email. Vui lòng thử lại sau."
    });
  }
});

// --- Khởi động Server ---
app.listen(PORT, () => {
  console.log(`Server đang chạy tại cổng ${PORT}`);
});
