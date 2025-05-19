import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../controllers/customer/customer_order_details_controller.dart';

class CustomerOrderDetailsView extends GetView<CustomerOrderDetailsController> {
  const CustomerOrderDetailsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          controller.order.value?.ref != null 
              ? 'Order #${controller.order.value!.ref}'
              : 'My Order Details',
        )),
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
        if (controller.order.value == null) {
          return const Center(child: Text('Order not found'));
        }
        final order = controller.order.value!;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOrderStatusCard(order),
              if (order.fulfillment != OrderFulfillment.pending && order.fulfillment != OrderFulfillment.draft)
                _buildDeliveryInfoCard(order),
              _buildDeliveryAddressCard(order),
              _buildOrderItemsCard(order),
              _buildOrderActions(order),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildOrderStatusCard(OrderModel order) {
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
                    color: controller.getStatusColor(order.fulfillment).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: controller.getStatusColor(order.fulfillment),
                    ),
                  ),
                  child: Text(
                    controller.getStatusText(order.fulfillment),
                    style: TextStyle(
                      color: controller.getStatusColor(order.fulfillment),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (order.fulfillment != OrderFulfillment.cancelled && order.fulfillment != OrderFulfillment.import)
                  controller.buildPaidBadge(order.paid ?? false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard(OrderModel order) {
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
          if (order.did != null)
            Obx(() {
              final delivery = controller.delivery.value;
              if (delivery == null) {
                return const ListTile(title: Text('Loading delivery info...'));
              }
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(delivery.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(delivery.email),
                    if (delivery.phone.isNotEmpty)
                      Text('+973 ${delivery.phone}'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(OrderModel order) {
    if (order.address == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: Text('Block ${order.address!.block}${order.address!.road != null ? ', Road ${order.address!.road}' : ''}'),
            subtitle: Text('Building ${order.address!.building}'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard(OrderModel order) {
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
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: order.orderlines.length,
            itemBuilder: (context, index) {
              final line = order.orderlines[index];
              final product = controller.products[line.id];
              if (product == null) return const SizedBox.shrink();
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${product.price.toStringAsFixed(3)} BD x ${line.quantity}'),
                trailing: Text(
                  '${(product.price * line.quantity).toStringAsFixed(3)} BD',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${controller.getOrderTotal().toStringAsFixed(3)} BD',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions(OrderModel order) {
    if (order.fulfillment != OrderFulfillment.pending) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: () => Get.toNamed('/customer/addresses', arguments: order),
            icon: const Icon(Icons.edit_location_alt),
            label: const Text('Change Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
          if (!order.paid!)
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement payment
                Get.snackbar(
                  'Coming Soon',
                  'Payment functionality is under development',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              icon: const Icon(Icons.payment),
              label: const Text('Pay Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ElevatedButton.icon(
            onPressed: () async {
              await controller.cancelOrder();
              Get.snackbar(
                'Order Cancelled',
                'Order #${order.ref ?? order.id} has been cancelled.',
                snackPosition: SnackPosition.BOTTOM,
              );
            },
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 