import 'dart:async';
import 'package:flutter/material.dart';
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
    // Đợi 3 giây rồi chuyển đến màn hình chào mừng
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Màu nền sẽ được lấy từ theme trong main.dart
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo của bạn
            Image.asset(
              'assets/images/logo.jpg', // **QUAN TRỌNG**: Đảm bảo đường dẫn này đúng
              width: 200,
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              // Lấy màu cam từ theme
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}