import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';

class AuthViewModel extends GetxController {
  final AuthUseCases authUseCases;

  AuthViewModel({required this.authUseCases});

  final Rx<UserEntity?> currentUser = Rx<UserEntity?>(null);
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    isLoading.value = true;
    try {
      final user = await authUseCases.getCurrentUser();
      currentUser.value = user;
    } catch (e) {
      // handle error gracefully
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> login(String email, String password) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final user = await authUseCases.login(email, password);
      currentUser.value = user;
      return true;
    } catch (e) {
      errorMessage.value = _parseAuthException(e.toString());
      _showErrorSnackbar(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required double height,
    required double weight,
    required int age,
  }) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      final user = await authUseCases.register(
        email: email,
        password: password,
        name: name,
        height: height,
        weight: weight,
        age: age,
      );
      currentUser.value = user;
      Get.snackbar(
        'Thành công',
        'Đăng ký tài khoản thành công.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      errorMessage.value = _parseAuthException(e.toString());
      _showErrorSnackbar(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> logout() async {
    isLoading.value = true;
    try {
      await authUseCases.logout();
      currentUser.value = null;
    } catch (e) {
      // handle error gracefully
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> resetPassword(String email) async {
    isLoading.value = true;
    errorMessage.value = '';
    try {
      await authUseCases.resetPassword(email);
      Get.snackbar(
        'Thành công',
        'Đã gửi email đặt lại mật khẩu.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
       errorMessage.value = _parseAuthException(e.toString());
      _showErrorSnackbar(errorMessage.value);
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String _parseAuthException(String exception) {
    if (exception.contains('user-not-found')) {
      return 'Email không tồn tại trong hệ thống.';
    } else if (exception.contains('wrong-password') || exception.contains('invalid-credential')) {
      return 'Sai email hoặc mật khẩu.';
    } else if (exception.contains('email-already-in-use')) {
      return 'Email đã được sử dụng.';
    } else if (exception.contains('weak-password')) {
      return 'Mật khẩu quá yếu.';
    } else if (exception.contains('invalid-email')) {
      return 'Email không hợp lệ.';
    }
    return 'Có lỗi xảy ra. Vui lòng thử lại sau.';
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Lỗi',
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      // Minimalist Text SnackBar style
      backgroundColor: Get.theme.snackBarTheme.backgroundColor?.withAlpha(204) ?? Get.theme.colorScheme.surface,
      colorText: Get.theme.snackBarTheme.contentTextStyle?.color ?? Get.theme.colorScheme.onSurface,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      isDismissible: true,
      icon: null, // Bỏ icon dư thừa
      shouldIconPulse: false,
    );
  }
}
