import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_now/screens/main_navigator.dart';
import 'package:gym_now/widgets/wave_clipper.dart';
import 'package:gym_now/widgets/modern_text_field.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/network_service.dart';
import 'package:gym_now/screens/register_screen.dart';
import 'package:gym_now/screens/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final NetworkService _networkService = NetworkService();
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  String error = '';
  bool _isLoading = false;
  bool _obscureText = true;
  bool _isConnected = true;
  StreamSubscription<bool>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    _networkService.initialize();
    _networkSubscription = _networkService.connectionStatus.listen((
      isConnected,
    ) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
    _checkNetworkStatus();
  }

  Future<void> _checkNetworkStatus() async {
    final isConnected = await _networkService.checkInternetConnection();
    if (mounted) {
      setState(() {
        _isConnected = isConnected;
      });
    }
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Giao diện sóng giữ nguyên
          ClipPath(
            clipper: WaveClipperTop(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4,
              color: const Color(0xFF1B263B),
            ),
          ),
          ClipPath(
            clipper: WaveClipperBottom(),
            child: Container(
              height: MediaQuery.of(context).size.height,
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                left: 30.0,
                right: 30.0,
                top: MediaQuery.of(context).padding.top + 20,
              ),
              child: Column(
                children: [
                  // Logo scroll cùng với nội dung
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        // Email field với design hiện đại
                        ModernTextField(
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập email của bạn' : null,
                          onChanged: (val) => setState(() => email = val),
                        ),
                        const SizedBox(height: 24.0),
                        // Password field với design hiện đại
                        ModernTextField(
                          label: 'Mật khẩu',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureText,
                          validator: (val) => val!.length < 6
                              ? 'Mật khẩu phải dài hơn 6 ký tự'
                              : null,
                          onChanged: (val) => setState(() => password = val),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[400],
                            ),
                            onPressed: () =>
                                setState(() => _obscureText = !_obscureText),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              'Quên mật khẩu?',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30.0),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Đăng nhập',
                                    style: TextStyle(fontSize: 18),
                                  ),
                            onPressed: _isLoading || !_isConnected
                                ? null
                                : () async {
                                    // Kiểm tra mạng trước khi đăng nhập
                                    final hasConnection = await _networkService
                                        .checkInternetConnection();
                                    if (!hasConnection) {
                                      setState(() {
                                        _isConnected = false;
                                        error =
                                            'Không có kết nối mạng. Vui lòng kiểm tra internet và thử lại.';
                                      });
                                      return;
                                    }

                                    if (_formKey.currentState!.validate()) {
                                      setState(() {
                                        _isLoading = true;
                                        error = '';
                                      });
                                      dynamic result = await _auth
                                          .signInWithEmailAndPassword(
                                            email,
                                            password,
                                          );

                                      // Dừng loading sau khi có kết quả
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                      }

                                      if (result == null) {
                                        setState(
                                          () => error =
                                              'Email hoặc mật khẩu không đúng',
                                        );
                                      } else {
                                        // **SỬA ĐỔI SNACKBAR Ở ĐÂY**
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Đăng nhập thành công!',
                                              textAlign: TextAlign.center,
                                            ),
                                            backgroundColor: Colors.green,
                                            behavior: SnackBarBehavior.floating,
                                            margin: const EdgeInsets.only(
                                              bottom: 50,
                                              left: 20,
                                              right: 20,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(24.0),
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );

                                        await Future.delayed(
                                          const Duration(milliseconds: 1200),
                                        );

                                        if (mounted) {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MainNavigator(),
                                            ),
                                            (route) => false,
                                          );
                                        }
                                      }
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Hiển thị cảnh báo mạng nếu không có kết nối
                        if (!_isConnected)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade600,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi_off,
                                  color: Colors.red,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Không có kết nối mạng',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Vui lòng kiểm tra kết nối internet và thử lại.',
                                        style: TextStyle(
                                          color: Colors.red.shade200,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (error.isNotEmpty)
                          Text(
                            error,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14.0,
                            ),
                          ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text.rich(
                            TextSpan(
                              text: "Chưa có tài khoản? ",
                              style: TextStyle(color: Colors.grey[400]),
                              children: [
                                TextSpan(
                                  text: "Đăng ký",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
