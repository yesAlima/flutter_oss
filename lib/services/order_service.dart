import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'product_service.dart';
import 'user_service.dart';
import '../routes/app_routes.dart';

class OrderService extends GetxService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ProductService _productService;
  final UserService _userService;
  OrderService(this._firestore, this._auth, this._productService, this._userService);

  final String _collection = 'orders';

  @override
  void onInit() {
    super.onInit();
    _ensureAllCustomersHaveDraftOrders();
  }

  Future<void> _ensureAllCustomersHaveDraftOrders() async {
    final customers = await _firestore.collection('customers').get();
    
    for (final customerDoc in customers.docs) {
      final customer = UserModel.fromFirestore(customerDoc);
      
      // Check if customer has a draft order
      final draftQuery = await _firestore
          .collection('orders')
          .where('cid', isEqualTo: customer.id)
          .where('fulfillment', isEqualTo: 'draft')
          .get();

      if (draftQuery.docs.isEmpty) {
        // Create a new draft order for the customer
        await _firestore.collection('orders').add({
          'cid': customer.id,
          'orderlines': [],
          'fulfillment': 'draft',
          'paid': false,
        });
      }
    }
  }

  Stream<OrderModel?> getOrderById(String orderId) {
    return _firestore
        .collection(_collection)
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  Stream<List<OrderModel>> getOrders({
    OrderFulfillment? fulfillment,
    String? userId,
  }) {
    final user = _auth.currentUser;
    
    if (user == null) {
      return Stream.value([]);
    }

    Query query = _firestore.collection(_collection);
    
    // Filter based on user role and fulfillment status
    final userModel = UserModel.fromFirebaseUser(user);
    if (userModel.isDelivery) {
      query = query.where('did', isEqualTo: user.uid);
      if (fulfillment != null) {
        query = query.where('fulfillment', isEqualTo: fulfillment.toString().split('.').last);
      }
    } else if (userModel.isAdmin || userModel.isSupplier) {
      if (fulfillment != null) {
        query = query.where('fulfillment', isEqualTo: fulfillment.toString().split('.').last);
      }
      if (userId != null) {
        query = query.where('cid', isEqualTo: userId);
      }
    } else {
      // For other roles, only show their own orders
      query = query.where('cid', isEqualTo: user.uid);
      if (fulfillment != null) {
        query = query.where('fulfillment', isEqualTo: fulfillment.toString().split('.').last);
      }
    }
    
    return query
        .orderBy('ref', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<OrderModel>> getPendingOrders() {
    return _firestore
        .collection(_collection)
        .where('fulfillment', isEqualTo: OrderFulfillment.pending.toString().split('.').last)
        .orderBy('ref', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Future<void> assignDelivery(String orderId, String deliveryId) async {
    final order = await getOrder(orderId);
    if (order == null) throw Exception('Order not found');
    
    if (order.fulfillment != OrderFulfillment.pending && order.fulfillment != OrderFulfillment.unfulfilled) {
      throw Exception('Can only assign delivery to pending or unfulfilled orders');
    }

    await _firestore.collection(_collection).doc(orderId).update({
      'did': deliveryId,
      'fulfillment': OrderFulfillment.unfulfilled.toString().split('.').last,
    });
  }

  Future<void> revokeDelivery(String orderId) async {
    final order = await getOrder(orderId);
    if (order == null) throw Exception('Order not found');
    
    if (order.fulfillment != OrderFulfillment.unfulfilled) {
      throw Exception('Can only revoke delivery from unfulfilled orders');
    }

    await _firestore.collection(_collection).doc(orderId).update({
      'did': null,
      'fulfillment': OrderFulfillment.pending.toString().split('.').last,
    });
  }

  Future<void> _returnStockForOrder(OrderModel order) async {
    for (var line in order.orderlines) {
      await _productService.increaseStock(line.id, line.quantity);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    final order = await getOrder(orderId);
    if (order == null) throw Exception('Order not found');

    // Return stock for cancelled orders
    await _returnStockForOrder(order);

    await _firestore.collection(_collection).doc(orderId).update({
      'fulfillment': OrderFulfillment.cancelled.toString().split('.').last,
      'paid': false,
    });
  }

  Future<void> updateFulfillment(String orderId, OrderFulfillment newFulfillment) async {
    final order = await getOrder(orderId);
    if (order == null) throw Exception('Order not found');

    // Validate state transition
    if (!_isValidFulfillmentTransition(order.fulfillment, newFulfillment)) {
      throw Exception('Invalid fulfillment state transition');
    }

    // Handle stock updates for cancelled orders
    if (newFulfillment == OrderFulfillment.cancelled && order.fulfillment != OrderFulfillment.cancelled) {
      await _returnStockForOrder(order);
    }

    await _firestore.collection(_collection).doc(orderId).update({
      'fulfillment': newFulfillment.toString().split('.').last,
    });
  }

  bool _isValidFulfillmentTransition(OrderFulfillment current, OrderFulfillment next) {
    switch (current) {
      case OrderFulfillment.draft:
        return next == OrderFulfillment.pending;
      case OrderFulfillment.pending:
        return next == OrderFulfillment.unfulfilled || next == OrderFulfillment.cancelled;
      case OrderFulfillment.unfulfilled:
        return next == OrderFulfillment.fulfilled || next == OrderFulfillment.cancelled;
      case OrderFulfillment.fulfilled:
        return next == OrderFulfillment.unfulfilled;
      case OrderFulfillment.cancelled:
        return false; // Can't change from cancelled
      case OrderFulfillment.import:
        return false; // Import orders can't change status
    }
  }

  Future<void> createOrder(OrderModel order) async {
    // Decrease stock for all items
    for (var line in order.orderlines) {
      await _productService.decreaseStock(line.id, line.quantity);
    }

    await _firestore.collection(_collection).doc(order.id).set({
      ...order.toMap(),
      'paid': false, // Initialize as unpaid
    });
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).delete();
    } catch (e) {
      print('Error deleting order: $e');
      rethrow;
    }
  }

  Future<OrderModel?> getOrder(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateOrder(String orderId, OrderModel order) async {
    await _firestore.collection(_collection).doc(orderId).update(order.toMap());
  }

  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _firestore
        .collection(_collection)
        .where('cid', isEqualTo: customerId)
        .orderBy('ref', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }

  Future<List<OrderModel>> getAllOrders() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('ref', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get orders: $e');
    }
  }

  Stream<OrderModel?> getDraftOrder(String customerId) {
    return _firestore
        .collection(_collection)
        .where('cid', isEqualTo: customerId)
        .where('fulfillment', isEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty 
            ? null 
            : OrderModel.fromFirestore(snapshot.docs.first));
  }

  Future<OrderModel> getOrCreateDraftOrder() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userModel = UserModel.fromFirebaseUser(user);
    final customer = await _userService.getUser(userModel.id);
    if (customer == null) throw Exception('Customer not found');

    print('Current user role: ${userModel.role}, isAdmin: ${userModel.isAdmin}, isSupplier: ${userModel.isSupplier}');

    // Try to find existing draft order
    final draftQuery = await _firestore
        .collection('orders')
        .where('cid', isEqualTo: customer.id)
        .where('fulfillment', isEqualTo: 'draft')
        .get();

    if (draftQuery.docs.isNotEmpty) {
      return OrderModel.fromFirestore(draftQuery.docs.first);
    }

    // Create new draft order
    final docRef = await _firestore.collection('orders').add({
      'cid': customer.id,
      'orderlines': [],
      'fulfillment': 'draft',
      'paid': false,
    });

    return OrderModel(
      id: docRef.id,
      cid: customer.id,
      orderlines: [],
      fulfillment: OrderFulfillment.draft,
      paid: false,
    );
  }

  Future<void> addToDraftOrder(String customerId, String productId, int quantity) async {
    final draftOrder = await getOrCreateDraftOrder();
    final orderlines = List<OrderLine>.from(draftOrder.orderlines);
    
    // Get product price
    final product = await _productService.getProduct(productId);
    if (product == null) throw Exception('Product not found');
    final price = product.price * quantity;
    
    // Check if product already exists in order
    final existingIndex = orderlines.indexWhere((line) => line.id == productId);
    if (existingIndex >= 0) {
      orderlines[existingIndex] = OrderLine(
        id: productId,
        quantity: orderlines[existingIndex].quantity + quantity,
        price: price,
      );
    } else {
      orderlines.add(OrderLine(
        id: productId,
        quantity: quantity,
        price: price,
      ));
    }

    await _firestore.collection(_collection).doc(draftOrder.id).update({
      'orderlines': orderlines.map((line) => line.toMap()).toList(),
    });
  }

  Future<void> updateDraftOrderQuantity(String customerId, String productId, int quantity) async {
    final draftOrder = await getOrCreateDraftOrder();
    final orderlines = List<OrderLine>.from(draftOrder.orderlines);
    
    // Get product price
    final product = await _productService.getProduct(productId);
    if (product == null) throw Exception('Product not found');
    final price = product.price * quantity;
    
    if (quantity <= 0) {
      orderlines.removeWhere((line) => line.id == productId);
    } else {
      final existingIndex = orderlines.indexWhere((line) => line.id == productId);
      if (existingIndex >= 0) {
        orderlines[existingIndex] = OrderLine(
          id: productId,
          quantity: quantity,
          price: price,
        );
      }
    }

    await _firestore.collection(_collection).doc(draftOrder.id).update({
      'orderlines': orderlines.map((line) => line.toMap()).toList(),
    });
  }

  Future<OrderModel> placeOrder() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userModel = UserModel.fromFirebaseUser(user);
    final customer = await _userService.getUser(userModel.id);
    if (customer == null) throw Exception('Customer not found');

    // Get the draft order
    final draftQuery = await _firestore
        .collection('orders')
        .where('cid', isEqualTo: customer.id)
        .where('fulfillment', isEqualTo: 'draft')
        .get();

    if (draftQuery.docs.isEmpty) {
      throw Exception('No draft order found');
    }

    final draftDoc = draftQuery.docs.first;
    final draftOrder = OrderModel.fromFirestore(draftDoc);

    if (draftOrder.orderlines.isEmpty) {
      throw Exception('Cannot place empty order');
    }

    if (draftOrder.address == null) {
      throw Exception('Please select a delivery address before placing the order');
    }

    // Decrease stock for all items in the order
    for (var line in draftOrder.orderlines) {
      await _productService.decreaseStock(line.id, line.quantity);
    }

    // Get the latest order number (ref) by fetching latest 20 orders and filtering in Dart
    final latestOrdersSnapshot = await _firestore
        .collection(_collection)
        .orderBy('ref', descending: true)
        .limit(20)
        .get();
    final nonDraftOrders = latestOrdersSnapshot.docs
        .map((doc) => OrderModel.fromFirestore(doc))
        .where((order) => order.fulfillment != OrderFulfillment.draft)
        .toList();
    int ref = 1;
    if (nonDraftOrders.isNotEmpty) {
      ref = (nonDraftOrders.first.ref ?? 0) + 1;
    }

    final orderedAt = DateTime.now();

    // Update the order to pending state with ref and orderedAt
    await draftDoc.reference.update({
      'fulfillment': 'pending',
      'ref': ref,
      'orderedAt': Timestamp.fromDate(orderedAt),
    });

    // Create a new draft order for future use
    await _firestore.collection('orders').add({
      'cid': customer.id,
      'orderlines': [],
      'fulfillment': 'draft',
      'paid': false,
    });

    // Navigate to home page
    Get.offAllNamed(AppRoutes.customer);

    return draftOrder.copyWith(
      fulfillment: OrderFulfillment.pending,
      ref: ref,
      orderedAt: orderedAt,
    );
  }

  Future<void> markOrderAsPaid(String orderId) async {
    await _firestore.collection(_collection).doc(orderId).update({
      'paid': true,
    });
  }

  Future<void> updateDraftOrderAddress(String customerId, AddressModel address) async {
    final draftOrder = await getOrCreateDraftOrder();
    await _firestore.collection(_collection).doc(draftOrder.id).update({
      'address': address.toMap(),
    });
  }

  // Add new method for import orders
  Future<void> createImportOrder({
    required String productId,
    required int quantity,
    required double price,
    required String sourceId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Fetch user from Firestore to get the correct role
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception('User not found');
    final userModel = UserModel.fromFirestore(userDoc);
    if (!userModel.isAdmin && !userModel.isSupplier) {
      throw Exception('Only admins and suppliers can create import orders');
    }


    // Count all non-draft orders to determine the next ref number
    final nonDraftOrdersSnapshot = await _firestore
        .collection(_collection)
        .where('fulfillment', isNotEqualTo: 'draft')
        .get();
    final ref = nonDraftOrdersSnapshot.docs.length + 1;
    final orderedAt = DateTime.now();

    // Create import order
    final docRef = await _firestore.collection(_collection).add({
      'orderlines': [
        {
          'id': productId,
          'quantity': quantity,
          'price': price,
        }
      ],
      'fulfillment': OrderFulfillment.import.toString().split('.').last,
      'orderedAt': Timestamp.fromDate(orderedAt),
      'ref': ref,
      'sourceId': sourceId,
    });

    // Increase stock for the product
    await _productService.increaseStock(productId, quantity);
  }

  // Add method to get import orders
  Stream<List<OrderModel>> getImportOrders() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    final userModel = UserModel.fromFirebaseUser(user);
    if (!userModel.isAdmin && !userModel.isSupplier) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('fulfillment', isEqualTo: OrderFulfillment.import.toString().split('.').last)
        .orderBy('ref', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList());
  }
} 