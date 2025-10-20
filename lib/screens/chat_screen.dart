import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Danh sách lưu trữ các tin nhắn
  final List<types.Message> _messages = [];
  // Định danh người dùng (tạm thời)
  final _user = const types.User(id: 'user_id'); // ID này sẽ được thay bằng ID người dùng thật sau
  // Định danh chatbot (tạm thời)
  final _bot = const types.User(id: 'bot_id', firstName: 'PT AI');

  @override
  void initState() {
    super.initState();
    // Thêm tin nhắn chào mừng ban đầu
    _addMessage(types.TextMessage(
      author: _bot,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: 'Xin chào! Tôi là Huấn luyện viên AI của bạn. Bạn cần giúp đỡ gì hôm nay?',
    ));
  }

  // Hàm thêm tin nhắn vào danh sách và cập nhật UI
  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message); // Thêm vào đầu danh sách để tin mới nhất ở dưới cùng
    });
  }

  // Hàm xử lý khi người dùng gửi tin nhắn
  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      text: message.text,
    );

    _addMessage(textMessage);

    // --- TẠM THỜI: Bot chỉ "nhại" lại ---
    // Sau này, đây sẽ là nơi gọi backend để lấy phản hồi từ AI
    Future.delayed(const Duration(milliseconds: 500), () {
      final botResponse = types.TextMessage(
        author: _bot,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: const Uuid().v4(),
        text: 'Bạn đã nói: "${message.text}" (Tôi sẽ sớm thông minh hơn!)',
      );
      _addMessage(botResponse);
    });
    // --- KẾT THÚC PHẦN TẠM THỜI ---
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
        theme: DefaultChatTheme( // Tùy chỉnh theme cho phù hợp với app
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          inputBackgroundColor: const Color(0xFF1B263B),
          inputTextColor: Colors.white,
          primaryColor: Theme.of(context).colorScheme.primary, // Màu cam
          secondaryColor: const Color(0xFF1B263B), // Màu nền tin nhắn của bot
          receivedMessageBodyTextStyle: const TextStyle(color: Colors.white),
          sentMessageBodyTextStyle: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}