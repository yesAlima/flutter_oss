import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/source_model.dart';
import '../../controllers/supplier/supplier_orders_controller.dart';
import 'package:intl/intl.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/source_service.dart';
import '../../views/import_view.dart';
import '../../controllers/import_controller.dart';

class SupplierOrdersView extends StatelessWidget {
  const SupplierOrdersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SupplierOrdersController());

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
                ...controller.supplierStatuses.map((status) {
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
                              'Order #${order.ref ?? (order.id.length > 6 ? order.id.substring(order.id.length - 6) : order.id)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                if (order.fulfillment == OrderFulfillment.import && order.sourceId != null)
                                  _buildSourceName(order.sourceId!),
                                if (order.fulfillment != OrderFulfillment.import && order.cid != null)
                                  _buildCustomerName(order.cid!),
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
                                if (order.fulfillment != OrderFulfillment.cancelled && order.paid != null)
                                  _buildPaidBadge(order.paid!),
                                Text(
                                  'Ordered At: ${order.orderedAt != null ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!) : 'N/A'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                children: [
                                if (order.fulfillment == OrderFulfillment.import)
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.purple,
                                    onPressed: () => _showImportDialog(context, order),
                                    tooltip: 'Edit Import',
                  ),
                ],
              ),
                            onTap: () => Get.toNamed(AppRoutes.supplierOrderDetails, arguments: order.id),
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

  Widget _buildSourceName(String sourceId) {
    return FutureBuilder<SourceModel?>(
      future: Get.find<SourceService>().getSource(sourceId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text('Loading source...');
        }
        if (snapshot.hasError) {
          return const Text('Error loading source');
        }
        final source = snapshot.data;
        return Text(
          'Source: ${source?.name ?? 'Unknown'}',
          style: const TextStyle(fontSize: 14),
        );
      },
    );
  }

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

  void _showImportDialog(BuildContext context, OrderModel order) {
    Get.put(ImportController());
    showDialog(
      context: context,
      builder: (context) => ImportView(order: order),
    );
  }
} 