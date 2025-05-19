import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/supplier/supplier_controller.dart';
import '../auth/logout_view.dart';
import 'supplier_orders_view.dart';
import 'supplier_products_view.dart';
import '../../routes/app_routes.dart';

class SupplierView extends GetView<SupplierController> {
  const SupplierView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Dashboard'),
        bottom: TabBar(
          controller: controller.tabController,
          tabs: const [
            Tab(text: 'Orders'),
            Tab(text: 'Products'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed(AppRoutes.profile),
          ),
          const LogoutView(),
        ],
      ),
      body: TabBarView(
        controller: controller.tabController,
        children: const [
          SupplierOrdersView(),
          SupplierProductsView(),
        ],
      ),
    );
  }
} 