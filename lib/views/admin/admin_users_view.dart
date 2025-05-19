import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../controllers/admin/admin_users_controller.dart';
import '../../routes/app_routes.dart';

class AdminUsersView extends GetView<AdminUsersController> {
  const AdminUsersView({Key? key}) : super(key: key);

  Widget _buildUserAvatar(String? name, String email) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(Get.context!).primaryColor.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name?.isNotEmpty == true ? name![0].toUpperCase() : email[0].toUpperCase(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(Get.context!).primaryColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed(AppRoutes.adminUserForm);
                controller.loadUsers();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller.searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => controller.refresh(),
            ),
          ),
          buildToggle(context),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = controller.filteredUsers;
              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Get.toNamed(
                        AppRoutes.adminUserForm,
                        arguments: user.id,
                      );
                      await controller.loadUsers();
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _buildUserAvatar(user.name, user.email),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.email,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: user.role == 'supplier' ? Colors.blue[50] : Colors.orange[50],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      user.role == 'supplier' ? 'Supplier' : 'Delivery',
                                      style: TextStyle(
                                        color: user.role == 'supplier' ? Colors.blue : Colors.orange,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: user.isActive,
                                  onChanged: (value) async {
                                    await controller.toggleUserStatus(user.id, value);
                                    final list = controller.selectedRole.value == UserRole.supplier
                                        ? controller.suppliers
                                        : controller.deliveries;
                                    final idx = list.indexWhere((u) => u.id == user.id);
                                    if (idx != -1) {
                                      list[idx] = list[idx].copyWith(isActive: value);
                                    }
                                  },
                                  activeColor: Theme.of(context).primaryColor,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () async {
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
                                    await controller.deleteUser(user.id);
                                    final list = controller.selectedRole.value == UserRole.supplier
                                        ? controller.suppliers
                                        : controller.deliveries;
                                    list.removeWhere((u) => u.id == user.id);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget buildToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 260,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          child: Obx(() {
            final isSupplier = controller.selectedRole.value == UserRole.supplier;
            return Stack(
              children: [
                AnimatedAlign(
                  alignment: isSupplier ? Alignment.centerLeft : Alignment.centerRight,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 130,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => controller.setRole(UserRole.supplier),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store,
                                    color: isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Supplier',
                                  style: TextStyle(
                                    color: isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => controller.setRole(UserRole.delivery),
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping,
                                    color: !isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Delivery',
                                  style: TextStyle(
                                    color: !isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
} 