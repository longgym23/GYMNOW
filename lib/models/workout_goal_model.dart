// lib/models/workout_goal_model.dart
enum GoalType { none, distance, time, calories }

class WorkoutGoal {
  final GoalType type;
  final double value; // distance in meters, time in seconds, calories in kcal

  WorkoutGoal({this.type = GoalType.none, this.value = 0});
}