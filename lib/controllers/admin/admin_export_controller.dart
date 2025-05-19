import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';
import '../../services/export_service.dart';

class AdminExportController extends GetxController {
  final AnalyticsService _analyticsService = Get.find<AnalyticsService>();
  final ExportService _exportService = Get.find<ExportService>();

  final isLoading = false.obs;
  final selectedFormat = 'CSV'.obs;
  final formats = ['CSV', 'Excel', 'PDF'];

  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();
  DateTime? minDate;
  DateTime? maxDate;

  @override
  void onInit() {
    super.onInit();
    _initDateRange();
  }

  Future<void> _initDateRange() async {
    isLoading.value = true;
    try {
      final firstOrderDate = await _analyticsService.getFirstOrderDate();
      minDate = firstOrderDate;
      maxDate = DateTime.now();
      final now = DateTime.now();
      startDate.value = DateTime(now.year, now.month, now.day, 0, 0);
      endDate.value = DateTime(now.year, now.month, now.day, 23, 59);
      update();
    } catch (e) {
      // fallback
      minDate = DateTime(2020, 1, 1);
      maxDate = DateTime.now();
      final now = DateTime.now();
      startDate.value = DateTime(now.year, now.month, now.day, 0, 0);
      endDate.value = DateTime(now.year, now.month, now.day, 23, 59);
      update();
    } finally {
      isLoading.value = false;
    }
  }

  void setStartDate(DateTime date) {
    startDate.value = date;
    update();
  }

  void setEndDate(DateTime date) {
    endDate.value = date;
    update();
  }

  void setFormat(String format) {
    selectedFormat.value = format;
    update();
  }

  Future<void> exportOrders() async {
    isLoading.value = true;
    try {
      switch (selectedFormat.value) {
        case 'CSV':
          final csv = await _analyticsService.exportOrdersToCSV(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          await _exportService.saveRawCsv('orders_export.csv', csv);
          break;
        case 'Excel':
          await _exportService.exportOrdersToExcel(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
        case 'PDF':
          await _exportService.exportOrdersToPdf(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
      }
      Get.snackbar(
        'Success',
        'Orders exported successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to export orders: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportProducts() async {
    isLoading.value = true;
    try {
      switch (selectedFormat.value) {
        case 'CSV':
          final csv = await _analyticsService.exportProductsToCSV(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          await _exportService.saveRawCsv('products_export.csv', csv);
          break;
        case 'Excel':
          await _exportService.exportProductsToExcel(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
        case 'PDF':
          await _exportService.exportProductsToPdf(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
      }
      Get.snackbar(
        'Success',
        'Products exported successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to export products: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportUsers() async {
    isLoading.value = true;
    try {
      switch (selectedFormat.value) {
        case 'CSV':
          final csv = await _analyticsService.exportUsersToCSV(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          await _exportService.saveRawCsv('users_export.csv', csv);
          break;
        case 'Excel':
          await _exportService.exportUsersToExcel(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
        case 'PDF':
          await _exportService.exportUsersToPdf(
            startDate: startDate.value,
            endDate: endDate.value,
          );
          break;
      }
      Get.snackbar(
        'Success',
        'Users exported successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to export users: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportAnalytics() async {
    isLoading.value = true;
    try {
      final analytics = await _analyticsService.exportAnalytics(
        type: 'sales',
        startDate: startDate.value,
        endDate: endDate.value,
      );
      switch (selectedFormat.value) {
        case 'CSV':
          await _exportService.exportToCsv('analytics_report.csv', analytics, startDate: startDate.value, endDate: endDate.value);
          break;
        case 'Excel':
          await _exportService.exportAnalyticsToExcel(analytics, startDate: startDate.value, endDate: endDate.value);
          break;
        case 'PDF':
          await _exportService.exportAnalyticsToPdf(analytics, startDate: startDate.value, endDate: endDate.value);
          break;
      }
      Get.snackbar(
        'Success',
        'Analytics exported successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to export analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }
} 