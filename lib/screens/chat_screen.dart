import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart'; // **<-- IMPORT MỚI**
import 'package:mime/mime.dart'; // **<-- IMPORT MỚI**

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<types.Message> _messages = [];
  final _user = types.User(id: FirebaseAuth.instance.currentUser?.uid ?? 'local_user');
  final _bot = const types.User(id: 'pt_ai_bot', firstName: 'PT AI');
  bool _isBotTyping = false;

  // Biến cho Speech-to-Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  // **BIẾN MỚI CHO GỬI ẢNH**
  final ImagePicker _picker = ImagePicker();
  String? _imageBase64; // Lưu ảnh đã mã hóa
  String? _imageMimeType; // Lưu loại ảnh (ví dụ: 'image/jpeg')
  String? _localImageUri; // Lưu đường dẫn ảnh local để hiển thị preview

  @override
  void initState() {
    super.initState();
    _addInitialMessage();
    _initSpeech();
  }

  @override
  void dispose() {
    _speechToText.stop();
    _textController.dispose();
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
    setStateIfMounted(() {
      _messages.insert(0, message);
    });
  }

  /// Thêm tin nhắn lỗi vào UI
  void _addErrorMessage(String text) {
     _addMessage(types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        status: types.Status.error,
        text: text,
      ));
  }

  /// Xử lý khi người dùng nhấn nút gửi tin nhắn
  void _handleSendPressed(types.PartialText message) async {
    // 1. Lấy dữ liệu text và ảnh từ state
    final String textToSend = message.text.trim();
    final String? imageToSend = _imageBase64;
    final String? mimeTypeToSend = _imageMimeType;
    final String? localImageUri = _localImageUri; // Lấy URI local

    // 2. Kiểm tra nếu không có gì để gửi
    if (textToSend.isEmpty && imageToSend == null) {
      return; // Không gửi tin nhắn rỗng
    }

    // 3. Tạo tin nhắn hiển thị trên UI
    types.Message userMessage;
    if (imageToSend != null && localImageUri != null) {
      // Tạo tin nhắn ảnh
      userMessage = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        name: 'image.jpg',
        size: imageToSend.length,
        uri: localImageUri, // Dùng đường dẫn file local để hiển thị ngay lập tức
        // text: textToSend, // Gửi kèm nội dung text (nếu có)
      );
    } else {
      // Tạo tin nhắn text
      userMessage = types.TextMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: textToSend,
      );
    }

    _addMessage(userMessage);

    // 4. Reset state và bật loading
    setStateIfMounted(() {
      _isBotTyping = true;
      _imageBase64 = null;
      _imageMimeType = null;
      _localImageUri = null;
    });
    _textController.clear();

    // --- 5. Bắt đầu gọi API ---
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addErrorMessage('Lỗi: Bạn cần đăng nhập để hỏi AI.');
        setStateIfMounted(() => _isBotTyping = false);
        return;
      }
      final idToken = await user.getIdToken();
      
      // *** THAY THẾ BẰNG URL RENDER CỦA BẠN ***
      const apiUrl = 'https://gymnow-pt-ai.onrender.com/askPTAI'; // <<-- KIỂM TRA LẠI URL NÀY!
      // ****************************************

      final requestBody = jsonEncode({
        'message': textToSend,
        'imageBase64': imageToSend, // Sẽ là null nếu không có ảnh
        'mimeType': mimeTypeToSend, // Sẽ là null nếu không có ảnh
      });

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 90)); // Tăng timeout cho upload ảnh

      // 6. Xử lý phản hồi (giữ nguyên logic cũ)
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data != null && data['reply'] != null) {
          final botResponse = types.TextMessage(
            author: _bot,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            id: const Uuid().v4(),
            text: data['reply'].toString(),
          );
          _addMessage(botResponse);
        } else {
           _addErrorMessage('AI không thể tạo phản hồi (dữ liệu trống).');
        }
      } else {
         String errorMsg = 'Lỗi kết nối (${response.statusCode}). Vui lòng thử lại.';
         try {
            final errorData = jsonDecode(utf8.decode(response.bodyBytes));
            if(errorData['error'] != null){ errorMsg = 'Lỗi từ AI: ${errorData['error']}'; }
         } catch (e) { /* Bỏ qua */ }
         print('Lỗi API Render: ${response.statusCode} - ${response.body}');
         _addErrorMessage(errorMsg);
      }

    } catch (error) { // 7. Xử lý lỗi (giữ nguyên logic cũ)
      print('Lỗi gọi API: $error');
      if (error is TimeoutException) {
        _addErrorMessage('Yêu cầu tới AI mất quá nhiều thời gian. Vui lòng thử lại.');
      } else {
        _addErrorMessage('Đã xảy ra lỗi mạng hoặc kết nối.');
      }
    } finally {
      setStateIfMounted(() => _isBotTyping = false);
    }
  }

  /// Xử lý khi nhấn nút đính kèm (📎)
  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B263B), // Đặt màu nền cho bottom sheet
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text('Chụp ảnh mới', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text('Chọn từ thư viện', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Lấy ảnh và chuyển thành Base64
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Giảm kích thước ảnh để gửi nhanh hơn
        imageQuality: 70, // Giảm chất lượng ảnh
      );

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        final mimeType = lookupMimeType(pickedFile.path) ?? 'image/jpeg';

        // Lưu ảnh vào state để chuẩn bị gửi
        setStateIfMounted(() {
          _imageBase64 = base64Image;
          _imageMimeType = mimeType;
          _localImageUri = pickedFile.path; // Lưu đường dẫn file local để hiển thị
        });

        // Tự động gửi ảnh (kèm theo bất kỳ text nào đang có trong ô)
        _handleSendPressed(types.PartialText(text: _textController.text));
      }
    } catch (e) {
      print("Lỗi chọn ảnh: $e");
      _addErrorMessage("Không thể chọn ảnh. Vui lòng thử lại.");
    }
  }
  
  // Hàm tiện ích để gọi setState an toàn
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

 Widget _buildInputArea() {
  return Container(
    color: const Color(0xFF1B263B), // Màu nền của thanh input
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Row(
          children: [
            // Nút attach (leading)
            IconButton(
              icon: Icon(Icons.attach_file, color: Theme.of(context).colorScheme.primary),
              onPressed: _handleAttachmentPressed,
              tooltip: 'Gửi ảnh',
            ),
            // Ô nhập text (Expanded để chiếm hết không gian)
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: false,
                minLines: 1,
                maxLines: 4, // Cho phép multiline
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFF2A3B4F), // Nền ô text
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _handleSendPressed(types.PartialText(text: text));
                  }
                },
              ),
            ),
            // Nút mic (trailing 1)
            IconButton(
              icon: Icon(
                _isListening ? Icons.mic_off : Icons.mic,
                color: _isListening ? Colors.redAccent : Theme.of(context).colorScheme.primary,
              ),
              onPressed: _speechEnabled ? (_isListening ? _stopListening : _startListening) : null,
              tooltip: _isListening ? 'Dừng ghi âm' : 'Bắt đầu ghi âm',
            ),
            // Nút send (trailing 2, chỉ hiện khi có text hoặc ảnh)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, child) {
                final hasContent = value.text.trim().isNotEmpty || _imageBase64 != null;
                return IconButton(
                  icon: Icon(Icons.send, color: hasContent ? Theme.of(context).colorScheme.primary : Colors.grey),
                  onPressed: hasContent
                      ? () => _handleSendPressed(types.PartialText(text: _textController.text))
                      : null,
                  tooltip: 'Gửi',
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Huấn luyện viên AI'),
      ),
      body: Chat(
        messages: _messages,
        onSendPressed: _handleSendPressed,
        user: _user,
        typingIndicatorOptions: TypingIndicatorOptions(
          typingUsers: _isBotTyping ? [_bot] : [],
        ),
        theme: DefaultChatTheme(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          inputBackgroundColor: const Color(0xFF1B263B),
          inputTextColor: Colors.white,
          primaryColor: Theme.of(context).colorScheme.primary, // Cam
          secondaryColor: const Color(0xFF2A3B4F), // Nền tin nhắn bot
          receivedMessageBodyTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
          sentMessageBodyTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        customBottomWidget: _buildInputArea(),
        emptyState: const Center(child: Text("Bắt đầu trò chuyện với PT AI!")),
      ),
    );
  }
}
