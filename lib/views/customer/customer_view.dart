import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/customer/customer_controller.dart';
import '../auth/logout_view.dart';
import 'customer_products_view.dart';

class CustomerView extends GetView<CustomerController> {
  const CustomerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Online Shopping System'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Get.toNamed('/customer/cart'),
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            onPressed: () => Get.toNamed('/customer/orders'),
          ),
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => Get.toNamed('/customer/addresses'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed('/profile'),
          ),
          const LogoutView(),
        ],
      ),
      body: const CustomerProductsView(),
    );
  }
} 