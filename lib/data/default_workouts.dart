import 'package:flutter/material.dart';
import 'package:gym_now/models/workout_type_model.dart';

final List<WorkoutType> defaultWorkoutTypes = [
  const WorkoutType(name: 'Chạy bộ', icon: Icons.directions_run, metValue: 7.0),
  const WorkoutType(name: 'Đi bộ', icon: Icons.directions_walk, metValue: 3.5),
  const WorkoutType(name: 'Đạp xe', icon: Icons.directions_bike, metValue: 8.0),
  const WorkoutType(name: 'Leo núi', icon: Icons.hiking, metValue: 6.0),
  // Bạn có thể thêm các chế độ khác ở đây, ví dụ như Bơi lội.
  // Lưu ý: Bơi lội sẽ không dùng GPS để vẽ đường đi.
];