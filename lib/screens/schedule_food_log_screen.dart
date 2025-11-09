import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gym_now/models/food_model.dart';
import 'package:gym_now/models/nutrition_goal_model.dart';

class ScheduleFoodLogScreen extends StatefulWidget {
  final FoodItem food;
  const ScheduleFoodLogScreen({Key? key, required this.food}) : super(key: key);

  @override
  State<ScheduleFoodLogScreen> createState() => _ScheduleFoodLogScreenState();
}

class _ScheduleFoodLogScreenState extends State<ScheduleFoodLogScreen> {
  DateTime _selectedDateTime = DateTime.now();
  bool _saving = false;

  /// Format thời gian theo định dạng 12h với AM/PM
  String _formatTime12h(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickDate() async {
    DateTime temp = _selectedDateTime;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFF1B263B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Xác nhận',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDateTime = DateTime(
                          temp.year,
                          temp.month,
                          temp.day,
                          _selectedDateTime.hour,
                          _selectedDateTime.minute,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _selectedDateTime,
                mode: CupertinoDatePickerMode.date,
                minimumDate: DateTime(1900),
                maximumDate: DateTime(2100),
                onDateTimeChanged: (v) => temp = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    DateTime temp = _selectedDateTime;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 350,
        decoration: const BoxDecoration(
          color: Color(0xFF1B263B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Xác nhận',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedDateTime = DateTime(
                          _selectedDateTime.year,
                          _selectedDateTime.month,
                          _selectedDateTime.day,
                          temp.hour,
                          temp.minute,
                        );
                      });
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _selectedDateTime,
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false, // Sử dụng định dạng 12h với AM/PM
                onDateTimeChanged: (v) => temp = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Lấy target dinh dưỡng từ meal plan hoặc nutrition goal
  Future<Map<String, double>> _getNutritionTargets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {
        'calories': 2093.0,
        'protein': 105.0,
        'carbs': 262.0,
        'fat': 70.0,
      };
    }

    // Thử lấy từ active meal plan trước
    final mealPlanSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('userMealPlans')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (mealPlanSnapshot.docs.isNotEmpty) {
      final planData = mealPlanSnapshot.docs.first.data();
      return {
        'calories': (planData['targetCalories'] ?? 2093.0).toDouble(),
        'protein': (planData['targetProtein'] ?? 105.0).toDouble(),
        'carbs': (planData['targetCarbs'] ?? 262.0).toDouble(),
        'fat': (planData['targetFat'] ?? 70.0).toDouble(),
      };
    }

    // Nếu không có meal plan, lấy từ nutrition goal
    final goalSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('nutritionGoals')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (goalSnapshot.docs.isNotEmpty) {
      final goal = NutritionGoal.fromDoc(goalSnapshot.docs.first);
      return {
        'calories': goal.targetCalories,
        'protein': goal.targetProtein,
        'carbs': goal.targetCarbs,
        'fat': goal.targetFat,
      };
    }

    // Mặc định
    return {'calories': 2093.0, 'protein': 105.0, 'carbs': 262.0, 'fat': 70.0};
  }

  /// Tính tổng dinh dưỡng trong ngày
  Future<Map<String, double>> _getDailyTotals(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0};
    }

    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('foodLogs')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .get();

    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      calories += ((data['calories'] ?? 0) as num).toDouble();
      protein += ((data['protein'] ?? 0) as num).toDouble();
      carbs += ((data['carbs'] ?? 0) as num).toDouble();
      fat += ((data['fat'] ?? 0) as num).toDouble();
    }

    return {
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };
  }

  /// Hiển thị cảnh báo nếu vượt quá target
  void _showWarningIfOverTarget(
    Map<String, double> currentTotals,
    Map<String, double> targets,
  ) {
    final newCal = currentTotals['calories']! + widget.food.calories;
    final newProtein = currentTotals['protein']! + widget.food.protein;
    final newCarbs = currentTotals['carbs']! + widget.food.carbs;
    final newFat = currentTotals['fat']! + widget.food.fat;

    final isOverCal = newCal > targets['calories']!;
    final isOverProtein = newProtein > targets['protein']!;
    final isOverCarbs = newCarbs > targets['carbs']!;
    final isOverFat = newFat > targets['fat']!;

    if (isOverCal || isOverProtein || isOverCarbs || isOverFat) {
      final warnings = <String>[];
      if (isOverCal) {
        warnings.add(
          'Calo: +${(newCal - targets['calories']!).toStringAsFixed(0)}',
        );
      }
      if (isOverProtein) {
        warnings.add(
          'Protein: +${(newProtein - targets['protein']!).toStringAsFixed(0)}g',
        );
      }
      if (isOverCarbs) {
        warnings.add(
          'Carbs: +${(newCarbs - targets['carbs']!).toStringAsFixed(0)}g',
        );
      }
      if (isOverFat) {
        warnings.add('Fat: +${(newFat - targets['fat']!).toStringAsFixed(0)}g');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cảnh báo: Vượt quá mục tiêu',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      warnings.join(', '),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Lấy target và totals hiện tại để kiểm tra cảnh báo
      final targets = await _getNutritionTargets();
      final currentTotals = await _getDailyTotals(_selectedDateTime);

      final entry = {
        'name': widget.food.name,
        'unit': widget.food.unit,
        'calories': widget.food.calories,
        'protein': widget.food.protein,
        'carbs': widget.food.carbs,
        'fat': widget.food.fat,
        'imageUrl': widget.food.imageUrl,
        'scheduledAt': Timestamp.fromDate(_selectedDateTime),
        'createdAt': Timestamp.now(),
        'source': 'nutrition_db',
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('foodLogs')
          .add(entry);

      if (!mounted) return;

      // Hiển thị cảnh báo nếu vượt quá target
      _showWarningIfOverTarget(currentTotals, targets);

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu nhật ký: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _selectedDateTime;
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn ngày & giờ'), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header với thông tin món ăn
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.3),
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildFoodImage(widget.food, 60, 60),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.food.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 16,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.food.calories.toStringAsFixed(0)} kcal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Tiêu đề
              const Text(
                'Chọn thời gian',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 20),
              // Card chọn ngày
              _buildDateTimeCard(
                context: context,
                title: 'Ngày',
                value:
                    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                icon: Icons.calendar_today,
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              // Card chọn giờ
              _buildDateTimeCard(
                context: context,
                title: 'Giờ',
                value: _formatTime12h(d),
                icon: Icons.schedule,
                onTap: _pickTime,
              ),
              const Spacer(),
              // Nút lưu
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: _saving ? null : _save,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: _saving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save, color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Lưu vào Nhật ký',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodImage(FoodItem food, double w, double h) {
    final src = food.imageUrl;
    if (src.isNotEmpty && src.startsWith('http')) {
      return Image.network(src, width: w, height: h, fit: BoxFit.cover);
    }
    final assetPath = src.isNotEmpty && src.startsWith('asset:')
        ? src.replaceFirst('asset:', '')
        : 'assets/images/Anh/${food.name}.jpg';
    return Image.asset(
      assetPath,
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (c, e, s) => Container(
        width: w,
        height: h,
        color: const Color(0xFF2A3B4F),
        child: Icon(Icons.restaurant, size: w * 0.6, color: Colors.white70),
      ),
    );
  }
}
