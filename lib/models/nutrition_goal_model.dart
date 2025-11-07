import 'package:cloud_firestore/cloud_firestore.dart';

enum GoalType {
  loseWeight, // Giảm cân giảm mỡ
  gainWeight, // Tăng cân
  gainMuscle, // Tăng cơ
  maintain, // Duy trì
}

class NutritionGoal {
  final String id;
  final String userId;
  final double height; // cm
  final double weight; // kg
  final int age;
  final String gender; // 'male' or 'female'
  final GoalType goalType;
  final double targetWeight; // kg
  final double targetCalories;
  final double targetProtein; // g
  final double targetCarbs; // g
  final double targetFat; // g
  final Timestamp createdAt;
  final bool isActive;

  NutritionGoal({
    required this.id,
    required this.userId,
    required this.height,
    required this.weight,
    required this.age,
    required this.gender,
    required this.goalType,
    required this.targetWeight,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'height': height,
    'weight': weight,
    'age': age,
    'gender': gender,
    'goalType': goalType.toString().split('.').last,
    'targetWeight': targetWeight,
    'targetCalories': targetCalories,
    'targetProtein': targetProtein,
    'targetCarbs': targetCarbs,
    'targetFat': targetFat,
    'createdAt': createdAt,
    'isActive': isActive,
  };

  factory NutritionGoal.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NutritionGoal(
      id: doc.id,
      userId: data['userId'] ?? '',
      height: (data['height'] ?? 0).toDouble(),
      weight: (data['weight'] ?? 0).toDouble(),
      age: (data['age'] ?? 25) as int,
      gender: data['gender'] ?? 'male',
      goalType: GoalType.values.firstWhere(
        (e) => e.toString().split('.').last == data['goalType'],
        orElse: () => GoalType.maintain,
      ),
      targetWeight: (data['targetWeight'] ?? 0).toDouble(),
      targetCalories: (data['targetCalories'] ?? 0).toDouble(),
      targetProtein: (data['targetProtein'] ?? 0).toDouble(),
      targetCarbs: (data['targetCarbs'] ?? 0).toDouble(),
      targetFat: (data['targetFat'] ?? 0).toDouble(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      isActive: (data['isActive'] ?? true) as bool,
    );
  }

  // Tính TDEE (Total Daily Energy Expenditure)
  static double calculateTDEE(
    double weight,
    double height,
    int age,
    String gender,
    double activityMultiplier,
  ) {
    // BMR (Basal Metabolic Rate) - Mifflin-St Jeor Equation
    double bmr;
    if (gender == 'male') {
      bmr = 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      bmr = 10 * weight + 6.25 * height - 5 * age - 161;
    }
    return bmr * activityMultiplier;
  }

  // Tính macro recommendations dựa trên goal
  static Map<String, double> calculateMacros(
    double tdee,
    GoalType goalType,
    double weight,
  ) {
    double targetCal;
    double protein, carbs, fat;

    switch (goalType) {
      case GoalType.loseWeight:
        targetCal = tdee * 0.85; // Deficit 15%
        protein = weight * 2.2; // 2.2g/kg
        fat = targetCal * 0.25 / 9; // 25% calories
        carbs = (targetCal - protein * 4 - fat * 9) / 4;
        break;
      case GoalType.gainWeight:
      case GoalType.gainMuscle:
        targetCal = tdee * 1.15; // Surplus 15%
        protein = weight * 2.2; // 2.2g/kg
        fat = targetCal * 0.25 / 9; // 25% calories
        carbs = (targetCal - protein * 4 - fat * 9) / 4;
        break;
      case GoalType.maintain:
        targetCal = tdee;
        protein = weight * 1.8; // 1.8g/kg
        fat = targetCal * 0.25 / 9; // 25% calories
        carbs = (targetCal - protein * 4 - fat * 9) / 4;
        break;
    }

    return {
      'calories': targetCal,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }
}
