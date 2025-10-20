import 'package:flutter/material.dart';

class WorkoutType {
  final String name;
  final IconData icon;
  final double metValue; // Chỉ số MET để tính calo sau này

  const WorkoutType({
    required this.name,
    required this.icon,
    required this.metValue,
  });
}