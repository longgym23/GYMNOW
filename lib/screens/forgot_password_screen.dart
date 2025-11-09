import 'package:flutter/material.dart';
import 'package:gym_now/services/pin_service.dart';
import 'package:gym_now/screens/verify_pin_screen.dart';
import 'package:gym_now/widgets/wave_clipper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PinService _pinService = PinService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String _error = '';
  String _successMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _error = '';
        _successMessage = '';
      });

      final email = _emailController.text.trim();
      final result = await _pinService.sendPinToEmail(email);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          setState(() {
            _successMessage = result['message'] as String;
          });

          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Chuyển đến màn hình xác thực mã PIN
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyPinScreen(email: email),
            ),
          );
        } else {
          setState(() {
            _error = result['message'] as String;
          });

          // Hiển thị thông báo lỗi
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] as String),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
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
                      'Quên mật khẩu',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nhập email của bạn để nhận mã PIN xác thực',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 50),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Vui lòng nhập email';
                            }
                            if (!val.contains('@')) {
                              return 'Email không hợp lệ';
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
                        // Thông báo thành công
                        if (_successMessage.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMessage,
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Nút gửi mã PIN
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendPin,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    'Gửi mã PIN',
                                    style: TextStyle(fontSize: 18),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Nút quay lại
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Quay lại đăng nhập',
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
