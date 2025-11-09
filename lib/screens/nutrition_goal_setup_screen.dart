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
      appBar: AppBar(
        title: const Text('Thiết lập mục tiêu dinh dưỡng'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Container(
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Height Card
                _buildSliderCard(
                  icon: Icons.height,
                  title: 'Chiều cao',
                  subtitle: 'cm',
                  value: _height,
                  min: 100,
                  max: 220,
                  divisions: 120,
                  displayValue: '${_height.toStringAsFixed(0)} cm',
                  onChanged: (v) => setState(() => _height = v.roundToDouble()),
                ),

                const SizedBox(height: 20),
                // Weight Card
                _buildSliderCard(
                  icon: Icons.monitor_weight,
                  title: 'Cân nặng',
                  subtitle: 'kg',
                  value: _weight,
                  min: 30,
                  max: 200,
                  divisions: 170,
                  displayValue: '${_weight.toStringAsFixed(0)} kg',
                  onChanged: (v) => setState(() {
                    _weight = v.roundToDouble();
                    _targetWeight = _weight;
                  }),
                ),

                const SizedBox(height: 20),
                // Age Card
                _buildSliderCard(
                  icon: Icons.cake,
                  title: 'Tuổi',
                  subtitle: 'tuổi',
                  value: _age.toDouble(),
                  min: 10,
                  max: 100,
                  divisions: 90,
                  displayValue: '$_age tuổi',
                  onChanged: (v) => setState(() => _age = v.round()),
                ),

                const SizedBox(height: 20),
                // Gender Card
                _buildGenderCard(),

                const SizedBox(height: 20),
                // Activity Level Card
                _buildDropdownCard(
                  icon: Icons.fitness_center,
                  title: 'Mức độ hoạt động',
                  child: DropdownButtonFormField<double>(
                    value: _activityMultiplier,
                    decoration: InputDecoration(
                      labelText: 'Hoạt động',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1B263B),
                    ),
                    dropdownColor: const Color(0xFF1B263B),
                    style: const TextStyle(color: Colors.white),
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
                ),

                const SizedBox(height: 20),
                // Goal Type Card
                _buildDropdownCard(
                  icon: Icons.flag,
                  title: 'Mục tiêu',
                  child: DropdownButtonFormField<GoalType>(
                    value: _goalType,
                    decoration: InputDecoration(
                      labelText: 'Mục tiêu',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1B263B),
                    ),
                    dropdownColor: const Color(0xFF1B263B),
                    style: const TextStyle(color: Colors.white),
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
                ),

                // Target Weight Card
                if (_goalType != GoalType.maintain) ...[
                  const SizedBox(height: 20),
                  _buildSliderCard(
                    icon: Icons.track_changes,
                    title: 'Cân nặng mục tiêu',
                    subtitle: 'kg',
                    value: _targetWeight,
                    min: _goalType == GoalType.loseWeight ? 30 : _weight,
                    max: _goalType == GoalType.loseWeight ? _weight : 200,
                    divisions:
                        ((_goalType == GoalType.loseWeight
                                    ? _weight - 30
                                    : 200 - _weight)
                                .abs())
                            .round(),
                    displayValue: '${_targetWeight.toStringAsFixed(0)} kg',
                    onChanged: (v) =>
                        setState(() => _targetWeight = v.roundToDouble()),
                  ),
                ],

                const SizedBox(height: 24),
                // Recommendations Preview Card
                _buildRecommendationsCard(recs),

                const SizedBox(height: 24),
                // Save Button
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      displayValue,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Theme.of(context).colorScheme.primary,
              inactiveTrackColor: Colors.grey[800],
              thumbColor: Theme.of(context).colorScheme.primary,
              overlayColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: displayValue,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'Giới tính',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildGenderOption(
                  label: 'Nam',
                  icon: Icons.male,
                  value: 'male',
                  isSelected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderOption(
                  label: 'Nữ',
                  icon: Icons.female,
                  value: 'female',
                  isSelected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required String value,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[400],
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(Map<String, double> recs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Khuyến nghị dinh dưỡng',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildNutritionItem(
            'Calories',
            '${recs['calories']!.toStringAsFixed(0)} kcal',
            Colors.orange,
            Icons.local_fire_department,
          ),
          const SizedBox(height: 12),
          _buildNutritionItem(
            'Protein',
            '${recs['protein']!.toStringAsFixed(1)} g',
            Colors.purple,
            Icons.fitness_center,
          ),
          const SizedBox(height: 12),
          _buildNutritionItem(
            'Carbs',
            '${recs['carbs']!.toStringAsFixed(1)} g',
            Colors.blue,
            Icons.energy_savings_leaf,
          ),
          const SizedBox(height: 12),
          _buildNutritionItem(
            'Fat',
            '${recs['fat']!.toStringAsFixed(1)} g',
            Colors.amber,
            Icons.water_drop,
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _saveGoal,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_saving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  'Lưu mục tiêu',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
