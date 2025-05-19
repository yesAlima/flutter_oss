import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';

class CustomerOrderDetailsController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  
  final order = Rx<OrderModel?>(null);
  final isLoading = true.obs;
  final products = <String, ProductModel>{}.obs;
  final delivery = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadOrder();
  }

  Future<void> loadOrder() async {
    isLoading.value = true;
    try {
      final orderId = Get.arguments as String;
      final fetchedOrder = await _orderService.getOrder(orderId);
      order.value = fetchedOrder;
      if (fetchedOrder != null) {
        await loadProducts(fetchedOrder);
        if (fetchedOrder.did != null) {
          await loadDelivery(fetchedOrder.did!);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load order details');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProducts(OrderModel order) async {
    final products = <String, ProductModel>{};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        products[line.id] = product;
      }
    }
    this.products.value = products;
  }

  Future<void> loadDelivery(String deliveryId) async {
    try {
      final deliveryUser = await _authService.getUser(deliveryId);
      delivery.value = deliveryUser;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load delivery information');
    }
  }

  double getOrderTotal() {
    if (order.value == null) return 0;
    double total = 0;
    for (var line in order.value!.orderlines) {
      if (line.price != null) {
        total += line.price!;
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

  Widget buildPaidBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid ? Colors.green : Colors.red,
        ),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(
          color: isPaid ? Colors.green : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Order Status Help'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order Statuses:'),
              SizedBox(height: 8),
              Text('• Pending: Your order is being processed'),
              Text('• Assigned to Delivery: A delivery person has been assigned'),
              Text('• Delivered: Your order has been delivered'),
              Text('• Cancelled: Your order has been cancelled'),
              SizedBox(height: 16),
              Text('Payment Status:'),
              SizedBox(height: 8),
              Text('• Paid: Payment has been received'),
              Text('• Unpaid: Payment is pending'),
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

  Future<void> updateOrder(OrderModel updatedOrder) async {
    order.value = updatedOrder;
    order.refresh();
  }

  Future<void> cancelOrder() async {
    if (order.value == null) return;
    await _orderService.cancelOrder(order.value!.id);
    final updatedOrder = await _orderService.getOrder(order.value!.id);
    if (updatedOrder != null) {
      updateOrder(updatedOrder);
    }
  }
} 