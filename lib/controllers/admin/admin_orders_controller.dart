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

class AdminOrdersController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  final SourceService _sourceService = Get.find<SourceService>();

  final searchController = TextEditingController();
  final orders = <OrderModel>[].obs;
  final isLoading = true.obs;
  final orderTotalsCache = <String, double>{}.obs;
  late final UserModel currentUser;

  // Filter state
  final selectedStatus = Rx<OrderFulfillment?>(null);
  final minTotal = Rx<double?>(null);
  final maxTotal = Rx<double?>(null);
  final minRef = Rx<int?>(null);
  final maxRef = Rx<int?>(null);
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final showPaid = true.obs;
  final showUnpaid = true.obs;
  final sortBy = 'orderedAt'.obs; // 'orderedAt', 'ref', 'total'
  final sortAsc = false.obs;

  // Full range values
  final fullMinTotal = Rx<double?>(null);
  final fullMaxTotal = Rx<double?>(null);
  final fullMinRef = Rx<int?>(null);
  final fullMaxRef = Rx<int?>(null);

  @override
  void onInit() {
    super.onInit();
    currentUser = _authService.currentUser!;
    loadOrders();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    try {
      List<OrderModel> orders;
      if (currentUser.isDelivery) {
        orders = await _orderService.getOrders(fulfillment: selectedStatus.value).first;
      } else if (currentUser.isAdmin) {
        orders = await _orderService.getAllOrders();
      } else {
        orders = await _orderService.getOrders(fulfillment: selectedStatus.value).first;
      }
      this.orders.value = orders.where((order) => order.fulfillment != OrderFulfillment.draft).toList();
      
      // Calculate full min/max for total and ref
      if (this.orders.isNotEmpty) {
        final totals = await Future.wait(this.orders.map((o) async {
          final products = await getProductsForOrder(o);
          return getOrderTotal(o, products);
        }));
        fullMinTotal.value = totals.reduce((a, b) => a < b ? a : b);
        fullMaxTotal.value = totals.reduce((a, b) => a > b ? a : b);
        final refs = this.orders.where((o) => o.ref != null).map((o) => o.ref!).toList();
        if (refs.isNotEmpty) {
          fullMinRef.value = refs.reduce((a, b) => a < b ? a : b);
          fullMaxRef.value = refs.reduce((a, b) => a > b ? a : b);
        }
      }
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

  List<OrderModel> get filteredOrders {
    var filtered = orders.where((order) {
      // Filter out import orders for non-admin and non-supplier users
      if (order.fulfillment == OrderFulfillment.import && 
          !currentUser.isAdmin && 
          !currentUser.isSupplier) {
        return false;
      }
      // Status filter
      if (selectedStatus.value != null && order.fulfillment != selectedStatus.value) {
        return false;
      }
      // Paid/unpaid filter
      if (!showPaid.value && order.paid == true) return false;
      if (!showUnpaid.value && order.paid == false) return false;
      // Reference number filter
      if (minRef.value != null && order.ref != null && order.ref! < minRef.value!) return false;
      if (maxRef.value != null && order.ref != null && order.ref! > maxRef.value!) return false;
      // OrderedAt date range
      if (startDate.value != null && order.orderedAt != null && order.orderedAt!.isBefore(startDate.value!)) return false;
      if (endDate.value != null && order.orderedAt != null && order.orderedAt!.isAfter(endDate.value!)) return false;
      return true;
    }).toList();

    // Total price filter (async, so use cache)
    filtered = filtered.where((order) {
      final total = orderTotalsCache[order.id];
      if (minTotal.value != null && total != null && total < minTotal.value!) return false;
      if (maxTotal.value != null && total != null && total > maxTotal.value!) return false;
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      if (sortBy.value == 'orderedAt') {
        cmp = (a.orderedAt ?? DateTime(1970)).compareTo(b.orderedAt ?? DateTime(1970));
      } else if (sortBy.value == 'ref') {
        cmp = (a.ref ?? 0).compareTo(b.ref ?? 0);
      } else if (sortBy.value == 'total') {
        final at = orderTotalsCache[a.id] ?? 0;
        final bt = orderTotalsCache[b.id] ?? 0;
        cmp = at.compareTo(bt);
      }
      return sortAsc.value ? cmp : -cmp;
    });
    return filtered;
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

  double getOrderTotal(OrderModel order, Map<String, ProductModel> products) {
    double total = 0;
    for (var line in order.orderlines) {
      final product = products[line.id];
      if (product != null) {
        total += product.price * line.quantity;
      }
    }
    return total;
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

  List<OrderFulfillment> get availableStatuses {
    if (currentUser.isAdmin || currentUser.isSupplier) {
      return [
        OrderFulfillment.pending,
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
        OrderFulfillment.cancelled,
        OrderFulfillment.import,
      ];
    } else if (currentUser.isDelivery) {
      return [
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
      ];
    } else {
      return [
        OrderFulfillment.pending,
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
        OrderFulfillment.cancelled,
      ];
    }
  }

  bool canViewDeliveryInfo(OrderModel order) => currentUser.isAdmin;
  
  bool canAssignDelivery(OrderModel order) => 
    currentUser.isAdmin && 
    (order.fulfillment == OrderFulfillment.pending || 
     order.fulfillment == OrderFulfillment.unfulfilled);
  
  bool canRevokeDelivery(OrderModel order) => 
    currentUser.isAdmin && 
    order.fulfillment == OrderFulfillment.unfulfilled;

  bool canUpdateStatus(OrderModel order, OrderFulfillment status) {
    if (currentUser.isDelivery && order.did != currentUser.id) return false;
    
    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        return currentUser.isAdmin && status == OrderFulfillment.cancelled;
      case OrderFulfillment.unfulfilled:
        return status == OrderFulfillment.fulfilled || 
               (currentUser.isAdmin && status == OrderFulfillment.cancelled);
      case OrderFulfillment.fulfilled:
        return status == OrderFulfillment.unfulfilled;
      case OrderFulfillment.cancelled:
      case OrderFulfillment.draft:
      case OrderFulfillment.import:
        return false;
    }
  }

  Future<void> assignDelivery(String orderId, String deliveryId) async {
    try {
      await _orderService.assignDelivery(orderId, deliveryId);
      final updatedOrder = await _orderService.getOrder(orderId);
      if (updatedOrder != null) {
        final index = orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          orders[index] = updatedOrder;
          // Update the order total in cache
          final products = await getProductsForOrder(updatedOrder);
          orderTotalsCache[orderId] = getOrderTotal(updatedOrder, products);
        }
      }
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

  Future<void> revokeDelivery(String orderId) async {
    try {
      await _orderService.revokeDelivery(orderId);
      final updatedOrder = await _orderService.getOrder(orderId);
      if (updatedOrder != null) {
        final index = orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          orders[index] = updatedOrder;
          // Update the order total in cache
          final products = await getProductsForOrder(updatedOrder);
          orderTotalsCache[orderId] = getOrderTotal(updatedOrder, products);
        }
      }
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

  Future<void> updateOrderStatus(String orderId, OrderFulfillment status) async {
    try {
      await _orderService.updateFulfillment(orderId, status);
      await loadOrders();
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

  Future<UserModel?> getUser(String userId) async {
    return await _authService.getUser(userId);
  }

  Future<List<UserModel>> getDeliveryUsers() async {
    return await _authService.getDeliveryUsers();
  }

  Future<SourceModel?> getSource(String sourceId) async {
    return await _sourceService.getSource(sourceId);
  }
  
} 