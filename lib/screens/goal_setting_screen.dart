import 'package:flutter/material.dart';
import 'package:gym_now/models/workout_goal_model.dart';
import 'package:numberpicker/numberpicker.dart';

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({Key? key}) : super(key: key);

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen> {
  int _distanceKm = 5;
  int _timeMinutes = 30;
  int _calories = 200;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mục tiêu'),
          bottom: const TabBar(
            indicatorColor: Colors.orange, // Thêm màu cho thanh chỉ báo
            indicatorWeight: 3.0,
            tabs: [
              Tab(text: 'Khoảng cách'),
              Tab(text: 'Thời gian'),
              Tab(text: 'Calo'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildDistancePicker(),
                  _buildTimePicker(),
                  _buildCaloriesPicker(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                // **THAY ĐỔI Ở ĐÂY: BỌC NÚT BẤM BẰNG BUILDER WIDGET**
                child: Builder(
                  builder: (BuildContext newContext) { // 'newContext' là context hợp lệ
                    return ElevatedButton(
                      child: const Text('GO', style: TextStyle(fontSize: 20)),
                      onPressed: () {
                        // Sử dụng 'newContext' để tìm TabController một cách chính xác
                        final tabIndex = DefaultTabController.of(newContext).index;
                        WorkoutGoal goal;

                        switch (tabIndex) {
                          case 0:
                            goal = WorkoutGoal(type: GoalType.distance, value: _distanceKm * 1000.0);
                            break;
                          case 1:
                            goal = WorkoutGoal(type: GoalType.time, value: _timeMinutes * 60.0);
                            break;
                          case 2:
                            goal = WorkoutGoal(type: GoalType.calories, value: _calories.toDouble());
                            break;
                          default:
                            goal = WorkoutGoal();
                        }
                        // Trả kết quả (goal) về màn hình trước đó
                        Navigator.pop(context, goal);
                      },
                    );
                  }
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistancePicker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            text: '$_distanceKm',
            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
            children: const [
              TextSpan(text: ',00', style: TextStyle(fontSize: 40, color: Colors.grey)),
              TextSpan(text: ' km', style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NumberPicker(
          value: _distanceKm,
          minValue: 1,
          maxValue: 50,
          step: 1,
          itemHeight: 100,
          axis: Axis.horizontal,
          onChanged: (value) => setState(() => _distanceKm = value),
          selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 36, fontWeight: FontWeight.bold),
          textStyle: const TextStyle(color: Colors.grey, fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    final hours = (_timeMinutes / 60).floor().toString().padLeft(2, '0');
    final minutes = (_timeMinutes % 60).toString().padLeft(2, '0');

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$hours:$minutes:00',
          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        NumberPicker(
          value: _timeMinutes,
          minValue: 10,
          maxValue: 180,
          step: 5,
          itemHeight: 100,
          axis: Axis.horizontal,
          onChanged: (value) => setState(() => _timeMinutes = value),
          selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 36, fontWeight: FontWeight.bold),
          textStyle: const TextStyle(color: Colors.grey, fontSize: 24),
        ),
      ],
    );
  }

  Widget _buildCaloriesPicker() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            text: '$_calories',
            style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold),
            children: const [
              TextSpan(text: ' kcal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NumberPicker(
          value: _calories,
          minValue: 50,
          maxValue: 1000,
          step: 50,
          itemHeight: 100,
          axis: Axis.horizontal,
          onChanged: (value) => setState(() => _calories = value),
          selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 36, fontWeight: FontWeight.bold),
          textStyle: const TextStyle(color: Colors.grey, fontSize: 24),
        ),
      ],
    );
  }
}