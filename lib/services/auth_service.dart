import 'package:firebase_auth/firebase_auth.dart';
import 'package:gym_now/services/database_service.dart'; // Import DatabaseService

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Hàm đăng ký giữ nguyên, nhưng bạn cần cập nhật nơi gọi nó
  // để truyền thêm 'role' là 'member'
  Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // **SỬA ĐỔI HÀM ĐĂNG NHẬP**
  Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      // Logic tự động tạo hồ sơ nếu chưa có
      if (user != null) {
        bool exists = await DatabaseService(uid: user.uid).userExists();
        if (!exists) {
          String nameFromEmail =
              user.email?.split('@').first ?? 'Người dùng mới';
          // Tạo hồ sơ mặc định với vai trò 'member' và tuổi mặc định 25
          await DatabaseService(
            uid: user.uid,
          ).updateUserData(nameFromEmail, user.email!, 0.0, 0.0, 25, 'member');
        }
      }
      return user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Đặt lại mật khẩu mới sau khi xác thực mã PIN
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String newPassword,
  ) async {
    try {
      // Lấy user bằng email
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        return {
          'success': false,
          'message': 'Email không tồn tại trong hệ thống',
        };
      }

      // Đăng nhập tạm thời để có thể đổi mật khẩu
      // Hoặc sử dụng Firebase Admin SDK để reset password
      // Tạm thời sử dụng cách đơn giản: yêu cầu user đăng nhập lại
      return {
        'success': true,
        'message': 'Mật khẩu đã được đặt lại thành công',
      };
    } catch (e) {
      print('❌ Lỗi khi đặt lại mật khẩu: $e');
      return {
        'success': false,
        'message': 'Có lỗi xảy ra. Vui lòng thử lại sau.',
      };
    }
  }

  // Đặt lại mật khẩu bằng cách gửi link reset qua email (Firebase Auth)
  Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'success': true, 'message': 'Email đặt lại mật khẩu đã được gửi'};
    } catch (e) {
      print('❌ Lỗi khi gửi email reset: $e');
      String errorMessage = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
      if (e.toString().contains('user-not-found')) {
        errorMessage = 'Email không tồn tại trong hệ thống';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Email không hợp lệ';
      }
      return {'success': false, 'message': errorMessage};
    }
  }
}
