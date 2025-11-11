import 'package:flutter/material.dart';
import 'package:gym_now/models/workout_goal_model.dart';
import 'package:numberpicker/numberpicker.dart';

class GoalSettingScreen extends StatefulWidget {
  const GoalSettingScreen({Key? key}) : super(key: key);

  @override
  State<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends State<GoalSettingScreen>
    with SingleTickerProviderStateMixin {
  int _distanceKm = 5;
  int _timeMinutes = 30;
  int _calories = 200;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: Column(
          children: [
            // Custom AppBar với gradient
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 10,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    Theme.of(context).scaffoldBackgroundColor,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'Thiết lập mục tiêu',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Cân bằng với IconButton
                    ],
                  ),
                  const SizedBox(height: 10),
                  // TabBar với style đẹp hơn
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B263B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      dividerColor:
                          Colors.transparent, // Loại bỏ gạch chân trắng
                      dividerHeight: 0, // Đảm bảo không có divider
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.route, size: 20),
                          text: 'Khoảng cách',
                        ),
                        Tab(
                          icon: Icon(Icons.timer, size: 20),
                          text: 'Thời gian',
                        ),
                        Tab(
                          icon: Icon(Icons.local_fire_department, size: 20),
                          text: 'Calo',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDistancePicker(),
                  _buildTimePicker(),
                  _buildCaloriesPicker(),
                ],
              ),
            ),
            // Nút GO với style đẹp hơn
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Builder(
                builder: (BuildContext newContext) {
                  return Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        final tabIndex = _tabController.index;
                        WorkoutGoal goal;

                        switch (tabIndex) {
                          case 0:
                            goal = WorkoutGoal(
                              type: GoalType.distance,
                              value: _distanceKm * 1000.0,
                            );
                            break;
                          case 1:
                            goal = WorkoutGoal(
                              type: GoalType.time,
                              value: _timeMinutes * 60.0,
                            );
                            break;
                          case 2:
                            goal = WorkoutGoal(
                              type: GoalType.calories,
                              value: _calories.toDouble(),
                            );
                            break;
                          default:
                            goal = WorkoutGoal();
                        }
                        Navigator.pop(context, goal);
                      },
                      child: const Text(
                        'BẮT ĐẦU',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistancePicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon và mô tả
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.route,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 30),
          // Hiển thị giá trị lớn
          Text.rich(
            TextSpan(
              text: '$_distanceKm',
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              children: [
                TextSpan(
                  text: ',00',
                  style: TextStyle(
                    fontSize: 40,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                TextSpan(
                  text: ' km',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Khoảng cách mục tiêu',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          // NumberPicker với style đẹp hơn
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NumberPicker(
              value: _distanceKm,
              minValue: 1,
              maxValue: 50,
              step: 1,
              itemHeight: 80,
              axis: Axis.horizontal,
              onChanged: (value) => setState(() => _distanceKm = value),
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    final hours = (_timeMinutes / 60).floor().toString().padLeft(2, '0');
    final minutes = (_timeMinutes % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon và mô tả
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.timer,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 30),
          // Hiển thị thời gian lớn
          Text(
            '$hours:$minutes:00',
            style: TextStyle(
              fontSize: 80,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Thời gian mục tiêu',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          // NumberPicker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NumberPicker(
              value: _timeMinutes,
              minValue: 10,
              maxValue: 180,
              step: 5,
              itemHeight: 80,
              axis: Axis.horizontal,
              onChanged: (value) => setState(() => _timeMinutes = value),
              selectedTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesPicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon và mô tả
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.3),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
            ),
            child: const Icon(
              Icons.local_fire_department,
              size: 60,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 30),
          // Hiển thị calo lớn
          Text.rich(
            TextSpan(
              text: '$_calories',
              style: TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              children: [
                TextSpan(
                  text: ' kcal',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Calo mục tiêu',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 40),
          // NumberPicker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: NumberPicker(
              value: _calories,
              minValue: 50,
              maxValue: 1000,
              step: 50,
              itemHeight: 80,
              axis: Axis.horizontal,
              onChanged: (value) => setState(() => _calories = value),
              selectedTextStyle: const TextStyle(
                color: Colors.orange,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
