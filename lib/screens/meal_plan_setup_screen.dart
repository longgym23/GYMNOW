import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/meal_plan_models.dart';

class MealPlanSetupScreen extends StatefulWidget {
  const MealPlanSetupScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanSetupScreen> createState() => _MealPlanSetupScreenState();
}

class _MealPlanSetupScreenState extends State<MealPlanSetupScreen> {
  double _targetKcal = 2000;
  int _mealsPerDay = 4;
  int _durationDays = 7; // số ngày
  bool _creating = false;

  Future<void> _createPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
      return;
    }

    setState(() => _creating = true);
    try {
      final firestore = FirebaseFirestore.instance;

      // Tạo plan gốc
      final planRef = await firestore.collection('mealPlans').add({
        'userId': user.uid,
        'title': 'Meal Plan hỗ trợ giảm cân',
        'days': _durationDays,
        'mealsPerDay': _mealsPerDay,
        'targetCaloriesPerDay': _targetKcal,
        'createdAt': Timestamp.now(),
      });

      // Lấy một số món ăn từ foods để lấp đầy (đơn giản: random lọc theo calo)
      final foodsSnap = await firestore.collection('foods').limit(200).get();
      final foods = foodsSnap.docs.map((d) => d.data()).toList();
      final rand = Random();

      for (int d = 1; d <= _durationDays; d++) {
        final List<MealEntry> entries = [];
        final perMealTarget = _targetKcal / _mealsPerDay;
        for (int m = 0; m < _mealsPerDay; m++) {
          final pick = foods[rand.nextInt(foods.length)];
          final entry = MealEntry(
            foodId: '',
            name: (pick['name'] ?? '') as String,
            unit: (pick['unit'] ?? '') as String,
            calories: (pick['calories'] ?? 0).toDouble().clamp(
              50,
              perMealTarget,
            ),
            protein: (pick['protein'] ?? 0).toDouble(),
            carbs: (pick['carbs'] ?? 0).toDouble(),
            fat: (pick['fat'] ?? 0).toDouble(),
          );
          entries.add(entry);
        }

        final day = MealPlanDay(
          dayIndex: d,
          targetCalories: _targetKcal,
          entries: entries,
        );
        await planRef.collection('days').doc('day_$d').set(day.toMap());
      }

      if (!mounted) return;
      Navigator.of(context).pop(planRef.id);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tạo kế hoạch: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo thực đơn giảm cân')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mục tiêu calo/ngày',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Slider(
              value: _targetKcal,
              min: 1200,
              max: 3000,
              divisions: 18,
              label: _targetKcal.toStringAsFixed(0),
              onChanged: (v) => setState(() => _targetKcal = v.roundToDouble()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _mealsPerDay,
                    decoration: const InputDecoration(labelText: 'Bữa/ngày'),
                    items: const [3, 4, 5, 6]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text('$e')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _mealsPerDay = v ?? 4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _durationDays,
                    decoration: const InputDecoration(labelText: 'Số ngày'),
                    items: const [3, 5, 7, 10, 14]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text('$e')),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _durationDays = v ?? 7),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creating ? null : _createPlan,
                icon: _creating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Tạo thực đơn giảm cân'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
