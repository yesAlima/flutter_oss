import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/source_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/source_service.dart';

class SupplierOrderDetailsController extends GetxController {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final _sourceService = Get.find<SourceService>();
  
  final Rx<OrderModel?> order = Rx<OrderModel?>(null);
  final RxBool isLoading = true.obs;
  final Rx<Map<String, ProductModel>> products = Rx<Map<String, ProductModel>>({});
  final Rx<UserModel?> customer = Rx<UserModel?>(null);
  final Rx<UserModel?> deliveryPerson = Rx<UserModel?>(null);
  final Rx<SourceModel?> source = Rx<SourceModel?>(null);

  @override
  void onInit() {
    super.onInit();
    final orderId = Get.arguments as String;
    loadOrder(orderId);
  }

  Future<void> loadOrder(String orderId) async {
    isLoading.value = true;
    try {
      final loadedOrder = await _orderService.getOrder(orderId);
      if (loadedOrder != null) {
        order.value = loadedOrder;
        await _loadRelatedData(loadedOrder);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load order details');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadRelatedData(OrderModel order) async {
    try {
      // Load products
      final Map<String, ProductModel> loadedProducts = {};
      for (final line in order.orderlines) {
        final product = await _productService.getProduct(line.id);
        if (product != null) {
          loadedProducts[line.id] = product;
        }
      }
      products.value = loadedProducts;

      // Load customer if available
      if (order.cid != null) {
        customer.value = await _authService.getUser(order.cid!);
      }

      // Load delivery person if available
      if (order.did != null) {
        deliveryPerson.value = await _authService.getUser(order.did!);
      }

      // Load source if it's an import order
      if (order.fulfillment == OrderFulfillment.import && order.sourceId != null) {
        source.value = await _sourceService.getSource(order.sourceId!);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load related data');
    }
  }

  double getOrderTotal() {
    if (order.value == null) return 0;
    double total = 0;
    for (var line in order.value!.orderlines) {
      total += line.price ?? 0;
    }
    return total;
  }

  double getUnitPrice(OrderLine line) {
    if (line.quantity == 0) return 0;
    return (line.price ?? 0) / line.quantity;
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
      case OrderFulfillment.import:
        return Colors.purple;
      case OrderFulfillment.draft:
        return Colors.grey;
    }
  }

  void showHelpDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Order Details Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                'Order Management',
                'View detailed information about the order, including customer details, delivery information, and order items.',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'The current status of the order:\n'
                '• Pending: Order is waiting to be processed\n'
                '• Assigned to Delivery: Order is assigned to a delivery person\n'
                '• Delivered: Order has been successfully delivered\n'
                '• Cancelled: Order has been cancelled\n'
                '• Import: Order is an import order',
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Available Actions',
                '• View customer details\n'
                '• View delivery information\n'
                '• View order items and quantities\n'
                '• View order total and payment status',
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

  Widget _buildHelpSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
} 