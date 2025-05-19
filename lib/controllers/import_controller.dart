import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/source_model.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../services/source_service.dart';
import '../services/product_service.dart';

class ImportController extends GetxController {
  final OrderService _orderService = Get.find<OrderService>();
  final SourceService _sourceService = Get.find<SourceService>();
  final ProductService _productService = Get.find<ProductService>();
  
  final formKey = GlobalKey<FormState>();
  final quantityController = TextEditingController();
  final priceController = TextEditingController();
  final selectedSource = Rx<SourceModel?>(null);
  final sources = <SourceModel>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadSources();
  }

  @override
  void onClose() {
    quantityController.dispose();
    priceController.dispose();
    super.onClose();
  }

  Future<void> loadSources() async {
    try {
      final loadedSources = await _sourceService.getAllSources();
      sources.value = loadedSources;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load sources');
    }
  }

  void initializeForEdit(OrderModel order) {
    if (order.orderlines.isNotEmpty) {
      quantityController.text = order.orderlines[0].quantity.toString();
      priceController.text = order.orderlines[0].price?.toString() ?? '';
    }
    if (order.sourceId != null) {
      final source = sources.firstWhereOrNull((s) => s.id == order.sourceId);
      if (source != null) {
        selectedSource.value = source;
      }
    }
  }

  double get totalPrice {
    final qty = int.tryParse(quantityController.text) ?? 0;
    final price = double.tryParse(priceController.text) ?? 0.0;
    return qty * price;
  }

  Future<void> createImportOrder({
    required String productId,
    required int quantity,
    required double price,
    required String sourceId,
  }) async {
    isLoading.value = true;
    try {
      await _orderService.createImportOrder(
        productId: productId,
        quantity: quantity,
        price: price,
        sourceId: sourceId,
      );
      Get.back();
      Get.snackbar('Success', 'Import order created successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to create import order');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateImportOrder({
    required OrderModel order,
    required int quantity,
    required double price,
    required String sourceId,
  }) async {
    isLoading.value = true;
    try {
      // Get the current product stock
      final product = await _productService.getProduct(order.orderlines[0].id);
      if (product == null) {
        throw Exception('Product not found');
      }

      // Calculate the stock difference
      final oldQuantity = order.orderlines[0].quantity;
      final stockDifference = quantity - oldQuantity;

      // Check if the update would result in negative stock
      if (product.stock + stockDifference < 0) {
        throw Exception('Cannot update import order: would result in negative stock');
      }

      // Update the order
      final updatedOrder = order.copyWith(
        sourceId: sourceId,
        orderlines: [
          OrderLine(
            id: order.orderlines[0].id,
            quantity: quantity,
            price: price,
          ),
        ],
      );
      await _orderService.updateOrder(order.id, updatedOrder);

      // Adjust the stock
      if (stockDifference != 0) {
        if (stockDifference > 0) {
          await _productService.increaseStock(order.orderlines[0].id, stockDifference);
        } else {
          await _productService.decreaseStock(order.orderlines[0].id, -stockDifference);
        }
      }

      Get.back();
      Get.snackbar('Success', 'Import order updated successfully');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void setSource(SourceModel? source) {
    selectedSource.value = source;
  }

  void clearForm() {
    quantityController.clear();
    priceController.clear();
    selectedSource.value = null;
  }

  bool validateForm() {
    if (formKey.currentState?.validate() ?? false) {
      if (selectedSource.value == null) {
        Get.snackbar('Error', 'Please select a source');
        return false;
      }
      return true;
    }
    return false;
  }
} 