import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_controller.dart';
import '../../views/auth/logout_view.dart';

class AdminView extends GetView<AdminController> {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed('/profile'),
          ),
          const LogoutView(),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context,
                    'Users',
                    Icons.people,
                    () => Get.toNamed('/admin/users'),
                    Colors.indigo,
                  ),
                  _buildDashboardCard(
                    context,
                    'Products',
                    Icons.inventory,
                    () => Get.toNamed('/admin/products'),
                    Colors.blue,
                  ),
                  _buildDashboardCard(
                    context,
                    'Orders',
                    Icons.shopping_cart,
                    () => Get.toNamed('/admin/orders'),
                    Colors.green,
                  ),
                  _buildDashboardCard(
                    context,
                    'Categories',
                    Icons.category,
                    () => Get.toNamed('/admin/categories'),
                    Colors.orange,
                  ),
                  _buildDashboardCard(
                    context,
                    'Sources',
                    Icons.source,
                    () => Get.toNamed('/admin/sources'),
                    Colors.purple,
                  ),
                  _buildDashboardCard(
                    context,
                    'Analytics',
                    Icons.analytics,
                    () => Get.toNamed('/admin/analytics'),
                    Colors.pink,
                  ),
                  _buildDashboardCard(
                    context,
                    'Export',
                    Icons.file_download,
                    () => Get.toNamed('/admin/export'),
                    Colors.teal,
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 