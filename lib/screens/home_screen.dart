import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/screens/chat_screen.dart'; // **<-- THÊM IMPORT NÀY**
import 'package:gym_now/screens/select_activity_screen.dart';
import 'package:gym_now/screens/welcome_screen.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Bỏ import tracking_screen không cần thiết ở đây

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _auth = AuthService();
  final user = FirebaseAuth.instance.currentUser;
  late Stream<StepCount> _stepCountStream;
  bool _pedometerAvailable = true;
  int _stepsAtStartOfDay = 0;
  DateTime? _lastResetDate;

  @override
  void initState() {
    super.initState();
    initPedometer();
    _loadStepsAtStartOfDay();
  }

  /// Lưu số bước chân vào đầu ngày
  Future<void> _saveStepsAtStartOfDay(int steps, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('steps_at_start_of_day', steps);
    await prefs.setString('last_reset_date', date.toIso8601String());
  }

  /// Lấy số bước chân vào đầu ngày
  Future<void> _loadStepsAtStartOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastResetDateStr = prefs.getString('last_reset_date');
    if (lastResetDateStr != null) {
      final lastResetDate = DateTime.parse(lastResetDateStr);
      final lastResetDay = DateTime(
        lastResetDate.year,
        lastResetDate.month,
        lastResetDate.day,
      );

      // Nếu đã qua ngày mới, reset số bước
      if (lastResetDay.isBefore(today)) {
        // Lấy số bước hiện tại và lưu làm số bước đầu ngày
        try {
          final stepCount = await Pedometer.stepCountStream.first;
          _stepsAtStartOfDay = stepCount.steps;
          _lastResetDate = today;
          await _saveStepsAtStartOfDay(_stepsAtStartOfDay, today);
        } catch (e) {
          print('Lỗi lấy số bước đầu ngày: $e');
          _stepsAtStartOfDay = 0;
          _lastResetDate = today;
          await _saveStepsAtStartOfDay(0, today);
        }
      } else {
        // Vẫn trong cùng ngày, lấy số bước đã lưu
        _stepsAtStartOfDay = prefs.getInt('steps_at_start_of_day') ?? 0;
        _lastResetDate = lastResetDay;
      }
    } else {
      // Lần đầu tiên, lấy số bước hiện tại
      try {
        final stepCount = await Pedometer.stepCountStream.first;
        _stepsAtStartOfDay = stepCount.steps;
        _lastResetDate = today;
        await _saveStepsAtStartOfDay(_stepsAtStartOfDay, today);
      } catch (e) {
        print('Lỗi lấy số bước đầu ngày: $e');
        _stepsAtStartOfDay = 0;
        _lastResetDate = today;
        await _saveStepsAtStartOfDay(0, today);
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  /// Tính số bước chân trong ngày từ Pedometer
  int _calculateTodayStepsFromPedometer(int currentSteps) {
    // Kiểm tra xem đã qua ngày mới chưa
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastResetDate == null || _lastResetDate!.isBefore(today)) {
      // Đã qua ngày mới, reset
      _stepsAtStartOfDay = currentSteps;
      _lastResetDate = today;
      _saveStepsAtStartOfDay(_stepsAtStartOfDay, today);
      return 0;
    }

    // Số bước trong ngày = số bước hiện tại - số bước đầu ngày
    final todaySteps = currentSteps - _stepsAtStartOfDay;
    return todaySteps > 0 ? todaySteps : 0;
  }

  void initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream
        .listen((event) {
          if (mounted) {
            setState(() {
              _pedometerAvailable = true;
            });
          }
        })
        .onError((error) {
          print('Pedometer Error: $error');
          if (mounted) {
            setState(() {
              _pedometerAvailable = false;
            });
          }
        });
  }

  /// Stream để lấy workout sessions trong ngày
  Stream<QuerySnapshot> _getTodayWorkoutSessionsStream() {
    if (user == null) return const Stream.empty();

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // Lấy tất cả sessions từ đầu ngày đến giờ, sau đó filter trong code
    return FirebaseFirestore.instance
        .collection('workouts')
        .doc(user!.uid)
        .collection('sessions')
        .where(
          'startTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .orderBy('startTime', descending: true)
        .snapshots();
  }

  /// Tính số bước chân từ quãng đường GPS
  /// Công thức: 1 bước chân trung bình = 0.7 mét (có thể điều chỉnh theo chiều cao)
  int _calculateStepsFromGPS(
    List<QueryDocumentSnapshot> sessions,
    double userHeight,
  ) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    double totalDistanceMeters = 0.0;
    for (var doc in sessions) {
      final data = doc.data() as Map<String, dynamic>;
      final startTime = (data['startTime'] as Timestamp?)?.toDate();

      // Filter chỉ lấy sessions trong ngày hôm nay
      if (startTime != null) {
        final isToday =
            startTime.isAtSameMomentAs(startOfDay) ||
            (startTime.isAfter(startOfDay) && startTime.isBefore(endOfDay));
        if (isToday) {
          final distance =
              (data['distanceInMeters'] as num?)?.toDouble() ?? 0.0;
          totalDistanceMeters += distance;
        }
      }
    }

    // Tính stride length (chiều dài bước chân) dựa trên chiều cao
    // Công thức: stride length (m) = height (cm) * 0.415 / 100
    // Hoặc dùng giá trị trung bình 0.7m nếu không có chiều cao
    double strideLengthMeters = 0.7; // Mặc định
    if (userHeight > 0) {
      strideLengthMeters = (userHeight * 0.415) / 100;
    }

    // Tính số bước chân: quãng đường / chiều dài bước chân
    final stepsFromGPS = (totalDistanceMeters / strideLengthMeters).round();
    return stepsFromGPS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang chủ'),
        automaticallyImplyLeading: false, // Ẩn nút back
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await _auth.signOut();
              // Đảm bảo quay về màn hình welcome sau khi đăng xuất
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: DatabaseService(uid: user!.uid).getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Lỗi tải dữ liệu người dùng.'));
          }
          if (snapshot.hasData && snapshot.data!.exists) {
            String userName =
                (snapshot.data!.data() as Map<String, dynamic>)['name'] ??
                'Bạn';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chào buổi sáng,',
                    style: TextStyle(fontSize: 28, color: Colors.grey[400]),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Card đếm bước chân với circular progress
                  Card(
                    color: const Color(0xFF1B263B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: StreamBuilder<StepCount>(
                        stream: _stepCountStream,
                        builder: (context, pedometerSnapshot) {
                          return FutureBuilder<DocumentSnapshot>(
                            future: DatabaseService(
                              uid: user!.uid,
                            ).getUserData(),
                            builder: (context, userSnapshot) {
                              // Lấy chiều cao user
                              double userHeight = 0.0;
                              if (userSnapshot.hasData &&
                                  userSnapshot.data!.exists) {
                                final userData =
                                    userSnapshot.data!.data()
                                        as Map<String, dynamic>;
                                userHeight =
                                    (userData['height'] as num?)?.toDouble() ??
                                    0.0;
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: _getTodayWorkoutSessionsStream(),
                                builder: (context, gpsSnapshot) {
                                  // Tính số bước trong ngày từ pedometer (nếu có)
                                  int pedometerTodaySteps = 0;
                                  if (_pedometerAvailable &&
                                      pedometerSnapshot.hasData) {
                                    pedometerTodaySteps =
                                        _calculateTodayStepsFromPedometer(
                                          pedometerSnapshot.data!.steps,
                                        );
                                  }

                                  // Tính số bước từ GPS
                                  int gpsSteps = 0;
                                  if (gpsSnapshot.hasData) {
                                    gpsSteps = _calculateStepsFromGPS(
                                      gpsSnapshot.data!.docs,
                                      userHeight,
                                    );
                                  }

                                  // Kết hợp: Ưu tiên pedometer nếu có (tính tất cả bước chân trong ngày)
                                  // Nếu không có pedometer, dùng GPS từ workout sessions
                                  // Nếu có cả hai, có thể cộng thêm GPS steps (nhưng thường pedometer đã bao gồm)
                                  int totalSteps =
                                      _pedometerAvailable &&
                                          pedometerTodaySteps > 0
                                      ? pedometerTodaySteps
                                      : gpsSteps;

                                  // Nếu có cả pedometer và GPS, và GPS > pedometer (có thể do workout không được tính trong pedometer)
                                  // Thì lấy giá trị lớn hơn hoặc cộng thêm phần chênh lệch
                                  if (_pedometerAvailable &&
                                      pedometerTodaySteps > 0 &&
                                      gpsSteps > pedometerTodaySteps) {
                                    // Có thể workout sessions có thêm bước chân mà pedometer chưa tính
                                    // Hoặc đơn giản lấy giá trị lớn hơn
                                    totalSteps = gpsSteps;
                                  }

                                  // Mục tiêu mặc định 10000 bước
                                  const int goalSteps = 10000;
                                  double progress = totalSteps / goalSteps;
                                  if (progress > 1.0) progress = 1.0;

                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          // Phần text bên trái
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      'Số bước chân hôm nay',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.grey[400],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Icon hiển thị nguồn dữ liệu
                                                    Icon(
                                                      _pedometerAvailable &&
                                                              pedometerTodaySteps >
                                                                  0
                                                          ? Icons.sensors
                                                          : Icons.location_on,
                                                      size: 16,
                                                      color: Colors.grey[500],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  totalSteps
                                                      .toString()
                                                      .replaceAllMapped(
                                                        RegExp(
                                                          r'(\d{1,3})(?=(\d{3})+(?!\d))',
                                                        ),
                                                        (Match m) => '${m[1]},',
                                                      ),
                                                  style: const TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                // Hiển thị thông tin nguồn
                                                if (gpsSteps > 0 &&
                                                    _pedometerAvailable &&
                                                    pedometerTodaySteps > 0)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4,
                                                        ),
                                                    child: Text(
                                                      'Từ workout: ${gpsSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} bước',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 20),
                                          // Circular progress bar bên phải
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              SizedBox(
                                                width: 100,
                                                height: 100,
                                                child: CircularProgressIndicator(
                                                  value: progress,
                                                  strokeWidth: 10,
                                                  backgroundColor:
                                                      Colors.grey[800],
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.orange),
                                                ),
                                              ),
                                              // Icon người chạy ở giữa
                                              Icon(
                                                Icons.directions_run,
                                                size: 40,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.secondary,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      // Progress text
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${(progress * 100).toStringAsFixed(0)}% hoàn thành',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                          Text(
                                            'Mục tiêu: ${goalSteps.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} bước',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Nút Bắt đầu Luyện tập
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SelectActivityScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Bắt đầu Luyện tập',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Trường hợp không tìm thấy document user (ví dụ: user tạo trên Auth nhưng chưa login lần nào)
          return const Center(
            child: Text('Không tìm thấy dữ liệu hồ sơ người dùng.'),
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
