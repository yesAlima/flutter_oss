import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../routes/app_routes.dart';

class AdminOrderDetailsView extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailsView({
    Key? key,
    required this.orderId,
  }) : super(key: key);

  @override
  State<AdminOrderDetailsView> createState() => AdminOrderDetailsViewState();
}

class AdminOrderDetailsViewState extends State<AdminOrderDetailsView> {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final Rx<OrderModel?> _order = Rx<OrderModel?>(null);
  final RxBool _isLoading = true.obs;
  late final UserModel _currentUser;
  Map<String, ProductModel> _products = {};

  RxBool get isLoading => _isLoading;
  Rx<OrderModel?> get order => _order;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser!;
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    _isLoading.value = true;
    try {
      _orderService.getOrderById(widget.orderId).listen((order) {
        _order.value = order;
        if (order != null) {
          _loadProducts(order);
        }
      });
    } catch (e) {
      Get.snackbar('Error', 'Failed to load order details');
    } finally {
      _isLoading.value = false;
    }
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
      _products = products;
    });
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

  double _getOrderTotal() {
    if (_order.value == null) return 0;
    double total = 0;
    for (var line in _order.value!.orderlines) {
      final product = _products[line.id];
      if (product != null) {
        total += product.price * line.quantity;
      }
    }
    return total;
  }

  Widget _buildCustomerInfo() {
    if (_order.value?.cid == null) return const SizedBox.shrink();
    return FutureBuilder<UserModel?>(
      future: _authService.getUser(_order.value!.cid!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: Icon(Icons.person),
            title: Text('Loading customer info...'),
          );
        }
        final customer = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(customer?.name ?? 'Unknown Customer'),
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
    );
  }

  Widget _buildDeliveryInfo() {
    if (!_canViewDeliveryInfo()) return const SizedBox.shrink();
    if (_order.value?.did == null) return const SizedBox.shrink();

    return FutureBuilder<UserModel?>(
      future: _authService.getUser(_order.value!.did!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: Icon(Icons.delivery_dining),
            title: Text('Loading delivery info...'),
          );
        }
        final delivery = snapshot.data;
        return ListTile(
          leading: const Icon(Icons.delivery_dining),
          title: Text(delivery?.name ?? 'Unknown Delivery'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(delivery?.email ?? ''),
              if (delivery?.phone != null && delivery!.phone.isNotEmpty)
                Text('+973 ${delivery.phone}'),
            ],
          ),
          trailing: _canAssignDelivery() ? _buildDeliveryChip() : null,
        );
      },
    );
  }

  Widget _buildDeliveryChip() {
    return RawChip(
      avatar: const Icon(Icons.delivery_dining, size: 18),
      label: const Text('Change Delivery'),
      onPressed: _showDeliveryUserMenu,
      backgroundColor: Colors.blue.shade100,
      labelStyle: TextStyle(
        color: Colors.blue.shade700,
      ),
    );
  }

  void _showDeliveryUserMenu() {
    if (!_currentUser.isAdmin) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<List<UserModel>>(
          future: _authService.getDeliveryUsers(),
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
                    try {
                      await _orderService.assignDelivery(_order.value!.id, user.id);
                      Navigator.pop(context);
                      Get.snackbar(
                        'Success',
                        'Delivery assigned successfully',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    } catch (e) {
                      Get.snackbar(
                        'Error',
                        'Failed to assign delivery: $e',
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDeliveryAddress() {
    if (_order.value?.address == null) return const SizedBox.shrink();

    final address = _order.value!.address!;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Address',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Block ${address.block}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildOrderItems() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: _order.value!.fulfillment != OrderFulfillment.import ? 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order.value?.orderlines.length ?? 0,
            itemBuilder: (context, index) {
              final line = _order.value!.orderlines[index];
              final product = _products[line.id];
              if (product == null) return const SizedBox.shrink();
              return ListTile(
                leading: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_not_supported),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_getOrderTotal().toStringAsFixed(3)} BD',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ) : 
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Order Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _order.value?.orderlines.length ?? 0,
            itemBuilder: (context, index) {
              final line = _order.value!.orderlines[index];
              final product = _products[line.id];
              if (product == null) return const SizedBox.shrink();
              return ListTile(
                leading: product.imageUrl != null
                    ? Image.network(
                        product.imageUrl!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image_not_supported),
                title: Text(product.name),
                subtitle: Text('${((line.price ?? 0)/line.quantity).toStringAsFixed(3)} BD x ${line.quantity}'),
                trailing: Text(
                  'Total: ${(line.price ?? 0 * line.quantity).toStringAsFixed(3)} BD',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatus() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_order.value!.fulfillment).withAlpha(100),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(_order.value!.fulfillment),
                    ),
                  ),
                  child: Text(
                    _getStatusText(_order.value!.fulfillment),
                    style: TextStyle(
                      color: _getStatusColor(_order.value!.fulfillment),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_order.value!.fulfillment != OrderFulfillment.cancelled && _order.value!.fulfillment != OrderFulfillment.import)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_order.value!.paid ?? false)
                          ? Colors.green.withAlpha(100)
                          : Colors.red.withAlpha(100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (_order.value!.paid ?? false) ? Colors.green : Colors.red,
                      ),
                    ),
                    child: Text(
                      (_order.value!.paid ?? false) ? 'Paid' : 'Unpaid',
                      style: TextStyle(
                        color: (_order.value!.paid ?? false) ? Colors.green : Colors.red,
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

  Widget _buildActionButtons() {
    if (_order.value == null) return const SizedBox.shrink();

    final order = _order.value!;
    if (_currentUser.isDelivery && order.did != _currentUser.id) {
      return const SizedBox.shrink();
    }

    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        if (!_currentUser.isAdmin) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(OrderFulfillment.cancelled),
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      case OrderFulfillment.unfulfilled:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_currentUser.isAdmin)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _updateOrderStatus(OrderFulfillment.cancelled),
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              if (_currentUser.isAdmin) const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(OrderFulfillment.fulfilled),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      case OrderFulfillment.fulfilled:
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _updateOrderStatus(OrderFulfillment.unfulfilled),
                  icon: const Icon(Icons.undo),
                  label: const Text('Revert to Unfulfilled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      case OrderFulfillment.cancelled:
      case OrderFulfillment.draft:
      case OrderFulfillment.import:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateOrderStatus(OrderFulfillment status) async {
    try {
      await _orderService.updateFulfillment(_order.value!.id, status);
      Get.snackbar(
        'Success',
        'Order status updated successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update order status: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  bool _canViewDeliveryInfo() => _currentUser.isAdmin;
  bool _canAssignDelivery() => 
    _currentUser.isAdmin && 
    (_order.value?.fulfillment == OrderFulfillment.pending || 
     _order.value?.fulfillment == OrderFulfillment.unfulfilled);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(
          _order.value?.ref != null 
              ? 'Order #${_order.value!.ref}'
              : 'Order Details',
        )),
      ),
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_order.value == null) {
          return const Center(child: Text('Order not found'));
        }

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildOrderStatus(),
              buildCustomerInfo(),
              buildDeliveryInfo(),
              buildDeliveryAddress(),
              buildOrderItems(),
              _buildActionButtons(),
            ],
          ),
        );
      }),
    );
  }

  Widget buildOrderStatus() => _buildOrderStatus();
  Widget buildCustomerInfo() => _buildCustomerInfo();
  Widget buildDeliveryInfo() => _buildDeliveryInfo();
  Widget buildDeliveryAddress() => _buildDeliveryAddress();
  Widget buildOrderItems() => _buildOrderItems();
} 