import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:gym_now/models/user_model.dart'; // Thêm import này
import 'package:gym_now/screens/admin_panel_screen.dart';
import 'package:gym_now/screens/edit_user_screen.dart';
import 'package:gym_now/screens/heart_rate_screen.dart';
import 'package:gym_now/screens/welcome_screen.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ của bạn')),
      body: FutureBuilder(
        future: DatabaseService(uid: user!.uid).getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Không thể tải dữ liệu hồ sơ.'));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          // **DÒNG CODE ĐƯỢC THÊM VÀO ĐỂ SỬA LỖI**
          final userModel = UserModel.fromFirestore(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Card thông tin cá nhân
              Card(
                color: const Color(0xFF1B263B),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        child: Icon(Icons.person, size: 60),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userData['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        userData['email'] ?? '',
                        style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
              // Nút chỉnh sửa
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // Bây giờ 'userModel' đã tồn tại và không còn lỗi
                      builder: (context) => EditUserScreen(user: userModel),
                    ),
                  );
                },
                child: const Text('Chỉnh sửa hồ sơ'),
              ),
              const SizedBox(height: 20),
              Card(
                color: const Color(0xFF1B263B),
                child: ListTile(
                  leading: Icon(Icons.favorite, color: Colors.redAccent),
                  title: const Text('Đo nhịp tim'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HeartRateScreen(),
                      ),
                    );
                  },
                ),
              ),
              // Card chỉ số cơ thể
              Card(
                color: const Color(0xFF1B263B),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        title: const Text('Chiều cao'),
                        trailing: Text('${userData['height'] ?? 0} cm'),
                      ),
                      ListTile(
                        title: const Text('Cân nặng'),
                        trailing: Text('${userData['weight'] ?? 0} kg'),
                      ),
                      ListTile(
                        title: const Text('Tuổi'),
                        trailing: Text('${userData['age'] ?? 25} tuổi'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Nút quản lý cho Admin
              if (userData['role'] == 'admin')
                ElevatedButton.icon(
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Bảng quản trị'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminPanelScreen(),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 10),
              // Nút đăng xuất hiện đại
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      // Hiển thị dialog xác nhận kiểu iOS
                      final confirm = await showCupertinoDialog<bool>(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Xác nhận đăng xuất'),
                          content: const Text(
                            'Bạn có chắc chắn muốn đăng xuất?',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  color: CupertinoColors.activeBlue,
                                ),
                              ),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Đăng xuất'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _auth.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WelcomeScreen(),
                            ),
                            (route) => false,
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.logout,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Đăng xuất',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}
