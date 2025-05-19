import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import 'package:intl/intl.dart';

class DeliveryOrdersController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  
  final searchController = TextEditingController();
  final orders = <OrderModel>[].obs;
  final isLoading = true.obs;
  final selectedStatus = Rx<OrderFulfillment?>(null);
  final currentUser = Rx<UserModel?>(null);
  
  // Filter state
  final minTotal = Rx<double?>(null);
  final maxTotal = Rx<double?>(null);
  final minRef = Rx<int?>(null);
  final maxRef = Rx<int?>(null);
  final startDate = Rx<DateTime?>(null);
  final endDate = Rx<DateTime?>(null);
  final sortBy = 'orderedAt'.obs;
  final sortAsc = false.obs;
  
  // Cache for min/max values
  final fullMinTotal = Rx<double?>(null);
  final fullMaxTotal = Rx<double?>(null);
  final fullMinRef = Rx<int?>(null);
  final fullMaxRef = Rx<int?>(null);
  
  final orderTotalsCache = <String, double>{}.obs;

  // Delivery-specific status filter options
  List<OrderFulfillment> get deliveryStatuses => [
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

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    try {
      final userId = currentUser.value!.id;
      final allOrders = await _orderService.getAllOrders();
      orders.value = allOrders.where((order) =>
        order.fulfillment != OrderFulfillment.draft &&
        (order.did == userId || order.fulfillment == OrderFulfillment.pending)
      ).toList();
      
      // Calculate full min/max for total and ref
      if (orders.isNotEmpty) {
        final totals = await Future.wait(orders.map((o) async {
          final products = await _getProductsForOrder(o);
          return _getOrderTotal(o, products);
        }));
        fullMinTotal.value = totals.reduce((a, b) => a < b ? a : b);
        fullMaxTotal.value = totals.reduce((a, b) => a > b ? a : b);
        final refs = orders.where((o) => o.ref != null).map((o) => o.ref!).toList();
        if (refs.isNotEmpty) {
          fullMinRef.value = refs.reduce((a, b) => a < b ? a : b);
          fullMaxRef.value = refs.reduce((a, b) => a > b ? a : b);
        }
      }
      await updateOrderTotalsCache();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateOrder(String orderId, OrderModel updatedOrder) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      orders[index] = updatedOrder;
      // Update the order total in cache
      final products = await _getProductsForOrder(updatedOrder);
      orderTotalsCache[orderId] = _getOrderTotal(updatedOrder, products);
    }
  }

  List<OrderModel> get filteredOrders {
    var filtered = orders.where((order) {
      // Status filter
      if (selectedStatus.value != null && order.fulfillment != selectedStatus.value) {
        return false;
      }
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

  List<OrderModel> getTabOrders(int tabIndex) {
    final userId = currentUser.value!.id;
    switch (tabIndex) {
      case 0: // All
        return filteredOrders.where((order) =>
          order.fulfillment == OrderFulfillment.pending ||
          (order.did == userId && order.fulfillment != OrderFulfillment.draft && order.fulfillment != OrderFulfillment.pending)
        ).toList();
      case 1: // Pending
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.pending).toList();
      case 2: // Claimed (Unfulfilled)
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.unfulfilled && order.did == userId).toList();
      case 3: // Delivered (Fulfilled)
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.fulfilled && order.did == userId).toList();
      case 4: // Cancelled
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.cancelled && order.did == userId).toList();
      default:
        return [];
    }
  }

  List<OrderModel> getTabOrdersByStatus() {
    if (selectedStatus.value == null) {
      return filteredOrders;
    } else {
      return filteredOrders.where((order) => order.fulfillment == selectedStatus.value).toList();
    }
  }

  Future<void> updateOrderTotalsCache() async {
    final Map<String, double> totals = {};
    for (final order in orders) {
      final products = await _getProductsForOrder(order);
      totals[order.id] = _getOrderTotal(order, products);
    }
    orderTotalsCache.value = totals;
  }

  Future<Map<String, ProductModel>> _getProductsForOrder(OrderModel order) async {
    final Map<String, ProductModel> products = {};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        products[line.id] = product;
      }
    }
    return products;
  }

  double _getOrderTotal(OrderModel order, Map<String, ProductModel> products) {
    double total = 0;
    for (var line in order.orderlines) {
      final product = products[line.id];
      if (product != null) {
        total += product.price * line.quantity;
      }
    }
    return total;
  }

  Future<void> claimOrder(String orderId) async {
    try {
      await _orderService.assignDelivery(orderId, currentUser.value!.id);
      final updatedOrder = await _orderService.getOrder(orderId);
      if (updatedOrder != null) {
        await updateOrder(orderId, updatedOrder);
        Get.snackbar('Success', 'Order claimed successfully', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to claim order');
    }
  }

  Future<void> markAsDelivered(String orderId) async {
    try {
      await _orderService.updateFulfillment(orderId, OrderFulfillment.fulfilled);
      final updatedOrder = await _orderService.getOrder(orderId);
      if (updatedOrder != null) {
        await updateOrder(orderId, updatedOrder);
        Get.snackbar('Success', 'Order marked as delivered', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to mark order as delivered');
    }
  }

  Future<void> revertToUnfulfilled(String orderId) async {
    try {
      await _orderService.updateFulfillment(orderId, OrderFulfillment.unfulfilled);
      final updatedOrder = await _orderService.getOrder(orderId);
      if (updatedOrder != null) {
        await updateOrder(orderId, updatedOrder);
        Get.snackbar('Success', 'Order reverted to unfulfilled', snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to revert order status');
    }
  }

  void setStatus(OrderFulfillment? status) {
    selectedStatus.value = status;
  }

  void setDateRange(DateTime? start, DateTime? end) {
    startDate.value = start;
    endDate.value = end;
  }

  void setTotalRange(double? min, double? max) {
    minTotal.value = min;
    maxTotal.value = max;
  }

  void setRefRange(int? min, int? max) {
    minRef.value = min;
    maxRef.value = max;
  }

  void setSorting(String field, bool ascending) {
    sortBy.value = field;
    sortAsc.value = ascending;
  }

  void clearFilters() {
    selectedStatus.value = null;
    minTotal.value = null;
    maxTotal.value = null;
    minRef.value = null;
    maxRef.value = null;
    startDate.value = null;
    endDate.value = null;
    sortBy.value = 'orderedAt';
    sortAsc.value = false;
    searchController.clear();
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
        return 'Claimed';
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
        title: const Text('Delivery Orders Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Order Management',
                'As a delivery personnel, you can:',
                [
                  'View orders assigned to you',
                  'Mark orders as delivered',
                  'Revert delivered orders to unfulfilled if needed',
                  'Filter and search your orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Orders can have the following statuses:',
                [
                  'Unfulfilled: Orders assigned to you for delivery',
                  'Fulfilled: Successfully delivered orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Actions',
                'Available actions for each status:',
                [
                  'Unfulfilled: Mark as delivered',
                  'Fulfilled: Revert to unfulfilled if needed',
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

  void showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinTotal = minTotal.value;
    final tempMaxTotal = maxTotal.value;
    final tempMinRef = minRef.value;
    final tempMaxRef = maxRef.value;
    final tempStartDate = startDate.value;
    final tempEndDate = endDate.value;
    final tempSortBy = sortBy.value;
    final tempSortAsc = sortAsc.value;

    // Create Rx variables for the dialog
    final dialogMinTotal = (tempMinTotal ?? fullMinTotal.value ?? 0.0).obs;
    final dialogMaxTotal = (tempMaxTotal ?? fullMaxTotal.value ?? 0.0).obs;
    final dialogMinRef = (tempMinRef ?? fullMinRef.value ?? 1).obs;
    final dialogMaxRef = (tempMaxRef ?? fullMaxRef.value ?? 1).obs;
    final dialogStartDate = tempStartDate.obs;
    final dialogEndDate = tempEndDate.obs;
    final dialogSortBy = tempSortBy.obs;
    final dialogSortAsc = tempSortAsc.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('Filter Orders'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Price (BD)', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinTotal.value, dialogMaxTotal.value),
                min: fullMinTotal.value ?? 0.0,
                max: fullMaxTotal.value ?? 1.0,
                divisions: ((fullMaxTotal.value ?? 1.0) - (fullMinTotal.value ?? 0.0)).round().clamp(1, 100),
                labels: RangeLabels(
                  '${dialogMinTotal.value.floor()} BD',
                  '${dialogMaxTotal.value.ceil()} BD',
                ),
                onChanged: (values) {
                  dialogMinTotal.value = values.start;
                  dialogMaxTotal.value = values.end;
                },
              )),
              const SizedBox(height: 16),
              const Text('Reference Number', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinRef.value.toDouble(), dialogMaxRef.value.toDouble()),
                min: (fullMinRef.value ?? 1).toDouble(),
                max: (fullMaxRef.value ?? 1).toDouble(),
                divisions: ((fullMaxRef.value ?? 1) - (fullMinRef.value ?? 1)).clamp(1, 100),
                labels: RangeLabels(
                  dialogMinRef.value.toString(),
                  dialogMaxRef.value.toString(),
                ),
                onChanged: (values) {
                  dialogMinRef.value = values.start.round();
                  dialogMaxRef.value = values.end.round();
                },
              )),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        Obx(() => OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: Get.context!,
                              initialDate: dialogStartDate.value ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) dialogStartDate.value = picked;
                          },
                          child: Text(dialogStartDate.value != null ? DateFormat('y-MM-dd').format(dialogStartDate.value!) : 'Any'),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        Obx(() => OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: Get.context!,
                              initialDate: dialogEndDate.value ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) dialogEndDate.value = picked;
                          },
                          child: Text(dialogEndDate.value != null ? DateFormat('y-MM-dd').format(dialogEndDate.value!) : 'Any'),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  Obx(() => ChoiceChip(
                    label: const Text('Order Date'),
                    selected: dialogSortBy.value == 'orderedAt',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'orderedAt';
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Reference Number'),
                    selected: dialogSortBy.value == 'ref',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'ref';
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Total Price'),
                    selected: dialogSortBy.value == 'total',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'total';
                    },
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => SwitchListTile(
                title: const Text('Sort Ascending'),
                value: dialogSortAsc.value,
                onChanged: (value) => dialogSortAsc.value = value,
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Clear all filters to their default values
              dialogMinTotal.value = fullMinTotal.value ?? 0.0;
              dialogMaxTotal.value = fullMaxTotal.value ?? 1.0;
              dialogMinRef.value = fullMinRef.value ?? 1;
              dialogMaxRef.value = fullMaxRef.value ?? 1;
              dialogStartDate.value = null;
              dialogEndDate.value = null;
              dialogSortBy.value = 'orderedAt';
              dialogSortAsc.value = false;
              Get.back();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () async {
              minTotal.value = dialogMinTotal.value;
              maxTotal.value = dialogMaxTotal.value;
              minRef.value = dialogMinRef.value;
              maxRef.value = dialogMaxRef.value;
              startDate.value = dialogStartDate.value;
              endDate.value = dialogEndDate.value;
              sortBy.value = dialogSortBy.value;
              sortAsc.value = dialogSortAsc.value;
              update();
              await updateOrderTotalsCache();
              Get.back();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
} 