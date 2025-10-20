import 'package:flutter/material.dart';
import 'package:gym_now/data/default_workouts.dart';
import 'package:gym_now/screens/tracking_screen.dart';

class SelectActivityScreen extends StatelessWidget {
  const SelectActivityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn Chế độ Tập luyện'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: defaultWorkoutTypes.length,
        itemBuilder: (context, index) {
          final activity = defaultWorkoutTypes[index];
          return InkWell(
            onTap: () {
              // **SỬA LỖI 4: ĐIỀU HƯỚNG TRỰC TIẾP, KHÔNG DÙNG DIALOG NỮA**
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TrackingScreen(
                    activityType: activity,
                    // Không cần truyền targetDurationInMinutes ở đây nữa
                  ),
                ),
              );
            },
            child: Card(
              color: const Color(0xFF1B263B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(activity.icon, size: 50, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 15),
                  Text(activity.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}