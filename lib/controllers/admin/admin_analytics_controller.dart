import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';

class AdminAnalyticsController extends GetxController {
  final AnalyticsService _analyticsService = Get.find<AnalyticsService>();

  final isLoading = false.obs;
  final analytics = <String, dynamic>{}.obs;

  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();
  DateTime? minDate;
  DateTime? maxDate;

  // Computed values for the dashboard
  double get totalRevenue => analytics['totalRevenue'] as double? ?? 0.0;
  double get totalImportCost => analytics['totalImportCost'] as double? ?? 0.0;
  double get totalProfit => analytics['totalProfit'] as double? ?? 0.0;
  int get totalOrders => analytics['totalOrders'] as int? ?? 0;
  double get averageOrderValue => analytics['averageOrderValue'] as double? ?? 0.0;
  Map<String, dynamic> get salesByDay => analytics['salesByDay'] as Map<String, dynamic>? ?? {};
  Map<String, dynamic> get productPerformance => analytics['productPerformance'] as Map<String, dynamic>? ?? {};

  // Helper methods for formatting
  String formatCurrency(double value) => '${value.toStringAsFixed(3)} BD';
  String formatPercentage(double value) => '${value.toStringAsFixed(1)}%';
  
  // Get top performing products
  List<MapEntry<String, dynamic>> get topProducts {
    final products = productPerformance.entries.toList();
    products.sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));
    return products.take(5).toList();
  }

  // Helper to get profit for a product
  double getProductProfit(Map<String, dynamic> data) {
    if (data.containsKey('profit')) {
      return data['profit'] as double;
    }
    final revenue = data['revenue'] as double? ?? 0.0;
    final importCost = data['importCost'] as double? ?? 0.0;
    return revenue - importCost;
  }

  // Get sales trend data for charts
  List<Map<String, dynamic>> get salesTrendData {
    final sales = salesByDay.entries.toList();
    sales.sort((a, b) => a.key.compareTo(b.key));
    return sales.map((entry) => {
      'date': entry.key,
      'revenue': entry.value,
    }).toList();
  }

  // Get profit margin
  double get profitMargin {
    if (totalRevenue == 0) return 0;
    return (totalProfit / totalRevenue) * 100;
  }

  @override
  void onInit() {
    super.onInit();
    _initDateRange();
  }

  Future<void> _initDateRange() async {
    isLoading.value = true;
    try {
      // Fetch the first order date
      final firstOrderDate = await _analyticsService.getFirstOrderDate();
      minDate = firstOrderDate;
      maxDate = DateTime.now();
      // Default: today 00:00 to today 23:59
      final now = DateTime.now();
      startDate.value = DateTime(now.year, now.month, now.day, 0, 0);
      endDate.value = DateTime(now.year, now.month, now.day, 23, 59);
      await loadAnalytics();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to initialize analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadAnalytics() async {
    isLoading.value = true;
    try {
      final analyticsData = await _analyticsService.getSalesAnalytics(
        startDate: startDate.value,
        endDate: endDate.value,
      );
      analytics.value = analyticsData;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void setStartDate(DateTime date) {
    startDate.value = date;
    loadAnalytics();
  }

  void setEndDate(DateTime date) {
    endDate.value = date;
    loadAnalytics();
  }
} 