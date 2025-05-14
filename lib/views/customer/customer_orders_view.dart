import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../routes/app_routes.dart';

class CustomerOrdersView extends StatefulWidget {
  const CustomerOrdersView({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersView> createState() => _CustomerOrdersViewState();
}

class _CustomerOrdersViewState extends State<CustomerOrdersView> {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final RxList<OrderModel> _orders = <OrderModel>[].obs;
  final RxBool _isLoading = true.obs;
  OrderFulfillment? _selectedStatus;
  Map<String, double> _orderTotalsCache = {};

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    _isLoading.value = true;
    try {
      final userId = _authService.currentUser!.id;
      final orders = await _orderService.getOrders(fulfillment: _selectedStatus).first;
      _orders.value = orders.where((order) => 
        order.cid == userId && 
        order.fulfillment != OrderFulfillment.draft
      ).toList();
      await _updateOrderTotalsCache();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _updateOrderTotalsCache() async {
    final Map<String, double> totals = {};
    for (final order in _orders) {
      final products = await _getProductsForOrder(order);
      totals[order.id] = _getOrderTotal(order, products);
    }
    if (mounted) {
      setState(() {
        _orderTotalsCache = totals;
      });
    }
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

  List<OrderModel> get filteredOrders {
    return _orders.where((order) {
      if (_selectedStatus != null && order.fulfillment != _selectedStatus) {
        return false;
      }
      return true;
    }).toList();
  }

  Widget buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedStatus == null,
            onSelected: (selected) {
              setState(() => _selectedStatus = null);
            },
          ),
          const SizedBox(width: 8),
          ..._availableStatuses.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_getStatusText(status)),
                selected: _selectedStatus == status,
                onSelected: (selected) {
                  setState(() => _selectedStatus = selected ? status : null);
                },
                backgroundColor: _getStatusColor(status).withAlpha(10),
                selectedColor: _getStatusColor(status).withAlpha(30),
                checkmarkColor: _getStatusColor(status),
                labelStyle: TextStyle(
                  color: _selectedStatus == status 
                      ? _getStatusColor(status)
                      : Colors.black87,
                  fontWeight: _selectedStatus == status 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<OrderFulfillment> get _availableStatuses => [
    OrderFulfillment.pending,
    OrderFulfillment.unfulfilled,
    OrderFulfillment.fulfilled,
    OrderFulfillment.cancelled,
  ];

  Widget _buildPaidBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPaid ? 'Paid' : 'Unpaid',
        style: TextStyle(
          color: isPaid ? Colors.green : Colors.red,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          buildStatusFilter(),
          Expanded(
            child: Obx(() => _isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('Order #${order.ref ?? order.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${_getStatusText(order.fulfillment)}',
                                style: TextStyle(
                                  color: _getStatusColor(order.fulfillment),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  if (order.fulfillment != OrderFulfillment.cancelled && order.paid != null)
                                    _buildPaidBadge(order.paid!),
                                  const SizedBox(width: 8),
                                  FutureBuilder<Map<String, ProductModel>>(
                                    future: _getProductsForOrder(order),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const SizedBox.shrink();
                                      final products = snapshot.data!;
                                      final total = _getOrderTotal(order, products);
                                      return Text(
                                        'Total: ${total.toStringAsFixed(3)} BD',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                'Ordered At: ${order.orderedAt != null ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!) : 'N/A'}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: _buildCustomerOrderActions(order),
                          onTap: () => Get.toNamed(AppRoutes.customerOrderDetails, arguments: order.id),
                        ),
                      );
                    },
                  )),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerOrderActions(OrderModel order) {
    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_location_alt, color: Colors.blue),
              tooltip: 'Change Address',
              onPressed: () => _changeOrderAddress(order),
            ),
            if (order.paid == false)
              IconButton(
                icon: const Icon(Icons.monetization_on, color: Colors.green),
                tooltip: 'Pay',
                onPressed: () => _payOrder(order),
              ),
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: 'Cancel',
              onPressed: () => _cancelOrder(order),
            ),
          ],
        );
      case OrderFulfillment.unfulfilled:
        if (order.paid == false)
          return IconButton(
            icon: const Icon(Icons.monetization_on, color: Colors.green),
            tooltip: 'Pay',
            onPressed: () => _payOrder(order),
          );
        else
          return const SizedBox.shrink();
      case OrderFulfillment.fulfilled:
      case OrderFulfillment.cancelled:
      case OrderFulfillment.draft:
      case OrderFulfillment.import:
        return const SizedBox.shrink();
    }
  }

  Future<void> _payOrder(OrderModel order) async {
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'paid': true,
    });
    Get.snackbar('Payment', 'Order #${order.ref ?? order.id} marked as paid.');
    await _loadOrders();
  }

  Future<void> _cancelOrder(OrderModel order) async {
    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'paid': false,
      'fulfillment': 'cancelled',
    });
    Get.snackbar('Order Cancelled', 'Order #${order.ref ?? order.id} has been cancelled.');
    await _loadOrders();
  }

  Future<void> _changeOrderAddress(OrderModel order) async {
    final newAddress = await Get.toNamed('/customer/addresses', arguments: order);
    if (newAddress != null) {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'address': newAddress.toMap(),
      });
      Get.snackbar('Success', 'Address updated for this order');
      await _loadOrders();
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Orders Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Order Management',
                'As a customer, you can:',
                [
                  'View all your orders',
                  'Track order status',
                  'View order details',
                  'Filter and search your orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Orders can have the following statuses:',
                [
                  'Pending: New orders awaiting delivery assignment',
                  'Unfulfilled: Orders assigned to delivery personnel',
                  'Fulfilled: Successfully delivered orders',
                  'Cancelled: Cancelled orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Payment Status',
                'Orders can be either:',
                [
                  'Paid: Payment has been completed',
                  'Unpaid: Payment is pending',
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

  Widget _buildCustomerName(String customerId) {
    return FutureBuilder<UserModel?>(
      future: _authService.getUser(customerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading customer...');
        }
        if (snapshot.hasError) {
          return const Text('Error loading customer');
        }
        final customer = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer: ${customer?.name ?? 'Unknown'}',
              style: const TextStyle(fontSize: 14),
            ),
            if (customer?.phone != null && customer!.phone.isNotEmpty)
              Text(
                '+973 ${customer.phone}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        );
      },
    );
  }
} 