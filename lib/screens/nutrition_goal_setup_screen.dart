import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/nutrition_goal_model.dart';

class NutritionGoalSetupScreen extends StatefulWidget {
  const NutritionGoalSetupScreen({Key? key}) : super(key: key);

  @override
  State<NutritionGoalSetupScreen> createState() =>
      _NutritionGoalSetupScreenState();
}

class _NutritionGoalSetupScreenState extends State<NutritionGoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  double _height = 170.0; // cm
  double _weight = 70.0; // kg
  int _age = 25;
  String _gender = 'male';
  GoalType _goalType = GoalType.maintain;
  double _targetWeight = 70.0;
  double _activityMultiplier =
      1.375; // Sedentary = 1.2, Light = 1.375, Moderate = 1.55, Active = 1.725, Very Active = 1.9
  bool _saving = false;

  Map<String, double> _calculateRecommendations() {
    final tdee = NutritionGoal.calculateTDEE(
      _weight,
      _height,
      _age,
      _gender,
      _activityMultiplier,
    );
    return NutritionGoal.calculateMacros(tdee, _goalType, _weight);
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bạn cần đăng nhập.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final recs = _calculateRecommendations();

      // Deactivate old goals
      final oldGoals = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('nutritionGoals')
          .where('isActive', isEqualTo: true)
          .get();

      for (final doc in oldGoals.docs) {
        await doc.reference.update({'isActive': false});
      }

      // Create new goal
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('nutritionGoals')
          .add({
            'userId': user.uid,
            'height': _height,
            'weight': _weight,
            'age': _age,
            'gender': _gender,
            'goalType': _goalType.toString().split('.').last,
            'targetWeight': _targetWeight,
            'targetCalories': recs['calories']!,
            'targetProtein': recs['protein']!,
            'targetCarbs': recs['carbs']!,
            'targetFat': recs['fat']!,
            'createdAt': Timestamp.now(),
            'isActive': true,
          });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi lưu mục tiêu: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recs = _calculateRecommendations();
    return Scaffold(
      appBar: AppBar(title: const Text('Thiết lập mục tiêu dinh dưỡng')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Height
              Text(
                'Chiều cao (cm)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _height,
                min: 100,
                max: 220,
                divisions: 120,
                label: _height.toStringAsFixed(0),
                onChanged: (v) => setState(() => _height = v.roundToDouble()),
              ),
              Text(
                '${_height.toStringAsFixed(0)} cm',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),
              // Weight
              Text(
                'Cân nặng (kg)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _weight,
                min: 30,
                max: 200,
                divisions: 170,
                label: _weight.toStringAsFixed(0),
                onChanged: (v) => setState(() {
                  _weight = v.roundToDouble();
                  _targetWeight = _weight;
                }),
              ),
              Text(
                '${_weight.toStringAsFixed(0)} kg',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),
              // Age
              Text('Tuổi', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _age.toDouble(),
                min: 10,
                max: 100,
                divisions: 90,
                label: _age.toString(),
                onChanged: (v) => setState(() => _age = v.round()),
              ),
              Text(
                '$_age tuổi',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),
              // Gender
              Text(
                'Giới tính',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Nam'),
                      value: 'male',
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Nữ'),
                      value: 'female',
                      groupValue: _gender,
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              // Activity Level
              Text(
                'Mức độ hoạt động',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<double>(
                value: _activityMultiplier,
                decoration: const InputDecoration(labelText: 'Hoạt động'),
                items: const [
                  DropdownMenuItem(value: 1.2, child: Text('Ít vận động')),
                  DropdownMenuItem(
                    value: 1.375,
                    child: Text('Nhẹ nhàng (1-3 lần/tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 1.55,
                    child: Text('Vừa phải (3-5 lần/tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 1.725,
                    child: Text('Năng động (6-7 lần/tuần)'),
                  ),
                  DropdownMenuItem(
                    value: 1.9,
                    child: Text('Rất năng động (2 lần/ngày)'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _activityMultiplier = v ?? 1.375),
              ),

              const SizedBox(height: 24),
              // Goal Type
              Text(
                'Mục tiêu',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButtonFormField<GoalType>(
                value: _goalType,
                decoration: const InputDecoration(labelText: 'Mục tiêu'),
                items: const [
                  DropdownMenuItem(
                    value: GoalType.loseWeight,
                    child: Text('Giảm cân giảm mỡ'),
                  ),
                  DropdownMenuItem(
                    value: GoalType.gainWeight,
                    child: Text('Tăng cân'),
                  ),
                  DropdownMenuItem(
                    value: GoalType.gainMuscle,
                    child: Text('Tăng cơ'),
                  ),
                  DropdownMenuItem(
                    value: GoalType.maintain,
                    child: Text('Duy trì'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _goalType = v ?? GoalType.maintain),
              ),

              const SizedBox(height: 24),
              // Target Weight
              if (_goalType != GoalType.maintain) ...[
                Text(
                  'Cân nặng mục tiêu (kg)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: _targetWeight,
                  min: _goalType == GoalType.loseWeight ? 30 : _weight,
                  max: _goalType == GoalType.loseWeight ? _weight : 200,
                  divisions:
                      ((_goalType == GoalType.loseWeight
                                  ? _weight - 30
                                  : 200 - _weight)
                              .abs())
                          .round(),
                  label: _targetWeight.toStringAsFixed(0),
                  onChanged: (v) =>
                      setState(() => _targetWeight = v.roundToDouble()),
                ),
                Text(
                  '${_targetWeight.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              // Recommendations Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B263B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khuyến nghị dinh dưỡng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _recRow(
                      'Calories',
                      '${recs['calories']!.toStringAsFixed(0)} kcal',
                    ),
                    _recRow(
                      'Protein',
                      '${recs['protein']!.toStringAsFixed(1)} g',
                    ),
                    _recRow('Carbs', '${recs['carbs']!.toStringAsFixed(1)} g'),
                    _recRow('Fat', '${recs['fat']!.toStringAsFixed(1)} g'),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveGoal,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Lưu mục tiêu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
