import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/category_service.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../profile_view.dart';
import '../auth/logout_view.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_products_view.dart';
import '../../routes/app_routes.dart';

class CustomerView extends StatefulWidget {
  const CustomerView({super.key});

  @override
  State<CustomerView> createState() => _CustomerViewState();
}

class _CustomerViewState extends State<CustomerView> {
  final _authService = Get.find<AuthService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Shopping System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Get.toNamed(AppRoutes.customerCart),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            onPressed: () => Get.toNamed(AppRoutes.customerOrders),
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => Get.toNamed(AppRoutes.customerAddresses),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed(AppRoutes.profile),
          ),
          const LogoutView(),
        ],
      ),
      body: const CustomerProductsView(),
    );
  }
} 