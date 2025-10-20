import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/user_model.dart'; // Thêm import này
import 'package:gym_now/screens/admin_panel_screen.dart';
import 'package:gym_now/screens/edit_user_screen.dart';
import 'package:gym_now/screens/heart_rate_screen.dart';
import 'package:gym_now/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;

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
                      const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 60)),
                      const SizedBox(height: 16),
                      Text(userData['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Text(userData['email'] ?? '', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                    ],
                  ),
                ),
              ),
              // Nút chỉnh sửa
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white24, 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      MaterialPageRoute(builder: (context) => const HeartRateScreen()),
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
                      ListTile(title: const Text('Chiều cao'), trailing: Text('${userData['height'] ?? 0} cm')),
                      ListTile(title: const Text('Cân nặng'), trailing: Text('${userData['weight'] ?? 0} kg')),
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
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}