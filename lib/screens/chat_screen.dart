import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<types.Message> _messages = [];
  final _user = types.User(
    id: FirebaseAuth.instance.currentUser?.uid ?? 'local_user',
  );
  final _bot = const types.User(id: 'pt_ai_bot', firstName: 'PT AI');
  bool _isBotTyping = false;

  // **BIẾN MỚI CHO SPEECH-TO-TEXT**
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  // Controller để điều khiển nội dung ô chat
  final TextEditingController _textController = TextEditingController();

  // **BIẾN MỚI CHO GỬI ẢNH**
  final ImagePicker _picker = ImagePicker();
  String? _imageBase64; // Lưu ảnh đã mã hóa
  String? _imageMimeType;

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
    _initSpeech(); // Khởi tạo speech-to-text
  }

  @override
  void dispose() {
    _speechToText.stop(); // Đảm bảo dừng nghe khi thoát
    _textController.dispose(); // Hủy controller
    super.dispose();
  }

  /// Khởi tạo và xin quyền micro
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (errorNotification) =>
            print('Lỗi SpeechToText: $errorNotification'),
        onStatus: (status) =>
            setState(() => _isListening = _speechToText.isListening),
      );
      if (mounted) setState(() {});
    } catch (e) {
      print("Lỗi khi khởi tạo SpeechToText: $e");
      setState(() => _speechEnabled = false);
    }
  }

  /// Bắt đầu nghe (khi nhấn giữ hoặc nhấn nút)
  void _startListening() async {
    if (!_speechEnabled) {
      print("Nhận dạng giọng nói chưa được kích hoạt.");
      return;
    }
    _stopListening(); // Dừng lần nghe trước nếu có
    if (!mounted) return;
    setState(() => _isListening = true);

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'vi_VN', // Đặt ngôn ngữ tiếng Việt
      listenMode: ListenMode.confirmation, // Chế độ nghe phù hợp cho dictation
      partialResults: true, // Nhận kết quả tạm thời
    );
  }

  /// Dừng nghe
  void _stopListening() async {
    if (!_isListening && !_speechToText.isListening) return;
    await _speechToText.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  /// Callback khi có kết quả nhận dạng
  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() {
      // Cập nhật nội dung ô chat bằng kết quả nhận dạng
      _textController.text = result.recognizedWords;
      // Di chuyển con trỏ về cuối
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
  }
  

  /// Thêm tin nhắn chào mừng (không đổi)
  void _addInitialMessage() {
    _addMessage(
      types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text:
            'Xin chào! Tôi là Huấn luyện viên AI của bạn. Bạn cần giúp đỡ gì hôm nay?',
      ),
    );
  }

  /// Hàm thêm một tin nhắn mới vào đầu danh sách (để hiển thị đúng thứ tự)
  void _addMessage(types.Message message) {
    // Chỉ cập nhật state nếu widget vẫn còn tồn tại trên cây widget
    if (mounted) {
      setState(() {
        _messages.insert(0, message);
      });
    }
  }

  /// Xử lý khi người dùng nhấn nút gửi tin nhắn
  void _handleSendPressed(types.PartialText message) async {
    // 1. Tạo và hiển thị tin nhắn của người dùng ngay lập tức
    final userMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text.trim(), // Xóa khoảng trắng thừa ở đầu/cuối
    );
    _addMessage(userMessage);

    // 2. Bật trạng thái "đang soạn tin"
    if (mounted) {
      setState(() => _isBotTyping = true);
    }

    try {
      // 3. Lấy thông tin xác thực người dùng
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addErrorMessage('Lỗi: Bạn cần đăng nhập để sử dụng tính năng này.');
        if (mounted) setState(() => _isBotTyping = false);
        return;
      }
      // Lấy ID Token để gửi lên backend xác thực
      final idToken = await user.getIdToken();

      // *** THAY THẾ BẰNG URL DỊCH VỤ RENDER CỦA BẠN ***
      const apiUrl =
          'https://gymnow-pt-ai.onrender.com/askPTAI'; // <<-- KIỂM TRA LẠI URL NÀY!
      // *************************************************

      // 4. Gửi yêu cầu POST đến backend Render
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken', // Gửi ID Token trong header
            },
            body: jsonEncode({
              'message': message.text.trim(),
            }), // Gửi tin nhắn trong body
          )
          .timeout(
            const Duration(seconds: 60),
          ); // Đặt giới hạn thời gian chờ là 60 giây

      // 5. Xử lý phản hồi từ backend
      if (response.statusCode == 200) {
        // Giải mã phản hồi JSON (sử dụng utf8 để hỗ trợ tiếng Việt)
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data != null && data['reply'] != null) {
          // Tạo và hiển thị tin nhắn trả lời của Bot
          final botResponse = types.TextMessage(
            author: _bot,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: const Uuid().v4(),
            text: data['reply'].toString(),
          );
          _addMessage(botResponse);
        } else {
          _addErrorMessage(
            'AI không thể tạo phản hồi (dữ liệu nhận về trống).',
          );
        }
      } else {
        // Xử lý lỗi HTTP (ví dụ: 403 Forbidden, 500 Internal Server Error)
        String errorMsg =
            'Lỗi kết nối (${response.statusCode}). Vui lòng thử lại sau.';
        try {
          // Cố gắng đọc thông báo lỗi cụ thể từ backend nếu có
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData != null && errorData['error'] != null) {
            errorMsg = 'Lỗi từ AI: ${errorData['error']}';
          }
        } catch (e) {
          /* Bỏ qua nếu body không phải JSON */
        }
        print('Lỗi API Render: ${response.statusCode} - ${response.body}');
        _addErrorMessage(errorMsg);
      }
    } catch (error) {
      // Xử lý các lỗi khác (mạng, timeout, Flutter...)
      print('Lỗi khi gọi API hoặc xử lý phản hồi: $error');
      if (error is TimeoutException) {
        _addErrorMessage(
          'Yêu cầu tới AI mất quá nhiều thời gian. Vui lòng thử lại.',
        );
      } else {
        _addErrorMessage(
          'Đã xảy ra lỗi mạng hoặc không thể kết nối đến máy chủ.',
        );
      }
    } finally {
      // 6. Tắt trạng thái "đang soạn tin" sau khi hoàn tất (dù thành công hay lỗi)
      if (mounted) {
        setState(() => _isBotTyping = false);
      }
    }
  }

  /// Hàm tiện ích để hiển thị tin nhắn báo lỗi từ Bot
  void _addErrorMessage(String text) {
    final errorMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      status: types
          .Status
          .error, // Đánh dấu là tin nhắn lỗi (có thể hiển thị khác biệt)
      text: text,
    );
    _addMessage(errorMessage);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Huấn luyện viên AI')),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: _user,
        typingIndicatorOptions: TypingIndicatorOptions(
          typingUsers: _isBotTyping ? [_bot] : [],
        ),
        // **SỬA LỖI Ở ĐÂY: XÓA KHỐI typingIndicatorTheme**
        theme: DefaultChatTheme(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          inputBackgroundColor: const Color(0xFF1B263B),
          inputTextColor: Colors.white,
          primaryColor: Theme.of(context).colorScheme.primary, // Cam
          secondaryColor: const Color(0xFF2A3B4F), // Nền tin nhắn bot
          receivedMessageBodyTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          sentMessageBodyTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          // typingIndicatorTheme: TypingIndicatorThemeData( // <<< XÓA HOẶC COMMENT KHỐI NÀY
          //    animatedCirclesColor: AlwaysStoppedAnimation(Colors.grey[400]!),
          //    animatedCircleSize: 5,
          //    bubbleColor: const Color(0xFF2A3B4F),
          //    countAvatarColor: Theme.of(context).colorScheme.primary,
          //    countTextColor: Colors.white,
          // )
        ),
        emptyState: const Center(child: Text("Bắt đầu trò chuyện với PT AI!")),
      ),
    );
  }
}
