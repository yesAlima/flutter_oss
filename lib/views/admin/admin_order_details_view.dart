import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../controllers/admin/admin_order_details_controller.dart';
import '../import_view.dart';
import '../../controllers/import_controller.dart';

class AdminOrderDetailsView extends GetView<AdminOrderDetailsController> {
  const AdminOrderDetailsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: controller.deleteOrder,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final order = controller.order.value;
        if (order == null) {
          return const Center(child: Text('Order not found'));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderHeader(order),
              const SizedBox(height: 24),
              _buildCustomerSection(order),
              const SizedBox(height: 24),
              if (order.did != null) ...[
                _buildDeliverySection(order),
                const SizedBox(height: 24),
              ],
              _buildOrderItemsSection(order),
              const SizedBox(height: 24),
              _buildOrderSummary(order),
              const SizedBox(height: 24),
              _buildActionsCard(order, context),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderHeader(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.ref ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: controller.getStatusColor(order.fulfillment).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    controller.getStatusText(order.fulfillment),
                    style: TextStyle(
                      color: controller.getStatusColor(order.fulfillment),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ordered At: ${order.orderedAt != null ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!) : 'N/A'}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (order.address != null) ...[
              const SizedBox(height: 8),
              Text(
                'Address: Block ${order.address!.block}, Building ${order.address!.building}${order.address!.road != null ? ', Road ${order.address!.road}' : ''}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerSection(OrderModel order) {
    Widget customerWidget;
    if (order.fulfillment == OrderFulfillment.import) {
      customerWidget = const Text('Source information not available');
    } else {
      customerWidget = FutureBuilder<UserModel?>(
        future: controller.getUser(order.cid!),
        builder: (context, snapshot) {
          final customer = snapshot.data;
          if (customer == null) {
            return const Text('Customer information not available');
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(customer.name, style: const TextStyle(fontSize: 16)),
              if (customer.phone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('+973 ${customer.phone}', style: const TextStyle(color: Colors.grey)),
              ],
            ],
          );
        },
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.fulfillment == OrderFulfillment.import
                  ? 'Source Information'
                  : 'Customer Information',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            customerWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FutureBuilder<UserModel?>(
              future: controller.getUser(order.did!),
              builder: (context, snapshot) {
                final deliveryPerson = snapshot.data;
                if (deliveryPerson == null) {
                  return const Text('Delivery information not available');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deliveryPerson.name, style: const TextStyle(fontSize: 16)),
                    if (deliveryPerson.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('+973 ${deliveryPerson.phone}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsSection(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Obx(() {
              final products = controller.products.value;
              if (products.isEmpty) {
                return const Text('No items in this order');
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: order.orderlines.length,
                itemBuilder: (context, index) {
                  final line = order.orderlines[index];
                  final product = products[line.id];
                  if (product == null) return const SizedBox.shrink();
                  final unitPrice = line.quantity == 0 ? 0 : (line.price ?? 0) / line.quantity;
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unit Price: ${unitPrice.toStringAsFixed(3)} BD'),
                        Text('Total: ${line.price?.toStringAsFixed(3) ?? '0.000'} BD'),
                      ],
                    ),
                    trailing: Text('x${line.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontSize: 16)),
                Text('${controller.getOrderTotal().toStringAsFixed(3)} BD', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            if (order.fulfillment != OrderFulfillment.cancelled && order.paid != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: order.paid! ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.paid! ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    color: order.paid! ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(OrderModel order, BuildContext context) {
    final isImport = order.fulfillment == OrderFulfillment.import;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!isImport && (order.fulfillment == OrderFulfillment.pending || order.fulfillment == OrderFulfillment.unfulfilled))
                  Tooltip(
                    message: order.did == null ? 'Assign Delivery' : 'Change Delivery',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delivery_dining),
                      label: Text(order.did == null ? 'Assign Delivery' : 'Change Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: _showDeliveryUserDialog,
                    ),
                  ),
                if (!isImport && order.fulfillment == OrderFulfillment.unfulfilled && order.did != null)
                  Tooltip(
                    message: 'Remove Delivery',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text('Remove Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => controller.revokeDelivery(order.id),
                    ),
                  ),
                if (!isImport && order.fulfillment == OrderFulfillment.unfulfilled)
                  Tooltip(
                    message: 'Mark as Delivered',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Mark as Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => controller.updateOrderStatus(OrderFulfillment.fulfilled),
                    ),
                  ),
                if (!isImport && (order.fulfillment == OrderFulfillment.pending || order.fulfillment == OrderFulfillment.unfulfilled))
                  Tooltip(
                    message: 'Cancel Order',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade100,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => controller.updateOrderStatus(OrderFulfillment.cancelled),
                    ),
                  ),
                if (!isImport && order.fulfillment == OrderFulfillment.fulfilled)
                  Tooltip(
                    message: 'Revert to Unfulfilled',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.undo),
                      label: const Text('Revert to Unfulfilled'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () => controller.updateOrderStatus(OrderFulfillment.unfulfilled),
                    ),
                  ),
                if (isImport)
                  Tooltip(
                    message: 'Edit Import Order',
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Import Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade100,
                        foregroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onPressed: () {
                        Get.lazyPut<ImportController>(() => ImportController());
                        showDialog(
                          context: context,
                          builder: (context) => ImportView(order: order),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryUserDialog() {
    if (!controller.currentUser.isAdmin) return;
    Get.dialog(
      AlertDialog(
        title: const Text('Assign Delivery'),
        content: FutureBuilder<List<UserModel>>(
          future: controller.getDeliveryUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final deliveryUsers = snapshot.data!;
            return SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: deliveryUsers.map((user) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user.name),
                  onTap: () async {
                    await controller.assignDelivery(user.id);
                    Get.back();
                  },
                )).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
} 