import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';

class CustomerOrdersController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  final UserService _userService = Get.find<UserService>();
  
  final orders = <OrderModel>[].obs;
  final isLoading = true.obs;
  final selectedStatus = Rx<OrderFulfillment?>(null);
  final orderTotalsCache = <String, double>{}.obs;
  final currentUser = Rx<UserModel?>(null);

  // Available statuses for filtering
  List<OrderFulfillment> get availableStatuses => [
    OrderFulfillment.pending,
    OrderFulfillment.unfulfilled,
    OrderFulfillment.fulfilled,
    OrderFulfillment.cancelled,
  ];

  @override
  void onInit() {
    super.onInit();
    currentUser.value = _authService.currentUser;
    loadOrders();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    try {
      final userId = currentUser.value!.id;
      final ordersStream = _orderService.getOrders(fulfillment: selectedStatus.value);
      ordersStream.listen((allOrders) {
        orders.value = allOrders.where((order) => 
          order.cid == userId && 
          order.fulfillment != OrderFulfillment.draft
        ).toList();
        updateOrderTotalsCache();
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateOrderTotalsCache() async {
    final Map<String, double> totals = {};
    for (final order in orders) {
      final products = await getProductsForOrder(order);
      totals[order.id] = getOrderTotal(order, products);
    }
    orderTotalsCache.value = totals;
  }

  Future<Map<String, ProductModel>> getProductsForOrder(OrderModel order) async {
    final Map<String, ProductModel> products = {};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        products[line.id] = product;
      }
    }
    return products;
  }

  double getOrderTotal(OrderModel order, Map<String, ProductModel> products) {
    double total = 0;
    for (var line in order.orderlines) {
      if (line.price != null) {
        total += line.price!;
      }
    }
    return total;
  }

  List<OrderModel> get filteredOrders {
    return orders.where((order) {
      if (selectedStatus.value != null && order.fulfillment != selectedStatus.value) {
        return false;
      }
      return true;
    }).toList();
  }

  void setStatus(OrderFulfillment? status) {
    selectedStatus.value = status;
    loadOrders();
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
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(
          color: isPaid ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<List<AddressModel>> getCustomerAddresses() async {
    final user = _authService.currentUser;
    if (user == null) return [];

    final customer = await _userService.getUser(user.id);
    if (customer == null) return [];

    return customer.addresses;
  }

  void updateOrderInList(OrderModel updatedOrder) {
    final index = orders.indexWhere((o) => o.id == updatedOrder.id);
    if (index != -1) {
      orders[index] = updatedOrder;
      orders.refresh();
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await _orderService.cancelOrder(orderId);
    final updatedOrder = await _orderService.getOrder(orderId);
    if (updatedOrder != null) {
      updateOrderInList(updatedOrder);
    }
  }
} 