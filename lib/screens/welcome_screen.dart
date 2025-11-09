import 'package:flutter/material.dart';
import 'package:gym_now/widgets/wave_clipper.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ClipPath(
            clipper: WaveClipperTop(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              color: const Color(0xFF1B263B), // Xanh navy đậm hơn một chút
            ),
          ),
          ClipPath(
            clipper: WaveClipperBottom(),
            child: Container(
              height: MediaQuery.of(context).size.height,
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor, // Lấy màu nền từ theme
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            child: Image.asset(
              'assets/images/logo.png', // **ĐÃ THAY ĐỔI**
              height: 50,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 30.0, bottom: 10),
                  child: Text(
                    'Welcome',
                    style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, bottom: 50),
                  child: Text(
                    'Bắt đầu hành trình sức khỏe của bạn.\nCùng nhau đạt được mục tiêu.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30.0, bottom: 80),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary, // Lấy màu cam
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_ios, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
