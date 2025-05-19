import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/delivery/delivery_controller.dart';
import '../auth/logout_view.dart';
import 'delivery_orders_view.dart';

class DeliveryView extends GetView<DeliveryController> {
  const DeliveryView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed('/profile'),
          ),
          const LogoutView(),
        ],
      ),
      body: const DeliveryOrdersView(),
    );
  }
} 