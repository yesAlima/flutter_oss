import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import 'package:intl/intl.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../routes/app_routes.dart';
import '../../services/product_service.dart';

class DeliveryOrdersView extends StatefulWidget {
  const DeliveryOrdersView({Key? key}) : super(key: key);

  @override
  State<DeliveryOrdersView> createState() => _DeliveryOrdersViewState();
}

class _DeliveryOrdersViewState extends State<DeliveryOrdersView> {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();

  // Local filter/search state for delivery
  final TextEditingController _searchController = TextEditingController();
  double? _minTotal;
  double? _maxTotal;
  int? _minRef;
  int? _maxRef;
  DateTime? _startDate;
  DateTime? _endDate;
  String _sortBy = 'orderedAt';
  bool _sortAsc = false;
  final RxBool _isLoading = true.obs;
  final RxList<OrderModel> _orders = <OrderModel>[].obs;
  Map<String, double> _orderTotalsCache = {};

  // Cache for min/max values
  double? _fullMinTotal;
  double? _fullMaxTotal;
  int? _fullMinRef;
  int? _fullMaxRef;

  OrderFulfillment? _selectedStatus;

  // Delivery-specific status filter options
  List<OrderFulfillment> get _deliveryStatuses => [
    OrderFulfillment.pending,
    OrderFulfillment.unfulfilled,
    OrderFulfillment.fulfilled,
    OrderFulfillment.cancelled,
  ];

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
        return 'Claimed';
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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    _isLoading.value = true;
    try {
      final userId = _authService.currentUser!.id;
      final allOrders = await _orderService.getAllOrders();
      _orders.value = allOrders.where((order) =>
        order.fulfillment != OrderFulfillment.draft &&
        (order.did == userId || order.fulfillment == OrderFulfillment.pending)
      ).toList();
      
      // Calculate full min/max for total and ref
      if (_orders.isNotEmpty) {
        final totals = await Future.wait(_orders.map((o) async {
          final products = await _getProductsForOrder(o);
          return _getOrderTotal(o, products);
        }));
        _fullMinTotal = totals.reduce((a, b) => a < b ? a : b);
        _fullMaxTotal = totals.reduce((a, b) => a > b ? a : b);
        final refs = _orders.where((o) => o.ref != null).map((o) => o.ref!).toList();
        if (refs.isNotEmpty) {
          _fullMinRef = refs.reduce((a, b) => a < b ? a : b);
          _fullMaxRef = refs.reduce((a, b) => a > b ? a : b);
        }
      }
      await _updateOrderTotalsCache();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      _isLoading.value = false;
    }
  }

  List<OrderModel> _getTabOrders(int tabIndex) {
    final userId = _authService.currentUser!.id;
    switch (tabIndex) {
      case 0: // All
        return filteredOrders.where((order) =>
          order.fulfillment == OrderFulfillment.pending ||
          (order.did == userId && order.fulfillment != OrderFulfillment.draft && order.fulfillment != OrderFulfillment.pending)
        ).toList();
      case 1: // Pending
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.pending).toList();
      case 2: // Claimed (Unfulfilled)
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.unfulfilled && order.did == userId).toList();
      case 3: // Delivered (Fulfilled)
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.fulfilled && order.did == userId).toList();
      case 4: // Cancelled
        return filteredOrders.where((order) => order.fulfillment == OrderFulfillment.cancelled && order.did == userId).toList();
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search orders',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showFilterDialog,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          // Status filter chips
          SingleChildScrollView(
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
                ..._deliveryStatuses.map((status) {
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
          ),
          Expanded(
            child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : ListView.builder(
                      key: ValueKey(_orders.length),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
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
                                  'Status: ${_getStatusText(order.fulfillment)}',
                                  style: TextStyle(
                                    color: _getStatusColor(order.fulfillment),
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
                                    onPressed: () async {
                                      await _orderService.assignDelivery(order.id, _authService.currentUser!.id);
                                      await _loadOrders();
                                      Get.snackbar('Success', 'Order claimed successfully', snackPosition: SnackPosition.BOTTOM);
                                    },
                                    tooltip: 'Claim Order',
                                  ),
                                if (order.did == _authService.currentUser!.id && order.fulfillment == OrderFulfillment.unfulfilled)
                                  IconButton(
                                    icon: const Icon(Icons.check_circle),
                                    color: Colors.green,
                                    onPressed: () async {
                                      await _orderService.updateFulfillment(order.id, OrderFulfillment.fulfilled);
                                      await _loadOrders();
                                      Get.snackbar('Success', 'Order marked as delivered', snackPosition: SnackPosition.BOTTOM);
                                    },
                                    tooltip: 'Mark as Delivered',
                                  ),
                                if (order.did == _authService.currentUser!.id && order.fulfillment == OrderFulfillment.fulfilled)
                                  IconButton(
                                    icon: const Icon(Icons.undo),
                                    color: Colors.orange,
                                    onPressed: () async {
                                      await _orderService.updateFulfillment(order.id, OrderFulfillment.unfulfilled);
                                      await _loadOrders();
                                      Get.snackbar('Success', 'Order reverted to unfulfilled', snackPosition: SnackPosition.BOTTOM);
                                    },
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

  // Delivery-specific filtered orders
  List<OrderModel> get filteredOrders {
    var filtered = _orders.where((order) {
      // Status filter
      if (_selectedStatus != null && order.fulfillment != _selectedStatus) {
        return false;
      }
      // Reference number filter
      if (_minRef != null && order.ref != null && order.ref! < _minRef!) return false;
      if (_maxRef != null && order.ref != null && order.ref! > _maxRef!) return false;
      // OrderedAt date range
      if (_startDate != null && order.orderedAt != null && order.orderedAt!.isBefore(_startDate!)) return false;
      if (_endDate != null && order.orderedAt != null && order.orderedAt!.isAfter(_endDate!)) return false;
      return true;
    }).toList();

    // Total price filter (async, so use cache)
    filtered = filtered.where((order) {
      final total = _orderTotalsCache[order.id];
      if (_minTotal != null && total != null && total < _minTotal!) return false;
      if (_maxTotal != null && total != null && total > _maxTotal!) return false;
      return true;
    }).toList();

    // Sorting
    filtered.sort((a, b) {
      int cmp = 0;
      if (_sortBy == 'orderedAt') {
        cmp = (a.orderedAt ?? DateTime(1970)).compareTo(b.orderedAt ?? DateTime(1970));
      } else if (_sortBy == 'ref') {
        cmp = (a.ref ?? 0).compareTo(b.ref ?? 0);
      } else if (_sortBy == 'total') {
        final at = _orderTotalsCache[a.id] ?? 0;
        final bt = _orderTotalsCache[b.id] ?? 0;
        cmp = at.compareTo(bt);
      }
      return _sortAsc ? cmp : -cmp;
    });
    return filtered;
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Orders Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                'Order Management',
                'As a delivery personnel, you can:',
                [
                  'View orders assigned to you',
                  'Mark orders as delivered',
                  'Revert delivered orders to unfulfilled if needed',
                  'Filter and search your orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Order Status',
                'Orders can have the following statuses:',
                [
                  'Unfulfilled: Orders assigned to you for delivery',
                  'Fulfilled: Successfully delivered orders',
                ],
              ),
              const SizedBox(height: 16),
              _buildHelpSection(
                'Actions',
                'Available actions for each status:',
                [
                  'Unfulfilled: Mark as delivered',
                  'Fulfilled: Revert to unfulfilled if needed',
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

  void _showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinTotal = _minTotal;
    final tempMaxTotal = _maxTotal;
    final tempMinRef = _minRef;
    final tempMaxRef = _maxRef;
    final tempStartDate = _startDate;
    final tempEndDate = _endDate;
    final tempSortBy = _sortBy;
    final tempSortAsc = _sortAsc;

    // Create Rx variables for the dialog
    final dialogMinTotal = (tempMinTotal ?? _fullMinTotal ?? 0.0).obs;
    final dialogMaxTotal = (tempMaxTotal ?? _fullMaxTotal ?? 0.0).obs;
    final dialogMinRef = (tempMinRef ?? _fullMinRef ?? 1).obs;
    final dialogMaxRef = (tempMaxRef ?? _fullMaxRef ?? 1).obs;
    final dialogStartDate = tempStartDate.obs;
    final dialogEndDate = tempEndDate.obs;
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
                min: _fullMinTotal ?? 0.0,
                max: _fullMaxTotal ?? 1.0,
                divisions: ((_fullMaxTotal ?? 1.0) - (_fullMinTotal ?? 0.0)).round().clamp(1, 100),
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
                min: (_fullMinRef ?? 1).toDouble(),
                max: (_fullMaxRef ?? 1).toDouble(),
                divisions: ((_fullMaxRef ?? 1) - (_fullMinRef ?? 1)).clamp(1, 100),
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
                              context: context,
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
                              context: context,
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
              dialogMinTotal.value = _fullMinTotal ?? 0.0;
              dialogMaxTotal.value = _fullMaxTotal ?? 1.0;
              dialogMinRef.value = _fullMinRef ?? 1;
              dialogMaxRef.value = _fullMaxRef ?? 1;
              dialogStartDate.value = null;
              dialogEndDate.value = null;
              dialogSortBy.value = 'orderedAt';
              dialogSortAsc.value = false;
              Get.back();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () async {
              _minTotal = dialogMinTotal.value;
              _maxTotal = dialogMaxTotal.value;
              _minRef = dialogMinRef.value;
              _maxRef = dialogMaxRef.value;
              _startDate = dialogStartDate.value;
              _endDate = dialogEndDate.value;
              _sortBy = dialogSortBy.value;
              _sortAsc = dialogSortAsc.value;
              setState(() {});
              await _updateOrderTotalsCache();
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