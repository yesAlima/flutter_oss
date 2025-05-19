import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/analytics_service.dart';

class AdminController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final AnalyticsService _analyticsService = Get.find<AnalyticsService>();

  final orders = <OrderModel>[].obs;
  final isLoading = true.obs;
  final totalOrders = 0.obs;
  final totalProducts = 0.obs;
  final totalUsers = 0.obs;
  final totalRevenue = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
    loadAnalytics();
  }

  Future<void> loadOrders() async {
    isLoading.value = true;
    try {
      final allOrders = await _orderService.getAllOrders();
      orders.value = allOrders.where((order) => order.fulfillment != OrderFulfillment.draft).toList();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load orders',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAnalytics() async {
    try {
      final analytics = await _analyticsService.getSalesAnalytics();
      totalOrders.value = analytics['totalOrders'] as int;
      totalRevenue.value = analytics['totalRevenue'] as double;

      final products = await _analyticsService.getTotalProducts();
      final users = await _analyticsService.getTotalUsers();
      totalProducts.value = products;
      totalUsers.value = users;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
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
} 