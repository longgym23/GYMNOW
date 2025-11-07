import 'package:cloud_firestore/cloud_firestore.dart';

enum MealPlanCategory {
  loseWeight, // Giảm cân
  maintainWeight, // Giữ dáng
  gainWeight, // Tăng cân
  gainMuscle, // Tăng cơ
}

class MealPlanTemplate {
  final String id;
  final String name;
  final String description;
  final MealPlanCategory category;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final List<MealEntry> meals; // List of meals for the template
  final String imageUrl;
  final Timestamp createdAt;

  MealPlanTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.meals,
    this.imageUrl = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'category': category.toString().split('.').last,
    'targetCalories': targetCalories,
    'targetProtein': targetProtein,
    'targetCarbs': targetCarbs,
    'targetFat': targetFat,
    'meals': meals.map((m) => m.toMap()).toList(),
    'imageUrl': imageUrl,
    'createdAt': createdAt,
  };

  factory MealPlanTemplate.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final categoryStr = data['category']?.toString() ?? '';

    // Handle category mapping
    MealPlanCategory category;
    try {
      category = MealPlanCategory.values.firstWhere(
        (e) => e.toString().split('.').last == categoryStr,
      );
    } catch (e) {
      // Fallback: try to match by name
      switch (categoryStr.toLowerCase()) {
        case 'loseweight':
          category = MealPlanCategory.loseWeight;
          break;
        case 'maintainweight':
          category = MealPlanCategory.maintainWeight;
          break;
        case 'gainweight':
          category = MealPlanCategory.gainWeight;
          break;
        case 'gainmuscle':
          category = MealPlanCategory.gainMuscle;
          break;
        default:
          category = MealPlanCategory.loseWeight;
      }
    }

    return MealPlanTemplate(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: category,
      targetCalories: (data['targetCalories'] ?? 0).toDouble(),
      targetProtein: (data['targetProtein'] ?? 0).toDouble(),
      targetCarbs: (data['targetCarbs'] ?? 0).toDouble(),
      targetFat: (data['targetFat'] ?? 0).toDouble(),
      meals:
          (data['meals'] as List<dynamic>?)
              ?.map((m) => MealEntry.fromMap(m as Map<String, dynamic>))
              .toList() ??
          [],
      imageUrl: data['imageUrl'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  factory MealPlanTemplate.fromCsvRow(Map<String, String> row) {
    // CSV format: name,description,category,targetCalories,targetProtein,targetCarbs,targetFat,meals
    // meals format: "meal1:food1,food2;meal2:food3,food4"
    final mealsStr = row['meals'] ?? '';
    final meals = <MealEntry>[];

    if (mealsStr.isNotEmpty) {
      final mealParts = mealsStr.split(';');
      for (final part in mealParts) {
        if (part.contains(':')) {
          final split = part.split(':');
          final mealName = split[0].trim();
          final foodsStr = split.length > 1 ? split[1] : '';
          final foods = foodsStr
              .split(',')
              .map((f) => f.trim())
              .where((f) => f.isNotEmpty)
              .toList();
          meals.add(MealEntry(name: mealName, foods: foods));
        }
      }
    }

    return MealPlanTemplate(
      id: '',
      name: row['name'] ?? '',
      description: row['description'] ?? '',
      category: MealPlanCategory.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() ==
            (row['category'] ?? '').toLowerCase(),
        orElse: () => MealPlanCategory.loseWeight,
      ),
      targetCalories: double.tryParse(row['targetCalories'] ?? '0') ?? 0,
      targetProtein: double.tryParse(row['targetProtein'] ?? '0') ?? 0,
      targetCarbs: double.tryParse(row['targetCarbs'] ?? '0') ?? 0,
      targetFat: double.tryParse(row['targetFat'] ?? '0') ?? 0,
      meals: meals,
      imageUrl: row['imageUrl'] ?? '',
      createdAt: Timestamp.now(),
    );
  }
}

class MealEntry {
  final String name; // e.g., "Buổi sáng", "Buổi trưa"
  final List<String> foods; // List of food names
  final List<FoodItemNutrition>?
  foodNutrition; // Nutrition details for each food

  MealEntry({required this.name, required this.foods, this.foodNutrition});

  Map<String, dynamic> toMap() => {
    'name': name,
    'foods': foods,
    'foodNutrition': foodNutrition?.map((f) => f.toMap()).toList(),
  };

  factory MealEntry.fromMap(Map<String, dynamic> map) {
    return MealEntry(
      name: map['name'] ?? '',
      foods:
          (map['foods'] as List<dynamic>?)?.map((f) => f.toString()).toList() ??
          [],
      foodNutrition: (map['foodNutrition'] as List<dynamic>?)
          ?.map((f) => FoodItemNutrition.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FoodItemNutrition {
  final String foodName;
  final String unit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  FoodItemNutrition({
    required this.foodName,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  Map<String, dynamic> toMap() => {
    'foodName': foodName,
    'unit': unit,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory FoodItemNutrition.fromMap(Map<String, dynamic> map) {
    return FoodItemNutrition(
      foodName: map['foodName'] ?? '',
      unit: map['unit'] ?? '',
      calories: (map['calories'] ?? 0).toDouble(),
      protein: (map['protein'] ?? 0).toDouble(),
      carbs: (map['carbs'] ?? 0).toDouble(),
      fat: (map['fat'] ?? 0).toDouble(),
    );
  }
}
