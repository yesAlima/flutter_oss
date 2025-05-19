import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../controllers/delivery/delivery_orders_controller.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';

class DeliveryOrdersView extends StatelessWidget {
  const DeliveryOrdersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DeliveryOrdersController());

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller.searchController,
                    decoration: InputDecoration(
                      labelText: 'Search orders',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: controller.showFilterDialog,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => controller.update(),
                  ),
                ),
              ],
            ),
          ),
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Obx(() => Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: controller.selectedStatus.value == null,
                  onSelected: (selected) {
                    controller.setStatus(null);
                  },
                ),
                const SizedBox(width: 8),
                ...controller.deliveryStatuses.map((status) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(controller.getStatusText(status)),
                      selected: controller.selectedStatus.value == status,
                      onSelected: (selected) {
                        controller.setStatus(selected ? status : null);
                      },
                      backgroundColor: controller.getStatusColor(status).withAlpha(10),
                      selectedColor: controller.getStatusColor(status).withAlpha(30),
                      checkmarkColor: controller.getStatusColor(status),
                      labelStyle: TextStyle(
                        color: controller.selectedStatus.value == status 
                            ? controller.getStatusColor(status)
                            : Colors.black87,
                        fontWeight: controller.selectedStatus.value == status 
                            ? FontWeight.bold 
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
                IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: controller.showHelpDialog,
                ),
              ],
            )),
          ),
          Expanded(
            child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : controller.filteredOrders.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : ListView.builder(
                      key: ValueKey(controller.orders.length),
                      itemCount: controller.filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = controller.filteredOrders[index];
                        return Card(
                          key: ValueKey(order.id),
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              'Order #${order.ref}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCustomerName(order.cid ?? ''),
                                Text(
                                  'Status: ${controller.getStatusText(order.fulfillment)}',
                                  style: TextStyle(
                                    color: controller.getStatusColor(order.fulfillment),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (order.address != null)
                                  Text(
                                    'Address: Block ${order.address!.block}, Building ${order.address!.building}${order.address!.road != null ? ', Road ${order.address!.road}' : ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                Text(
                                  'Ordered At: ${order.orderedAt != null ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!) : 'N/A'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (order.fulfillment == OrderFulfillment.pending)
                                  IconButton(
                                    icon: const Icon(Icons.add_task),
                                    color: Colors.blue,
                                    onPressed: () => controller.claimOrder(order.id),
                                    tooltip: 'Claim Order',
                                  ),
                                if (order.did == controller.currentUser.value?.id && order.fulfillment == OrderFulfillment.unfulfilled)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle),
                                    color: Colors.green,
                                    onPressed: () => controller.markAsDelivered(order.id),
                                    tooltip: 'Mark as Delivered',
                                  ),
                                if (order.did == controller.currentUser.value?.id && order.fulfillment == OrderFulfillment.fulfilled)
                                  IconButton(
                                    icon: const Icon(Icons.undo),
                                    color: Colors.blue,
                                    onPressed: () => controller.revertToUnfulfilled(order.id),
                                    tooltip: 'Revert to Unfulfilled',
                                  ),
                              ],
                            ),
                            onTap: () => Get.toNamed(AppRoutes.deliveryOrderDetails, arguments: order.id),
                          ),
                        );
                      },
                    ),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerName(String customerId) {
    return FutureBuilder<UserModel?>(
      future: Get.find<AuthService>().getUser(customerId),
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