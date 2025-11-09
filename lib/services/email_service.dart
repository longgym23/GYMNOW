import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  // URL của backend server (có thể thay đổi tùy theo cấu hình)
  // Nếu sử dụng Firebase Functions, URL sẽ là:
  // 'https://us-central1-gymnow-e1ebd.cloudfunctions.net/sendPinEmail'
  static const String _backendUrl = 'https://gymnow-pt-ai.onrender.com';

  // Gửi mã PIN qua email
  Future<Map<String, dynamic>> sendPinEmail(String email, String pin) async {
    try {
      // Gọi API backend để gửi email
      final response = await http
          .post(
            Uri.parse('$_backendUrl/sendPinEmail'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'pin': pin}),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Request timeout');
            },
          );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Email đã được gửi thành công',
        };
      } else {
        return {
          'success': false,
          'message': 'Không thể gửi email. Vui lòng thử lại sau.',
        };
      }
    } catch (e) {
      print('❌ Lỗi khi gửi email: $e');
      // Nếu backend không khả dụng, vẫn trả về success để test
      // Trong production, nên xử lý lỗi tốt hơn
      return {
        'success': false,
        'message': 'Không thể kết nối đến server email. Vui lòng thử lại sau.',
      };
    }
  }
}
