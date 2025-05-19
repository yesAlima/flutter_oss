import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // If the field is empty, only allow 3 or 6
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // If the first character is not 3 or 6, return the old value
    if (newValue.text.length == 1 && !['3', '6'].contains(newValue.text[0])) {
      return oldValue;
    }

    // If we already have a first digit (3 or 6), only allow digits for the rest
    if (oldValue.text.isNotEmpty && ['3', '6'].contains(oldValue.text[0])) {
      if (newValue.text.length > oldValue.text.length) {
        final newChar = newValue.text[newValue.text.length - 1];
        if (!RegExp(r'[0-9]').hasMatch(newChar)) {
          return oldValue;
        }
      }
    }

    // Limit to 8 digits
    if (newValue.text.length > 8) {
      return oldValue;
    }

    return newValue;
  }
}

class ProfileController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final UserService _userService = Get.find<UserService>();

  final formKey = GlobalKey<FormState>();
  final displayNameController = TextEditingController();
  final emailController = TextEditingController();
  final prevPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confPasswordController = TextEditingController();
  final phoneController = TextEditingController();

  final isEditing = false.obs;
  final showPrevPassword = false.obs;
  final showNewPassword = false.obs;
  final showConfPassword = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initializeControllers();
    isEditing.value = true;
  }

  void _initializeControllers() {
    final user = _authService.currentUser;
    if (user != null) {
      displayNameController.text = user.name;
      emailController.text = user.email;
      phoneController.text = user.phone;
    }
  }

  @override
  void onClose() {
    displayNameController.dispose();
    emailController.dispose();
    prevPasswordController.dispose();
    newPasswordController.dispose();
    confPasswordController.dispose();
    phoneController.dispose();
    super.onClose();
  }

  void toggleEditing() {
    isEditing.value = !isEditing.value;
    if (!isEditing.value) {
      _resetForm();
    }
  }

  void _resetForm() {
    final user = _authService.currentUser;
    if (user != null) {
      displayNameController.text = user.name;
      emailController.text = user.email;
      phoneController.text = user.phone;
    }
    prevPasswordController.clear();
    newPasswordController.clear();
    confPasswordController.clear();
  }

  Future<void> updateProfile() async {
    if (!formKey.currentState!.validate()) return;

    try {
      final user = _authService.currentUser;
      if (user != null) {
        // Update user profile
        await _userService.updateUser(user.id, UserModel(
          id: user.id,
          email: emailController.text,
          name: displayNameController.text,
          role: user.role,
          isActive: user.isActive,
          phone: phoneController.text,
        ));

        // Update password if provided
        if (newPasswordController.text.isNotEmpty) {
          await _authService.updatePassword(
            prevPasswordController.text,
            newPasswordController.text,
          );
        }

        isEditing.value = false;
        _resetForm();

        Get.snackbar(
          'Success',
          'Profile updated successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update profile: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void togglePrevPasswordVisibility() => showPrevPassword.value = !showPrevPassword.value;
  void toggleNewPasswordVisibility() => showNewPassword.value = !showNewPassword.value;
  void toggleConfPasswordVisibility() => showConfPassword.value = !showConfPassword.value;

  String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!GetUtils.isEmail(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^[36]\d{7}$').hasMatch(value)) {
      return 'Phone number must be 8 digits starting with 3 or 6';
    }
    return null;
  }

  String? validateNewPassword(String? value) {
    if (value != null && value.isNotEmpty) {
      if (value.length < 8) {
        return 'Password must be at least 8 characters';
      }
      if (!value.contains(RegExp(r'[A-Z]'))) {
        return 'Password must contain at least one uppercase letter';
      }
      if (!value.contains(RegExp(r'[a-z]'))) {
        return 'Password must contain at least one lowercase letter';
      }
      if (!value.contains(RegExp(r'[0-9]'))) {
        return 'Password must contain at least one number';
      }
      if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        return 'Password must contain at least one special character';
      }
    }
    return null;
  }

  String? validateConfPassword(String? value) {
    if (newPasswordController.text.isNotEmpty) {
      if (value == null || value.isEmpty) {
        return 'Please confirm your password';
      }
      if (value != newPasswordController.text) {
        return 'Passwords do not match';
      }
    }
    return null;
  }

  String? validatePrevPassword(String? value) {
    if (newPasswordController.text.isNotEmpty) {
      if (value == null || value.isEmpty) {
        return 'Current password is required to set a new password';
      }
    }
    return null;
  }
} 