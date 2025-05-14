import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';
import '../services/order_service.dart';
import '../services/source_service.dart';
import '../models/source_model.dart';
import 'dart:async';

class OrderController extends GetxController {
  final _orderService = Get.find<OrderService>();
  final SourceService _sourceService = Get.find<SourceService>();
  final RxList<OrderModel> orders = <OrderModel>[].obs;
  final Rx<OrderModel?> draftOrder = Rx<OrderModel?>(null);
  final RxBool isLoading = false.obs;
  final RxList<SourceModel> sources = <SourceModel>[].obs;
  final RxBool isLoadingSources = false.obs;
  String? userId;
  StreamSubscription? _orderSub;
  StreamSubscription? _draftSub;

  @override
  void onClose() {
    _orderSub?.cancel();
    _draftSub?.cancel();
    super.onClose();
  }

  void listenToUserOrders(String userId) {
    this.userId = userId;
    _orderSub?.cancel();
    _draftSub?.cancel();

    // Listen to non-draft orders
    _orderSub = FirebaseFirestore.instance
        .collection('orders')
        .where('cid', isEqualTo: userId)
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .orderBy('orderedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      orders.value = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    });

    // Listen to draft order
    _draftSub = _orderService.getDraftOrder(userId).listen((draft) {
      draftOrder.value = draft;
    });
  }

  Future<void> payOrder(OrderModel order) async {
    await _orderService.markOrderAsPaid(order.id);
  }

  Future<void> cancelOrder(OrderModel order) async {
    await _orderService.cancelOrder(order.id);
  }

  Future<void> addToDraftOrder(String productId, int quantity) async {
    if (userId == null) return;
    await _orderService.addToDraftOrder(userId!, productId, quantity);
  }

  Future<void> updateDraftOrderQuantity(String productId, int quantity) async {
    if (userId == null) return;
    await _orderService.updateDraftOrderQuantity(userId!, productId, quantity);
  }

  Future<void> placeOrder() async {
    if (userId == null) return;
    if (draftOrder.value?.orderlines.isEmpty ?? true) {
      Get.snackbar(
        'Error',
        'Cannot place empty order',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (draftOrder.value?.address == null) {
      Get.snackbar(
        'Error',
        'Please select a delivery address before placing the order',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      await _orderService.placeOrder();
      Get.snackbar(
        'Success',
        'Order placed successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to place order: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> updateDraftOrderAddress(AddressModel address) async {
    if (userId == null) return;
    try {
      await _orderService.updateDraftOrderAddress(userId!, address);
      Get.snackbar(
        'Success',
        'Delivery address updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update delivery address: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  double getDraftOrderTotal(Map<String, ProductModel> products) {
    if (draftOrder.value == null) return 0;
    
    double total = 0;
    for (var line in draftOrder.value!.orderlines) {
      final product = products[line.id];
      if (product != null) {
        total += product.price * line.quantity;
      }
    }
    return total;
  }

  // Source management methods
  Future<void> loadSources() async {
    try {
      isLoadingSources.value = true;
      final loadedSources = await _sourceService.getAllSources();
      sources.value = loadedSources;
    } catch (e) {
      Get.snackbar('Error', 'Failed to load sources: $e');
    } finally {
      isLoadingSources.value = false;
    }
  }

  Future<void> createSource(String name, {String? description}) async {
    try {
      isLoadingSources.value = true;
      await _sourceService.createSource(name, description: description);
      await loadSources();
      Get.snackbar('Success', 'Source created successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to create source: $e');
    } finally {
      isLoadingSources.value = false;
    }
  }

  Future<void> updateSource(String id, String name, {String? description}) async {
    try {
      isLoadingSources.value = true;
      await _sourceService.updateSource(id, name, description: description);
      await loadSources();
      Get.snackbar('Success', 'Source updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update source: $e');
    } finally {
      isLoadingSources.value = false;
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      isLoadingSources.value = true;
      await _sourceService.deleteSource(id);
      await loadSources();
      Get.snackbar('Success', 'Source deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete source: $e');
    } finally {
      isLoadingSources.value = false;
    }
  }

  Future<void> createImportOrder({
    required String productId,
    required int quantity,
    required double price,
    required String sourceId,
  }) async {
    try {
      isLoading.value = true;
      await _orderService.createImportOrder(
        productId: productId,
        quantity: quantity,
        price: price,
        sourceId: sourceId,
      );
      Get.snackbar('Success', 'Import order created successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to create import order: $e');
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
    try {
      isLoading.value = true;
      // Only update the first orderline for price/quantity
      final updatedOrderlines = List<OrderLine>.from(order.orderlines);
      if (updatedOrderlines.isNotEmpty) {
        updatedOrderlines[0] = updatedOrderlines[0].copyWith(
          quantity: quantity,
          price: price,
        );
      }
      await _orderService.updateOrder(order.id, order.copyWith(
        orderlines: updatedOrderlines,
        sourceId: sourceId,
      ));
      Get.snackbar('Success', 'Import order updated successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to update import order: $e');
    } finally {
      isLoading.value = false;
    }
  }

  OrderService get orderService => _orderService;
} 