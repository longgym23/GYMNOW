import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final double height;
  final double weight;
  final String role; // **<-- TRƯỜNG CÒN THIẾU**

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.height,
    required this.weight,
    required this.role, // **<-- THÊM VÀO CONSTRUCTOR**
  });

  // **HÀM CÒN THIẾU GÂY RA LỖI**
  // Hàm này tạo một đối tượng UserModel từ dữ liệu đọc về trên Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      height: (data['height'] ?? 0.0).toDouble(),
      weight: (data['weight'] ?? 0.0).toDouble(),
      role: data['role'] ?? 'member', // Mặc định là 'member' nếu không có
    );
  }

  // Cập nhật lại hàm toMap để có cả trường 'role'
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'height': height,
      'weight': weight,
      'role': role,
    };
  }
}