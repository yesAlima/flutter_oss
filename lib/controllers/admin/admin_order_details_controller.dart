import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';

class AdminOrderDetailsController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();

  final order = Rx<OrderModel?>(null);
  final isLoading = true.obs;
  final products = <String, ProductModel>{}.obs;
  late final UserModel currentUser;

  @override
  void onInit() {
    super.onInit();
    currentUser = _authService.currentUser!;
    final orderId = Get.arguments as String;
    loadOrder(orderId);
  }

  Future<void> loadOrder(String orderId) async {
    isLoading.value = true;
    try {
      _orderService.getOrderById(orderId).listen((orderData) {
        order.value = orderData;
        if (orderData != null) {
          loadProducts(orderData);
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load order details',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadProducts(OrderModel order) async {
    final productMap = <String, ProductModel>{};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        productMap[line.id] = product;
      }
    }
    products.value = productMap;
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
        return 'Unfulfilled';
      case OrderFulfillment.fulfilled:
        return 'Fulfilled';
      case OrderFulfillment.cancelled:
        return 'Cancelled';
      case OrderFulfillment.draft:
        return 'Draft';
      case OrderFulfillment.import:
        return 'Import';
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

  bool canViewDeliveryInfo() {
    return currentUser.isAdmin || currentUser.isDelivery;
  }

  bool canAssignDelivery() {
    return currentUser.isAdmin &&
      (order.value?.fulfillment == OrderFulfillment.pending ||
       order.value?.fulfillment == OrderFulfillment.unfulfilled);
  }

  Future<void> assignDelivery(String deliveryId) async {
    if (!canAssignDelivery()) return;

    try {
      await _orderService.assignDelivery(order.value!.id, deliveryId);
      Get.snackbar(
        'Success',
        'Delivery assigned successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to assign delivery: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateOrderStatus(OrderFulfillment status) async {
    if (!currentUser.isAdmin) return;

    try {
      await _orderService.updateFulfillment(order.value!.id, status);
      Get.snackbar(
        'Success',
        'Order status updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update order status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> toggleOrderPaid() async {
    if (!currentUser.isAdmin) return;

    try {
      if (order.value?.paid ?? false) {
        await _orderService.updateOrder(
          order.value!.id,
          order.value!.copyWith(paid: false),
        );
      } else {
        await _orderService.markOrderAsPaid(order.value!.id);
      }
      Get.snackbar(
        'Success',
        'Order payment status updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update order payment status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> deleteOrder() async {
    if (!currentUser.isAdmin) return;

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _orderService.deleteOrder(order.value!.id);
      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Order deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete order: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<UserModel?> getUser(String userId) async {
    return await _authService.getUser(userId);
  }

  Future<List<UserModel>> getDeliveryUsers() async {
    return await _authService.getDeliveryUsers();
  }

  Future<void> revokeDelivery(String orderId) async {
    try {
      await _orderService.revokeDelivery(orderId);
      await loadOrder(orderId);
      Get.snackbar(
        'Success',
        'Delivery removed and order reverted to pending',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove delivery: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
} 