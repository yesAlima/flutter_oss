import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../controllers/customer/customer_orders_controller.dart';

class CustomerOrdersView extends StatefulWidget {
  const CustomerOrdersView({Key? key}) : super(key: key);

  @override
  State<CustomerOrdersView> createState() => _CustomerOrdersViewState();
}

class _CustomerOrdersViewState extends State<CustomerOrdersView> {
  final _controller = Get.put(CustomerOrdersController());

  @override
  void initState() {
    super.initState();
    _controller.loadOrders();
  }

  Widget buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Obx(() => Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _controller.selectedStatus.value == null,
            onSelected: (selected) {
              _controller.setStatus(null);
            },
          ),
          const SizedBox(width: 8),
          ..._controller.availableStatuses.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_controller.getStatusText(status)),
                selected: _controller.selectedStatus.value == status,
                onSelected: (selected) {
                  _controller.setStatus(selected ? status : null);
                },
                backgroundColor: _controller.getStatusColor(status).withAlpha(10),
                selectedColor: _controller.getStatusColor(status).withAlpha(30),
                checkmarkColor: _controller.getStatusColor(status),
                labelStyle: TextStyle(
                  color: _controller.selectedStatus.value == status 
                      ? _controller.getStatusColor(status)
                      : Colors.black87,
                  fontWeight: _controller.selectedStatus.value == status 
                      ? FontWeight.bold 
                      : FontWeight.normal,
                ),
              ),
            );
          }),
        ],
      )),
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
            child: Obx(() => _controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _controller.filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _controller.filteredOrders[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text('Order #${order.ref ?? order.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status: ${_controller.getStatusText(order.fulfillment)}',
                                style: TextStyle(
                                  color: _controller.getStatusColor(order.fulfillment),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Row(
                                children: [
                                  if (order.fulfillment != OrderFulfillment.cancelled && order.paid != null)
                                    _controller.buildPaidBadge(order.paid!),
                                  const SizedBox(width: 8),
                                  FutureBuilder<Map<String, ProductModel>>(
                                    future: _controller.getProductsForOrder(order),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) return const SizedBox.shrink();
                                      final products = snapshot.data!;
                                      final total = _controller.getOrderTotal(order, products);
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
    _controller.loadOrders();
  }

  Future<void> _cancelOrder(OrderModel order) async {
    await _controller.cancelOrder(order.id);
    Get.snackbar('Order Cancelled', 'Order #${order.ref ?? order.id} has been cancelled.');
  }

  Future<void> _changeOrderAddress(OrderModel order) async {
    final addresses = await _controller.getCustomerAddresses();
    if (addresses.isEmpty) {
      Get.snackbar('Error', 'No addresses found. Please add an address first.');
      return;
    }

    final selectedAddress = await showDialog<AddressModel>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Delivery Address'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return ListTile(
                title: Text(address.building),
                subtitle: Text(address.block),
                onTap: () => Navigator.pop(context, address),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedAddress != null) {
      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
        'address': selectedAddress.toMap(),
      });
      Get.snackbar('Success', 'Address updated for this order');
      _controller.loadOrders();
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
} 