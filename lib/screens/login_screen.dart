import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:gym_now/screens/main_navigator.dart';
import 'package:gym_now/widgets/wave_clipper.dart';
import 'package:gym_now/widgets/modern_text_field.dart';
import 'package:gym_now/services/network_service.dart';
import 'package:gym_now/screens/register_screen.dart';
import 'package:gym_now/screens/forgot_password_screen.dart';
import '../presentation/viewmodels/auth_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthViewModel _authViewModel = Get.find<AuthViewModel>();
  final NetworkService _networkService = NetworkService();
  final _formKey = GlobalKey<FormState>();
  
  String email = '';
  String password = '';
  bool _obscureText = true;
  bool _isConnected = true;
  StreamSubscription<bool>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    _networkService.initialize();
    _networkSubscription = _networkService.connectionStatus.listen((isConnected) {
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
                        ModernTextField(
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) => val!.isEmpty ? 'Nhập email của bạn' : null,
                          onChanged: (val) => email = val,
                        ),
                        const SizedBox(height: 24.0),
                        ModernTextField(
                          label: 'Mật khẩu',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscureText,
                          validator: (val) => val!.length < 6 ? 'Mật khẩu phải dài hơn 6 ký tự' : null,
                          onChanged: (val) => password = val,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey[400],
                            ),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Get.to(() => const ForgotPasswordScreen());
                            },
                            child: Text(
                              'Quên mật khẩu?',
                              style: TextStyle(color: Colors.grey[400]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 30.0),
                        Obx(() {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _authViewModel.isLoading.value || !_isConnected
                                  ? null
                                  : () async {
                                      final hasConnection = await _networkService.checkInternetConnection();
                                      if (!hasConnection) {
                                        setState(() {
                                          _isConnected = false;
                                        });
                                        _authViewModel.errorMessage.value = 'Không có kết nối mạng. Vui lòng kiểm tra internet và thử lại.';
                                        return;
                                      }

                                      if (_formKey.currentState!.validate()) {
                                        final success = await _authViewModel.login(email, password);
                                        if (success) {
                                          Get.snackbar(
                                            'Thành công',
                                            'Đăng nhập thành công!',
                                            snackPosition: SnackPosition.BOTTOM,
                                            backgroundColor: Colors.green.withOpacity(0.8),
                                            colorText: Colors.white,
                                            margin: const EdgeInsets.all(16),
                                            borderRadius: 8,
                                            icon: null,
                                          );
                                          Get.offAll(() => const MainNavigator());
                                        }
                                      }
                                    },
                              child: _authViewModel.isLoading.value
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Đăng nhập', style: TextStyle(fontSize: 18)),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                        if (!_isConnected)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade600, width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.wifi_off, color: Colors.red, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Không có kết nối mạng',
                                        style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Vui lòng kiểm tra kết nối internet và thử lại.',
                                        style: TextStyle(color: Colors.red.shade200, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Obx(() {
                          if (_authViewModel.errorMessage.value.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                _authViewModel.errorMessage.value,
                                style: const TextStyle(color: Colors.red, fontSize: 14.0),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                        TextButton(
                          onPressed: () {
                            Get.to(() => const RegisterScreen());
                          },
                          child: Text.rich(
                            TextSpan(
                              text: "Chưa có tài khoản? ",
                              style: TextStyle(color: Colors.grey[400]),
                              children: [
                                TextSpan(
                                  text: "Đăng ký",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.secondary,
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
