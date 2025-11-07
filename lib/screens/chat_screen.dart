import 'dart:async';
import 'dart:convert';
import 'dart:io'; // <-- IMPORT MỚI cho File
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- IMPORT MỚI cho Firestore
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

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

  // Biến cho Speech-to-Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  // BIẾN CHO GỬI ẢNH
  final ImagePicker _picker = ImagePicker();
  String? _imageBase64; // Lưu ảnh đã mã hóa
  String? _imageMimeType; // Lưu loại ảnh (ví dụ: 'image/jpeg')
  String? _localImageUri; // Lưu đường dẫn ảnh local để hiển thị preview

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadMessages(); // Load lịch sử chat từ Firestore
    _addInitialMessageIfEmpty(); // Thêm message chào nếu chưa có
    _initSpeech();
  }

  @override
  void dispose() {
    _speechToText.stop();
    _textController.dispose();
    super.dispose();
  }

  /// Hàm chuyển đổi tất cả Timestamp trong Map thành int (millisecondsSinceEpoch)
  Map<String, dynamic> _convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.millisecondsSinceEpoch);
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertTimestamps(value));
      } else if (value is List) {
        return MapEntry(
          key,
          value.map((item) {
            if (item is Map<String, dynamic>) {
              return _convertTimestamps(item);
            }
            return item;
          }).toList(),
        );
      } else {
        return MapEntry(key, value);
      }
    });
  }

  /// Load messages từ Firestore
  Future<void> _loadMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('chats')
          .doc(user.uid)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get();

      final loadedMessages = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            final convertedData = _convertTimestamps(
              Map<String, dynamic>.from(data),
            );

            // Xử lý status nếu cần (loại bỏ 'Status.' nếu có)
            if (convertedData['status'] != null &&
                convertedData['status'].toString().startsWith('Status.')) {
              convertedData['status'] = convertedData['status']
                  .toString()
                  .split('.')
                  .last;
            }

            if (convertedData['type'] == 'text') {
              return types.TextMessage.fromJson(convertedData);
            } else if (convertedData['type'] == 'image') {
              return types.ImageMessage.fromJson(convertedData);
            }
            return null;
          })
          .whereType<types.Message>()
          .toList();

      setStateIfMounted(() {
        _messages.addAll(loadedMessages);
      });
    } catch (e) {
      print('Lỗi load messages: $e');
      _addErrorMessage('Không thể load lịch sử chat.');
    }
  }

  /// Lưu message vào Firestore
  Future<void> _saveMessage(types.Message message) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final json = message.toJson();
      json['type'] = message is types.TextMessage
          ? 'text'
          : 'image'; // Thêm type để deserialize
      // Đảm bảo createdAt là int
      if (json['createdAt'] is int) {
        // OK
      } else {
        json['createdAt'] = DateTime.now().millisecondsSinceEpoch;
      }

      // Lưu status dưới dạng string ngắn (ví dụ: 'sent' thay vì 'Status.sent')
      if (json['status'] != null) {
        json['status'] = json['status'].toString().split('.').last;
      }

      await _firestore
          .collection('chats')
          .doc(user.uid)
          .collection('messages')
          .doc(message.id)
          .set(json);
    } catch (e) {
      print('Lỗi save message: $e');
    }
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

  /// Bắt đầu nghe
  void _startListening() async {
    if (!_speechEnabled) {
      print("Nhận dạng giọng nói chưa được kích hoạt.");
      return;
    }
    _stopListening();
    if (!mounted) return;
    setState(() => _isListening = true);

    await _speechToText.listen(
      onResult: _onSpeechResult,
      localeId: 'vi_VN',
      listenMode: ListenMode.confirmation,
      partialResults: true,
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
      _textController.text = result.recognizedWords;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: _textController.text.length),
      );
    });
  }

  /// Thêm tin nhắn chào mừng nếu danh sách rỗng
  void _addInitialMessageIfEmpty() {
    if (_messages.isEmpty) {
      final initialMessage = types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text:
            'Xin chào! Tôi là Huấn luyện viên AI của bạn. Bạn cần giúp đỡ gì hôm nay?',
      );
      _addMessage(initialMessage);
      _saveMessage(initialMessage); // Lưu initial message
    }
  }

  /// Hàm thêm một tin nhắn mới vào đầu danh sách
  void _addMessage(types.Message message) {
    setStateIfMounted(() {
      _messages.insert(0, message);
    });
  }

  /// Thêm tin nhắn lỗi vào UI
  void _addErrorMessage(String text) {
    final errorMessage = types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      status: types.Status.error,
      text: text,
    );
    _addMessage(errorMessage);
    _saveMessage(errorMessage);
  }

  /// Xử lý khi người dùng nhấn nút gửi tin nhắn
  void _handleSendPressed(types.PartialText message) async {
    final String textToSend = message.text.trim();
    final String? imageToSend = _imageBase64;
    final String? mimeTypeToSend = _imageMimeType;
    final String? localImageUri = _localImageUri;

    if (textToSend.isEmpty && imageToSend == null) {
      return;
    }

    types.Message userMessage;
    if (imageToSend != null && localImageUri != null) {
      userMessage = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        name: 'image.jpg',
        size: imageToSend.length,
        uri: localImageUri,
      );
    } else {
      userMessage = types.TextMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: textToSend,
      );
    }

    _addMessage(userMessage);
    _saveMessage(userMessage); // Lưu user message

    setStateIfMounted(() {
      _isBotTyping = true;
      _imageBase64 = null;
      _imageMimeType = null;
      _localImageUri = null;
    });
    _textController.clear();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addErrorMessage('Lỗi: Bạn cần đăng nhập để hỏi AI.');
        setStateIfMounted(() => _isBotTyping = false);
        return;
      }
      final idToken = await user.getIdToken();

      const apiUrl = 'https://gymnow-pt-ai.onrender.com/askPTAI';

      final requestBody = jsonEncode({
        'message': textToSend,
        'imageBase64': imageToSend,
        'mimeType': mimeTypeToSend,
      });

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 90));

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
          _saveMessage(botResponse); // Lưu bot response
        } else {
          _addErrorMessage('AI không thể tạo phản hồi (dữ liệu trống).');
        }
      } else {
        String errorMsg =
            'Lỗi kết nối (${response.statusCode}). Vui lòng thử lại.';
        try {
          final errorData = jsonDecode(utf8.decode(response.bodyBytes));
          if (errorData['error'] != null) {
            errorMsg = 'Lỗi từ AI: ${errorData['error']}';
          }
        } catch (e) {}
        print('Lỗi API Render: ${response.statusCode} - ${response.body}');
        _addErrorMessage(errorMsg);
      }
    } catch (error) {
      print('Lỗi gọi API: $error');
      if (error is TimeoutException) {
        _addErrorMessage(
          'Yêu cầu tới AI mất quá nhiều thời gian. Vui lòng thử lại.',
        );
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
      backgroundColor: const Color(0xFF1B263B),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_camera, color: Colors.white),
                title: const Text(
                  'Chụp ảnh mới',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.white),
                title: const Text(
                  'Chọn từ thư viện',
                  style: TextStyle(color: Colors.white),
                ),
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

  /// Lấy ảnh và chuyển thành Base64 (KHÔNG gửi ngay)
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final imageBytes = await pickedFile.readAsBytes();
        final base64Image = base64Encode(imageBytes);
        final mimeType = lookupMimeType(pickedFile.path) ?? 'image/jpeg';

        // Chỉ lưu vào state, không gửi ngay
        setStateIfMounted(() {
          _imageBase64 = base64Image;
          _imageMimeType = mimeType;
          _localImageUri = pickedFile.path;
        });
      }
    } catch (e) {
      print("Lỗi chọn ảnh: $e");
      _addErrorMessage("Không thể chọn ảnh. Vui lòng thử lại.");
    }
  }

  /// Xóa ảnh preview
  void _clearImage() {
    setStateIfMounted(() {
      _imageBase64 = null;
      _imageMimeType = null;
      _localImageUri = null;
    });
  }

  // Hàm tiện ích để gọi setState an toàn
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview ảnh nếu có
              if (_localImageUri != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3B4F),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: Colors.orange.shade400.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.0),
                          image: DecorationImage(
                            image: FileImage(File(_localImageUri!)),
                            fit: BoxFit.cover,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ảnh đã chọn',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhấn gửi để gửi ảnh',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 18,
                          ),
                        ),
                        onPressed: _clearImage,
                        tooltip: 'Xóa ảnh',
                      ),
                    ],
                  ),
                ),
              // Input row
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A3B4F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: Colors.orange.shade400,
                      ),
                      onPressed: _handleAttachmentPressed,
                      tooltip: 'Gửi ảnh',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A3B4F),
                        borderRadius: BorderRadius.circular(30.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _textController,
                        autofocus: false,
                        minLines: 1,
                        maxLines: 4,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Nhập tin nhắn...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          filled: false,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20.0,
                            vertical: 14.0,
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty || _imageBase64 != null) {
                            _handleSendPressed(types.PartialText(text: text));
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _isListening
                          ? Colors.red.withOpacity(0.2)
                          : const Color(0xFF2A3B4F),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic_off : Icons.mic,
                        color: _isListening
                            ? Colors.redAccent
                            : Colors.orange.shade400,
                      ),
                      onPressed: _speechEnabled
                          ? (_isListening ? _stopListening : _startListening)
                          : null,
                      tooltip: _isListening ? 'Dừng ghi âm' : 'Bắt đầu ghi âm',
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (context, value, child) {
                      final hasContent =
                          value.text.trim().isNotEmpty || _imageBase64 != null;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: hasContent
                              ? LinearGradient(
                                  colors: [
                                    Colors.orange.shade400,
                                    Colors.orange.shade600,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: hasContent ? null : const Color(0xFF2A3B4F),
                          shape: BoxShape.circle,
                          boxShadow: hasContent
                              ? [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: hasContent ? Colors.white : Colors.grey,
                          ),
                          onPressed: hasContent
                              ? () => _handleSendPressed(
                                  types.PartialText(text: _textController.text),
                                )
                              : null,
                          tooltip: 'Gửi',
                        ),
                      );
                    },
                  ),
                ],
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
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Huấn luyện viên AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Luôn sẵn sàng hỗ trợ',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: Chat(
          messages: _messages,
          onSendPressed: _handleSendPressed,
          user: _user,
          typingIndicatorOptions: TypingIndicatorOptions(
            typingUsers: _isBotTyping ? [_bot] : [],
          ),
          theme: DefaultChatTheme(
            backgroundColor: Colors.transparent,
            inputBackgroundColor: const Color(0xFF1B263B),
            inputTextColor: Colors.white,
            primaryColor: Colors.orange.shade400,
            secondaryColor: const Color(0xFF2A3B4F),
            receivedMessageBodyTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            sentMessageBodyTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            receivedMessageDocumentIconColor: Colors.orange.shade400,
            sentMessageDocumentIconColor: Colors.orange.shade400,
            receivedMessageCaptionTextStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            sentMessageCaptionTextStyle: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          customBottomWidget: _buildInputArea(),
          emptyState: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade300, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Bắt đầu trò chuyện với PT AI!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tôi có thể giúp bạn về dinh dưỡng, tập luyện và sức khỏe',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
