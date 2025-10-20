import 'package:firebase_auth/firebase_auth.dart';
import 'package:gym_now/services/database_service.dart'; // Import DatabaseService

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Hàm đăng ký giữ nguyên, nhưng bạn cần cập nhật nơi gọi nó
  // để truyền thêm 'role' là 'member'
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
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
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
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
          String nameFromEmail = user.email?.split('@').first ?? 'Người dùng mới';
          // Tạo hồ sơ mặc định với vai trò 'member'
          await DatabaseService(uid: user.uid).updateUserData(nameFromEmail, user.email!, 0, 0, 'member');
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
}