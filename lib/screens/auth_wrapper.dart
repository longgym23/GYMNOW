// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:gym_now/screens/main_navigator.dart'; // Màn hình chính sau khi đăng nhập
// import 'package:gym_now/screens/welcome_screen.dart'; // Màn hình chào mừng/đăng nhập

// class AuthWrapper extends StatelessWidget {
//   const AuthWrapper({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // Lắng nghe các thay đổi trạng thái xác thực
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(), // Luồng (stream) theo dõi trạng thái đăng nhập
//       builder: (context, snapshot) {
//         // Nếu đang trong quá trình kiểm tra (chờ kết nối)
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           // Hiển thị vòng xoay loading trong khi kiểm tra
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//         // Nếu người dùng đã đăng nhập (snapshot có dữ liệu)
//         else if (snapshot.hasData) {
//           // Hiển thị màn hình điều hướng chính của ứng dụng
//           return const MainNavigator();
//         }
//         // Nếu người dùng chưa đăng nhập (snapshot không có dữ liệu)
//         else {
//           // Hiển thị màn hình chào mừng (nơi dẫn đến đăng nhập/đăng ký)
//           return const WelcomeScreen();
//         }
//       },
//     );
//   }
// }