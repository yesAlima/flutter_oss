import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../models/order_model.dart';
import '../../models/user_model.dart';
import '../../models/product_model.dart';
import '../../models/source_model.dart';
import '../../services/order_service.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/source_service.dart';
import '../../routes/app_routes.dart';
import '../import_view.dart';
import '../../controllers/order_controller.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({Key? key}) : super(key: key);

  @override
  State<AdminOrdersView> createState() => AdminOrdersViewState();
}

class AdminOrdersViewState extends State<AdminOrdersView> {
  final _orderService = Get.find<OrderService>();
  final _authService = Get.find<AuthService>();
  final _productService = Get.find<ProductService>();
  final _sourceService = Get.find<SourceService>();
  final _searchController = TextEditingController();
  final RxList<OrderModel> _orders = <OrderModel>[].obs;
  final RxBool _isLoading = true.obs;
  OrderFulfillment? _selectedStatus;
  late final UserModel _currentUser;

  // Filter state
  double? _minTotal;
  double? _maxTotal;
  int? _minRef;
  int? _maxRef;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showPaid = true;
  bool _showUnpaid = true;
  String _sortBy = 'orderedAt'; // 'orderedAt', 'ref', 'total'
  bool _sortAsc = false;

  double? _fullMinTotal;
  double? _fullMaxTotal;
  int? _fullMinRef;
  int? _fullMaxRef;

  Map<String, double> _orderTotalsCache = {};

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser!;
    _loadOrders();
    _updateOrderTotalsCache();
  }

  Future<void> _loadOrders() async {
    _isLoading.value = true;
    try {
      List<OrderModel> orders;
      if (_currentUser.isDelivery) {
        orders = await _orderService.getOrders(fulfillment: _selectedStatus).first;
      } else if (_currentUser.isAdmin) {
        orders = await _orderService.getAllOrders();
      } else {
        orders = await _orderService.getOrders(fulfillment: _selectedStatus).first;
      }
      _orders.value = orders.where((order) => order.fulfillment != OrderFulfillment.draft).toList();
      
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
    } catch (e) {
      Get.snackbar('Error', 'Failed to load orders');
    } finally {
      _isLoading.value = false;
    }
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
      case OrderFulfillment.import:
        return Colors.purple;
      case OrderFulfillment.draft:
        return Colors.grey;
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

  List<OrderModel> get _filteredOrders {
    var filtered = _orders.where((order) {
      // Filter out import orders for non-admin and non-supplier users
      if (order.fulfillment == OrderFulfillment.import && 
          !_currentUser.isAdmin && 
          !_currentUser.isSupplier) {
        return false;
      }
      // Status filter
      if (_selectedStatus != null && order.fulfillment != _selectedStatus) {
        return false;
      }
      // Paid/unpaid filter
      if (!_showPaid && order.paid == true) return false;
      if (!_showUnpaid && order.paid == false) return false;
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

  void _showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinTotal = _minTotal;
    final tempMaxTotal = _maxTotal;
    final tempMinRef = _minRef;
    final tempMaxRef = _maxRef;
    final tempStartDate = _startDate;
    final tempEndDate = _endDate;
    final tempShowPaid = _showPaid;
    final tempShowUnpaid = _showUnpaid;
    final tempSortBy = _sortBy;
    final tempSortAsc = _sortAsc;

    // Create Rx variables for the dialog
    final dialogMinTotal = (tempMinTotal ?? _fullMinTotal ?? 0.0).obs;
    final dialogMaxTotal = (tempMaxTotal ?? _fullMaxTotal ?? 0.0).obs;
    final dialogMinRef = (tempMinRef ?? _fullMinRef ?? 1).obs;
    final dialogMaxRef = (tempMaxRef ?? _fullMaxRef ?? 1).obs;
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
              dialogMinTotal.value = _fullMinTotal ?? 0.0;
              dialogMaxTotal.value = _fullMaxTotal ?? 1.0;
              dialogMinRef.value = _fullMinRef ?? 1;
              dialogMaxRef.value = _fullMaxRef ?? 1;
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
              _minTotal = dialogMinTotal.value;
              _maxTotal = dialogMaxTotal.value;
              _minRef = dialogMinRef.value;
              _maxRef = dialogMaxRef.value;
              _startDate = dialogStartDate.value;
              _endDate = dialogEndDate.value;
              _showPaid = dialogShowPaid.value;
              _showUnpaid = dialogShowUnpaid.value;
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

  List<OrderFulfillment> get _availableStatuses {
    if (_currentUser.isAdmin || _currentUser.isSupplier) {
      return [
        OrderFulfillment.pending,
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
        OrderFulfillment.cancelled,
        OrderFulfillment.import,
      ];
    } else if (_currentUser.isDelivery) {
      return [
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
      ];
    } else {
      return [
        OrderFulfillment.pending,
        OrderFulfillment.unfulfilled,
        OrderFulfillment.fulfilled,
        OrderFulfillment.cancelled,
      ];
    }
  }

  bool _canViewDeliveryInfo(OrderModel order) => _currentUser.isAdmin;
  bool _canAssignDelivery(OrderModel order) => 
    _currentUser.isAdmin && 
    (order.fulfillment == OrderFulfillment.pending || 
     order.fulfillment == OrderFulfillment.unfulfilled);
  bool _canRevokeDelivery(OrderModel order) => 
    _currentUser.isAdmin && 
    order.fulfillment == OrderFulfillment.unfulfilled;

  bool _canUpdateStatus(OrderModel order, OrderFulfillment status) {
    if (_currentUser.isDelivery && order.did != _currentUser.id) return false;
    
    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        return _currentUser.isAdmin && status == OrderFulfillment.cancelled;
      case OrderFulfillment.unfulfilled:
        return status == OrderFulfillment.fulfilled || 
               (_currentUser.isAdmin && status == OrderFulfillment.cancelled);
      case OrderFulfillment.fulfilled:
        return status == OrderFulfillment.unfulfilled;
      case OrderFulfillment.cancelled:
      case OrderFulfillment.draft:
      case OrderFulfillment.import:
        return false;
    }
  }

  void _onOrderTap(OrderModel order) {
    Get.toNamed(AppRoutes.adminOrderDetails, arguments: order.id);
  }

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
          buildStatusFilter(),
          Expanded(
            child: Obx(() => AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _isLoading.value
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                  ? const Center(child: Text('No orders found'))
                  : ListView.builder(
                      key: ValueKey(_filteredOrders.length),
                      itemCount: _filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
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
                                        future: _sourceService.getSource(order.sourceId!),
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
                                    'Status: ${_getStatusText(order.fulfillment)}',
                                    style: TextStyle(
                                      color: _getStatusColor(order.fulfillment),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_canViewDeliveryInfo(order) && order.did != null)
                                    FutureBuilder<UserModel?>(
                                      future: _authService.getUser(order.did!),
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
                              onTap: () => _onOrderTap(order),
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

  Widget _buildActionButtons(OrderModel order) {
    if (_currentUser.isDelivery && order.did != _currentUser.id) {
      return const SizedBox.shrink();
    }

    switch (order.fulfillment) {
      case OrderFulfillment.pending:
        if (!_currentUser.isAdmin) return const SizedBox.shrink();
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
              onPressed: () => _updateOrderStatus(order, OrderFulfillment.cancelled),
            ),
          ],
        );
      case OrderFulfillment.unfulfilled:
        if (!_currentUser.isAdmin) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (order.did != null) ...[
              FutureBuilder<UserModel?>(
                future: _authService.getUser(order.did!),
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
                color: Colors.red,
                tooltip: 'Remove Delivery',
                onPressed: () async {
                  try {
                    await _orderService.revokeDelivery(order.id);
                    await _updateOrderStatus(order, OrderFulfillment.pending);
                    Get.snackbar(
                      'Success',
                      'Delivery removed and order reverted to pending',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to remove delivery: $e',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
              ),
            ],
            IconButton(
              icon: const Icon(Icons.check_circle),
              color: Colors.green,
              tooltip: 'Mark as Delivered',
              onPressed: () => _updateOrderStatus(order, OrderFulfillment.fulfilled),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              color: Colors.red,
              tooltip: 'Cancel Order',
              onPressed: () => _updateOrderStatus(order, OrderFulfillment.cancelled),
            ),
          ],
        );
      case OrderFulfillment.fulfilled:
        if (!_currentUser.isAdmin) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              color: Colors.orange,
              tooltip: 'Revert to Unfulfilled',
              onPressed: () => _updateOrderStatus(order, OrderFulfillment.unfulfilled),
            ),
          ],
        );
      case OrderFulfillment.cancelled:
        return const SizedBox.shrink();
      case OrderFulfillment.import:
        if (!_currentUser.isAdmin && !_currentUser.isSupplier) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              color: Colors.blue,
              tooltip: 'Edit Import Order',
              onPressed: () async {
                await Get.find<OrderController>().loadSources();
                showDialog(
                  context: context,
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

  Widget _buildDeliveryChip(OrderModel order) {
    if (!_currentUser.isAdmin) return const SizedBox.shrink();

    return FutureBuilder<UserModel?>(
      future: order.did != null ? _authService.getUser(order.did!) : Future.value(null),
      builder: (context, snapshot) {
        final deliveryUser = snapshot.data;
        final hasDelivery = deliveryUser != null;
        return RawChip(
          avatar: const Icon(Icons.delivery_dining, size: 18),
          label: Text(
            hasDelivery ? deliveryUser.name : 'Assign Delivery',
            style: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _showDeliveryUserMenu(order),
          backgroundColor: Colors.blue.shade100,
          labelStyle: TextStyle(
            color: Colors.blue.shade700,
          ),
          deleteIcon: (hasDelivery && order.fulfillment == OrderFulfillment.unfulfilled)
              ? const Icon(Icons.close, size: 16, color: Colors.red)
              : null,
          onDeleted: (hasDelivery && order.fulfillment == OrderFulfillment.unfulfilled)
              ? () async {
                  try {
                    await _orderService.revokeDelivery(order.id);
                    await _loadOrders();
                    Get.snackbar(
                      'Success',
                      'Delivery assignment removed',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Failed to remove delivery: $e',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                }
              : null,
        );
      },
    );
  }

  void _showDeliveryUserMenu(OrderModel order) {
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
                      await _orderService.assignDelivery(order.id, user.id);
                      await _loadOrders();
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

  Future<void> _updateOrderStatus(OrderModel order, OrderFulfillment status) async {
    try {
      await _orderService.updateFulfillment(order.id, status);
      await _loadOrders();
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

  // Add these public getters for subclass access
  bool get isLoading => _isLoading.value;
  List<OrderModel> get filteredOrders => _filteredOrders;
  String getStatusText(OrderFulfillment status) => _getStatusText(status);
  Widget buildPaidBadge(bool paid) => _buildPaidBadge(paid);
  void onOrderTap(OrderModel order) => _onOrderTap(order);

  // Add these protected methods for subclasses
  @protected
  void setOrders(List<OrderModel> orders) {
    _orders.value = orders;
  }

  @protected
  void setLoading(bool loading) {
    _isLoading.value = loading;
  }

  @protected
  Future<void> updateOrderTotalsCache() async {
    await _updateOrderTotalsCache();
  }

  @protected
  double? get fullMinTotal => _fullMinTotal;
  @protected
  double? get fullMaxTotal => _fullMaxTotal;
  @protected
  int? get fullMinRef => _fullMinRef;
  @protected
  int? get fullMaxRef => _fullMaxRef;
} 