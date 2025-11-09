import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gym_now/services/pin_service.dart';
import 'package:gym_now/screens/login_screen.dart';
import 'package:gym_now/widgets/wave_clipper.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final PinService _pinService = PinService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _error = '';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      try {
        // Kiểm tra email có tồn tại không
        final methods = await _auth.fetchSignInMethodsForEmail(widget.email);
        if (methods.isEmpty) {
          setState(() {
            _isLoading = false;
            _error = 'Email không tồn tại trong hệ thống';
          });
          return;
        }

        // Gửi email reset password từ Firebase Auth
        // User sẽ nhận email với link để đặt lại mật khẩu
        await _auth.sendPasswordResetEmail(
          email: widget.email,
          actionCodeSettings: ActionCodeSettings(
            url: 'https://gymnow-e1ebd.firebaseapp.com',
            handleCodeInApp: false,
          ),
        );

        // Xóa mã PIN đã sử dụng
        await _pinService.deletePin(widget.email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Link đặt lại mật khẩu đã được gửi đến email của bạn. Vui lòng kiểm tra email và làm theo hướng dẫn để đặt mật khẩu mới.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Đóng',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );

          // Chuyển về màn hình đăng nhập sau 2 giây
          await Future.delayed(const Duration(seconds: 2));

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (e.toString().contains('user-not-found')) {
              _error = 'Email không tồn tại trong hệ thống';
            } else if (e.toString().contains('invalid-email')) {
              _error = 'Email không hợp lệ';
            } else {
              _error = 'Có lỗi xảy ra. Vui lòng thử lại sau.';
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Giao diện sóng
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
                  // Logo
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 50,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  // Tiêu đề
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Đặt lại mật khẩu',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email: ${widget.email}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu mới',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(() {
                                _obscurePassword = !_obscurePassword;
                              }),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng nhập mật khẩu mới';
                            }
                            if (val.length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Xác nhận mật khẩu',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              }),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu';
                            }
                            if (val != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // Thông báo lỗi
                        if (_error.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Nút đặt lại mật khẩu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _resetPassword,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Đặt lại mật khẩu',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Nút quay lại
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Quay lại',
                            style: TextStyle(fontSize: 16),
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
