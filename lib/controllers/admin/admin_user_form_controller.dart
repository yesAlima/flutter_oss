import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

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

class AdminUserFormController extends GetxController with GetSingleTickerProviderStateMixin {
  final UserService _userService = Get.find<UserService>();
  
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  
  final isLoading = false.obs;
  final isEditing = false.obs;
  final selectedRole = 'supplier'.obs;
  final isActive = true.obs;
  
  // Password visibility states
  final showPassword = false.obs;
  final showConfirmPassword = false.obs;
  final showNewPassword = false.obs;
  
  String? userId;
  late final AnimationController loadingController;

  @override
  void onInit() {
    super.onInit();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    userId = Get.arguments as String?;
    if (userId != null) {
      loadUser();
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    newPasswordController.dispose();
    phoneController.dispose();
    loadingController.dispose();
    super.onClose();
  }

  Future<void> loadUser() async {
    isLoading.value = true;
    try {
      final user = await _userService.getUser(userId!);
      if (user != null) {
        nameController.text = user.name;
        emailController.text = user.email;
        phoneController.text = user.phone;
        selectedRole.value = user.role;
        isActive.value = user.isActive;
        isEditing.value = true;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load user: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resetUserPassword(String id, String newPassword) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('adminSetUserPassword');
      await callable.call(<String, dynamic>{
        'uid': id,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> saveUser() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final user = UserModel(
        id: userId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        email: emailController.text,
        name: nameController.text,
        role: selectedRole.value,
        isActive: isActive.value,
        phone: phoneController.text,
      );

      if (isEditing.value) {
        await _userService.updateUser(userId!, user);
        if (newPasswordController.text.isNotEmpty) {
          await resetUserPassword(userId!, newPasswordController.text);
        }
      } else {
        await _userService.createUser(user, passwordController.text);
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'User ${isEditing.value ? 'updated' : 'added'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save user: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

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

  String? validatePassword(String? value) {
    if (!isEditing.value && (value == null || value.isEmpty)) {
      return 'Password is required';
    }
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

  String? validateConfirmPassword(String? value) {
    if (!isEditing.value && (value == null || value.isEmpty)) {
      return 'Please confirm your password';
    }
    if (value != passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? validateNewPassword(String? value) {
    if (isEditing.value && value != null && value.isNotEmpty) {
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

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    if (!RegExp(r'^[36]\d{7}$').hasMatch(value)) {
      return 'Phone number must be 8 digits starting with 3 or 6';
    }
    return null;
  }

  void toggleShowPassword() => showPassword.value = !showPassword.value;
  void toggleShowConfirmPassword() => showConfirmPassword.value = !showConfirmPassword.value;
  void toggleShowNewPassword() => showNewPassword.value = !showNewPassword.value;
  void setRole(String role) => selectedRole.value = role;
  void toggleActive() => isActive.value = !isActive.value;
} 