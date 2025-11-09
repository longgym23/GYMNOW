import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gym_now/screens/main_navigator.dart';
import 'welcome_screen.dart'; // Màn hình chào mừng

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Đợi một chút để hiển thị splash screen và Firebase Auth khởi tạo
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Đợi Firebase Auth khởi tạo xong và lấy trạng thái hiện tại
    // Sử dụng authStateChanges() để đảm bảo lấy được trạng thái chính xác
    await FirebaseAuth.instance.authStateChanges().first;

    if (!mounted) return;

    // Kiểm tra xem user đã đăng nhập chưa
    final user = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (user != null) {
        // User đã đăng nhập, chuyển đến màn hình chính
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigator()),
        );
      } else {
        // User chưa đăng nhập, chuyển đến màn hình chào mừng
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Đặt màu nền khớp với màu background của app
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        // Đảm bảo toàn bộ màn hình có màu nền đồng nhất
        color: const Color(0xFF0D1B2A),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo của bạn - wrap trong Container để đảm bảo background khớp
              Container(
                decoration: BoxDecoration(
                  color: const Color(0x837796), // Màu nền khớp với app
                  borderRadius: BorderRadius.circular(20), // Bo góc nhẹ nếu cần
                ),
                padding: const EdgeInsets.all(8), // Padding nhỏ để che viền
                child: Image.asset(
                  'assets/images/logo.png', // **QUAN TRỌNG**: Đảm bảo đường dẫn này đúng
                  width: 200,
                  fit: BoxFit.contain, // Đảm bảo logo không bị méo
                ),
              ),
              const SizedBox(height: 20),
              CircularProgressIndicator(
                // Lấy màu cam từ theme
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
