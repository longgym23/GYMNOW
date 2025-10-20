import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/user_model.dart';
import 'package:gym_now/screens/edit_user_screen.dart';
import 'package:gym_now/services/database_service.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý Hội viên')),
      body: StreamBuilder<QuerySnapshot>(
        stream: DatabaseService().getAllUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Không tìm thấy hội viên nào hoặc đã có lỗi.'));
          }
          final userDocs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: userDocs.length,
            itemBuilder: (context, index) {
              final user = UserModel.fromFirestore(userDocs[index]);
              return Card(
                color: const Color(0xFF1B263B),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(child: Text(user.name.isNotEmpty ? user.name.substring(0, 1) : '?')),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Text(
                    user.role, 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: user.role == 'admin' ? Colors.amber : Colors.grey[400]
                    )
                  ),
                  onTap: () {
                    // **THAY ĐỔI Ở ĐÂY**
                    // Điều hướng đến màn hình chỉnh sửa và truyền đối tượng user qua
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditUserScreen(user: user),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}