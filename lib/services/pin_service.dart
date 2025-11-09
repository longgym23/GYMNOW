import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_now/services/email_service.dart';
import 'dart:math';

class PinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmailService _emailService = EmailService();

  // Tạo mã PIN 6 số ngẫu nhiên
  String _generatePin() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Gửi mã PIN và lưu vào Firestore
  Future<Map<String, dynamic>> sendPinToEmail(String email) async {
    try {
      // Kiểm tra email có tồn tại trong Firebase Auth không
      // (Có thể thêm validation ở đây nếu cần)

      // Tạo mã PIN
      final pin = _generatePin();
      final now = DateTime.now();
      final expiresAt = now.add(
        const Duration(minutes: 10),
      ); // Mã PIN hết hạn sau 10 phút

      // Lưu mã PIN vào Firestore
      await _firestore.collection('passwordResetPins').doc(email).set({
        'pin': pin,
        'email': email,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'used': false,
      });

      // Gửi email với mã PIN
      final emailResult = await _emailService.sendPinEmail(email, pin);

      // Log mã PIN để test (chỉ trong development)
      print('📧 Mã PIN cho $email: $pin');
      print('⏰ Mã PIN hết hạn lúc: ${expiresAt.toString()}');

      if (emailResult['success'] == true) {
        return {
          'success': true,
          'message':
              emailResult['message'] ?? 'Mã PIN đã được gửi đến email của bạn',
        };
      } else {
        // Nếu không gửi được email, vẫn lưu PIN vào Firestore
        // User có thể xem mã PIN trong console log (chỉ để test)
        return {
          'success': true,
          'message':
              'Mã PIN đã được tạo. ${emailResult['message'] ?? 'Vui lòng kiểm tra email của bạn'}',
        };
      }
    } catch (e) {
      print('❌ Lỗi khi gửi mã PIN: $e');
      return {
        'success': false,
        'message': 'Có lỗi xảy ra. Vui lòng thử lại sau.',
      };
    }
  }

  // Xác thực mã PIN
  Future<Map<String, dynamic>> verifyPin(String email, String pin) async {
    try {
      final doc = await _firestore
          .collection('passwordResetPins')
          .doc(email)
          .get();

      if (!doc.exists) {
        return {
          'success': false,
          'message': 'Mã PIN không hợp lệ hoặc đã hết hạn',
        };
      }

      final data = doc.data()!;
      final storedPin = data['pin'] as String;
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      final used = data['used'] as bool;

      // Kiểm tra mã PIN đã được sử dụng chưa
      if (used) {
        return {'success': false, 'message': 'Mã PIN đã được sử dụng'};
      }

      // Kiểm tra mã PIN đã hết hạn chưa
      if (DateTime.now().isAfter(expiresAt)) {
        return {
          'success': false,
          'message': 'Mã PIN đã hết hạn. Vui lòng yêu cầu mã mới',
        };
      }

      // Kiểm tra mã PIN có đúng không
      if (storedPin != pin) {
        return {'success': false, 'message': 'Mã PIN không đúng'};
      }

      // Đánh dấu mã PIN đã được sử dụng
      await _firestore.collection('passwordResetPins').doc(email).update({
        'used': true,
      });

      return {'success': true, 'message': 'Xác thực mã PIN thành công'};
    } catch (e) {
      print('❌ Lỗi khi xác thực mã PIN: $e');
      return {
        'success': false,
        'message': 'Có lỗi xảy ra. Vui lòng thử lại sau.',
      };
    }
  }

  // Xóa mã PIN cũ (nếu cần)
  Future<void> deletePin(String email) async {
    try {
      await _firestore.collection('passwordResetPins').doc(email).delete();
    } catch (e) {
      print('❌ Lỗi khi xóa mã PIN: $e');
    }
  }
}
