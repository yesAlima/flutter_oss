import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';
import 'supplier_orders_view.dart';
import 'supplier_products_view.dart';
import '../auth/logout_view.dart';

class SupplierView extends StatefulWidget {
  const SupplierView({super.key});

  @override
  State<SupplierView> createState() => _SupplierViewState();
}

class _SupplierViewState extends State<SupplierView> with SingleTickerProviderStateMixin {
  final _authService = Get.find<AuthService>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Products'),
          ],
        ),
        actions:  [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed(AppRoutes.profile),
          ),
          const LogoutView(),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SupplierOrdersView(),
          SupplierProductsView(),
        ],
      ),
    );
  }
} 