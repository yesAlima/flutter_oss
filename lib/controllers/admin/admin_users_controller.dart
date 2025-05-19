import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../routes/app_routes.dart';

class AdminUsersController extends GetxController with GetSingleTickerProviderStateMixin {
  final UserService _userService = Get.find<UserService>();
  
  final searchController = TextEditingController();
  final selectedRole = UserRole.supplier.obs;
  final suppliers = <UserModel>[].obs;
  final deliveries = <UserModel>[].obs;
  final isLoading = true.obs;
  final imageLoadingStates = <String, bool>{}.obs;
  
  late final AnimationController loadingController;

  @override
  void onInit() {
    super.onInit();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    loadUsers();
  }

  @override
  void onClose() {
    searchController.dispose();
    loadingController.dispose();
    super.onClose();
  }

  Future<void> loadUsers() async {
    isLoading.value = true;
    try {
      final users = await _userService.getAllUsers();
      suppliers.value = users.where((user) => user.role == 'supplier').toList();
      deliveries.value = users.where((user) => user.role == 'delivery').toList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load users');
    } finally {
      isLoading.value = false;
    }
  }

  List<UserModel> get filteredUsers {
    final searchTerm = searchController.text.toLowerCase();
    final users = selectedRole.value == UserRole.supplier ? suppliers : deliveries;
    return users.where((user) {
      final email = user.email.toLowerCase();
      final name = user.name.toLowerCase();
      return email.contains(searchTerm) || name.contains(searchTerm);
    }).toList();
  }

  Future<void> deleteUser(String userId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    isLoading.value = true;
    try {
      await _userService.deleteUser(userId);
      await loadUsers();
      Get.snackbar(
        'Success',
        'User deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete user: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _userService.updateUserStatus(userId, isActive);
      Get.snackbar(
        'Success',
        'User status updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update user status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void navigateToAddUser() async {
    await Get.toNamed(AppRoutes.adminUserForm);
    loadUsers();
  }

  void navigateToEditUser(UserModel user) async {
    await Get.toNamed(
      AppRoutes.adminUserForm,
      arguments: user,
    );
    loadUsers();
  }

  void setRole(UserRole role) {
    selectedRole.value = role;
  }

  Widget buildUserAvatar(String? name, String email, BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name?.isNotEmpty == true ? name![0].toUpperCase() : email[0].toUpperCase(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }
} 