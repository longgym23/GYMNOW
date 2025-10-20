import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/data/default_workouts.dart'; // Import để lấy icon
import 'package:gym_now/screens/workout_detail_screen.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  /// Hàm tính toán tổng quãng đường cho mỗi loại hoạt động
  Map<String, double> _calculateTotals(List<QueryDocumentSnapshot> sessions) {
    final Map<String, double> totals = {};
    for (var session in sessions) {
      final data = session.data() as Map<String, dynamic>;
      final activityType = data['activityType'] as String;
      // Chuyển đổi an toàn từ num sang double
      final distance = (data['distanceInMeters'] as num).toDouble();
      
      // Cập nhật tổng, nếu chưa có thì tạo mới
      totals.update(activityType, (value) => value + distance, ifAbsent: () => distance);
    }
    return totals;
  }

  /// Hàm tìm icon tương ứng với tên hoạt động
  IconData _getIconForActivity(String activityName) {
    try {
      // Tìm trong danh sách defaultWorkoutTypes
      return defaultWorkoutTypes.firstWhere((type) => type.name == activityName).icon;
    } catch (e) {
      return Icons.fitness_center; // Icon mặc định nếu không tìm thấy
    }
  }

  /// Hàm định dạng thời gian (vd: 25:30)
  String _formatDuration(int totalSeconds) {
    final duration = Duration(seconds: totalSeconds);
    final minutes = duration.inMinutes;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê & Lịch sử'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService(uid: uid).getWorkoutSessionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Đã xảy ra lỗi khi tải dữ liệu.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có lịch sử luyện tập.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
            );
          }

          final sessions = snapshot.data!.docs;
          final totalStats = _calculateTotals(sessions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // **WIDGET MỚI: BẢNG TÓM TẮT TỔNG QUÃNG ĐƯỜNG**
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Tổng kết',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Card(
                color: const Color(0xFF1B263B),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: totalStats.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Icon(_getIconForActivity(entry.key), color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 16),
                            Text(entry.key, style: const TextStyle(fontSize: 16)),
                            const Spacer(),
                            Text(
                              '${(entry.value / 1000).toStringAsFixed(2)} km',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              const Divider(height: 32, indent: 16, endIndent: 16),

              // DANH SÁCH LỊCH SỬ CÁC BUỔI TẬP
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Lịch sử chi tiết',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded( // **QUAN TRỌNG**: Bọc ListView.builder trong Expanded
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final sessionData = sessions[index].data() as Map<String, dynamic>;
                    final startTime = (sessionData['startTime'] as Timestamp).toDate();
                    return Card(
                      color: const Color(0xFF1B263B),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        leading: Icon(_getIconForActivity(sessionData['activityType']), color: Colors.white, size: 40),
                        title: Text(
                          DateFormat('EEEE, dd MMM yyyy', 'vi_VN').format(startTime),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Quãng đường'),
                                  Text(
                                    '${(sessionData['distanceInMeters'] / 1000).toStringAsFixed(2)} km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Thời gian'),
                                  Text(
                                    _formatDuration(sessionData['durationInSeconds']),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          // **THAY ĐỔI Ở ĐÂY**
                          // Điều hướng đến màn hình chi tiết và truyền toàn bộ document của buổi tập qua
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutDetailScreen(session: sessions[index]),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}