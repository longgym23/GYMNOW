import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:gym_now/services/network_service.dart';
import 'package:gym_now/widgets/wave_clipper.dart';
import 'package:gym_now/widgets/modern_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
  final NetworkService _networkService = NetworkService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String name = '';
  double height = 0.0;
  double weight = 0.0;
  int age = 25;
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
                      'Đăng ký',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: <Widget>[
                        // Tên field với design hiện đại
                        ModernTextField(
                          label: 'Tên của bạn',
                          prefixIcon: Icons.person_outline,
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập tên của bạn' : null,
                          onChanged: (val) => setState(() => name = val),
                        ),
                        const SizedBox(height: 20.0),
                        // Email field với design hiện đại
                        ModernTextField(
                          label: 'Email',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập email' : null,
                          onChanged: (val) => setState(() => email = val),
                        ),
                        const SizedBox(height: 20.0),
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
                        const SizedBox(height: 20.0),
                        // Chiều cao field với design hiện đại
                        ModernTextField(
                          label: 'Chiều cao (cm)',
                          prefixIcon: Icons.height_outlined,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val!.isEmpty) return 'Nhập chiều cao';
                            if (double.tryParse(val) == null ||
                                double.parse(val) <= 0)
                              return 'Chiều cao không hợp lệ';
                            return null;
                          },
                          onChanged: (val) => setState(
                            () => height = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Cân nặng field với design hiện đại
                        ModernTextField(
                          label: 'Cân nặng (kg)',
                          prefixIcon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val!.isEmpty) return 'Nhập cân nặng';
                            if (double.tryParse(val) == null ||
                                double.parse(val) <= 0)
                              return 'Cân nặng không hợp lệ';
                            return null;
                          },
                          onChanged: (val) => setState(
                            () => weight = double.tryParse(val) ?? 0.0,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        // Tuổi field với design hiện đại
                        ModernTextField(
                          label: 'Tuổi',
                          prefixIcon: Icons.cake_outlined,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val!.isEmpty) return 'Nhập tuổi';
                            final ageValue = int.tryParse(val);
                            if (ageValue == null ||
                                ageValue <= 0 ||
                                ageValue > 120)
                              return 'Tuổi không hợp lệ (1-120)';
                            return null;
                          },
                          onChanged: (val) =>
                              setState(() => age = int.tryParse(val) ?? 25),
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
                                    'Đăng ký',
                                    style: TextStyle(fontSize: 18),
                                  ),
                            onPressed: _isLoading || !_isConnected
                                ? null
                                : () async {
                                    // Kiểm tra mạng trước khi đăng ký
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
                                          .registerWithEmailAndPassword(
                                            email,
                                            password,
                                          );
                                      setState(() => _isLoading = false);

                                      if (result == null) {
                                        setState(
                                          () => error =
                                              'Email không hợp lệ hoặc đã tồn tại',
                                        );
                                      } else {
                                        await DatabaseService(
                                          uid: result.uid,
                                        ).updateUserData(
                                          name,
                                          email,
                                          height,
                                          weight,
                                          age,
                                          'member',
                                        );

                                        // **SỬA ĐỔI SNACKBAR Ở ĐÂY**
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Đăng ký thành công! Vui lòng đăng nhập.',
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
                                          ),
                                        );

                                        Navigator.pop(context);
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
                          onPressed: () => Navigator.pop(context),
                          child: Text.rich(
                            TextSpan(
                              text: "Đã có tài khoản? ",
                              style: TextStyle(color: Colors.grey[400]),
                              children: [
                                TextSpan(
                                  text: "Đăng nhập",
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
