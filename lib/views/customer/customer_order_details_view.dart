import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../controllers/order_controller.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class CustomerOrderDetailsView extends StatefulWidget {
  final String orderId;
  const CustomerOrderDetailsView({Key? key, required this.orderId}) : super(key: key);

  @override
  State<CustomerOrderDetailsView> createState() => _CustomerOrderDetailsViewState();
}

class _CustomerOrderDetailsViewState extends State<CustomerOrderDetailsView> {
  final _orderController = Get.find<OrderController>();
  final _productService = Get.find<ProductService>();
  final _authService = Get.find<AuthService>();
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
      final fetchedOrder = await _orderController.orderService.getOrder(widget.orderId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          order.value?.ref != null 
              ? 'Order #${order.value!.ref}'
              : 'My Order Details',
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
              if (o.fulfillment != OrderFulfillment.pending && o.fulfillment != OrderFulfillment.draft)
                _buildDeliveryInfoCard(o),
              _buildDeliveryAddressCard(o),
              _buildOrderItemsCard(o),
              _buildOrderActions(o),
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
                const SizedBox(width: 8),
                if (o.fulfillment != OrderFulfillment.cancelled && o.fulfillment != OrderFulfillment.import)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (o.paid ?? false)
                          ? Colors.green.withAlpha(100)
                          : Colors.red.withAlpha(100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (o.paid ?? false) ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      (o.paid ?? false) ? 'Paid' : 'Unpaid',
                      style: TextStyle(
                        color: (o.paid ?? false) ? Colors.green : Colors.red,
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

  Widget _buildDeliveryInfoCard(OrderModel o) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Delivery Information', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          if (o.did != null)
            FutureBuilder<UserModel?>(
              future: _authService.getUser(o.did!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(title: Text('Loading delivery info...'));
                }
                if (snapshot.hasError) {
                  return const ListTile(title: Text('Error loading delivery info'));
                }
                final delivery = snapshot.data;
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(delivery?.name ?? 'Unknown'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(delivery?.email ?? ''),
                      if (delivery?.phone != null && delivery!.phone.isNotEmpty)
                        Text('+973 ${delivery.phone}'),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(OrderModel o) {
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

  Widget _buildOrderItemsCard(OrderModel o) {
    double total = 0;
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
            final price = product?.price ?? 0;
            final lineTotal = price * line.quantity;
            total += lineTotal;
            return ListTile(
              leading: product?.imageUrl != null
                  ? Image.network(product!.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                  : const Icon(Icons.image_not_supported),
              title: Text(product?.name ?? 'Product not found'),
              subtitle: Text('${price.toStringAsFixed(3)} BD x ${line.quantity}'),
              trailing: Text('${lineTotal.toStringAsFixed(3)} BD', style: const TextStyle(fontWeight: FontWeight.bold)),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${total.toStringAsFixed(3)} BD', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(OrderModel order) {
    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_location_alt, color: Colors.blue),
                label: const Text('Change Address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _changeOrderAddress(order),
              ),
              if (order.paid == false)
                ElevatedButton.icon(
                  icon: const Icon(Icons.monetization_on, color: Colors.green),
                  label: const Text('Pay'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade800,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _payOrder(order),
                ),
              ElevatedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.white),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _cancelOrder(order),
              ),
            ],
          ),
        );
      case OrderFulfillment.unfulfilled:
        if (order.paid == false)
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.monetization_on, color: Colors.green),
              label: const Text('Pay'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade50,
                foregroundColor: Colors.green.shade800,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => _payOrder(order),
            ),
          );
        else
          return const SizedBox.shrink();
      case OrderFulfillment.fulfilled:
      case OrderFulfillment.cancelled:
      case OrderFulfillment.draft:
        return const SizedBox.shrink();
      case OrderFulfillment.import:
        return const SizedBox.shrink();
    }
  }

  Future<void> _payOrder(OrderModel order) async {
    try {
      await _orderController.payOrder(order);
      Get.snackbar('Payment', 'Order #\${order.ref ?? order.id} marked as paid.');
      await _loadOrder();
    } catch (e) {
      Get.snackbar('Error', 'Failed to update payment status');
    }
  }

  Future<void> _cancelOrder(OrderModel order) async {
    try {
      await _orderController.cancelOrder(order);
      Get.snackbar('Order Cancelled', 'Order #\${order.ref ?? order.id} has been cancelled.');
      await _loadOrder();
    } catch (e) {
      Get.snackbar('Error', 'Failed to cancel order');
    }
  }

  Future<void> _changeOrderAddress(OrderModel order) async {
    final newAddress = await Get.toNamed('/customer/addresses', arguments: order);
    if (newAddress != null) {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'address': newAddress.toMap(),
      });
      Get.snackbar('Success', 'Address updated for this order');
      await _loadOrder();
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Details Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Order Information',
                'You can view:',
                [
                  'Order reference number',
                  'Order date and time',
                  'Order status',
                  'Payment status',
                  'Delivery information',
                  'Order items and quantities',
                  'Total amount',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Your order can have the following statuses:',
                [
                  'Pending: New order awaiting delivery assignment',
                  'Unfulfilled: Order assigned to delivery personnel',
                  'Fulfilled: Successfully delivered order',
                  'Cancelled: Cancelled order',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Payment Status',
                'Your order can have the following payment statuses:',
                [
                  'Pending: Payment not yet processed',
                  'Paid: Payment successfully processed',
                  'Failed: Payment processing failed',
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