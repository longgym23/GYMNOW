import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/meal_plan_models.dart';

class MealPlanScreen extends StatefulWidget {
  final String? planId; // Nếu null -> lấy plan mới nhất của user
  const MealPlanScreen({Key? key, this.planId}) : super(key: key);

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  MealPlan? _plan;
  int _selectedDay = 1;
  MealPlanDay? _dayData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fs = FirebaseFirestore.instance;
    setState(() => _loading = true);
    try {
      DocumentSnapshot? planDoc;
      if (widget.planId != null) {
        planDoc = await fs.collection('mealPlans').doc(widget.planId).get();
      } else {
        final q = await fs
            .collection('mealPlans')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) planDoc = q.docs.first;
      }
      if (planDoc == null || !planDoc.exists) {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
        return;
      }
      final plan = MealPlan.fromDoc(planDoc);
      final daySnap = await planDoc.reference
          .collection('days')
          .doc('day_$_selectedDay')
          .get();
      final day = MealPlanDay.fromMap(
        Map<String, dynamic>.from(daySnap.data() ?? {}),
      );
      if (mounted) {
        setState(() {
          _plan = plan;
          _dayData = day;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải plan: $e')));
    }
  }

  Future<void> _toggleEntry(int idx, bool value) async {
    if (_plan == null || _dayData == null) return;
    final planRef = FirebaseFirestore.instance
        .collection('mealPlans')
        .doc(_plan!.id);
    final dayRef = planRef.collection('days').doc('day_$_selectedDay');
    final entries = _dayData!.entries;
    entries[idx].done = value;
    await dayRef.update({'entries': entries.map((e) => e.toMap()).toList()});
    setState(() {});

    if (_dayData!.consumedCalories >= _dayData!.targetCalories) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hoàn thành thực đơn ngày!')),
        );
      }
    }
  }

  List<Widget> _buildDayChips() {
    if (_plan == null) return [];
    return List.generate(_plan!.days, (i) {
      final idx = i + 1;
      final selected = idx == _selectedDay;
      return ChoiceChip(
        label: Text('$idx'),
        selected: selected,
        onSelected: (v) async {
          if (!v) return;
          setState(() {
            _selectedDay = idx;
            _loading = true;
          });
          final daySnap = await FirebaseFirestore.instance
              .collection('mealPlans')
              .doc(_plan!.id)
              .collection('days')
              .doc('day_$idx')
              .get();
          final day = MealPlanDay.fromMap(
            Map<String, dynamic>.from(daySnap.data() ?? {}),
          );
          if (mounted) {
            setState(() {
              _dayData = day;
              _loading = false;
            });
          }
        },
      );
    });
  }

  List<PieChartSectionData> _progressSections() {
    if (_dayData == null) return [];
    final consumed = _dayData!.consumedCalories;
    final total = _dayData!.targetCalories;
    final remain = (total - consumed).clamp(0, total);
    return [
      PieChartSectionData(
        value: consumed.toDouble(),
        color: Colors.purple,
        title: '',
      ),
      PieChartSectionData(
        value: remain.toDouble(),
        color: Colors.grey.shade700,
        title: '',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thực đơn theo ngày')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_plan == null || _dayData == null)
          ? const Center(child: Text('Chưa có thực đơn. Hãy tạo mới.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(label: const Text('Cân bằng')),
                      Chip(label: Text('${_plan!.mealsPerDay} bữa/ngày')),
                      Chip(label: Text('${_plan!.days} ngày')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Thực đơn theo ngày',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: _buildDayChips()),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.pie_chart, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        '${_dayData!.targetCalories.toStringAsFixed(0)} calo',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: _progressSections(),
                          sectionsSpace: 2,
                          centerSpaceRadius: 44,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${_dayData!.consumedCalories.toStringAsFixed(0)} / ${_dayData!.targetCalories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Bữa ăn',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_dayData!.entries.length, (i) {
                    final e = _dayData!.entries[i];
                    return Card(
                      color: const Color(0xFF1B263B),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: Checkbox(
                          value: e.done,
                          onChanged: (v) => _toggleEntry(i, v ?? false),
                        ),
                        title: Text(
                          e.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${e.unit} • ${e.calories.toStringAsFixed(0)} cal',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                            const SizedBox(width: 4),
                            Text('${e.protein.toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.grain,
                              size: 16,
                              color: Colors.lightBlueAccent,
                            ),
                            const SizedBox(width: 4),
                            Text('${e.carbs.toStringAsFixed(1)}g'),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.oil_barrel,
                              size: 16,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text('${e.fat.toStringAsFixed(1)}g'),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
