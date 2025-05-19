import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/user_model.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<double> getTotalSales() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc);
      total += order.orderlines.fold<double>(
        0,
        (summ, line) => summ + line.quantity,
      );
    }
    return total;
  }

  Future<int> getTotalOrders() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    return snapshot.docs.length;
  }

  Future<int> getTotalProducts() async {
    final snapshot = await _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<int> getTotalUsers() async {
    final snapshot = await _firestore
        .collection('users')
        .where('isActive', isEqualTo: true)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  Future<double> getTotalRevenue() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    double total = 0;
    for (var doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc);
      total += order.orderlines.fold<double>(
        0,
        (summ, line) => summ + line.quantity,
      );
    }
    return total;
  }

  Future<Map<String, int>> getProductSales() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    final Map<String, int> sales = {};
    for (var doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc);
      for (var line in order.orderlines) {
        sales[line.id] = (sales[line.id] ?? 0) + line.quantity.toInt();
      }
    }
    return sales;
  }

  Future<Map<String, double>> getCategoryRevenue() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    final Map<String, double> revenue = {};
    for (var doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc);
      for (var line in order.orderlines) {
        final product = await _firestore
            .collection('products')
            .doc(line.id)
            .get();
        if (product.exists) {
          final categoryId = product.data()!['categoryId'] as String;
          revenue[categoryId] = (revenue[categoryId] ?? 0) + line.quantity;
        }
      }
    }
    return revenue;
  }

  Future<Map<String, dynamic>> getSalesAnalytics({
    DateTime? startDate,
    DateTime? endDate,
    OrderFulfillment? status,
  }) async {
    Query query = _firestore.collection('orders');

    // If a status is provided, use equality filter
    if (status != null) {
      query = query.where('fulfillment', isEqualTo: status.toString().split('.').last);
    }

    // Use orderedAt for date range filtering
    if (startDate != null) {
      query = query.where('orderedAt', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('orderedAt', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();
    double totalRevenue = 0;
    double totalImportCost = 0;
    int totalOrders = 0;
    Map<String, int> productSales = {};
    Map<String, int> productImports = {};
    Map<String, double> categoryRevenue = {};
    Map<String, String> categoryIdToName = {};
    Map<String, double> salesByDay = {};

    // Track revenue and import cost per product
    Map<String, double> productRevenue = {};
    Map<String, double> productImportCost = {};

    // Preload all categories for name mapping
    final categoriesSnapshot = await _firestore.collection('categories').get();
    for (var doc in categoriesSnapshot.docs) {
      final data = doc.data();
      categoryIdToName[doc.id] = data['name'] ?? doc.id;
    }

    for (var doc in snapshot.docs) {
      final order = OrderModel.fromFirestore(doc);
      if (order.fulfillment == OrderFulfillment.draft) continue;
      final orderDate = order.orderedAt;
      final isImport = order.fulfillment == OrderFulfillment.import;
      double orderTotal = 0;

      // Calculate order total using orderline prices
      for (var line in order.orderlines) {
        if (line.price != null) {
          if (isImport) {
            // For imports, add to costs
            totalImportCost += line.price!;
            productImports[line.id] = (productImports[line.id] ?? 0) + line.quantity.toInt();
            productImportCost[line.id] = (productImportCost[line.id] ?? 0) + line.price!;
          } else if (order.paid == true) {
            // For paid orders, add to revenue
            orderTotal += line.price!;
            productSales[line.id] = (productSales[line.id] ?? 0) + line.quantity.toInt();
            productRevenue[line.id] = (productRevenue[line.id] ?? 0) + line.price!;
            // Calculate price per unit
            final pricePerUnit = line.price! / line.quantity;
            // Add to category revenue
            final product = await _firestore
                .collection('products')
                .doc(line.id)
                .get();
            if (product.exists) {
              final categoryId = product.data()!['categoryId'] as String;
              final categoryName = categoryIdToName[categoryId] ?? categoryId;
              categoryRevenue[categoryName] = (categoryRevenue[categoryName] ?? 0) + line.price!;
            }
          }
        }
      }

      if (!isImport && order.paid == true) {
        totalRevenue += orderTotal;
        totalOrders++;
        if (orderDate != null) {
          final dayKey = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
          salesByDay[dayKey] = (salesByDay[dayKey] ?? 0) + orderTotal;
        }
      }
    }

    // Calculate average order value and conversion rate
    final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    const conversionRate = 0.0; // Placeholder, needs real calculation
    final totalProfit = totalRevenue - totalImportCost;

    // Product performance: sales vs. imports
    Map<String, Map<String, dynamic>> productPerformance = {};
    final productsSnapshot = await _firestore.collection('products').get();
    final productIdToName = {for (var doc in productsSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final allProductIds = <String>{...productSales.keys, ...productImports.keys};
    for (final pid in allProductIds) {
      final name = productIdToName[pid] ?? pid;
      final revenue = productRevenue[pid] ?? 0.0;
      final importCost = productImportCost[pid] ?? 0.0;
      productPerformance[name] = {
        'sold': productSales[pid] ?? 0,
        'imported': productImports[pid] ?? 0,
        'revenue': revenue,
        'importCost': importCost,
        'profit': revenue - importCost,
      };
    }

    return {
      'totalRevenue': totalRevenue,
      'totalImportCost': totalImportCost,
      'totalProfit': totalProfit,
      'totalOrders': totalOrders,
      'productSales': productSales,
      'productImports': productImports,
      'productPerformance': productPerformance,
      'categoryRevenue': categoryRevenue,
      'salesByDay': salesByDay,
      'averageOrderValue': averageOrderValue,
      'conversionRate': conversionRate,
    };
  }

  Future<Map<String, dynamic>> getInventoryAnalytics() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      int totalProducts = products.length;
      int totalStock = 0;
      int lowStockProducts = 0;
      Map<String, int> productsByCategory = {};

      for (final product in products) {
        totalStock += product.stock;
        if (product.alert != null && product.stock <= product.alert!) {
          lowStockProducts++;
        }
        if (product.categoryId != null) {
          productsByCategory[product.categoryId!] =
              (productsByCategory[product.categoryId!] ?? 0) + 1;
        }
      }
      return {
        'totalProducts': totalProducts,
        'totalStock': totalStock,
        'lowStockProducts': lowStockProducts,
        'productsByCategory': productsByCategory,
      };
    } catch (e) {
      throw Exception('Failed to get inventory analytics: $e');
    }
  }

  Future<Map<String, dynamic>> getUserActivityAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('users');

      if (startDate != null) {
        query = query.where('lastActivity', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('lastActivity', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

      int totalUsers = users.length;
      int activeUsers = users.where((user) => user.isActive).length;
      Map<String, int> usersByRole = {};

      for (final user in users) {
        usersByRole[user.role.toString().split('.').last] =
            (usersByRole[user.role.toString().split('.').last] ?? 0) + 1;
      }

      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'inactiveUsers': totalUsers - activeUsers,
        'usersByRole': usersByRole,
      };
    } catch (e) {
      throw Exception('Failed to get user activity analytics: $e');
    }
  }

  Future<Map<String, dynamic>> getFinancialAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('orders')
          .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last);

      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

      double totalRevenue = 0;
      double totalCost = 0;
      Map<String, double> revenueByMonth = {};
      Map<String, double> costByMonth = {};

      for (final order in orders) {
        final orderTotal = order.orderlines.fold<double>(
          0,
          (summ, line) => summ + line.quantity,
        );
        totalRevenue += orderTotal;
        totalCost += orderTotal * 0.7; // Assuming 70% cost of goods sold

        final month = order.orderedAt!.month.toString().padLeft(2, '0');
        final year = order.orderedAt!.year.toString();
        final monthYear = '$year-$month';

        revenueByMonth[monthYear] = (revenueByMonth[monthYear] ?? 0) + orderTotal;
        costByMonth[monthYear] = (costByMonth[monthYear] ?? 0) + (orderTotal * 0.7);
      }

      return {
        'totalRevenue': totalRevenue,
        'totalCost': totalCost,
        'totalProfit': totalRevenue - totalCost,
        'profitMargin': totalRevenue > 0
            ? ((totalRevenue - totalCost) / totalRevenue) * 100
            : 0,
        'revenueByMonth': revenueByMonth,
        'costByMonth': costByMonth,
      };
    } catch (e) {
      throw Exception('Failed to get financial analytics: $e');
    }
  }

  Future<List<Map<String, dynamic>>> exportAnalytics({
    required String type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      switch (type.toLowerCase()) {
        case 'sales':
          final analytics = await getSalesAnalytics(
            startDate: startDate,
            endDate: endDate,
          );
          return [analytics];
        case 'inventory':
          final analytics = await getInventoryAnalytics();
          return [analytics];
        case 'users':
          final analytics = await getUserActivityAnalytics(
            startDate: startDate,
            endDate: endDate,
          );
          return [analytics];
        case 'financial':
          final analytics = await getFinancialAnalytics(
            startDate: startDate,
            endDate: endDate,
          );
          return [analytics];
        default:
          throw Exception('Invalid analytics type: $type');
      }
    } catch (e) {
      throw Exception('Failed to export analytics: $e');
    }
  }

  Future<String> exportOrdersToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Only include fulfilled and import orders
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', whereIn: ['fulfilled', 'import'])
        .get();
    var orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

    // Filter by date in Dart
    if (startDate != null && endDate != null) {
      orders = orders.where((o) =>
        o.orderedAt != null &&
        o.orderedAt!.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        o.orderedAt!.isBefore(endDate.add(const Duration(seconds: 1)))
      ).toList();
    }

    // Preload all users and sources for name mapping
    final usersSnapshot = await _firestore.collection('users').get();
    final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final sourcesSnapshot = await _firestore.collection('sources').get();
    final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};

    // Sort by ref descending
    orders.sort((a, b) => (b.ref ?? 0).compareTo(a.ref ?? 0));

    final csv = StringBuffer();
    csv.writeln('Ref,Name,Status,Total,Date');

    for (var order in orders) {
      // Name: customer or source
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      // Status
      final status = order.fulfillment.toString().split('.').last;
      // Total with prefix
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      // Date
      final dateStr = order.orderedAt?.toIso8601String() ?? '';
      // Ref
      final refStr = order.ref?.toString() ?? '';
      csv.writeln([
        refStr,
        name,
        status,
        totalStr,
        dateStr
      ].join(','));
    }
    return csv.toString();
  }

  Future<String> exportProductsToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Fetch all products
    final productsSnapshot = await _firestore.collection('products').get();
    final products = productsSnapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
    // Get product performance analytics for the specified interval
    final analytics = await getSalesAnalytics(startDate: startDate, endDate: endDate);
    final productPerformance = analytics['productPerformance'] as Map<String, dynamic>? ?? {};
    // Sort products by name
    products.sort((a, b) => a.name.compareTo(b.name));
    final csv = StringBuffer();
    csv.writeln('Product Name,Stock,Revenue,Cost,Profit/Loss');
    for (final product in products) {
      final perf = productPerformance[product.name] as Map<String, dynamic>?;
      final revenue = perf != null ? (perf['revenue'] as double? ?? 0.0) : 0.0;
      final cost = perf != null ? (perf['importCost'] as double? ?? 0.0) : 0.0;
      final profit = revenue - cost;
      final profitStr = profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3);
      csv.writeln([
        product.name,
        product.stock,
        revenue.toStringAsFixed(3),
        cost.toStringAsFixed(3),
        profitStr,
      ].join(','));
    }
    return csv.toString();
  }

  Future<String> exportUsersToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Get all users
    final usersSnapshot = await _firestore.collection('users').get();
    var users = usersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();

    // Get all orders for activity counting
    final ordersSnapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    var orders = ordersSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

    // Filter orders by date range if specified
    if (startDate != null && endDate != null) {
      orders = orders.where((o) =>
        o.orderedAt != null &&
        o.orderedAt!.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        o.orderedAt!.isBefore(endDate.add(const Duration(seconds: 1)))
      ).toList();
    }

    // Count activities for each user
    Map<String, int> userActivities = {};
    for (var order in orders) {
      if (order.cid != null) {
        userActivities[order.cid!] = (userActivities[order.cid!] ?? 0) + 1;
      }
      if (order.sourceId != null) {
        userActivities[order.sourceId!] = (userActivities[order.sourceId!] ?? 0) + 1;
      }
    }

    // Only include delivery and customer roles
    users = users.where((u) => u.isDelivery || u.isCustomer).toList();
    users.sort((a, b) => a.role.compareTo(b.role));

    final csv = StringBuffer();
    csv.writeln('Name,Email,Phone,Role,Activity Count');

    for (var user in users) {
      // Get activity count based on role
      int activityCount = 0;
      if (user.isSupplier) {
        // Count imports for suppliers
        activityCount = orders.where((o) => 
          o.fulfillment == OrderFulfillment.import && 
          o.sourceId == user.id
        ).length;
      } else if (user.isDelivery) {
        // Count deliveries for delivery users
        activityCount = orders.where((o) => 
          o.fulfillment == OrderFulfillment.fulfilled && 
          o.did == user.id
        ).length;
      } else if (user.isCustomer) {
        // Count orders for customers
        activityCount = orders.where((o) => 
          o.fulfillment == OrderFulfillment.fulfilled && 
          o.cid == user.id
        ).length;
      }

      csv.writeln([
        user.name,
        user.email,
        user.phone,
        user.role,
        activityCount.toString(),
      ].join(','));
    }
    
    return csv.toString();
  }

  Future<String> exportAnalyticsToJSON() async {
    final analytics = await getSalesAnalytics();
    return jsonEncode(analytics);
  }

  Future<void> exportToCsv(String fileName, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;

    final headers = data.first.keys.toList();
    final csv = StringBuffer();

    // Add headers
    csv.writeln(headers.join(','));

    // Add data
    for (final row in data) {
      final values = headers.map((header) => row[header]).toList();
      csv.writeln(values.join(','));
    }

    // Save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName.csv');
    await file.writeAsString(csv.toString());

    // Share file
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<DateTime> getFirstOrderDate() async {
    final snapshot = await _firestore
        .collection('orders')
        .orderBy('orderedAt', descending: false)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      final order = OrderModel.fromFirestore(snapshot.docs.first);
      return order.orderedAt ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Returns top 5 and bottom 5 orders (excluding imports) by total price within date range
  Future<Map<String, List<OrderModel>>> getTopBottomOrders({DateTime? startDate, DateTime? endDate}) async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isEqualTo: OrderFulfillment.fulfilled.toString().split('.').last)
        .get();
    var orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    if (startDate != null && endDate != null) {
      orders = orders.where((o) =>
        o.orderedAt != null &&
        o.orderedAt!.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        o.orderedAt!.isBefore(endDate.add(const Duration(seconds: 1)))
      ).toList();
    }
    // Pair each order with its total
    final orderTotals = orders.map((o) {
      double total = 0;
      for (final line in o.orderlines) {
        if (line.price != null) total += line.price!;
      }
      return {'order': o, 'total': total};
    }).toList();
    orderTotals.sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    final top = orderTotals.take(5).map((e) => e['order'] as OrderModel).toList();
    final bottom = orderTotals.reversed.take(5).map((e) => e['order'] as OrderModel).toList().reversed.toList();
    return {
      'top': top,
      'bottom': bottom,
    };
  }

  /// Returns top 5 and bottom 5 products by profit/loss within date range
  Future<Map<String, List<Map<String, dynamic>>>> getTopBottomProducts({DateTime? startDate, DateTime? endDate}) async {
    final analytics = await getSalesAnalytics(startDate: startDate, endDate: endDate);
    final productPerformance = analytics['productPerformance'] as Map<String, dynamic>? ?? {};
    final perfList = productPerformance.entries.map((e) {
      final data = e.value as Map<String, dynamic>;
      final profit = (data['revenue'] as double? ?? 0.0) - (data['importCost'] as double? ?? 0.0);
      return {
        'name': e.key,
        'stock': data['stock'] ?? 0,
        'revenue': data['revenue'] ?? 0.0,
        'cost': data['importCost'] ?? 0.0,
        'profit': profit,
      };
    }).toList();
    perfList.sort((a, b) => (b['profit'] as double).compareTo(a['profit'] as double));
    return {
      'top': perfList.take(5).toList(),
      'bottom': perfList.reversed.take(5).toList().reversed.toList(),
    };
  }

  /// Returns top 5 and bottom 5 delivery users by number of deliveries within date range
  Future<Map<String, List<Map<String, dynamic>>>> getTopBottomDeliveryUsers({DateTime? startDate, DateTime? endDate}) async {
    // Get all users
    final usersSnapshot = await _firestore.collection('users').get();
    var users = usersSnapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    // Only delivery users
    users = users.where((u) => u.isDelivery).toList();
    // Get all orders for activity counting
    final ordersSnapshot = await _firestore.collection('orders')
        .where('fulfillment', isEqualTo: OrderFulfillment.fulfilled.toString().split('.').last)
        .get();
    var orders = ordersSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    if (startDate != null && endDate != null) {
      orders = orders.where((o) =>
        o.orderedAt != null &&
        o.orderedAt!.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        o.orderedAt!.isBefore(endDate.add(const Duration(seconds: 1)))
      ).toList();
    }
    // Count deliveries for each user
    final userDeliveries = users.map((user) {
      final count = orders.where((o) => o.did == user.id).length;
      return {
        'name': user.name,
        'email': user.email,
        'phone': user.phone,
        'role': user.role,
        'deliveries': count,
      };
    }).toList();
    userDeliveries.sort((a, b) => (b['deliveries'] as int).compareTo(a['deliveries'] as int));
    return {
      'top': userDeliveries.take(5).toList(),
      'bottom': userDeliveries.reversed.take(5).toList().reversed.toList(),
    };
  }
} 