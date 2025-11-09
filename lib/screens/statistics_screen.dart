import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/data/default_workouts.dart'; // Import để lấy icon
import 'package:gym_now/screens/workout_detail_screen.dart';
import 'package:gym_now/screens/chat_screen.dart';
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
      totals.update(
        activityType,
        (value) => value + distance,
        ifAbsent: () => distance,
      );
    }
    return totals;
  }

  /// Hàm tìm icon tương ứng với tên hoạt động
  IconData _getIconForActivity(String activityName) {
    try {
      // Tìm trong danh sách defaultWorkoutTypes
      return defaultWorkoutTypes
          .firstWhere((type) => type.name == activityName)
          .icon;
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

  /// Lấy màu gradient cho từng loại hoạt động
  List<Color> _getActivityColors(String activityType) {
    switch (activityType) {
      case 'Chạy bộ':
        return [Colors.red.shade400, Colors.orange.shade600];
      case 'Đạp xe':
        return [Colors.blue.shade400, Colors.cyan.shade600];
      case 'Bơi lội':
        return [Colors.cyan.shade400, Colors.blue.shade600];
      case 'Đi bộ':
        return [Colors.green.shade400, Colors.teal.shade600];
      case 'Leo núi':
        return [Colors.brown.shade400, Colors.orange.shade600];
      default:
        return [Colors.purple.shade400, Colors.pink.shade600];
    }
  }

  /// Widget hiển thị stat item - COMPACT
  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hiển thị thông báo iOS style
  void _showIOSNotification(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(isError ? 'Lỗi' : 'Thành công'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê & Lịch sử')),
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
              // **PHẦN TỔNG KẾT - COMPACT DESIGN**
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade400,
                            Colors.purple.shade600,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tổng kết',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Grid layout cho summary cards - COMPACT
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: totalStats.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B263B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade700.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Chưa có dữ liệu',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: totalStats.entries.map((entry) {
                          final colors = _getActivityColors(entry.key);
                          return Container(
                            width: (MediaQuery.of(context).size.width - 40) / 2,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colors[0].withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getIconForActivity(entry.key),
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  entry.key,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(entry.value / 1000).toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),

              const SizedBox(height: 16),

              // DANH SÁCH LỊCH SỬ CÁC BUỔI TẬP - COMPACT DESIGN
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade400, Colors.red.shade600],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.history,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Lịch sử chi tiết',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // **QUAN TRỌNG**: Bọc ListView.builder trong Expanded
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final sessionData =
                        sessions[index].data() as Map<String, dynamic>;
                    final startTime = (sessionData['startTime'] as Timestamp)
                        .toDate();
                    final activityType = sessionData['activityType'] as String;
                    final colors = _getActivityColors(activityType);
                    final distanceKm = (sessionData['distanceInMeters'] / 1000);
                    final duration = sessionData['durationInSeconds'] as int;
                    final calories = sessionData['caloriesBurned'] as int? ?? 0;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1B263B),
                            const Color(0xFF2A3B4F),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors[0].withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkoutDetailScreen(
                                  session: sessions[index],
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Icon với gradient background - COMPACT
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: colors),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors[0].withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _getIconForActivity(activityType),
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Thông tin chi tiết - COMPACT
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Ngày tháng - COMPACT
                                      Text(
                                        DateFormat(
                                          'EEEE, dd MMM yyyy',
                                          'vi_VN',
                                        ).format(startTime),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      // Thông tin stats - COMPACT
                                      Row(
                                        children: [
                                          // Quãng đường
                                          Expanded(
                                            child: _buildStatItem(
                                              Icons.straighten,
                                              'Quãng đường',
                                              '${distanceKm.toStringAsFixed(2)} km',
                                              Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // Thời gian
                                          Expanded(
                                            child: _buildStatItem(
                                              Icons.timer,
                                              'Thời gian',
                                              _formatDuration(duration),
                                              Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (calories > 0) ...[
                                        const SizedBox(height: 6),
                                        _buildStatItem(
                                          Icons.local_fire_department,
                                          'Calo',
                                          '$calories cal',
                                          Colors.orange,
                                          isFullWidth: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Nút xóa - COMPACT
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () async {
                                        // Hiển thị dialog xác nhận xóa (iOS style)
                                        final confirm =
                                            await showCupertinoDialog<bool>(
                                              context: context,
                                              builder: (BuildContext context) =>
                                                  CupertinoAlertDialog(
                                                    title: const Text(
                                                      'Xác nhận xóa',
                                                    ),
                                                    content: const Text(
                                                      'Bạn có chắc chắn muốn xóa buổi tập luyện này không?',
                                                    ),
                                                    actions: [
                                                      CupertinoDialogAction(
                                                        child: const Text(
                                                          'Hủy',
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(false),
                                                      ),
                                                      CupertinoDialogAction(
                                                        isDestructiveAction:
                                                            true,
                                                        child: const Text(
                                                          'Xóa',
                                                        ),
                                                        onPressed: () =>
                                                            Navigator.of(
                                                              context,
                                                            ).pop(true),
                                                      ),
                                                    ],
                                                  ),
                                            );

                                        if (confirm == true && mounted) {
                                          try {
                                            final sessionId =
                                                sessions[index].id;
                                            await DatabaseService(
                                              uid: uid,
                                            ).deleteWorkoutSession(sessionId);
                                            if (mounted) {
                                              _showIOSNotification(
                                                context,
                                                'Đã xóa buổi tập luyện thành công',
                                                isError: false,
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              _showIOSNotification(
                                                context,
                                                'Lỗi khi xóa: $e',
                                                isError: true,
                                              );
                                            }
                                          }
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 8,
        shape: const CircleBorder(), // Bo góc tròn hoàn toàn
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle, // Đảm bảo tròn hoàn toàn
            gradient: LinearGradient(
              colors: [Colors.orange.shade300, Colors.orange.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/chatbot.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback icon nếu không tìm thấy ảnh
              return const Icon(Icons.smart_toy, color: Colors.white, size: 32);
            },
          ),
        ),
      ),
    );
  }
}
