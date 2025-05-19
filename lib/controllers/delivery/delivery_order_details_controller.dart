import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';

class DeliveryOrderDetailsController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  
  final orderId = ''.obs;
  final order = Rx<OrderModel?>(null);
  final isLoading = true.obs;
  final products = <String, ProductModel>{}.obs;
  final customer = Rx<UserModel?>(null);
  final currentUser = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _authService.currentUser;
    if (Get.arguments != null) {
      orderId.value = Get.arguments;
      loadOrder();
    }
  }

  Future<void> loadOrder() async {
    isLoading.value = true;
    try {
      final fetchedOrder = await _orderService.getOrder(orderId.value);
      order.value = fetchedOrder;
      if (fetchedOrder != null) {
        await loadProducts(fetchedOrder);
        if (fetchedOrder.cid != null) {
          customer.value = await _authService.getUser(fetchedOrder.cid!);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load order details');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProducts(OrderModel order) async {
    final loadedProducts = <String, ProductModel>{};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        loadedProducts[line.id] = product;
      }
    }
    products.value = loadedProducts;
  }

  Future<void> claimOrder() async {
    try {
      if (order.value != null) {
        await _orderService.assignDelivery(orderId.value, currentUser.value!.id);
        await loadOrder();
        Get.snackbar('Success', 'Order claimed successfully', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to claim order');
    }
  }

  Future<void> markAsDelivered() async {
    try {
      if (order.value != null) {
        await _orderService.updateFulfillment(orderId.value, OrderFulfillment.fulfilled);
        await loadOrder();
        Get.snackbar('Success', 'Order marked as delivered', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark order as delivered');
    }
  }

  Future<void> revertToUnfulfilled() async {
    try {
      if (order.value != null) {
        await _orderService.updateFulfillment(orderId.value, OrderFulfillment.unfulfilled);
        await loadOrder();
        Get.snackbar('Success', 'Order reverted to unfulfilled', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to revert order status');
    }
  }

  double getOrderTotal() {
    double total = 0;
    if (order.value != null) {
      for (final line in order.value!.orderlines) {
        final product = products[line.id];
        if (product != null) {
          total += product.price * line.quantity;
        }
      }
    }
    return total;
  }

  Color getStatusColor(OrderFulfillment status) {
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

  String getStatusText(OrderFulfillment status) {
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

  void showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delivery Order Details Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                'Order Management',
                'As a delivery personnel, you can:',
                [
                  'View assigned order details',
                  'Mark orders as delivered',
                  'View customer information',
                  'View delivery location',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Orders can have the following statuses:',
                [
                  'Unfulfilled: Orders assigned to you',
                  'Fulfilled: Successfully delivered orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Actions',
                'Available actions for each status:',
                [
                  'Unfulfilled: Mark as delivered',
                  'Fulfilled: No actions available',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String subtitle, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...points.map((point) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  point,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }
} 