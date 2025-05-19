import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/source_model.dart';
import '../../routes/app_routes.dart';
import '../import_view.dart';
import '../../controllers/admin/admin_orders_controller.dart';

class AdminOrdersView extends GetView<AdminOrdersController> {
  const AdminOrdersView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
      ),
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
                        onPressed: _showFilterDialog,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => controller.update(),
                  ),
                ),
              ],
            ),
          ),
          _buildStatusFilter(),
          Expanded(
            child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: controller.isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : controller.filteredOrders.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : ListView.builder(
                      key: ValueKey(controller.filteredOrders.length),
                      itemCount: controller.filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = controller.filteredOrders[index];
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Card(
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
                                  if (order.fulfillment == OrderFulfillment.import) ...[
                                    if (order.orderlines.isNotEmpty && order.orderlines[0].price != null)
                                    if (order.sourceId != null)
                                      FutureBuilder<SourceModel?>(
                                        future: controller.getSource(order.sourceId!),
                                        builder: (context, snapshot) {
                                          final source = snapshot.data;
                                          return Text(
                                            'Source: ${source?.name ?? order.sourceId}',
                                            style: const TextStyle(fontSize: 14),
                                          );
                                        },
                                      ),
                                  ],
                                  if (order.fulfillment != OrderFulfillment.import && order.cid != null)
                                    _buildCustomerName(order.cid!),
                                  Text(
                                    'Status: ${controller.getStatusText(order.fulfillment)}',
                                    style: TextStyle(
                                      color: controller.getStatusColor(order.fulfillment),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (controller.canViewDeliveryInfo(order) && order.did != null)
                                    FutureBuilder<UserModel?>(
                                      future: controller.getUser(order.did!),
                                      builder: (context, snapshot) {
                                        final deliveryUser = snapshot.data;
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Delivery: ${deliveryUser?.name ?? order.did}',
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                            if (deliveryUser?.phone != null && deliveryUser!.phone.isNotEmpty)
                                              Text(
                                                '+973 ${deliveryUser.phone}',
                                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (order.fulfillment == OrderFulfillment.import) ...[
                                        if (order.orderlines.isNotEmpty && order.orderlines[0].price != null)
                                          Text(
                                            '  Total: ${order.orderlines[0].price!.toStringAsFixed(3)} BD',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                      ] else ...[
                                        if (order.fulfillment != OrderFulfillment.cancelled && order.paid != null)
                                          _buildPaidBadge(order.paid!),
                                        const SizedBox(width: 8),
                                        FutureBuilder<Map<String, ProductModel>>(
                                          future: controller.getProductsForOrder(order),
                                          builder: (context, snapshot) {
                                            if (!snapshot.hasData) return const SizedBox.shrink();
                                            final products = snapshot.data!;
                                            final total = controller.getOrderTotal(order, products);
                                            return Text(
                                              'Total: ${total.toStringAsFixed(3)} BD',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'Ordered At: ${order.orderedAt != null ? DateFormat('MMM d, y HH:mm').format(order.orderedAt!) : 'N/A'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  if (order.address != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Address: Block ${order.address!.block}, Building ${order.address!.building}${order.address!.road != null ? ', Road ${order.address!.road}' : ''}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  _buildActionButtons(order),
                                ],
                              ),
                              onTap: () => Get.toNamed(AppRoutes.adminOrderDetails, arguments: order.id),
                            ),
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

  Widget _buildStatusFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: controller.selectedStatus.value == null,
            onSelected: (selected) {
              controller.selectedStatus.value = null;
            },
          ),
          const SizedBox(width: 8),
          ...controller.availableStatuses.map((status) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(controller.getStatusText(status)),
                selected: controller.selectedStatus.value == status,
                onSelected: (selected) {
                  controller.selectedStatus.value = selected ? status : null;
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
        ],
      ),
    );
  }

  void _showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinTotal = controller.minTotal.value;
    final tempMaxTotal = controller.maxTotal.value;
    final tempMinRef = controller.minRef.value;
    final tempMaxRef = controller.maxRef.value;
    final tempStartDate = controller.startDate.value;
    final tempEndDate = controller.endDate.value;
    final tempShowPaid = controller.showPaid.value;
    final tempShowUnpaid = controller.showUnpaid.value;
    final tempSortBy = controller.sortBy.value;
    final tempSortAsc = controller.sortAsc.value;

    // Create Rx variables for the dialog
    final dialogMinTotal = (tempMinTotal ?? controller.fullMinTotal.value ?? 0.0).obs;
    final dialogMaxTotal = (tempMaxTotal ?? controller.fullMaxTotal.value ?? 0.0).obs;
    final dialogMinRef = (tempMinRef ?? controller.fullMinRef.value ?? 1).obs;
    final dialogMaxRef = (tempMaxRef ?? controller.fullMaxRef.value ?? 1).obs;
    final dialogStartDate = tempStartDate.obs;
    final dialogEndDate = tempEndDate.obs;
    final dialogShowPaid = tempShowPaid.obs;
    final dialogShowUnpaid = tempShowUnpaid.obs;
    final dialogSortBy = tempSortBy.obs;
    final dialogSortAsc = tempSortAsc.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('Filter Orders'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Price (BD)', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinTotal.value, dialogMaxTotal.value),
                min: controller.fullMinTotal.value ?? 0.0,
                max: controller.fullMaxTotal.value ?? 1.0,
                divisions: ((controller.fullMaxTotal.value ?? 1.0) - (controller.fullMinTotal.value ?? 0.0)).round().clamp(1, 100),
                labels: RangeLabels(
                  '${dialogMinTotal.value.floor()} BD',
                  '${dialogMaxTotal.value.ceil()} BD',
                ),
                onChanged: (values) {
                  dialogMinTotal.value = values.start;
                  dialogMaxTotal.value = values.end;
                },
              )),
              const SizedBox(height: 16),
              const Text('Reference Number', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinRef.value.toDouble(), dialogMaxRef.value.toDouble()),
                min: (controller.fullMinRef.value ?? 1).toDouble(),
                max: (controller.fullMaxRef.value ?? 1).toDouble(),
                divisions: ((controller.fullMaxRef.value ?? 1) - (controller.fullMinRef.value ?? 1)).clamp(1, 100),
                labels: RangeLabels(
                  dialogMinRef.value.toString(),
                  dialogMaxRef.value.toString(),
                ),
                onChanged: (values) {
                  dialogMinRef.value = values.start.round();
                  dialogMaxRef.value = values.end.round();
                },
              )),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        Obx(() => OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: Get.context!,
                              initialDate: dialogStartDate.value ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) dialogStartDate.value = picked;
                          },
                          child: Text(dialogStartDate.value != null ? DateFormat('y-MM-dd').format(dialogStartDate.value!) : 'Any'),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold)),
                        Obx(() => OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: Get.context!,
                              initialDate: dialogEndDate.value ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) dialogEndDate.value = picked;
                          },
                          child: Text(dialogEndDate.value != null ? DateFormat('y-MM-dd').format(dialogEndDate.value!) : 'Any'),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Paid'),
                      value: dialogShowPaid.value,
                      onChanged: (value) => dialogShowPaid.value = value,
                    )),
                  ),
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Unpaid'),
                      value: dialogShowUnpaid.value,
                      onChanged: (value) => dialogShowUnpaid.value = value,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  Obx(() => ChoiceChip(
                    label: const Text('Order Date'),
                    selected: dialogSortBy.value == 'orderedAt',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'orderedAt';
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Reference Number'),
                    selected: dialogSortBy.value == 'ref',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'ref';
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Total Price'),
                    selected: dialogSortBy.value == 'total',
                    onSelected: (selected) {
                      if (selected) dialogSortBy.value = 'total';
                    },
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => SwitchListTile(
                title: const Text('Sort Ascending'),
                value: dialogSortAsc.value,
                onChanged: (value) => dialogSortAsc.value = value,
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Clear all filters to their default values
              dialogMinTotal.value = controller.fullMinTotal.value ?? 0.0;
              dialogMaxTotal.value = controller.fullMaxTotal.value ?? 1.0;
              dialogMinRef.value = controller.fullMinRef.value ?? 1;
              dialogMaxRef.value = controller.fullMaxRef.value ?? 1;
              dialogStartDate.value = null;
              dialogEndDate.value = null;
              dialogShowPaid.value = true;
              dialogShowUnpaid.value = true;
              dialogSortBy.value = 'orderedAt';
              dialogSortAsc.value = false;
              Get.back();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () async {
              controller.minTotal.value = dialogMinTotal.value;
              controller.maxTotal.value = dialogMaxTotal.value;
              controller.minRef.value = dialogMinRef.value;
              controller.maxRef.value = dialogMaxRef.value;
              controller.startDate.value = dialogStartDate.value;
              controller.endDate.value = dialogEndDate.value;
              controller.showPaid.value = dialogShowPaid.value;
              controller.showUnpaid.value = dialogShowUnpaid.value;
              controller.sortBy.value = dialogSortBy.value;
              controller.sortAsc.value = dialogSortAsc.value;
              controller.update();
              await controller.updateOrderTotalsCache();
              Get.back();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerName(String customerId) {
    return FutureBuilder<UserModel?>(
      future: controller.getUser(customerId),
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

  Widget _buildActionButtons(OrderModel order) {
    if (controller.currentUser.isDelivery && order.did != controller.currentUser.id) {
      return const SizedBox.shrink();
    }

    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        if (!controller.currentUser.isAdmin) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delivery_dining),
              color: Colors.blue,
              tooltip: 'Assign Delivery',
              onPressed: () => _showDeliveryUserMenu(order),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              color: Colors.red,
              tooltip: 'Cancel Order',
              onPressed: () => controller.updateOrderStatus(order.id, OrderFulfillment.cancelled),
            ),
          ],
        );
      case OrderFulfillment.unfulfilled:
        if (!controller.currentUser.isAdmin) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.did != null) ...[
              FutureBuilder<UserModel?>(
                future: controller.getUser(order.did!),
                builder: (context, snapshot) {
                  final deliveryUser = snapshot.data;
                  return TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                    label: Text(
                      deliveryUser?.name ?? 'Change Delivery',
                      style: const TextStyle(color: Colors.blue),
                    ),
                    onPressed: () => _showDeliveryUserMenu(order),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: Colors.orange,
                tooltip: 'Remove Delivery',
                onPressed: () => controller.revokeDelivery(order.id),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.check_circle),
              color: Colors.green,
              tooltip: 'Mark as Delivered',
              onPressed: () => controller.updateOrderStatus(order.id, OrderFulfillment.fulfilled),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              color: Colors.red,
              tooltip: 'Cancel Order',
              onPressed: () => controller.updateOrderStatus(order.id, OrderFulfillment.cancelled),
            ),
          ],
        );
      case OrderFulfillment.fulfilled:
        if (!controller.currentUser.isAdmin) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              color: Colors.blue,
              tooltip: 'Revert to Unfulfilled',
              onPressed: () => controller.updateOrderStatus(order.id, OrderFulfillment.unfulfilled),
            ),
          ],
        );
      case OrderFulfillment.cancelled:
        return const SizedBox.shrink();
      case OrderFulfillment.import:
        if (!controller.currentUser.isAdmin && !controller.currentUser.isSupplier) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: Colors.purple,
              tooltip: 'Edit Import Order',
              onPressed: () async {
                showDialog(
                  context: Get.context!,
                  builder: (context) => ImportView(order: order),
                );
              },
            ),
          ],
        );
      case OrderFulfillment.draft:
        return const SizedBox.shrink();
    }
  }

  void _showDeliveryUserMenu(OrderModel order) {
    if (!controller.currentUser.isAdmin) return;

    showModalBottomSheet(
      context: Get.context!,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<List<UserModel>>(
          future: controller.getDeliveryUsers(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final deliveryUsers = snapshot.data!;
            return ListView(
              shrinkWrap: true,
              children: [
                const ListTile(
                  title: Text('Assign Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                ...deliveryUsers.map((user) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(user.name),
                  onTap: () async {
                    await controller.assignDelivery(order.id, user.id);
                    Navigator.pop(context);
                  },
                )),
              ],
            );
          },
        );
      },
    );
  }
} 