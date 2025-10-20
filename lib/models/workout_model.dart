// Trong file lib/models/workout_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class WorkoutSession {
  final String id;
  final String activityType; // 'Chạy bộ', 'Bơi lội'...
  final DateTime startTime;
  final int durationInSeconds; // Thời gian tập (giây)
  final double distanceInMeters; // Quãng đường (mét)
  final int caloriesBurned;
  final List<GeoPoint> routePoints; // Lưu lại toạ độ GPS

  WorkoutSession({
    required this.id,
    required this.activityType,
    required this.startTime,
    required this.durationInSeconds,
    required this.distanceInMeters,
    required this.caloriesBurned,
    required this.routePoints,
  });

  // Hàm để chuyển đổi object sang Map để lưu vào Firestore
  Map<String, dynamic> toMap() {
    return {
      'activityType': activityType,
      'startTime': Timestamp.fromDate(startTime),
      'durationInSeconds': durationInSeconds,
      'distanceInMeters': distanceInMeters,
      'caloriesBurned': caloriesBurned,
      'routePoints': routePoints,
    };
  }
}