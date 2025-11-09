import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/user_model.dart';
import 'package:gym_now/screens/edit_user_screen.dart';
import 'package:gym_now/screens/workout_detail_screen.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:intl/intl.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final UserModel user;

  const AdminUserDetailScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen>
    with SingleTickerProviderStateMixin {
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
      appBar: AppBar(
        title: Text(widget.user.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditUserScreen(user: widget.user),
                ),
              ).then((_) {
                // Refresh lại dữ liệu nếu cần
                setState(() {});
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Xóa user',
            onPressed: () => _showDeleteUserDialog(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Thông tin', icon: Icon(Icons.person)),
            Tab(text: 'Tập luyện', icon: Icon(Icons.fitness_center)),
            Tab(text: 'Thực đơn', icon: Icon(Icons.restaurant_menu)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Header với thông tin cơ bản
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white,
                  child: Text(
                    widget.user.name.isNotEmpty
                        ? widget.user.name.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.user.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.user.email,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildInfoCard(
                      'Chiều cao',
                      '${widget.user.height.toStringAsFixed(1)} cm',
                      Icons.height,
                    ),
                    _buildInfoCard(
                      'Cân nặng',
                      '${widget.user.weight.toStringAsFixed(1)} kg',
                      Icons.monitor_weight,
                    ),
                    _buildInfoCard(
                      'Tuổi',
                      '${widget.user.age} tuổi',
                      Icons.cake,
                    ),
                    _buildInfoCard(
                      'Vai trò',
                      widget.user.role,
                      Icons.admin_panel_settings,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildWorkoutsTab(),
                _buildMealPlansTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildInfoTab() {
    // Tính BMI
    final bmi =
        widget.user.weight /
        ((widget.user.height / 100) * (widget.user.height / 100));
    String bmiCategory;
    Color bmiColor;
    if (bmi < 18.5) {
      bmiCategory = 'Thiếu cân';
      bmiColor = Colors.blue;
    } else if (bmi < 25) {
      bmiCategory = 'Bình thường';
      bmiColor = Colors.green;
    } else if (bmi < 30) {
      bmiCategory = 'Thừa cân';
      bmiColor = Colors.orange;
    } else {
      bmiCategory = 'Béo phì';
      bmiColor = Colors.red;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF1B263B),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thông tin chi tiết',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Email', widget.user.email, Icons.email),
                const Divider(),
                _buildInfoRow(
                  'Chiều cao',
                  '${widget.user.height.toStringAsFixed(1)} cm',
                  Icons.height,
                ),
                const Divider(),
                _buildInfoRow(
                  'Cân nặng',
                  '${widget.user.weight.toStringAsFixed(1)} kg',
                  Icons.monitor_weight,
                ),
                const Divider(),
                _buildInfoRow('Tuổi', '${widget.user.age} tuổi', Icons.cake),
                const Divider(),
                _buildInfoRow(
                  'Vai trò',
                  widget.user.role,
                  Icons.admin_panel_settings,
                ),
                const Divider(),
                _buildInfoRow(
                  'BMI',
                  '${bmi.toStringAsFixed(1)} ($bmiCategory)',
                  Icons.analytics,
                  valueColor: bmiColor,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseService().getWorkoutSessionsStreamForUser(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có lịch sử tập luyện',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final workouts = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: workouts.length,
          itemBuilder: (context, index) {
            final doc = workouts[index];
            final data = doc.data() as Map<String, dynamic>;
            final startTime = (data['startTime'] as Timestamp).toDate();
            final duration = data['durationInSeconds'] as int;
            final distance = data['distanceInMeters'] as double;
            final calories = data['caloriesBurned'] as int;
            final activityType = data['activityType'] as String;

            return Card(
              color: const Color(0xFF1B263B),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  activityType,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(startTime),
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(duration / 60).toStringAsFixed(0)} phút',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.straighten,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(distance / 1000).toStringAsFixed(2)} km',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$calories kcal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  WorkoutDetailScreen(session: doc),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.map,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () =>
                            _showDeleteWorkoutDialog(doc.id, activityType),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                isThreeLine: true,
                onTap: () {
                  // Xem chi tiết với map khi tap vào card
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkoutDetailScreen(session: doc),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMealPlansTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: DatabaseService().getMealPlansStreamForUser(widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[600]),
                const SizedBox(height: 16),
                Text(
                  'Chưa có thực đơn nào',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final mealPlans = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: mealPlans.length,
          itemBuilder: (context, index) {
            final doc = mealPlans[index];
            final data = doc.data() as Map<String, dynamic>;
            final templateName =
                data['templateName'] as String? ?? 'Thực đơn tùy chỉnh';
            final startDate = (data['startDate'] as Timestamp).toDate();
            final endDate = (data['endDate'] as Timestamp).toDate();
            final duration = data['duration'] as int? ?? 0;
            final isActive = data['isActive'] as bool? ?? false;
            final targetCalories =
                (data['targetCalories'] as num?)?.toDouble() ?? 0.0;
            final isCustomized = data['isCustomized'] as bool? ?? false;

            return Card(
              color: const Color(0xFF1B263B),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                title: Text(
                  templateName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isActive ? 'Đang hoạt động' : 'Đã kết thúc',
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? Colors.green : Colors.grey[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (isCustomized) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Tùy chỉnh',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$duration ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${targetCalories.toStringAsFixed(0)} kcal/ngày',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  tooltip: 'Xóa',
                  color: Colors.red,
                  onPressed: () =>
                      _showDeleteMealPlanDialog(doc.id, templateName),
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  // Helper function để hiển thị thông báo iOS style
  void _showIOSNotification(String message, {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isError ? 'Lỗi' : 'Thành công'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // Dialog xác nhận xóa user
  void _showDeleteUserDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa User'),
        content: Text(
          'Bạn có chắc chắn muốn xóa user "${widget.user.name}"?\n\nHành động này sẽ xóa tất cả dữ liệu liên quan (workouts, meal plans, food logs) và không thể hoàn tác.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Xóa'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await DatabaseService().deleteUserForAdmin(widget.user.id);
                if (mounted) {
                  _showIOSNotification('Đã xóa user thành công');
                  Navigator.of(context).pop(); // Quay lại admin panel
                }
              } catch (e) {
                if (mounted) {
                  _showIOSNotification('Lỗi khi xóa user: $e', isError: true);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Dialog xác nhận xóa workout
  void _showDeleteWorkoutDialog(String sessionId, String activityType) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa Buổi Tập'),
        content: Text(
          'Bạn có chắc chắn muốn xóa buổi tập "$activityType"?\n\nHành động này không thể hoàn tác.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Xóa'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await DatabaseService().deleteWorkoutSessionForUser(
                  widget.user.id,
                  sessionId,
                );
                if (mounted) {
                  _showIOSNotification('Đã xóa buổi tập thành công');
                }
              } catch (e) {
                if (mounted) {
                  _showIOSNotification(
                    'Lỗi khi xóa buổi tập: $e',
                    isError: true,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // Dialog xác nhận xóa meal plan
  void _showDeleteMealPlanDialog(String mealPlanId, String templateName) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Xóa Thực Đơn'),
        content: Text(
          'Bạn có chắc chắn muốn xóa thực đơn "$templateName"?\n\nHành động này sẽ xóa tất cả dữ liệu liên quan và không thể hoàn tác.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Hủy'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Xóa'),
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await DatabaseService().deleteMealPlanForUser(
                  widget.user.id,
                  mealPlanId,
                );
                if (mounted) {
                  _showIOSNotification('Đã xóa thực đơn thành công');
                }
              } catch (e) {
                if (mounted) {
                  _showIOSNotification(
                    'Lỗi khi xóa thực đơn: $e',
                    isError: true,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
