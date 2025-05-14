import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../routes/app_routes.dart';
import '../../services/analytics_service.dart';
import '../../widgets/analytics_card.dart';
import '../../services/auth_service.dart';
import '../../views/auth/logout_view.dart';
import 'package:intl/intl.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final _orderService = Get.find<OrderService>();
  final RxList<OrderModel> _orders = <OrderModel>[].obs;
  final RxBool _isLoading = true.obs;
  final _analyticsService = Get.find<AnalyticsService>();
  final _authService = Get.find<AuthService>();
  int _totalOrders = 0;
  int _totalProducts = 0;
  int _totalUsers = 0;
  double _totalRevenue = 0;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadAnalytics();
  }

  Future<void> _loadOrders() async {
    _isLoading.value = true;
    try {
      final orders = await _orderService.getAllOrders();
      _orders.value = orders.where((order) => order.fulfillment != OrderFulfillment.draft).toList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _loadAnalytics() async {
    try {
      final analytics = await _analyticsService.getSalesAnalytics();
      _totalOrders = analytics['totalOrders'] as int;
      _totalRevenue = analytics['totalRevenue'] as double;

      final totalProducts = await _analyticsService.getTotalProducts();
      final totalUsers = await _analyticsService.getTotalUsers();
      _totalProducts = totalProducts;
      _totalUsers = totalUsers;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Color _getStatusColor(OrderFulfillment status) {
    switch (status) {
      case OrderFulfillment.pending:
        return Colors.orange;
      case OrderFulfillment.unfulfilled:
        return Colors.blue;
      case OrderFulfillment.fulfilled:
        return Colors.green;
      case OrderFulfillment.cancelled:
        return Colors.red;
      case OrderFulfillment.draft:
        return Colors.grey;
      case OrderFulfillment.import:
        return Colors.purple;
    }
  }

  String _getStatusText(OrderFulfillment status) {
    switch (status) {
      case OrderFulfillment.pending:
        return 'Pending';
      case OrderFulfillment.unfulfilled:
        return 'Assigned to Delivery';
      case OrderFulfillment.fulfilled:
        return 'Delivered';
      case OrderFulfillment.cancelled:
        return 'Cancelled';
      case OrderFulfillment.draft:
        return 'Draft';
      case OrderFulfillment.import:
        return 'Import';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed(AppRoutes.profile),
          ),
          const LogoutView(),
        ],
      ),
      body: Obx(() {
        if (_isLoading.value) {
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
                    () => Get.toNamed(AppRoutes.adminUsers),
                    Colors.indigo,
                  ),
                  _buildDashboardCard(
                    context,
                    'Products',
                    Icons.inventory,
                    () => Get.toNamed(AppRoutes.adminProducts),
                    Colors.blue,
                  ),
                  _buildDashboardCard(
                    context,
                    'Orders',
                    Icons.shopping_cart,
                    () => Get.toNamed(AppRoutes.adminOrders),
                    Colors.green,
                  ),
                  _buildDashboardCard(
                    context,
                    'Categories',
                    Icons.category,
                    () => Get.toNamed(AppRoutes.adminCategories),
                    Colors.orange,
                  ),
                  _buildDashboardCard(
                    context,
                    'Sources',
                    Icons.source,
                    () => Get.toNamed(AppRoutes.sources),
                    Colors.purple,
                  ),
                  _buildDashboardCard(
                    context,
                    'Analytics',
                    Icons.analytics,
                    () => Get.toNamed(AppRoutes.adminAnalytics),
                    Colors.pink,
                  ),
                  _buildDashboardCard(
                    context,
                    'Export',
                    Icons.file_download,
                    () => Get.toNamed(AppRoutes.adminExport),
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withAlpha(10),
                color.withAlpha(20),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: color,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} 