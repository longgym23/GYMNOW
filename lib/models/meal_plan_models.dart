import 'package:cloud_firestore/cloud_firestore.dart';

class MealEntry {
  final String foodId;
  final String name;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  bool done;

  MealEntry({
    required this.foodId,
    required this.name,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.done = false,
  });

  Map<String, dynamic> toMap() => {
    'foodId': foodId,
    'name': name,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'done': done,
  };

  factory MealEntry.fromMap(Map<String, dynamic> data) => MealEntry(
    foodId: data['foodId'] ?? '',
    name: data['name'] ?? '',
    unit: data['unit'] ?? '',
    calories: (data['calories'] ?? 0).toDouble(),
    protein: (data['protein'] ?? 0).toDouble(),
    carbs: (data['carbs'] ?? 0).toDouble(),
    fat: (data['fat'] ?? 0).toDouble(),
    done: (data['done'] ?? false) as bool,
  );
}

class MealPlanDay {
  final int dayIndex; // 1..n
  final double targetCalories;
  final List<MealEntry> entries;

  MealPlanDay({
    required this.dayIndex,
    required this.targetCalories,
    required this.entries,
  });

  double get consumedCalories =>
      entries.where((e) => e.done).fold(0.0, (a, b) => a + b.calories);

  Map<String, dynamic> toMap() => {
    'dayIndex': dayIndex,
    'targetCalories': targetCalories,
    'entries': entries.map((e) => e.toMap()).toList(),
  };

  factory MealPlanDay.fromMap(Map<String, dynamic> data) => MealPlanDay(
    dayIndex: (data['dayIndex'] ?? 1) as int,
    targetCalories: (data['targetCalories'] ?? 0).toDouble(),
    entries: (data['entries'] as List<dynamic>? ?? [])
        .map((e) => MealEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
  );
}

class MealPlan {
  final String id;
  final String userId;
  final String title;
  final int days;
  final int mealsPerDay;
  final double targetCaloriesPerDay;
  final Timestamp createdAt;

  MealPlan({
    required this.id,
    required this.userId,
    required this.title,
    required this.days,
    required this.mealsPerDay,
    required this.targetCaloriesPerDay,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'days': days,
    'mealsPerDay': mealsPerDay,
    'targetCaloriesPerDay': targetCaloriesPerDay,
    'createdAt': createdAt,
  };

  factory MealPlan.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlan(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      days: (data['days'] ?? 7) as int,
      mealsPerDay: (data['mealsPerDay'] ?? 4) as int,
      targetCaloriesPerDay: (data['targetCaloriesPerDay'] ?? 0).toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
