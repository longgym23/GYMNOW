import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/models/user_model.dart';
import 'package:gym_now/services/database_service.dart';

class EditUserScreen extends StatefulWidget {
  final UserModel user; // Màn hình này sẽ nhận vào một đối tượng UserModel

  const EditUserScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();

  // Sử dụng TextEditingController để quản lý và cập nhật dữ liệu trong form
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late String _selectedRole;

  // **BIẾN MỚI: Lưu vai trò của người đang đăng nhập**
  String _currentUserRole = 'member';

  @override
  void initState() {
    super.initState();
    // Khởi tạo các controller với dữ liệu hiện tại của người dùng
    _nameController = TextEditingController(text: widget.user.name);
    _heightController = TextEditingController(text: widget.user.height.toString());
    _weightController = TextEditingController(text: widget.user.weight.toString());
    _selectedRole = widget.user.role;

    // Lấy vai trò của người dùng hiện tại để quyết định có hiển thị ô vai trò không
    _getCurrentUserRole();
  }

  // **HÀM MỚI: Lấy vai trò của người dùng đang đăng nhập**
  Future<void> _getCurrentUserRole() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userData = await DatabaseService(uid: currentUser.uid).getUserData();
      if (userData.exists && mounted) {
        setState(() {
          _currentUserRole = (userData.data() as Map<String, dynamic>)['role'] ?? 'member';
        });
      }
    }
  }

  @override
  void dispose() {
    // Hủy các controller khi widget bị xóa để tránh rò rỉ bộ nhớ
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sửa hồ sơ: ${widget.user.name}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Tên hội viên'),
              validator: (val) => val!.isEmpty ? 'Không được để trống' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _heightController,
              decoration: const InputDecoration(labelText: 'Chiều cao (cm)'),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Không được để trống' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
              keyboardType: TextInputType.number,
              validator: (val) => val!.isEmpty ? 'Không được để trống' : null,
            ),
            
            // **THAY ĐỔI Ở ĐÂY: CHỈ HIỂN THỊ DROPDOWN CHO ADMIN**
            if (_currentUserRole == 'admin') ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: 'Vai trò'),
                items: ['member', 'admin'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedRole = newValue!;
                  });
                },
              ),
            ],

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  // Gọi service để cập nhật dữ liệu trên Firestore
                  await DatabaseService(uid: widget.user.id).updateUserData(
                    _nameController.text,
                    widget.user.email, // Email không cho sửa
                    double.parse(_heightController.text),
                    double.parse(_weightController.text),
                    _selectedRole, // Member sẽ tự lưu lại role 'member' của mình
                  );

                  // Hiển thị thông báo thành công và quay lại
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cập nhật thành công!')),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Lưu thay đổi'),
            ),
          ],
        ),
      ),
    );
  }
}