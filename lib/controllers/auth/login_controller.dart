import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';

class LoginController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();

  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final obscurePassword = true.obs;

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  Future<void> signIn() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      await _authService.signIn(
        emailController.text,
        passwordController.text,
      );

      // Wait until currentUser is not null
      while (_authService.currentUser == null) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      final user = _authService.currentUser;
      if (user?.role == 'admin') {
        Get.offAllNamed('/admin');
      } else if (user?.role == 'supplier') {
        Get.offAllNamed('/supplier');
      } else if (user?.role == 'delivery') {
        Get.offAllNamed('/delivery');
      } else {
        Get.offAllNamed('/customer');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign in: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void togglePasswordVisibility() => obscurePassword.value = !obscurePassword.value;

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }
} 