import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  // URL của backend server (có thể thay đổi tùy theo cấu hình)
  // Nếu sử dụng Firebase Functions, URL sẽ là:
  // 'https://us-central1-gymnow-e1ebd.cloudfunctions.net/sendPinEmail'
  static const String _backendUrl = 'https://gymnow-pt-ai.onrender.com';

  // Gửi mã PIN qua email với retry logic
  Future<Map<String, dynamic>> sendPinEmail(String email, String pin) async {
    int maxRetries = 2;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        print(
          '📤 Đang gửi email (lần thử ${retryCount + 1}/${maxRetries + 1})...',
        );

        // Gọi API backend để gửi email với timeout dài hơn (30 giây)
        final response = await http
            .post(
              Uri.parse('$_backendUrl/sendPinEmail'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'email': email, 'pin': pin}),
            )
            .timeout(
              const Duration(seconds: 30), // Tăng timeout lên 30 giây
              onTimeout: () {
                throw Exception('Request timeout sau 30 giây');
              },
            );

        print('📥 Response status: ${response.statusCode}');
        print('📥 Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message': data['message'] ?? 'Email đã được gửi thành công',
          };
        } else {
          // Nếu lỗi server, thử lại
          if (retryCount < maxRetries) {
            retryCount++;
            print('⚠️ Lỗi ${response.statusCode}, thử lại sau 2 giây...');
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return {
            'success': false,
            'message': 'Không thể gửi email. Vui lòng thử lại sau.',
          };
        }
      } catch (e) {
        print('❌ Lỗi khi gửi email (lần thử ${retryCount + 1}): $e');

        // Nếu là timeout hoặc connection error, thử lại
        if (retryCount < maxRetries &&
            (e.toString().contains('timeout') ||
                e.toString().contains('Connection') ||
                e.toString().contains('Failed host lookup'))) {
          retryCount++;
          print('🔄 Thử lại sau 3 giây...');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }

        // Nếu đã thử hết hoặc lỗi khác, trả về lỗi
        return {
          'success': false,
          'message':
              'Không thể kết nối đến server email. Server có thể đang tạm thời không khả dụng. Vui lòng thử lại sau.',
        };
      }
    }

    // Không bao giờ đến đây, nhưng để đảm bảo
    return {
      'success': false,
      'message': 'Không thể gửi email sau nhiều lần thử.',
    };
  }
}
