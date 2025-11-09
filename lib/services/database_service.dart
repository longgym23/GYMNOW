import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gym_now/models/workout_model.dart';

class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  final CollectionReference userCollection = FirebaseFirestore.instance
      .collection('users');

  // **SỬA ĐỔI 1: Thêm 'age' và 'role' vào hàm cập nhật dữ liệu**
  Future<void> updateUserData(
    String name,
    String email,
    double height,
    double weight,
    int age,
    String role,
  ) async {
    return await userCollection.doc(uid).set({
      'name': name,
      'email': email,
      'height': height,
      'weight': weight,
      'age': age,
      'role': role,
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

  // **THÊM MỚI: Hàm lấy workouts của một user cụ thể (cho Admin)**
  Stream<QuerySnapshot> getWorkoutSessionsStreamForUser(String userId) {
    final workoutCollection = FirebaseFirestore.instance
        .collection('workouts')
        .doc(userId)
        .collection('sessions');
    return workoutCollection.orderBy('startTime', descending: true).snapshots();
  }

  // **THÊM MỚI: Hàm lấy meal plans của một user cụ thể (cho Admin)**
  Stream<QuerySnapshot> getMealPlansStreamForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('userMealPlans')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // **THÊM MỚI: Hàm lấy food logs của một user cụ thể (cho Admin)**
  Stream<QuerySnapshot> getFoodLogsStreamForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('foodLogs')
        .orderBy('scheduledAt', descending: true)
        .snapshots();
  }

  // **THÊM MỚI: Hàm xóa workout session của một user (cho Admin)**
  Future<void> deleteWorkoutSessionForUser(
    String userId,
    String sessionId,
  ) async {
    try {
      final workoutCollection = FirebaseFirestore.instance
          .collection('workouts')
          .doc(userId)
          .collection('sessions');
      await workoutCollection.doc(sessionId).delete();
    } catch (e) {
      print('Lỗi khi xóa buổi tập: $e');
      rethrow;
    }
  }

  // **THÊM MỚI: Hàm xóa meal plan của một user (cho Admin)**
  Future<void> deleteMealPlanForUser(String userId, String mealPlanId) async {
    try {
      // Xóa meal plan document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('userMealPlans')
          .doc(mealPlanId)
          .delete();

      // Xóa tất cả các days subcollection
      final daysSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('userMealPlans')
          .doc(mealPlanId)
          .collection('days')
          .get();

      for (final dayDoc in daysSnapshot.docs) {
        await dayDoc.reference.delete();
      }
    } catch (e) {
      print('Lỗi khi xóa thực đơn: $e');
      rethrow;
    }
  }

  // **THÊM MỚI: Hàm xóa user (cho Admin) - Xóa tất cả dữ liệu liên quan**
  Future<void> deleteUserForAdmin(String userId) async {
    try {
      // Xóa user document
      await userCollection.doc(userId).delete();

      // Xóa workouts
      final workoutsSnapshot = await FirebaseFirestore.instance
          .collection('workouts')
          .doc(userId)
          .collection('sessions')
          .get();
      for (final workoutDoc in workoutsSnapshot.docs) {
        await workoutDoc.reference.delete();
      }

      // Xóa meal plans
      final mealPlansSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('userMealPlans')
          .get();
      for (final mealPlanDoc in mealPlansSnapshot.docs) {
        // Xóa days subcollection
        final daysSnapshot = await mealPlanDoc.reference
            .collection('days')
            .get();
        for (final dayDoc in daysSnapshot.docs) {
          await dayDoc.reference.delete();
        }
        // Xóa meal plan
        await mealPlanDoc.reference.delete();
      }

      // Xóa food logs
      final foodLogsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('foodLogs')
          .get();
      for (final foodLogDoc in foodLogsSnapshot.docs) {
        await foodLogDoc.reference.delete();
      }

      // Xóa nutrition goals
      final goalsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('nutritionGoals')
          .get();
      for (final goalDoc in goalsSnapshot.docs) {
        await goalDoc.reference.delete();
      }
    } catch (e) {
      print('Lỗi khi xóa user: $e');
      rethrow;
    }
  }
}
