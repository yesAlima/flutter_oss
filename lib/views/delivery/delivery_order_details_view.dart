import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';

class DeliveryOrderDetailsView extends StatefulWidget {
  final String orderId;
  const DeliveryOrderDetailsView({Key? key, required this.orderId}) : super(key: key);

  @override
  State<DeliveryOrderDetailsView> createState() => _DeliveryOrderDetailsViewState();
}

class _DeliveryOrderDetailsViewState extends State<DeliveryOrderDetailsView> {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final Rx<OrderModel?> order = Rx<OrderModel?>(null);
  final RxBool isLoading = true.obs;
  final Map<String, ProductModel> _products = {};

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadProducts(OrderModel order) async {
    final products = <String, ProductModel>{};
    for (final line in order.orderlines) {
      final product = await _productService.getProduct(line.id);
      if (product != null) {
        products[line.id] = product;
      }
    }
    setState(() {
      _products.clear();
      _products.addAll(products);
    });
  }

  Future<void> _loadOrder() async {
    isLoading.value = true;
    try {
      final fetchedOrder = await _orderService.getOrder(widget.orderId);
      order.value = fetchedOrder;
      if (fetchedOrder != null) {
        await _loadProducts(fetchedOrder);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load order details');
    } finally {
      isLoading.value = false;
    }
  }

  Color _getStatusColor(OrderFulfillment status) {
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
  String _getStatusText(OrderFulfillment status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          order.value?.ref != null 
              ? 'Order #${order.value!.ref}'
              : 'Order Details',
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (order.value == null) {
          return const Center(child: Text('Order not found'));
        }
        final o = order.value!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderStatusCard(o),
              buildCustomerInfo(o),
              buildDeliveryAddress(o),
              buildOrderItems(o),
              _buildDeliveryActionButtons(o),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderStatusCard(OrderModel o) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(o.fulfillment).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(o.fulfillment),
                    ),
                  ),
                  child: Text(
                    _getStatusText(o.fulfillment),
                    style: TextStyle(
                      color: _getStatusColor(o.fulfillment),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCustomerInfo(OrderModel o) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Customer Information', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          if (o.cid != null)
            FutureBuilder<UserModel?>(
              future: _authService.getUser(o.cid!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(title: Text('Loading customer info...'));
                }
                if (snapshot.hasError) {
                  return const ListTile(title: Text('Error loading customer info'));
                }
                final customer = snapshot.data;
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(customer?.name ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer?.email ?? ''),
                      if (customer?.phone != null && customer!.phone.isNotEmpty)
                        Text('+973 ${customer.phone}'),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget buildDeliveryAddress(OrderModel o) {
    if (o.address == null) return const SizedBox.shrink();
    final address = o.address!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Block ${address.block}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (address.road != null) ...[
                        const SizedBox(height: 4),
                        Text('Road ${address.road}'),
                      ],
                      const SizedBox(height: 4),
                      Text('Building ${address.building}'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOrderItems(OrderModel o) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Order Items', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ...o.orderlines.map((line) {
            final product = _products[line.id];
            return ListTile(
              title: Text(product?.name ?? 'Product not found'),
              subtitle: Text('Quantity: ${line.quantity}'),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryActionButtons(OrderModel order) {
    final currentUserId = _authService.currentUser?.id;
    if (order.fulfillment == OrderFulfillment.pending) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_task),
                label: const Text('Claim Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                onPressed: () async {
                  await _orderService.assignDelivery(order.id, currentUserId!);
                  await _loadOrder();
                  Get.snackbar('Success', 'Order claimed successfully', snackPosition: SnackPosition.BOTTOM);
                },
              ),
            ),
          ],
        ),
      );
    }
    // Other delivery actions (mark as delivered, revert)
    List<Widget> actions = [];
    if (order.did == currentUserId && order.fulfillment == OrderFulfillment.unfulfilled) {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.check_circle),
          label: const Text('Mark as Delivered'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: () async {
            await _orderService.updateFulfillment(order.id, OrderFulfillment.fulfilled);
            await _loadOrder();
            Get.snackbar('Success', 'Order marked as delivered', snackPosition: SnackPosition.BOTTOM);
          },
        ),
      );
    }
    if (order.did == currentUserId && order.fulfillment == OrderFulfillment.fulfilled) {
      actions.add(
        ElevatedButton.icon(
          icon: const Icon(Icons.undo),
          label: const Text('Revert to Unfulfilled'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: () async {
            await _orderService.updateFulfillment(order.id, OrderFulfillment.unfulfilled);
            await _loadOrder();
            Get.snackbar('Success', 'Order reverted to unfulfilled', snackPosition: SnackPosition.BOTTOM);
          },
        ),
      );
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: actions.map((a) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: a))).toList(),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Order Details Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Order Management',
                'As a delivery personnel, you can:',
                [
                  'View assigned order details',
                  'Mark orders as delivered',
                  'View customer information',
                  'View delivery location',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Orders can have the following statuses:',
                [
                  'Unfulfilled: Orders assigned to you',
                  'Fulfilled: Successfully delivered orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Actions',
                'Available actions for each status:',
                [
                  'Unfulfilled: Mark as delivered',
                  'Fulfilled: No actions available',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
} 