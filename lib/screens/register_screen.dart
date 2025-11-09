import 'package:flutter/material.dart';
import 'package:gym_now/services/auth_service.dart';
import 'package:gym_now/services/database_service.dart';
import 'package:gym_now/widgets/wave_clipper.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _auth = AuthService();
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
                        // Các TextFormField giữ nguyên
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Tên của bạn',
                          ),
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập tên của bạn' : null,
                          onChanged: (val) => setState(() => name = val),
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập email' : null,
                          onChanged: (val) => setState(() => email = val),
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Mật khẩu',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
                            ),
                          ),
                          validator: (val) => val!.length < 6
                              ? 'Mật khẩu phải dài hơn 6 ký tự'
                              : null,
                          onChanged: (val) => setState(() => password = val),
                        ),
                        const SizedBox(height: 20.0),
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Chiều cao (cm)',
                          ),
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
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Cân nặng (kg)',
                          ),
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
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Tuổi'),
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
                            onPressed: _isLoading
                                ? null
                                : () async {
                                    if (_formKey.currentState!.validate()) {
                                      setState(() => _isLoading = true);
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
