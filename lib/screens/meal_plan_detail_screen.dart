import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_now/models/food_model.dart';
import 'package:gym_now/models/meal_plan_template_model.dart';
import 'package:gym_now/screens/customize_meal_plan_screen.dart';

class MealPlanDetailScreen extends StatefulWidget {
  final MealPlanTemplate template;

  const MealPlanDetailScreen({Key? key, required this.template})
    : super(key: key);

  @override
  State<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends State<MealPlanDetailScreen> {
  int _selectedDay = 1;
  int _selectedDuration = 7;
  List<MealEntry>? _customizedMeals; // Lưu thực đơn đã tùy chỉnh

  Future<void> _openCustomizeScreen() async {
    final customizedMeals = await Navigator.push<List<MealEntry>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomizeMealPlanScreen(template: widget.template),
      ),
    );

    if (customizedMeals != null) {
      setState(() {
        _customizedMeals = customizedMeals;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã lưu thực đơn tùy chỉnh')),
      );
    }
  }

  Future<void> _startMealPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
      return;
    }

    // Sử dụng thực đơn đã tùy chỉnh nếu có, nếu không dùng template gốc
    final mealsToUse = _customizedMeals ?? widget.template.meals;

    // Create user meal plan
    final startDate = DateTime.now();
    final endDate = startDate.add(Duration(days: _selectedDuration));

    final mealPlanRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('userMealPlans')
        .add({
          'templateId': widget.template.id,
          'templateName': widget.template.name,
          'startDate': Timestamp.fromDate(startDate),
          'endDate': Timestamp.fromDate(endDate),
          'duration': _selectedDuration,
          'isActive': true,
          'isCustomized': _customizedMeals != null,
          'customizedMeals': _customizedMeals != null
              ? mealsToUse.map((m) => m.toMap()).toList()
              : null,
          // Lưu target calories và macros từ template
          'targetCalories': widget.template.targetCalories,
          'targetProtein': widget.template.targetProtein,
          'targetCarbs': widget.template.targetCarbs,
          'targetFat': widget.template.targetFat,
          'createdAt': Timestamp.now(),
        });

    // Load foods from Firestore để lấy thông tin dinh dưỡng
    final foodsSnapshot = await FirebaseFirestore.instance
        .collection('foods')
        .get();
    final foodMap = <String, FoodItem>{};
    for (final doc in foodsSnapshot.docs) {
      final food = FoodItem.fromFirestore(doc);
      foodMap[food.name.toLowerCase()] = food;
    }

    // Helper to find food by name
    FoodItem? findFood(String name) {
      final exact = foodMap[name.toLowerCase()];
      if (exact != null) return exact;
      for (final entry in foodMap.entries) {
        if (name.toLowerCase().contains(entry.key) ||
            entry.key.contains(name.toLowerCase())) {
          return entry.value;
        }
      }
      return null;
    }

    // Tạo meal plan entries cho mỗi ngày (KHÔNG tạo food logs)
    // Lưu vào subcollection days/{dayIndex} với thông tin các món ăn và trạng thái hoàn thành
    final batch = FirebaseFirestore.instance.batch();
    int batchCount = 0;
    int totalItems = 0;
    int totalSkipped = 0;

    for (int day = 0; day < _selectedDuration; day++) {
      final dayIndex = day + 1;
      final currentDate = startDate.add(Duration(days: day));
      final dayEntries = <Map<String, dynamic>>[];

      for (final meal in mealsToUse) {
        for (final foodName in meal.foods) {
          // Ưu tiên tìm thông tin dinh dưỡng từ foodNutrition trước
          FoodItemNutrition? nutrition;
          if (meal.foodNutrition != null && meal.foodNutrition!.isNotEmpty) {
            // Tìm trong foodNutrition với nhiều cách so sánh
            try {
              nutrition = meal.foodNutrition!.firstWhere(
                (n) {
                  // So sánh chính xác
                  if (n.foodName.toLowerCase().trim() ==
                      foodName.toLowerCase().trim()) {
                    return true;
                  }
                  // So sánh một phần (chứa)
                  if (n.foodName.toLowerCase().contains(
                        foodName.toLowerCase(),
                      ) ||
                      foodName.toLowerCase().contains(
                        n.foodName.toLowerCase(),
                      )) {
                    return true;
                  }
                  return false;
                },
                orElse: () => FoodItemNutrition(
                  foodName: foodName,
                  unit: '',
                  calories: 0,
                  protein: 0,
                  carbs: 0,
                  fat: 0,
                ),
              );
            } catch (e) {
              print('⚠️ Không tìm thấy nutrition cho: $foodName');
              nutrition = null;
            }
          }

          // Nếu không tìm thấy trong foodNutrition, tìm trong foods collection
          FoodItem? food;
          if (nutrition == null || nutrition.calories == 0) {
            food = findFood(foodName);
            if (food == null) {
              print('⚠️ Không tìm thấy món ăn: $foodName');
              totalSkipped++;
              continue;
            }
            // Nếu không có nutrition từ foodNutrition, dùng từ food
            if (nutrition == null) {
              nutrition = FoodItemNutrition(
                foodName: food.name,
                unit: food.unit,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat,
              );
            }
          }

          // Lấy imageUrl từ food nếu có, nếu không thì để rỗng
          String imageUrl = '';
          if (food != null) {
            imageUrl = food.imageUrl;
          } else {
            // Thử tìm food chỉ để lấy imageUrl
            final tempFood = findFood(foodName);
            if (tempFood != null) {
              imageUrl = tempFood.imageUrl;
            }
          }

          // Sử dụng tên từ nutrition hoặc foodName
          final finalFoodName = nutrition.foodName.isNotEmpty
              ? nutrition.foodName
              : (food?.name ?? foodName);

          dayEntries.add({
            'foodName': finalFoodName,
            'mealName': meal.name,
            'mealHour': _getMealHour(meal.name),
            'unit': nutrition.unit,
            'calories': nutrition.calories,
            'protein': nutrition.protein,
            'carbs': nutrition.carbs,
            'fat': nutrition.fat,
            'imageUrl': imageUrl,
            'completed': false, // Chưa hoàn thành
            'completedAt': null,
          });

          print(
            '✅ Đã thêm món: $finalFoodName - ${nutrition.calories} cal, ${nutrition.protein}g protein, ${nutrition.carbs}g carbs, ${nutrition.fat}g fat',
          );
          totalItems++;
        }
      }

      // Lưu day entries vào subcollection
      final dayRef = mealPlanRef.collection('days').doc('day_$dayIndex');
      batch.set(dayRef, {
        'dayIndex': dayIndex,
        'date': Timestamp.fromDate(currentDate),
        'entries': dayEntries,
        'totalItems': dayEntries.length,
        'completedItems': 0,
      });
      batchCount++;

      // Firestore batch limit is 500
      if (batchCount >= 450) {
        try {
          await batch.commit();
          print('✅ Đã commit batch: $batchCount days');
        } catch (e) {
          print('❌ Lỗi commit batch: $e');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi tạo thực đơn: $e')));
          return;
        }
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      try {
        await batch.commit();
        print('✅ Đã commit batch cuối: $batchCount days');
      } catch (e) {
        print('❌ Lỗi commit batch cuối: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tạo thực đơn: $e')));
        return;
      }
    }

    print(
      '✅ Tổng kết: Đã tạo meal plan với $totalItems món ăn, bỏ qua $totalSkipped món ăn',
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã bắt đầu thực đơn "${widget.template.name}" trong $_selectedDuration ngày',
        ),
      ),
    );
  }

  int _getMealHour(String mealName) {
    switch (mealName) {
      case 'Buổi sáng':
        return 7;
      case 'Buổi trưa':
        return 12;
      case 'Buổi chiều':
      case 'Bữa phụ 1':
        return 15;
      case 'Buổi tối':
        return 18;
      case 'Bữa phụ 2':
        return 21;
      default:
        return 12;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCategoryColor(
                        widget.template.category,
                      ).withOpacity(0.9),
                      _getCategoryColor(
                        widget.template.category,
                      ).withOpacity(0.6),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 100,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTag(
                        '${widget.template.meals.length} bữa/ngày',
                        Colors.blueAccent,
                      ),
                      _buildTag('7 ngày', Colors.greenAccent),
                      if (widget.template.category ==
                          MealPlanCategory.loseWeight)
                        _buildTag(
                          'Ít tinh bột - Tăng đạm',
                          Colors.orangeAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title
                  Text(
                    widget.template.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    widget.template.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Nutrition summary with chart
                  _buildNutritionSummary(),
                  const SizedBox(height: 24),
                  // Daily menu
                  const Text(
                    'Thực đơn theo ngày',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  // Day selector
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedDay = day),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _selectedDay == day
                                    ? theme.colorScheme.primary
                                    : const Color(0xFF2A3B4F),
                                border: Border.all(
                                  color: _selectedDay == day
                                      ? Colors.transparent
                                      : Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: _selectedDay == day
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Meals for selected day (use customized if available)
                  ...(_customizedMeals ?? widget.template.meals).map(
                    (meal) => _buildMealCard(meal),
                  ),
                  const SizedBox(height: 24),
                  // Duration selector
                  const Text(
                    'Chọn số ngày thực hiện',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(30, (index) {
                      final days = index + 1;
                      final isSelected = _selectedDuration == days;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedDuration = days),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : const Color(0xFF2A3B4F),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$days',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _openCustomizeScreen,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Tùy chỉnh kế hoạch'),
                              if (_customizedMeals != null) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.check_circle, size: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _startMealPlan,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                          child: const Text('Ăn theo kế hoạch này'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildNutritionSummary() {
    // Get nutrition values directly from template (imported from CSV)
    final totalCal = widget.template.targetCalories;
    final totalProtein = widget.template.targetProtein;
    final totalCarbs = widget.template.targetCarbs;
    final totalFat = widget.template.targetFat;

    // Debug: Verify values are correct
    // print('Nutrition Summary - Calories: $totalCal, Protein: $totalProtein, Carbs: $totalCarbs, Fat: $totalFat');

    // Calculate calorie-based percentages for pie chart
    final proteinCal = totalProtein * 4;
    final carbsCal = totalCarbs * 4;
    final fatCal = totalFat * 9;
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total calories with pie chart
          Row(
            children: [
              // Pie chart
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          PieChartSectionData(
                            value: totalMacroCal > 0
                                ? (proteinCal / totalMacroCal * 100)
                                : 0,
                            color: Colors.redAccent,
                            showTitle: false,
                            radius: 35,
                          ),
                          PieChartSectionData(
                            value: totalMacroCal > 0
                                ? (carbsCal / totalMacroCal * 100)
                                : 0,
                            color: Colors.lightBlueAccent,
                            showTitle: false,
                            radius: 35,
                          ),
                          PieChartSectionData(
                            value: totalMacroCal > 0
                                ? (fatCal / totalMacroCal * 100)
                                : 0,
                            color: Colors.amber,
                            showTitle: false,
                            radius: 35,
                          ),
                        ],
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        startDegreeOffset: -90,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalCal.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'calo',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Macro values
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMacroRow(
                      Icons.bolt,
                      'Chất đạm',
                      totalProtein,
                      Colors.redAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildMacroRow(
                      Icons.grain,
                      'Đường bột',
                      totalCarbs,
                      Colors.lightBlueAccent,
                    ),
                    const SizedBox(height: 8),
                    _buildMacroRow(
                      Icons.oil_barrel,
                      'Chất béo',
                      totalFat,
                      Colors.amber,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(
    IconData icon,
    String label,
    double value,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
        Text(
          '${value.toStringAsFixed(1)}g',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMealCard(MealEntry meal) {
    // Calculate meal total calories
    double mealCal = 0;
    if (meal.foodNutrition != null) {
      mealCal = meal.foodNutrition!.fold(0.0, (sum, n) => sum + n.calories);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Meal name with total calories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (mealCal > 0)
                  Text(
                    'Tổng ${mealCal.toStringAsFixed(0)} calo',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Food items with nutrition details
            if (meal.foodNutrition != null && meal.foodNutrition!.isNotEmpty)
              ...meal.foodNutrition!.map(
                (nutrition) => _buildFoodItemCard(nutrition),
              )
            else
              // Fallback to old display
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meal.foods.map((food) {
                  return Chip(
                    label: Text(food, style: const TextStyle(fontSize: 12)),
                    backgroundColor: const Color(0xFF2A3B4F),
                    avatar: _buildFoodImage(food, 24, 24),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodItemCard(FoodItemNutrition nutrition) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3B4F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildFoodImage(nutrition.foodName, 60, 60),
          ),
          const SizedBox(width: 12),
          // Food info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nutrition.foodName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${nutrition.unit} • ${nutrition.calories.toStringAsFixed(0)} calo',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                // Macronutrients
                Row(
                  children: [
                    const Icon(Icons.bolt, size: 12, color: Colors.redAccent),
                    const SizedBox(width: 2),
                    Text(
                      '${nutrition.protein.toStringAsFixed(1)}g',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.grain,
                      size: 12,
                      color: Colors.lightBlueAccent,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${nutrition.carbs.toStringAsFixed(1)}g',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.oil_barrel, size: 12, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${nutrition.fat.toStringAsFixed(1)}g',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodImage(String foodName, double w, double h) {
    final assetPath = 'assets/images/Anh2/$foodName.jpg';
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        assetPath,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) =>
            Icon(Icons.restaurant, size: w * 0.6, color: Colors.white70),
      ),
    );
  }

  Color _getCategoryColor(MealPlanCategory category) {
    switch (category) {
      case MealPlanCategory.loseWeight:
        return Colors.orange;
      case MealPlanCategory.maintainWeight:
        return Colors.green;
      case MealPlanCategory.gainWeight:
        return Colors.blue;
      case MealPlanCategory.gainMuscle:
        return Colors.purple;
    }
  }
}
