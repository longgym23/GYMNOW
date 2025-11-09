import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/food_model.dart';
import 'package:gym_now/models/nutrition_goal_model.dart';
import 'package:intl/intl.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({Key? key}) : super(key: key);

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  DateTime _selectedDay = DateTime.now();

  Stream<QuerySnapshot<Map<String, dynamic>>> _logStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    final start = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
    );
    final end = start.add(const Duration(days: 1));
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('foodLogs')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .orderBy('scheduledAt')
        .snapshots();
  }

  Map<String, double> _getDailyTotalsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    double calories = 0, protein = 0, carbs = 0, fat = 0;
    for (final doc in docs) {
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

  Future<void> _pickDayCupertino() async {
    DateTime temp = _selectedDay;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 300,
        color: const Color(0xFF1B263B),
        child: Column(
          children: [
            SizedBox(
              height: 55,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Hủy'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('Lựa chọn'),
                    onPressed: () {
                      setState(
                        () => _selectedDay = DateTime(
                          temp.year,
                          temp.month,
                          temp.day,
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: _selectedDay,
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: (v) => temp = v,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getActiveGoalStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('nutritionGoals')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots();
  }

  Future<void> _addFoodToHour(int hour) async {
    final time = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day,
      hour,
    );
    final food = await _showFoodSearchDialog();
    if (food == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('foodLogs')
        .add({
          'name': food.name,
          'unit': food.unit,
          'calories': food.calories,
          'protein': food.protein,
          'carbs': food.carbs,
          'fat': food.fat,
          'imageUrl': food.imageUrl,
          'scheduledAt': Timestamp.fromDate(time),
          'createdAt': Timestamp.now(),
          'source': 'nutrition_db',
        });
  }

  Future<FoodItem?> _showFoodSearchDialog() async {
    return showDialog<FoodItem>(
      context: context,
      builder: (context) => _FoodSearchDialog(buildFoodImage: _buildFoodImage),
    );
  }

  Widget _buildFoodImage(String imageUrl, String name, double w, double h) {
    // Nếu có URL từ internet, dùng trực tiếp
    if (imageUrl.isNotEmpty && imageUrl.startsWith('http')) {
      return Image.network(imageUrl, width: w, height: h, fit: BoxFit.cover);
    }

    // Nếu có asset path cụ thể, dùng nó
    if (imageUrl.isNotEmpty && imageUrl.startsWith('asset:')) {
      return Image.asset(
        imageUrl.replaceFirst('asset:', ''),
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => const Icon(Icons.restaurant, size: 32),
      );
    }

    // Normalize tên món ăn để match với tên file ảnh
    String normalizedName = name.trim();

    // Thử nhiều cách đặt tên khác nhau cho cả Anh và Anh2
    final imagePaths = [
      // Thử Anh2 trước
      'assets/images/Anh2/$normalizedName.jpg',
      'assets/images/Anh2/${normalizedName.toLowerCase()}.jpg',
      'assets/images/Anh2/${_capitalizeFirst(normalizedName)}.jpg',
      'assets/images/Anh2/${normalizedName.replaceAll(' ', '_')}.jpg',
      'assets/images/Anh2/${normalizedName.replaceAll(' ', '_').toLowerCase()}.jpg',
      // Sau đó thử Anh
      'assets/images/Anh/$normalizedName.jpg',
      'assets/images/Anh/${normalizedName.toLowerCase()}.jpg',
      'assets/images/Anh/${_capitalizeFirst(normalizedName)}.jpg',
      'assets/images/Anh/${normalizedName.replaceAll(' ', '_')}.jpg',
      'assets/images/Anh/${normalizedName.replaceAll(' ', '_').toLowerCase()}.jpg',
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: _FoodImageLoader(imagePaths: imagePaths, width: w, height: h),
    );
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final isToday =
        _selectedDay.year == DateTime.now().year &&
        _selectedDay.month == DateTime.now().month &&
        _selectedDay.day == DateTime.now().day;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => _selectedDay = _selectedDay.subtract(
                  const Duration(days: 1),
                ),
              ),
            ),
            Text(
              isToday ? 'Hôm nay' : DateFormat('dd/MM').format(_selectedDay),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => _selectedDay = _selectedDay.add(const Duration(days: 1)),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _pickDayCupertino,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _logStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];

          // Lấy active meal plan để filter food logs và lấy target
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser!.uid)
                .collection('userMealPlans')
                .where('isActive', isEqualTo: true)
                .limit(1)
                .snapshots(),
            builder: (context, mealPlanSnapshot) {
              String? activeMealPlanId;
              double targetCal = 2093.0;
              double targetProtein = 105.0;
              double targetCarbs = 262.0;
              double targetFat = 70.0;

              // Nếu có active meal plan, lấy target từ meal plan
              if (mealPlanSnapshot.hasData &&
                  mealPlanSnapshot.data!.docs.isNotEmpty) {
                final planData = mealPlanSnapshot.data!.docs.first.data();
                activeMealPlanId = mealPlanSnapshot.data!.docs.first.id;
                targetCal = (planData['targetCalories'] ?? 0.0) as double;
                targetProtein = (planData['targetProtein'] ?? 0.0) as double;
                targetCarbs = (planData['targetCarbs'] ?? 0.0) as double;
                targetFat = (planData['targetFat'] ?? 0.0) as double;
              }

              // Filter food logs:
              // - Nếu có active meal plan, hiển thị cả logs từ meal plan VÀ logs được thêm thủ công
              // - Nếu không có active meal plan, hiển thị tất cả logs
              final filteredDocs = activeMealPlanId != null
                  ? docs.where((doc) {
                      final data = doc.data();
                      final source = data['source'] as String?;
                      // Hiển thị logs từ meal plan hoặc logs được thêm thủ công (nutrition_db, manual, etc.)
                      if (source == 'meal_plan') {
                        return data['mealPlanId'] == activeMealPlanId;
                      } else {
                        // Hiển thị các logs không phải từ meal plan (được thêm thủ công)
                        return true;
                      }
                    }).toList()
                  : docs;

              final totals = filteredDocs.isEmpty
                  ? {'calories': 0.0, 'protein': 0.0, 'carbs': 0.0, 'fat': 0.0}
                  : _getDailyTotalsFromDocs(filteredDocs);

              // Group by hour từ filtered docs
              final hourlyGroups = <int, List<Map<String, dynamic>>>{};
              for (final doc in filteredDocs) {
                final data = doc.data();
                final ts =
                    (data['scheduledAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
                final hour = ts.hour;
                hourlyGroups.putIfAbsent(hour, () => []);
                hourlyGroups[hour]!.add({...data, 'id': doc.id});
              }

              // Nếu không có active meal plan, lấy target từ NutritionGoal
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _getActiveGoalStream(),
                builder: (context, goalSnapshot) {
                  // Chỉ dùng NutritionGoal nếu không có active meal plan
                  if (activeMealPlanId == null &&
                      goalSnapshot.hasData &&
                      goalSnapshot.data!.docs.isNotEmpty) {
                    final goal = NutritionGoal.fromDoc(
                      goalSnapshot.data!.docs.first,
                    );
                    targetCal = goal.targetCalories;
                    targetProtein = goal.targetProtein;
                    targetCarbs = goal.targetCarbs;
                    targetFat = goal.targetFat;
                  }

                  print(
                    '📊 Nhật ký - Target: Cal=$targetCal, Protein=$targetProtein, Carbs=$targetCarbs, Fat=$targetFat',
                  );
                  print(
                    '📊 Nhật ký - Totals: Cal=${totals['calories']}, Protein=${totals['protein']}, Carbs=${totals['carbs']}, Fat=${totals['fat']}',
                  );
                  print('📊 Nhật ký - Active meal plan ID: $activeMealPlanId');
                  print(
                    '📊 Nhật ký - Filtered docs: ${filteredDocs.length} từ ${docs.length} total',
                  );

                  // Kiểm tra xem có macro nào vượt quá target không
                  final isOverCal = totals['calories']! > targetCal;
                  final isOverProtein = totals['protein']! > targetProtein;
                  final isOverCarbs = totals['carbs']! > targetCarbs;
                  final isOverFat = totals['fat']! > targetFat;
                  final hasAnyOver =
                      isOverCal || isOverProtein || isOverCarbs || isOverFat;

                  return Column(
                    children: [
                      // Banner cảnh báo nếu có macro vượt quá
                      if (hasAnyOver)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.withOpacity(0.2),
                                Colors.orange.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cảnh báo: Vượt quá mục tiêu',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        if (isOverCal)
                                          _buildWarningChip(
                                            'Calo',
                                            totals['calories']! - targetCal,
                                          ),
                                        if (isOverProtein)
                                          _buildWarningChip(
                                            'Protein',
                                            totals['protein']! - targetProtein,
                                          ),
                                        if (isOverCarbs)
                                          _buildWarningChip(
                                            'Carbs',
                                            totals['carbs']! - targetCarbs,
                                          ),
                                        if (isOverFat)
                                          _buildWarningChip(
                                            'Fat',
                                            totals['fat']! - targetFat,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Nutrition Summary - Compact 2x2 Grid Layout
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            // Row 1: Calories and Protein
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactNutritionCard(
                                    icon: Icons.local_fire_department,
                                    label: 'Calories',
                                    current: totals['calories']!,
                                    target: targetCal,
                                    unit: 'cal',
                                    color: Colors.purple,
                                    gradient: [
                                      Colors.purple.shade400,
                                      Colors.purple.shade600,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildCompactNutritionCard(
                                    icon: Icons.bolt,
                                    label: 'Protein',
                                    current: totals['protein']!,
                                    target: targetProtein,
                                    unit: 'g',
                                    color: Colors.red,
                                    gradient: [
                                      Colors.red.shade400,
                                      Colors.red.shade600,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Row 2: Carbs and Fat
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactNutritionCard(
                                    icon: Icons.grain,
                                    label: 'Carbs',
                                    current: totals['carbs']!,
                                    target: targetCarbs,
                                    unit: 'g',
                                    color: Colors.blue,
                                    gradient: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade600,
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildCompactNutritionCard(
                                    icon: Icons.oil_barrel,
                                    label: 'Fat',
                                    current: totals['fat']!,
                                    target: targetFat,
                                    unit: 'g',
                                    color: Colors.amber,
                                    gradient: [
                                      Colors.amber.shade400,
                                      Colors.amber.shade600,
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Timeline
                      Expanded(
                        child: ListView.builder(
                          itemCount: 24,
                          itemBuilder: (context, index) {
                            final hour = index;
                            final items = hourlyGroups[hour] ?? [];
                            final hourCal = items.fold(
                              0.0,
                              (s, i) =>
                                  s + ((i['calories'] ?? 0) as num).toDouble(),
                            );
                            final hourProtein = items.fold(
                              0.0,
                              (s, i) =>
                                  s + ((i['protein'] ?? 0) as num).toDouble(),
                            );
                            final hourCarbs = items.fold(
                              0.0,
                              (s, i) =>
                                  s + ((i['carbs'] ?? 0) as num).toDouble(),
                            );
                            final hourFat = items.fold(
                              0.0,
                              (s, i) => s + ((i['fat'] ?? 0) as num).toDouble(),
                            );

                            return Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 0,
                                top: 8,
                                bottom: 8,
                              ),
                              child: Stack(
                                children: [
                                  // Horizontal line from time pill to add button (only when no items)
                                  // Line is centered at the middle of time pill (padding 6 + text height ~20/2 = ~16px from top of Container)
                                  if (items.isEmpty)
                                    Positioned(
                                      left: 0,
                                      right:
                                          64, // 48 for button + 16 for padding
                                      top:
                                          14, // Center of time pill: padding (6) + half of text height (~10) = 16
                                      child: Container(
                                        height: 1,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  // Content row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Time pill và summary row - wrapped in IntrinsicHeight for alignment
                                            IntrinsicHeight(
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  // Time pill
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade700,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      '${hour.toString().padLeft(2, '0')}:00',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        height: 1.0,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Summary calories and macros
                                                  if (items.isNotEmpty)
                                                    Expanded(
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons
                                                                .local_fire_department,
                                                            size: 16,
                                                            color:
                                                                Colors.purple,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            '${hourCal.toStringAsFixed(0)} cal',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          const Icon(
                                                            Icons.bolt,
                                                            size: 14,
                                                            color: Colors
                                                                .redAccent,
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Text(
                                                            '${hourProtein.toStringAsFixed(0)}g',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          const Icon(
                                                            Icons.grain,
                                                            size: 14,
                                                            color: Colors
                                                                .lightBlueAccent,
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Text(
                                                            '${hourCarbs.toStringAsFixed(0)}g',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          const Icon(
                                                            Icons.oil_barrel,
                                                            size: 14,
                                                            color: Colors.amber,
                                                          ),
                                                          const SizedBox(
                                                            width: 2,
                                                          ),
                                                          Text(
                                                            '${hourFat.toStringAsFixed(0)}g',
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Food entries
                                            if (items.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF2A3B4F,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    ...items
                                                        .asMap()
                                                        .entries
                                                        .map(
                                                          (entry) =>
                                                              _buildFoodEntry(
                                                                entry.value,
                                                                entry.key,
                                                              ),
                                                        ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Add button - aligned to far right, centered with time pill
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 16,
                                        ),
                                        child: SizedBox(
                                          height:
                                              28, // Match time pill height (6 + 14 + 6 + 2 for border)
                                          child: Align(
                                            alignment: Alignment.center,
                                            child: IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade800,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.grey.shade700,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.add,
                                                  size: 20,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _addFoodToHour(hour),
                                              tooltip: 'Thêm món ăn',
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addFoodToHour(DateTime.now().hour),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCompactNutritionCard({
    required IconData icon,
    required String label,
    required double current,
    required double target,
    required String unit,
    required Color color,
    required List<Color> gradient,
  }) {
    final isOverTarget = current > target;
    final progress = (current / target).clamp(0.0, 1.0);
    final displayProgress = isOverTarget ? 1.0 : progress;
    final percentage = isOverTarget
        ? ((current - target) / target * 100)
        : (progress * 100);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isOverTarget
            ? Colors.red.withOpacity(0.15)
            : const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
        border: isOverTarget
            ? Border.all(color: Colors.red.withOpacity(0.6), width: 1.5)
            : Border.all(
                color: Colors.grey.shade700.withOpacity(0.3),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: isOverTarget
                ? Colors.red.withOpacity(0.15)
                : Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOverTarget
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : gradient,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (isOverTarget ? Colors.red : color).withOpacity(
                        0.3,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Icon(icon, color: Colors.white, size: 16),
                    if (isOverTarget)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning,
                            size: 7,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isOverTarget ? Colors.red : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: isOverTarget
                      ? Colors.red.withOpacity(0.2)
                      : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isOverTarget
                        ? Colors.red.withOpacity(0.5)
                        : color.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  isOverTarget
                      ? '+${percentage.toStringAsFixed(0)}%'
                      : '${percentage.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isOverTarget ? Colors.red : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: displayProgress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverTarget ? Colors.red : color,
              ),
            ),
          ),
          // Over target warning
          if (isOverTarget) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: Colors.red.shade300,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    'Vượt quá ${(current - target).toStringAsFixed(0)} $unit',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.red.shade300,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningChip(String label, double excess) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '+${excess.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFoodEntry(String logId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('foodLogs')
          .doc(logId)
          .delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xóa món ăn: $e')));
      }
    }
  }

  Widget _buildFoodEntry(Map<String, dynamic> item, int index) {
    final name = (item['name'] ?? '').toString();
    final unit = (item['unit'] ?? '').toString();
    final calories = ((item['calories'] ?? 0) as num).toDouble();
    final protein = ((item['protein'] ?? 0) as num).toDouble();
    final carbs = ((item['carbs'] ?? 0) as num).toDouble();
    final fat = ((item['fat'] ?? 0) as num).toDouble();
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final logId = (item['id'] ?? '').toString();

    return Dismissible(
      key: Key('food_entry_${logId}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showCupertinoDialog<bool>(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('Xóa món ăn?'),
                content: const Text(
                  'Bạn có chắc chắn muốn xóa món ăn này khỏi nhật ký?',
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Hủy'),
                  ),
                  CupertinoDialogAction(
                    onPressed: () => Navigator.pop(context, true),
                    isDestructiveAction: true,
                    child: const Text('Xóa'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (direction) {
        if (logId.isNotEmpty) {
          _deleteFoodEntry(logId);
        }
      },
      child: Padding(
        padding: EdgeInsets.only(top: index > 0 ? 12 : 0),
        child: Row(
          children: [
            // Food image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildFoodImage(imageUrl, name, 60, 60),
            ),
            const SizedBox(width: 12),
            // Food info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${unit} • ${calories.toStringAsFixed(0)} cal',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 2),
                      Text(
                        '${protein.toStringAsFixed(1)}g',
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
                        '${carbs.toStringAsFixed(1)}g',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.oil_barrel,
                        size: 12,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${fat.toStringAsFixed(1)}g',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog tìm kiếm món ăn
class _FoodSearchDialog extends StatefulWidget {
  final Widget Function(String imageUrl, String name, double w, double h)
  buildFoodImage;

  const _FoodSearchDialog({required this.buildFoodImage});

  @override
  State<_FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<_FoodSearchDialog> {
  String searchQuery = '';
  Stream<QuerySnapshot>? foodsStream;
  late final TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController();
    foodsStream = FirebaseFirestore.instance
        .collection('foods')
        .orderBy('name')
        .limit(50)
        .snapshots();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  /// Hàm remove dấu tiếng Việt
  String _removeDiacritics(String str) {
    const Map<String, String> diacriticsMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    String result = str.toLowerCase();
    diacriticsMap.forEach((vietnamese, english) {
      result = result.replaceAll(vietnamese, english);
    });
    return result;
  }

  /// Kiểm tra xem food có match với search query không (hỗ trợ không dấu và chữ cái đầu)
  bool _matchesSearch(String foodName, String query) {
    final normalizedFood = _removeDiacritics(foodName);
    final normalizedQuery = _removeDiacritics(query);

    // Tìm kiếm chính xác hoặc chứa
    if (normalizedFood.contains(normalizedQuery)) {
      return true;
    }

    // Tìm kiếm theo chữ cái đầu của từng từ
    final words = normalizedFood.split(' ');
    final firstLetters = words.map((w) => w.isNotEmpty ? w[0] : '').join('');
    if (firstLetters.contains(normalizedQuery)) {
      return true;
    }

    return false;
  }

  void _updateSearch(String query) {
    setState(() {
      searchQuery = query.toLowerCase();
      // Lấy tất cả foods và filter ở client-side
      foodsStream = FirebaseFirestore.instance
          .collection('foods')
          .orderBy('name')
          .limit(200)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF1B263B),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.7),
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
                    child: const Icon(
                      Icons.bookmark_add_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Danh sách món ăn',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2A3B4F),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nhập tên món ăn...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.clear,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                            ),
                            onPressed: () {
                              searchController.clear();
                              _updateSearch('');
                            },
                          )
                        : null,
                    filled: false,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onChanged: _updateSearch,
                ),
              ),
            ),
            // Food list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: foodsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3B4F),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Không tìm thấy món ăn',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final foodDocs = snapshot.data!.docs;

                  // Filter kết quả nếu có search query
                  final filteredDocs = searchQuery.isNotEmpty
                      ? foodDocs.where((doc) {
                          final food = FoodItem.fromFirestore(doc);
                          return _matchesSearch(food.name, searchQuery);
                        }).toList()
                      : foodDocs;

                  if (filteredDocs.isEmpty && searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3B4F),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.restaurant_menu,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Không tìm thấy món ăn',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final food = FoodItem.fromFirestore(filteredDocs[index]);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A3B4F),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(context, food),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [
                                          Theme.of(context).colorScheme.primary
                                              .withOpacity(0.3),
                                          Theme.of(context).colorScheme.primary
                                              .withOpacity(0.1),
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: widget.buildFoodImage(
                                        food.imageUrl,
                                        food.name,
                                        60,
                                        60,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          food.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.local_fire_department,
                                                    size: 14,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${food.calories.toStringAsFixed(0)} kcal',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '/ ${food.unit}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget để load ảnh với fallback
class _FoodImageLoader extends StatelessWidget {
  final List<String> imagePaths;
  final double width;
  final double height;

  const _FoodImageLoader({
    required this.imagePaths,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return _tryLoadImage(0);
  }

  Widget _tryLoadImage(int index) {
    if (index >= imagePaths.length) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFF2A3B4F),
        child: Icon(Icons.restaurant, size: width * 0.5, color: Colors.white70),
      );
    }

    return Image.asset(
      imagePaths[index],
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _tryLoadImage(index + 1);
      },
    );
  }
}
