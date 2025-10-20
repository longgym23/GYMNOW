import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/screens/chat_screen.dart'; // **<-- THÊM IMPORT NÀY**
import 'package:gym_now/screens/select_activity_screen.dart';
import 'package:gym_now/screens/welcome_screen.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:pedometer/pedometer.dart';
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

  @override
  void initState() {
    super.initState();
    initPedometer();
  }

  void initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream.listen((event) {}).onError((error) {
      print('Pedometer Error: $error');
      // Cân nhắc hiển thị lỗi cho người dùng nếu cần
    });
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
          )
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
            String userName = (snapshot.data!.data() as Map<String, dynamic>)['name'] ?? 'Bạn';

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
                  // Card đếm bước chân
                  Card(
                    color: const Color(0xFF1B263B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Icon(Icons.directions_walk, size: 40, color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Số bước chân hôm nay', style: TextStyle(fontSize: 16, color: Colors.white70)),
                                StreamBuilder<StepCount>(
                                  stream: _stepCountStream,
                                  builder: (context, snapshot) {
                                    int steps = snapshot.hasData ? snapshot.data!.steps : 0;
                                    return Text(
                                      '$steps',
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ],
                            ),
                          )
                        ],
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
                          MaterialPageRoute(builder: (context) => const SelectActivityScreen()),
                        );
                      },
                      child: const Text('Bắt đầu Luyện tập', style: TextStyle(fontSize: 18)),
                    ),
                  ),

                  // **NÚT MỚI ĐỂ MỞ CHATBOT**
                  const SizedBox(height: 20), // Thêm khoảng cách
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Hỏi PT AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary, // Màu xanh dương
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
          // Trường hợp không tìm thấy document user (ví dụ: user tạo trên Auth nhưng chưa login lần nào)
          return const Center(child: Text('Không tìm thấy dữ liệu hồ sơ người dùng.'));
        },
      ),
    );
  }
}