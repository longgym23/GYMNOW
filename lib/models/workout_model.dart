// Trong file lib/models/workout_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Model để lưu thông tin vận tốc cho mỗi cung đường
class RouteSegment {
  final int index; // Vị trí trong danh sách routePoints
  final double speedKmh; // Vận tốc (km/h) cho cung đường này
  final double distanceMeters; // Khoảng cách của cung đường (mét)
  final int durationSeconds; // Thời gian di chuyển cung đường này (giây)

  RouteSegment({
    required this.index,
    required this.speedKmh,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  Map<String, dynamic> toMap() {
    return {
      'index': index,
      'speedKmh': speedKmh,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
    };
  }

  factory RouteSegment.fromMap(Map<String, dynamic> map) {
    return RouteSegment(
      index: (map['index'] as num).toInt(),
      speedKmh: (map['speedKmh'] as num).toDouble(),
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      durationSeconds: (map['durationSeconds'] as num).toInt(),
    );
  }
}

class WorkoutSession {
  final String id;
  final String activityType; // 'Chạy bộ', 'Bơi lội'...
  final DateTime startTime;
  final int durationInSeconds; // Thời gian tập (giây)
  final double distanceInMeters; // Quãng đường (mét)
  final int caloriesBurned;
  final List<GeoPoint> routePoints; // Lưu lại toạ độ GPS
  final List<RouteSegment>? routeSegments; // Lưu vận tốc cho mỗi cung đường

  WorkoutSession({
    required this.id,
    required this.activityType,
    required this.startTime,
    required this.durationInSeconds,
    required this.distanceInMeters,
    required this.caloriesBurned,
    required this.routePoints,
    this.routeSegments,
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
      'routeSegments': routeSegments?.map((s) => s.toMap()).toList() ?? [],
    };
  }
}
