import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../controllers/supplier/supplier_order_details_controller.dart';
import 'package:intl/intl.dart';
import '../../controllers/import_controller.dart';
import '../import_view.dart';

class SupplierOrderDetailsView extends StatelessWidget {
  const SupplierOrderDetailsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SupplierOrderDetailsController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: controller.showHelpDialog,
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
              _buildOrderHeader(order, controller),
              const SizedBox(height: 24),
              _buildCustomerSection(controller),
              const SizedBox(height: 24),
              if (order.did != null) ...[
                _buildDeliverySection(controller),
                const SizedBox(height: 24),
              ],
              _buildOrderItemsSection(order, controller),
              const SizedBox(height: 24),
              _buildOrderSummary(order, controller),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderHeader(OrderModel order, SupplierOrderDetailsController controller) {
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _buildCustomerSection(SupplierOrderDetailsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.order.value?.fulfillment == OrderFulfillment.import
                  ? 'Source Information'
                  : 'Customer Information',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              if (controller.order.value?.fulfillment == OrderFulfillment.import) {
                final source = controller.source.value;
                if (source == null) {
                  return const Text('Source information not available');
                }
                return Text(
                  source.name,
                  style: const TextStyle(fontSize: 16),
                );
              } else {
                final customer = controller.customer.value;
                if (customer == null) {
                  return const Text('Customer information not available');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (customer.phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+973 ${customer.phone}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ],
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverySection(SupplierOrderDetailsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Obx(() {
              final deliveryPerson = controller.deliveryPerson.value;
              if (deliveryPerson == null) {
                return const Text('Delivery information not available');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deliveryPerson.name,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (deliveryPerson.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+973 ${deliveryPerson.phone}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsSection(OrderModel order, SupplierOrderDetailsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
                  
                  final unitPrice = controller.getUnitPrice(line);
                  return ListTile(
                    title: Text(product.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unit Price: ${unitPrice.toStringAsFixed(3)} BD'),
                        Text('Total: ${line.price?.toStringAsFixed(3) ?? '0.000'} BD'),
                      ],
                    ),
                    trailing: Text(
                      'x${line.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(OrderModel order, SupplierOrderDetailsController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount:',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '${controller.getOrderTotal().toStringAsFixed(3)} BD',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                          context: Get.context!,
                          builder: (context) => ImportView(order: order),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
} 