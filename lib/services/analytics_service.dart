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
        (sum, line) => sum + line.quantity,
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
        (sum, line) => sum + line.quantity,
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
      if (isImport && order.orderlines.isNotEmpty) {
        // Import order: single orderline, quantity = total import cost, id = product id
        final line = order.orderlines.first;
        totalImportCost += line.quantity;
        productImports[line.id] = (productImports[line.id] ?? 0) + line.quantity.toInt();
        orderTotal = 0; // Import orders do not count as revenue
      } else {
        // Sales order
        orderTotal = order.orderlines.fold<double>(
          0,
          (sum, line) => sum + line.quantity,
        );
        totalRevenue += orderTotal;
        totalOrders++;
        if (orderDate != null) {
          final dayKey = '${orderDate.year}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
          salesByDay[dayKey] = (salesByDay[dayKey] ?? 0) + orderTotal;
        }
        for (var line in order.orderlines) {
          productSales[line.id] = (productSales[line.id] ?? 0) + line.quantity.toInt();
          final product = await _firestore
              .collection('products')
              .doc(line.id)
              .get();
          if (product.exists) {
            final categoryId = product.data()!['categoryId'] as String;
            final categoryName = categoryIdToName[categoryId] ?? categoryId;
            categoryRevenue[categoryName] = (categoryRevenue[categoryName] ?? 0) + line.quantity;
          }
        }
      }
    }

    // Calculate average order value and conversion rate (dummy for now)
    final averageOrderValue = totalOrders > 0 ? totalRevenue / totalOrders : 0.0;
    const conversionRate = 0.0; // Placeholder, needs real calculation
    final totalProfit = totalRevenue - totalImportCost;

    // Product performance: sales vs. imports
    Map<String, Map<String, int>> productPerformance = {};
    final productsSnapshot = await _firestore.collection('products').get();
    final productIdToName = {for (var doc in productsSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final allProductIds = <String>{...productSales.keys, ...productImports.keys};
    for (final pid in allProductIds) {
      productPerformance[productIdToName[pid] ?? pid] = {
        'sold': productSales[pid] ?? 0,
        'imported': productImports[pid] ?? 0,
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
          (sum, line) => sum + line.quantity,
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

  Future<String> exportOrdersToCSV() async {
    final snapshot = await _firestore.collection('orders')
        .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last)
        .get();
    final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
    
    final csv = StringBuffer();
    csv.writeln('Order ID,Date,Customer,Total,Status');
    
    for (var order in orders) {
      csv.writeln([
        order.id,
        order.orderedAt!.toIso8601String(),
        order.cid,
        order.orderlines.fold<double>(
          0,
          (sum, line) => sum + line.quantity,
        ).toStringAsFixed(2),
        order.fulfillment.toString().split('.').last,
      ].join(','));
    }
    
    return csv.toString();
  }

  Future<String> exportProductsToCSV() async {
    final snapshot = await _firestore
        .collection('products')
        .where('isActive', isEqualTo: true)
        .get();
    final products = snapshot.docs
        .map((doc) => ProductModel.fromFirestore(doc))
        .toList();
    
    final csv = StringBuffer();
    csv.writeln('Product ID,Name,Description,Price,Stock,Category');
    
    for (var product in products) {
      csv.writeln([
        product.id,
        product.name,
        product.description,
        product.price.toStringAsFixed(2),
        product.stock,
        product.categoryId,
      ].join(','));
    }
    
    return csv.toString();
  }

  Future<String> exportUsersToCSV() async {
    final snapshot = await _firestore.collection('users').get();
    final users = snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
    
    final csv = StringBuffer();
    csv.writeln('User ID,Name,Email,Role,Status');
    
    for (var user in users) {
      csv.writeln([
        user.id,
        user.name,
        user.email,
        user.role.toString().split('.').last,
        user.isActive ? 'Active' : 'Inactive',
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
} 