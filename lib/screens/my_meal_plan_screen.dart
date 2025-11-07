import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/nutrition_goal_model.dart';
import 'package:intl/intl.dart';

class MyMealPlanScreen extends StatefulWidget {
  const MyMealPlanScreen({Key? key}) : super(key: key);

  @override
  State<MyMealPlanScreen> createState() => _MyMealPlanScreenState();
}

class _MyMealPlanScreenState extends State<MyMealPlanScreen> {
  DateTime _selectedDate = DateTime.now();
  int _selectedTab = 0; // 0: Daily meals, 1: Active meal plans

  Stream<QuerySnapshot<Map<String, dynamic>>> _getActiveMealPlansStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    // Query không có orderBy để tránh cần index, sẽ sort trong code
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('userMealPlans')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  // Toggle hoàn thành món ăn và tạo food log vào nhật ký
  Future<void> _toggleMealItemCompleted(
    String mealPlanId,
    int dayIndex,
    int entryIndex,
    Map<String, dynamic> entryData,
    bool completed,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final dayRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('userMealPlans')
          .doc(mealPlanId)
          .collection('days')
          .doc('day_$dayIndex');

      // Update entry completed status
      final dayDoc = await dayRef.get();
      if (!dayDoc.exists) return;

      final dayData = dayDoc.data() as Map<String, dynamic>;
      final entries = (dayData['entries'] as List<dynamic>)
          .cast<Map<String, dynamic>>();

      if (entryIndex >= entries.length) return;

      entries[entryIndex]['completed'] = completed;
      entries[entryIndex]['completedAt'] = completed ? Timestamp.now() : null;

      // Update completedItems count
      final completedItems = entries
          .where((e) => e['completed'] == true)
          .length;

      await dayRef.update({
        'entries': entries,
        'completedItems': completedItems,
      });

      // Nếu hoàn thành, tạo food log vào nhật ký với thời gian hiện tại
      if (completed) {
        // Đảm bảo lấy đúng dữ liệu từ entryData (đã có từ meal plan)
        final foodLogData = {
          'name': entryData['foodName'] ?? '',
          'unit': entryData['unit'] ?? '',
          'calories': (entryData['calories'] ?? 0.0) as num,
          'protein': (entryData['protein'] ?? 0.0) as num,
          'carbs': (entryData['carbs'] ?? 0.0) as num,
          'fat': (entryData['fat'] ?? 0.0) as num,
          'imageUrl': entryData['imageUrl'] ?? '',
          'scheduledAt': Timestamp.now(), // Thời gian hiện tại khi hoàn thành
          'source': 'meal_plan',
          'mealPlanId': mealPlanId,
          'consumed': true, // Đã hoàn thành nên consumed = true
          'createdAt': Timestamp.now(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('foodLogs')
            .add(foodLogData);

        print(
          '✅ Đã tạo food log vào nhật ký cho món: ${entryData['foodName']}',
        );
        print(
          '   📊 Dữ liệu: ${foodLogData['calories']} cal, ${foodLogData['protein']}g protein, ${foodLogData['carbs']}g carbs, ${foodLogData['fat']}g fat',
        );
      }
    } catch (e) {
      print('❌ Lỗi toggle meal item: $e');
    }
  }

  Future<void> _toggleConsumed(String logId, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('foodLogs')
        .doc(logId)
        .update({'consumed': value});
  }

  Map<String, List<Map<String, dynamic>>> _groupByMealFromDocs(
    List<DocumentSnapshot> docs,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    print('📊 Grouping ${docs.length} food logs by meal');

    // Sort by scheduledAt if not already sorted
    final sortedDocs = docs.toList()
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aTime = aData?['scheduledAt'] as Timestamp?;
        final bTime = bData?['scheduledAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return aTime.compareTo(bTime);
      });

    for (final doc in sortedDocs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final ts =
          (data['scheduledAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final hour = ts.hour;
      String meal;
      if (hour >= 5 && hour < 10) {
        meal = 'Buổi sáng';
      } else if (hour >= 10 && hour < 14) {
        meal = 'Buổi trưa';
      } else if (hour >= 14 && hour < 18) {
        meal = 'Buổi chiều';
      } else {
        meal = 'Buổi tối';
      }
      groups.putIfAbsent(meal, () => []);
      groups[meal]!.add({...data, 'id': doc.id});
    }

    print('✅ Grouped into ${groups.length} meals: ${groups.keys.toList()}');
    return groups;
  }

  double _getTotalCaloriesFromDocs(
    List<DocumentSnapshot> docs, {
    bool onlyConsumed = false,
  }) {
    return docs.fold(0.0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return sum;
      if (onlyConsumed) {
        final consumed = (data['consumed'] ?? false) as bool;
        if (!consumed) return sum;
      }
      return sum + ((data['calories'] ?? 0) as num).toDouble();
    });
  }

  Map<String, double> _getTotalMacrosFromDocs(
    List<DocumentSnapshot> docs, {
    bool onlyConsumed = false,
  }) {
    double protein = 0, carbs = 0, fat = 0;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if (onlyConsumed) {
        final consumed = (data['consumed'] ?? false) as bool;
        if (!consumed) continue;
      }
      protein += ((data['protein'] ?? 0) as num).toDouble();
      carbs += ((data['carbs'] ?? 0) as num).toDouble();
      fat += ((data['fat'] ?? 0) as num).toDouble();
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
  }

  // Calculate macros from meal plan entries
  Map<String, double> _calculateMacrosFromEntries(
    List<Map<String, dynamic>> entries, {
    bool onlyCompleted = false,
  }) {
    double protein = 0, carbs = 0, fat = 0;
    for (final entry in entries) {
      if (onlyCompleted) {
        final completed = (entry['completed'] ?? false) as bool;
        if (!completed) continue;
      }
      protein += ((entry['protein'] ?? 0) as num).toDouble();
      carbs += ((entry['carbs'] ?? 0) as num).toDouble();
      fat += ((entry['fat'] ?? 0) as num).toDouble();
    }
    return {'protein': protein, 'carbs': carbs, 'fat': fat};
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

  Widget _buildActiveMealPlansTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getActiveMealPlansStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có thực đơn đang thực hiện',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy chọn một thực đơn từ tab "Thực đơn tự tạo"',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Sort documents by createdAt descending (newest first)
        final sortedDocs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aCreated = (a.data()['createdAt'] as Timestamp?);
            final bCreated = (b.data()['createdAt'] as Timestamp?);
            if (aCreated == null || bCreated == null) return 0;
            return bCreated.compareTo(aCreated); // Descending
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data();
            final startDate = (data['startDate'] as Timestamp).toDate();
            final endDate = (data['endDate'] as Timestamp).toDate();
            final duration = data['duration'] as int? ?? 7;
            final templateName = data['templateName'] as String? ?? 'Thực đơn';
            final isCustomized = data['isCustomized'] as bool? ?? false;

            // Tính tiến độ dựa trên số món đã hoàn thành
            // Lấy tổng số món và số món đã hoàn thành từ tất cả các ngày
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser!.uid)
                  .collection('userMealPlans')
                  .doc(doc.id)
                  .collection('days')
                  .snapshots(),
              builder: (context, daysSnapshot) {
                int totalItems = 0;
                int completedItems = 0;

                if (daysSnapshot.hasData) {
                  for (final dayDoc in daysSnapshot.data!.docs) {
                    final dayData = dayDoc.data();
                    final entries = (dayData['entries'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>();
                    totalItems += entries.length;
                    completedItems += entries
                        .where((e) => e['completed'] == true)
                        .length;
                  }
                }

                final progress = totalItems > 0
                    ? (completedItems / totalItems).clamp(0.0, 1.0)
                    : 0.0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: const Color(0xFF1B263B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        templateName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isCustomized) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(
                                              0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange,
                                              width: 1,
                                            ),
                                          ),
                                          child: const Text(
                                            'Đã tùy chỉnh',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () async {
                                // Deactivate meal plan
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('userMealPlans')
                                      .doc(doc.id)
                                      .update({'isActive': false});
                                }
                              },
                              tooltip: 'Dừng thực đơn',
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Progress bar
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Tiến độ: $completedItems / $totalItems món',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.shade700,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab selector
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3B4F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(child: _buildTabButton('Thực đơn hôm nay', 0)),
              Expanded(child: _buildTabButton('Thực đơn của bạn', 1)),
            ],
          ),
        ),
        // Content based on selected tab
        Expanded(
          child: _selectedTab == 0
              ? _buildDailyMealsTab()
              : _buildActiveMealPlansTab(),
        ),
      ],
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyMealsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getActiveMealPlansStream(),
      builder: (context, planSnapshot) {
        if (planSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!planSnapshot.hasData || planSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'Chưa có thực đơn đang thực hiện',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hãy chọn một thực đơn từ tab "Thực đơn tự tạo"',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final planDoc = planSnapshot.data!.docs.first;
        final planData = planDoc.data();
        final mealPlanId = planDoc.id;
        final startDate = (planData['startDate'] as Timestamp).toDate();

        // Tính day index dựa trên selectedDate và startDate
        final daysDiff = _selectedDate
            .difference(
              DateTime(startDate.year, startDate.month, startDate.day),
            )
            .inDays;

        if (daysDiff < 0 || daysDiff >= (planData['duration'] as int? ?? 7)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'Ngày này ngoài phạm vi thực đơn',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final dayIndex = daysDiff + 1;

        // Lấy day data
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('userMealPlans')
              .doc(mealPlanId)
              .collection('days')
              .doc('day_$dayIndex')
              .snapshots(),
          builder: (context, daySnapshot) {
            if (daySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!daySnapshot.hasData || !daySnapshot.data!.exists) {
              return const Center(
                child: Text(
                  'Chưa có dữ liệu cho ngày này',
                  style: TextStyle(color: Colors.white70),
                ),
              );
            }

            final dayData = daySnapshot.data!.data()!;
            final entries = (dayData['entries'] as List<dynamic>)
                .cast<Map<String, dynamic>>();

            // Group entries by meal
            final meals = <String, List<Map<String, dynamic>>>{};
            for (int i = 0; i < entries.length; i++) {
              final entry = entries[i];
              final mealName = entry['mealName'] as String? ?? 'Khác';
              meals.putIfAbsent(mealName, () => []);
              meals[mealName]!.add({...entry, 'entryIndex': i});
            }

            // Calculate totals - chỉ tính từ các món đã hoàn thành cho consumedCal
            // và tất cả món cho totalCal và macros
            final macros = _calculateMacrosFromEntries(
              entries,
              onlyCompleted: false,
            );
            final totalCal = entries.fold(
              0.0,
              (sum, e) => sum + ((e['calories'] ?? 0) as num).toDouble(),
            );
            final consumedCal = entries
                .where((e) => e['completed'] == true)
                .fold(
                  0.0,
                  (sum, e) => sum + ((e['calories'] ?? 0) as num).toDouble(),
                );

            // Debug: In ra thông tin để kiểm tra
            print('📊 Tổng số món: ${entries.length}');
            print('📊 Tổng calo: $totalCal');
            print('📊 Calo đã hoàn thành: $consumedCal');
            print(
              '📊 Macros: Protein=${macros['protein']}, Carbs=${macros['carbs']}, Fat=${macros['fat']}',
            );

            // Lấy target calories và macros từ meal plan thay vì từ NutritionGoal
            final targetCal = (planData['targetCalories'] ?? 0.0) as double;
            final targetProtein = (planData['targetProtein'] ?? 0.0) as double;
            final targetCarbs = (planData['targetCarbs'] ?? 0.0) as double;
            final targetFat = (planData['targetFat'] ?? 0.0) as double;

            print(
              '🎯 Target từ meal plan: Cal=$targetCal, Protein=$targetProtein, Carbs=$targetCarbs, Fat=$targetFat',
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date selector
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () {
                          setState(
                            () => _selectedDate = _selectedDate.subtract(
                              const Duration(days: 1),
                            ),
                          );
                        },
                      ),
                      Text(
                        DateFormat('dd/MM').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () {
                          setState(
                            () => _selectedDate = _selectedDate.add(
                              const Duration(days: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                // Daily summary with charts (compact)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      // Row: Pie chart (with kcal in center) + Macro values
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Pie chart with kcal in center - nhỏ hơn
                          Container(
                            width: 80,
                            height: 80,
                            padding: const EdgeInsets.all(6),
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sections: _buildMacroSections(macros),
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 20,
                                    startDegreeOffset: -90,
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${consumedCal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '/ ${targetCal.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    const Text(
                                      'calo',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Macro values as separate blocks (vertical) - gọn hơn
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMacroBlock(
                                  Icons.bolt,
                                  'CHẤT ĐẠM',
                                  macros['protein']!,
                                  targetProtein,
                                  Colors.redAccent,
                                  Colors.blue,
                                ),
                                const SizedBox(height: 4),
                                _buildMacroBlock(
                                  Icons.ac_unit,
                                  'ĐƯỜNG BỘT',
                                  macros['carbs']!,
                                  targetCarbs,
                                  Colors.lightBlueAccent,
                                  Colors.blue,
                                ),
                                const SizedBox(height: 4),
                                _buildMacroBlock(
                                  Icons.oil_barrel,
                                  'CHẤT BÉO',
                                  macros['fat']!,
                                  targetFat,
                                  Colors.amber,
                                  Colors.amber,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar below chart
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: (consumedCal / targetCal).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.shade700,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${((consumedCal / targetCal) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // Meal sections
                Expanded(
                  child: meals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant_menu,
                                size: 64,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Chưa có thực đơn nào',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Hãy chọn một thực đơn từ tab "Thực đơn tự tạo"',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: meals.length,
                          itemBuilder: (context, index) {
                            final mealName = meals.keys.elementAt(index);
                            final items = meals[mealName]!;
                            final mealCal = items.fold(
                              0.0,
                              (s, i) =>
                                  s + ((i['calories'] ?? 0) as num).toDouble(),
                            );
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          mealName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${mealCal.toStringAsFixed(0)} calo',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...items.map(
                                    (item) => _buildMealPlanFoodItem(
                                      item,
                                      mealPlanId,
                                      dayIndex,
                                    ),
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
  }

  Widget _buildMacroBlock(
    IconData icon,
    String label,
    double current,
    double target,
    Color iconColor,
    Color badgeColor,
  ) {
    final percentage = target > 0
        ? ((current / target) * 100).clamp(0.0, 100.0)
        : 0.0;
    // Màu badge: xanh cho protein/carb, vàng cho fat khi đạt 100%
    final Color finalBadgeColor = iconColor == Colors.amber && percentage >= 100
        ? Colors.amber
        : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3B4F),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          // Badge with percentage
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: finalBadgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${percentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Value
          Text(
            '${current.toStringAsFixed(1)} g',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          // Icon and label
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildMacroSections(Map<String, double> macros) {
    // Tính phần trăm dựa trên calories từ mỗi macro (không phải grams)
    // Protein và Carbs: 4 cal/g, Fat: 9 cal/g
    final proteinCal = macros['protein']! * 4;
    final carbsCal = macros['carbs']! * 4;
    final fatCal = macros['fat']! * 9;
    final totalCal = (proteinCal + carbsCal + fatCal).clamp(
      0.0001,
      double.infinity,
    );

    // Radius nhỏ hơn để đảm bảo không bị cắt khi có padding
    return [
      PieChartSectionData(
        value: proteinCal / totalCal * 100,
        color: Colors.redAccent,
        showTitle: false,
        radius: 30,
      ),
      PieChartSectionData(
        value: carbsCal / totalCal * 100,
        color: Colors.lightBlueAccent,
        showTitle: false,
        radius: 30,
      ),
      PieChartSectionData(
        value: fatCal / totalCal * 100,
        color: Colors.amber,
        showTitle: false,
        radius: 30,
      ),
    ];
  }

  // Build food item từ meal plan với checkbox
  Widget _buildMealPlanFoodItem(
    Map<String, dynamic> item,
    String mealPlanId,
    int dayIndex,
  ) {
    final completed = (item['completed'] ?? false) as bool;
    final calories = ((item['calories'] ?? 0) as num).toDouble();
    final protein = ((item['protein'] ?? 0) as num).toDouble();
    final carbs = ((item['carbs'] ?? 0) as num).toDouble();
    final fat = ((item['fat'] ?? 0) as num).toDouble();
    final name = (item['foodName'] ?? '').toString();
    final entryIndex = item['entryIndex'] as int;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildFoodImage(name, 60, 60),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${calories.toStringAsFixed(0)} cal'),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text('${protein.toStringAsFixed(1)}g'),
                const SizedBox(width: 12),
                const Icon(
                  Icons.grain,
                  size: 14,
                  color: Colors.lightBlueAccent,
                ),
                const SizedBox(width: 4),
                Text('${carbs.toStringAsFixed(1)}g'),
                const SizedBox(width: 12),
                const Icon(Icons.oil_barrel, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${fat.toStringAsFixed(1)}g'),
              ],
            ),
          ],
        ),
        trailing: _AnimatedCheckButton(
          consumed: completed,
          onTap: () => _toggleMealItemCompleted(
            mealPlanId,
            dayIndex,
            entryIndex,
            item,
            !completed,
          ),
        ),
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> item) {
    final consumed = (item['consumed'] ?? false) as bool;
    final calories = ((item['calories'] ?? 0) as num).toDouble();
    final protein = ((item['protein'] ?? 0) as num).toDouble();
    final carbs = ((item['carbs'] ?? 0) as num).toDouble();
    final fat = ((item['fat'] ?? 0) as num).toDouble();
    final name = (item['name'] ?? '').toString();
    final logId = item['id'] as String;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildFoodImage(name, 60, 60),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${calories.toStringAsFixed(0)} cal'),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text('${protein.toStringAsFixed(1)}g'),
                const SizedBox(width: 12),
                const Icon(
                  Icons.grain,
                  size: 14,
                  color: Colors.lightBlueAccent,
                ),
                const SizedBox(width: 4),
                Text('${carbs.toStringAsFixed(1)}g'),
                const SizedBox(width: 12),
                const Icon(Icons.oil_barrel, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${fat.toStringAsFixed(1)}g'),
              ],
            ),
          ],
        ),
        trailing: _AnimatedCheckButton(
          consumed: consumed,
          onTap: () => _toggleConsumed(logId, !consumed),
        ),
      ),
    );
  }

  Widget _buildFoodImage(String name, double w, double h) {
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

class _AnimatedCheckButton extends StatefulWidget {
  final bool consumed;
  final VoidCallback onTap;

  const _AnimatedCheckButton({
    Key? key,
    required this.consumed,
    required this.onTap,
  }) : super(key: key);

  @override
  State<_AnimatedCheckButton> createState() => _AnimatedCheckButtonState();
}

class _AnimatedCheckButtonState extends State<_AnimatedCheckButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _colorAnimation = ColorTween(
      begin: Colors.grey.shade700,
      end: Theme.of(context).colorScheme.primary,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.consumed) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_AnimatedCheckButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.consumed != widget.consumed) {
      if (widget.consumed) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _colorAnimation.value ??
                    (widget.consumed
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade700),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.consumed ? Icons.check : Icons.add,
                  key: ValueKey(widget.consumed),
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
