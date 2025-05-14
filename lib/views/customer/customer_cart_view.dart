import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';
import '../../routes/app_routes.dart';

class CustomerCartView extends StatefulWidget {
  const CustomerCartView({Key? key}) : super(key: key);

  @override
  State<CustomerCartView> createState() => _CustomerCartViewState();
}

class _CustomerCartViewState extends State<CustomerCartView> {
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final _userService = Get.find<UserService>();
  final Rx<OrderModel?> _cart = Rx<OrderModel?>(null);
  final RxBool _isLoading = true.obs;
  final RxMap<String, ProductModel> _products = <String, ProductModel>{}.obs;
  final RxList<AddressModel> _addresses = <AddressModel>[].obs;
  final Rx<AddressModel?> _selectedAddress = Rx<AddressModel?>(null);
  final RxBool _isAddressExpanded = true.obs;

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _userService.getUser(user.id);
      if (userData != null) {
        _addresses.value = userData.addresses;
        // If cart has an address, select it
        if (_cart.value?.address != null) {
          final matchingAddress = _addresses.firstWhere(
            (a) => a.block == _cart.value!.address!.block && 
                  a.building == _cart.value!.address!.building,
            orElse: () => _addresses.first,
          );
          _selectedAddress.value = matchingAddress;
        } else {
          _selectedAddress.value = _addresses.firstOrNull;
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load addresses');
    }
  }

  Future<void> _loadCart() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      // Get draft order (cart)
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      final draftOrderQuery = await ordersRef
          .where('cid', isEqualTo: user.id)
          .where('fulfillment', isEqualTo: 'draft')
          .get();

      if (draftOrderQuery.docs.isEmpty) {
        _cart.value = null;
      } else {
        _cart.value = OrderModel.fromFirestore(draftOrderQuery.docs.first);
        // Load product details for each orderline
        for (final line in _cart.value!.orderlines) {
          if (!_products.containsKey(line.id)) {
            final product = await _productService.getProduct(line.id);
            if (product != null) {
              _products[line.id] = product;
            }
          }
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load cart: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _updateQuantity(String productId, int newQuantity) async {
    try {
      if (_cart.value == null) return;

      final orderlines = List<OrderLine>.from(_cart.value!.orderlines);
      final index = orderlines.indexWhere((line) => line.id == productId);
      
      if (index >= 0) {
        if (newQuantity <= 0) {
          orderlines.removeAt(index);
        } else {
          orderlines[index] = OrderLine(
            id: productId,
            quantity: newQuantity,
          );
        }

        await FirebaseFirestore.instance
            .collection('orders')
            .doc(_cart.value!.id)
            .update({
          'orderlines': orderlines.map((line) => line.toMap()).toList(),
        });

        _loadCart(); // Reload cart to reflect changes
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update quantity: $e');
    }
  }

  Future<void> _updateCartAddress(AddressModel? address) async {
    try {
      if (_cart.value == null) return;

      await FirebaseFirestore.instance
          .collection('orders')
          .doc(_cart.value!.id)
          .update({
        'address': address?.toMap(),
      });

      _selectedAddress.value = address;
      _loadCart(); // Reload cart to reflect changes
    } catch (e) {
      Get.snackbar('Error', 'Failed to update delivery address');
    }
  }

  Future<void> _placeOrder() async {
    try {
      if (_cart.value == null || _cart.value!.orderlines.isEmpty) {
        Get.snackbar('Error', 'Cart is empty');
        return;
      }

      if (_selectedAddress.value == null) {
        Get.snackbar('Error', 'Please select a delivery address');
        return;
      }

      // Decrease stock for each product in the order
      for (final line in _cart.value!.orderlines) {
        await _productService.decreaseStock(line.id, line.quantity);
      }

      // Update order status
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      final nonDraftOrders = await ordersRef
          .where('fulfillment', isNotEqualTo: 'draft')
          .get();
      final nextRef = (nonDraftOrders.docs.length + 1);

      await ordersRef
          .doc(_cart.value!.id)
          .update({
        'fulfillment': 'pending',
        'orderedAt': FieldValue.serverTimestamp(),
        'ref': nextRef,
        'address': _selectedAddress.value!.toMap(),
      });

      Get.snackbar('Success', 'Order placed successfully');
      Get.offAllNamed(AppRoutes.customerOrders);
    } catch (e) {
      Get.snackbar('Error', 'Failed to place order: $e');
    }
  }

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.category,
          size: 64,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.error,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildAddressSelector() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: IconButton(
              icon: Obx(() => Icon(
                _isAddressExpanded.value ? Icons.expand_less : Icons.expand_more,
              )),
              onPressed: () => _isAddressExpanded.value = !_isAddressExpanded.value,
            ),
          ),
          Obx(() => _isAddressExpanded.value ? Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _addresses.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No addresses found. Please add an address to place your order.'),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await Get.toNamed(AppRoutes.customerAddressForm);
                          _loadAddresses();
                        },
                        icon: const Icon(Icons.add_location),
                        label: const Text('Add Address'),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Select a delivery address:'),
                        TextButton.icon(
                          onPressed: () async {
                            await Get.toNamed(AppRoutes.customerAddressForm);
                            _loadAddresses();
                          },
                          icon: const Icon(Icons.add_location),
                          label: const Text('Add New'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: _addresses.map((address) => RadioListTile<AddressModel>(
                        value: address,
                        groupValue: _selectedAddress.value,
                        onChanged: (value) {
                          if (value != null) {
                            _selectedAddress.value = value;
                            _updateCartAddress(value);
                          }
                        },
                        title: Text('Block ${address.block}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (address.road != null) Text('Road ${address.road}'),
                            Text('Building ${address.building}'),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                ),
          ) : const SizedBox.shrink()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_cart.value == null || _cart.value!.orderlines.isEmpty) {
          return const Center(
            child: Text('Your cart is empty'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildAddressSelector(),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _cart.value!.orderlines.length,
                    itemBuilder: (context, index) {
                      final line = _cart.value!.orderlines[index];
                      final product = _products[line.id];
                      
                      if (product == null) return const SizedBox.shrink();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _buildProductImage(product.imageUrl),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${product.price.toStringAsFixed(3)} BD',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove),
                                          onPressed: line.quantity > 1
                                              ? () => _updateQuantity(
                                                    line.id,
                                                    line.quantity - 1,
                                                  )
                                              : null,
                                        ),
                                        Text(
                                          '${line.quantity}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add),
                                          onPressed: line.quantity < product.stock
                                              ? () => _updateQuantity(
                                                    line.id,
                                                    line.quantity + 1,
                                                  )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _updateQuantity(line.id, 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Obx(() {
                          final total = _cart.value!.orderlines.fold<double>(
                            0,
                            (sum, line) {
                              final product = _products[line.id];
                              return sum + (product?.price ?? 0) * line.quantity;
                            },
                          );
                          return Text(
                            '${total.toStringAsFixed(3)} BD',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedAddress.value != null ? _placeOrder : null,
                        child: const Text('Place Order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
} 