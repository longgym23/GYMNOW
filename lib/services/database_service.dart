import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_now/models/workout_model.dart';

class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  final CollectionReference userCollection = FirebaseFirestore.instance
      .collection('users');

  // **SỬA ĐỔI 1: Thêm 'role' vào hàm cập nhật dữ liệu**
  Future<void> updateUserData(
    String name,
    String email,
    double height,
    double weight,
    String role,
  ) async {
    return await userCollection.doc(uid).set({
      'name': name,
      'email': email,
      'height': height,
      'weight': weight,
      'role': role, // Thêm trường vai trò
    });
  }

  // **THÊM MỚI 1: Hàm kiểm tra sự tồn tại của người dùng**
  Future<bool> userExists() async {
    final doc = await userCollection.doc(uid).get();
    return doc.exists;
  }

  Future<DocumentSnapshot> getUserData() async {
    return await userCollection.doc(uid).get();
  }

  // **THÊM MỚI 2: Hàm lấy tất cả người dùng cho Admin**
  // Không cần uid vì Admin có quyền xem tất cả
  Stream<QuerySnapshot> getAllUsersStream() {
    return FirebaseFirestore.instance.collection('users').snapshots();
  }

  Future<void> addWorkoutSession(WorkoutSession session) async {
    try {
      final workoutCollection = FirebaseFirestore.instance
          .collection('workouts')
          .doc(uid)
          .collection('sessions');
      await workoutCollection.doc(session.id).set(session.toMap());
    } catch (e) {
      print('Lỗi khi lưu buổi tập: $e');
    }
  }

  Stream<QuerySnapshot> getWorkoutSessionsStream() {
    final workoutCollection = FirebaseFirestore.instance
        .collection('workouts')
        .doc(uid)
        .collection('sessions');
    return workoutCollection.orderBy('startTime', descending: true).snapshots();
  }

  // Hàm xóa buổi tập luyện
  Future<void> deleteWorkoutSession(String sessionId) async {
    try {
      final workoutCollection = FirebaseFirestore.instance
          .collection('workouts')
          .doc(uid)
          .collection('sessions');
      await workoutCollection.doc(sessionId).delete();
    } catch (e) {
      print('Lỗi khi xóa buổi tập: $e');
      rethrow;
    }
  }
}
