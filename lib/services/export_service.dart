import 'dart:io';
import 'dart:ui';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/user_model.dart';
import 'package:get/get.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' if (dart.library.io) 'dart:io' as platform;

class ExportService extends GetxService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> _downloadWebFile(Uint8List bytes, String fileName) async {
    final blob = platform.Blob([bytes]);
    final url = platform.Url.createObjectUrlFromBlob(blob);
    final anchor = platform.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    platform.Url.revokeObjectUrl(url);
  }

  Future<void> exportOrdersToExcel({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Customer Name');
      sheet.getRangeByName('B1').setText('Status');
      sheet.getRangeByName('C1').setText('Items');
      sheet.getRangeByName('D1').setText('Total');
      sheet.getRangeByName('E1').setText('Ordered At');
      sheet.getRangeByName('F1').setText('Paid');

      Query query = _firestore.collection('orders')
          .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last);
      if (startDate != null) {
        query = query.where('orderedAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('orderedAt', isLessThanOrEqualTo: endDate);
      }
      if (status != null) {
        query = query.where('fulfillment', isEqualTo: status);
      }
      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      // Preload all users for name mapping
      final usersSnapshot = await _firestore.collection('users').get();
      final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      for (var i = 0; i < orders.length; i++) {
        final order = orders[i];
        final row = i + 2;
        final customerName = order.cid != null ? (userIdToName[order.cid] ?? order.cid) : '';
        sheet.getRangeByName('A$row').setText(customerName);
        sheet.getRangeByName('B$row').setText(order.fulfillment.toString().split('.').last);
        sheet.getRangeByName('C$row').setText(order.orderlines.length.toString());
        sheet.getRangeByName('D$row').setText(order.orderlines.fold<double>(0, (sum, line) => sum + line.quantity).toString());
        sheet.getRangeByName('E$row').setText(DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!));
        sheet.getRangeByName('F$row').setText(order.paid == true ? 'Yes' : 'No');
      }
      sheet.getRangeByName('A1:F${orders.length + 1}').autoFitColumns();
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'orders_export.xlsx');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/orders_export.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'orders_export.xlsx',
        Uint8List.fromList(bytes),
        MimeType.MICROSOFTEXCEL.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export orders: $e');
    }
  }

  Future<void> exportOrdersToPdf({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Customer Name';
      header.cells[1].value = 'Status';
      header.cells[2].value = 'Items';
      header.cells[3].value = 'Total';
      header.cells[4].value = 'Ordered At';
      header.cells[5].value = 'Paid';
      Query query = _firestore.collection('orders')
          .where('fulfillment', isNotEqualTo: OrderFulfillment.draft.toString().split('.').last);
      if (startDate != null) {
        query = query.where('orderedAt', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('orderedAt', isLessThanOrEqualTo: endDate);
      }
      if (status != null) {
        query = query.where('fulfillment', isEqualTo: status);
      }
      final snapshot = await query.get();
      final orders = snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      final usersSnapshot = await _firestore.collection('users').get();
      final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      for (var order in orders) {
        final PdfGridRow row = grid.rows.add();
        final customerName = order.cid != null ? (userIdToName[order.cid] ?? order.cid) : '';
        row.cells[0].value = customerName;
        row.cells[1].value = order.fulfillment.toString().split('.').last;
        row.cells[2].value = order.orderlines.length.toString();
        row.cells[3].value = order.orderlines.fold<double>(0, (sum, line) => sum + line.quantity).toString();
        row.cells[4].value = DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!);
        row.cells[5].value = order.paid == true ? 'Yes' : 'No';
      }
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
      final List<int> bytes = await document.save();
      document.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'orders_export.pdf');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/orders_export.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'orders_export.pdf',
        Uint8List.fromList(bytes),
        MimeType.PDF.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export orders: $e');
    }
  }

  Future<void> exportProductsToExcel() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Name');
      sheet.getRangeByName('B1').setText('Description');
      sheet.getRangeByName('C1').setText('Price');
      sheet.getRangeByName('D1').setText('Stock');
      sheet.getRangeByName('E1').setText('Category');
      final snapshot = await _firestore.collection('products').get();
      final products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
      final categoriesSnapshot = await _firestore.collection('categories').get();
      final categoryIdToName = {for (var doc in categoriesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        final row = i + 2;
        final categoryName = product.categoryId != null ? (categoryIdToName[product.categoryId] ?? product.categoryId) : '';
        sheet.getRangeByName('A$row').setText(product.name);
        sheet.getRangeByName('B$row').setText(product.description);
        sheet.getRangeByName('C$row').setText(product.price.toString());
        sheet.getRangeByName('D$row').setText(product.stock.toString());
        sheet.getRangeByName('E$row').setText(categoryName);
      }
      sheet.getRangeByName('A1:E${products.length + 1}').autoFitColumns();
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'products_export.xlsx');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/products_export.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'products_export.xlsx',
        Uint8List.fromList(bytes),
        MimeType.MICROSOFTEXCEL.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export products: $e');
    }
  }

  Future<void> exportProductsToPdf() async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 5);
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Name';
      header.cells[1].value = 'Description';
      header.cells[2].value = 'Price';
      header.cells[3].value = 'Stock';
      header.cells[4].value = 'Category';
      final snapshot = await _firestore.collection('products').get();
      final products = snapshot.docs.map((doc) => ProductModel.fromFirestore(doc)).toList();
      final categoriesSnapshot = await _firestore.collection('categories').get();
      final categoryIdToName = {for (var doc in categoriesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      for (var product in products) {
        final PdfGridRow row = grid.rows.add();
        final categoryName = product.categoryId != null ? (categoryIdToName[product.categoryId] ?? product.categoryId) : '';
        row.cells[0].value = product.name;
        row.cells[1].value = product.description;
        row.cells[2].value = product.price.toString();
        row.cells[3].value = product.stock.toString();
        row.cells[4].value = categoryName;
      }
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
      final List<int> bytes = await document.save();
      document.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'products_export.pdf');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/products_export.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'products_export.pdf',
        Uint8List.fromList(bytes),
        MimeType.PDF.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export products: $e');
    }
  }

  Future<void> exportCategoriesToExcel() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Name');
      sheet.getRangeByName('B1').setText('Description');
      final snapshot = await _firestore.collection('categories').get();
      final categories = snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      for (var i = 0; i < categories.length; i++) {
        final category = categories[i];
        final row = i + 2;
        sheet.getRangeByName('A$row').setText(category.name);
        sheet.getRangeByName('B$row').setText(category.description);
      }
      sheet.getRangeByName('A1:B${categories.length + 1}').autoFitColumns();
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'categories_export.xlsx');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/categories_export.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'categories_export.xlsx',
        Uint8List.fromList(bytes),
        MimeType.MICROSOFTEXCEL.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export categories: $e');
    }
  }

  Future<void> exportCategoriesToPdf() async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 2);
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Name';
      header.cells[1].value = 'Description';
      final snapshot = await _firestore.collection('categories').get();
      final categories = snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
      for (var category in categories) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = category.name;
        row.cells[1].value = category.description;
      }
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
      final List<int> bytes = await document.save();
      document.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'categories_export.pdf');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/categories_export.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'categories_export.pdf',
        Uint8List.fromList(bytes),
        MimeType.PDF.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export categories: $e');
    }
  }

  Future<void> exportUsersToExcel() async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Name');
      sheet.getRangeByName('B1').setText('Email');
      sheet.getRangeByName('C1').setText('Role');
      final snapshot = await _firestore.collection('users').get();
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      for (var i = 0; i < users.length; i++) {
        final user = users[i];
        final row = i + 2;
        sheet.getRangeByName('A$row').setText(user.name);
        sheet.getRangeByName('B$row').setText(user.email);
        sheet.getRangeByName('C$row').setText(user.role.toString().split('.').last);
      }
      sheet.getRangeByName('A1:C${users.length + 1}').autoFitColumns();
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'users_export.xlsx');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/users_export.xlsx';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'users_export.xlsx',
        Uint8List.fromList(bytes),
        MimeType.MICROSOFTEXCEL.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export users: $e');
    }
  }

  Future<void> exportUsersToPdf() async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 3);
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Name';
      header.cells[1].value = 'Email';
      header.cells[2].value = 'Role';
      final snapshot = await _firestore.collection('users').get();
      final users = snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
      for (var user in users) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = user.name;
        row.cells[1].value = user.email;
        row.cells[2].value = user.role.toString().split('.').last;
      }
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
      final List<int> bytes = await document.save();
      document.dispose();
      if (kIsWeb) {
        await _downloadWebFile(Uint8List.fromList(bytes), 'users_export.pdf');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final String path = '${directory.path}/users_export.pdf';
      final File file = File(path);
      await file.writeAsBytes(bytes);
      await FileSaver.instance.saveFile(
        'users_export.pdf',
        Uint8List.fromList(bytes),
        MimeType.PDF.toString(),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to export users: $e');
    }
  }

  Future<void> exportToCsv(String fileName, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) return;
    final headers = data.first.keys.toList();
    final csv = StringBuffer();
    csv.writeln(headers.join(','));
    for (final row in data) {
      final values = headers.map((header) => row[header]).toList();
      csv.writeln(values.join(','));
    }
    // If productPerformance is present, export as a separate CSV
    if (data.first.containsKey('productPerformance')) {
      final perf = data.first['productPerformance'] as Map<String, dynamic>;
      final perfCsv = StringBuffer();
      perfCsv.writeln('Product,Sold,Imported');
      perf.forEach((product, perfData) {
        perfCsv.writeln('$product,${perfData['sold'] ?? 0},${perfData['imported'] ?? 0}');
      });
      if (kIsWeb) {
        final bytes = utf8.encode(csv.toString());
        final perfBytes = utf8.encode(perfCsv.toString());
        await _downloadWebFile(Uint8List.fromList(bytes), fileName);
        await _downloadWebFile(Uint8List.fromList(perfBytes), 'product_performance.csv');
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv.toString());
      final perfFile = File('${directory.path}/product_performance.csv');
      await perfFile.writeAsString(perfCsv.toString());
      await Share.shareXFiles([XFile(file.path), XFile(perfFile.path)]);
      return;
    }
    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      await _downloadWebFile(Uint8List.fromList(bytes), fileName);
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv.toString());
    await Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> exportAnalyticsToExcel(List<Map<String, dynamic>> analytics) async {
    if (analytics.isEmpty) return;
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    final headers = analytics.first.keys.toList();
    for (int i = 0; i < headers.length; i++) {
      sheet.getRangeByIndex(1, i + 1).setText(headers[i]);
    }
    for (int row = 0; row < analytics.length; row++) {
      final data = analytics[row];
      for (int col = 0; col < headers.length; col++) {
        sheet.getRangeByIndex(row + 2, col + 1).setText('${data[headers[col]] ?? ''}');
      }
    }
    sheet.getRangeByIndex(1, 1, analytics.length + 1, headers.length).autoFitColumns();

    // Add product performance sheet if present
    if (analytics.first.containsKey('productPerformance')) {
      final Worksheet perfSheet = workbook.worksheets.addWithName('Product Performance');
      final perf = analytics.first['productPerformance'] as Map<String, dynamic>;
      final perfHeaders = ['Product', 'Sold', 'Imported'];
      for (int i = 0; i < perfHeaders.length; i++) {
        perfSheet.getRangeByIndex(1, i + 1).setText(perfHeaders[i]);
      }
      int row = 2;
      perf.forEach((product, data) {
        perfSheet.getRangeByIndex(row, 1).setText(product);
        perfSheet.getRangeByIndex(row, 2).setText('${data['sold'] ?? 0}');
        perfSheet.getRangeByIndex(row, 3).setText('${data['imported'] ?? 0}');
        row++;
      });
      perfSheet.getRangeByIndex(1, 1, row - 1, perfHeaders.length).autoFitColumns();
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    if (kIsWeb) {
      await _downloadWebFile(Uint8List.fromList(bytes), 'analytics_report.xlsx');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/analytics_report.xlsx';
    final File file = File(path);
    await file.writeAsBytes(bytes);
    await FileSaver.instance.saveFile(
      'analytics_report.xlsx',
      Uint8List.fromList(bytes),
      MimeType.MICROSOFTEXCEL.toString(),
    );
  }

  Future<void> exportAnalyticsToPdf(List<Map<String, dynamic>> analytics) async {
    if (analytics.isEmpty) return;
    final PdfDocument document = PdfDocument();
    final PdfPage page = document.pages.add();
    final PdfGrid grid = PdfGrid();
    final headers = analytics.first.keys.toList();
    grid.columns.add(count: headers.length);
    grid.headers.add(1);
    final PdfGridRow headerRow = grid.headers[0];
    for (int i = 0; i < headers.length; i++) {
      headerRow.cells[i].value = headers[i];
    }
    for (final data in analytics) {
      final PdfGridRow row = grid.rows.add();
      for (int i = 0; i < headers.length; i++) {
        row.cells[i].value = '${data[headers[i]] ?? ''}';
      }
    }
    grid.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
    );

    // Add product performance table if present
    if (analytics.first.containsKey('productPerformance')) {
      final PdfPage perfPage = document.pages.add();
      final PdfGrid perfGrid = PdfGrid();
      final perfHeaders = ['Product', 'Sold', 'Imported'];
      perfGrid.columns.add(count: perfHeaders.length);
      perfGrid.headers.add(1);
      final PdfGridRow perfHeaderRow = perfGrid.headers[0];
      for (int i = 0; i < perfHeaders.length; i++) {
        perfHeaderRow.cells[i].value = perfHeaders[i];
      }
      final perf = analytics.first['productPerformance'] as Map<String, dynamic>;
      perf.forEach((product, data) {
        final PdfGridRow row = perfGrid.rows.add();
        row.cells[0].value = product;
        row.cells[1].value = '${data['sold'] ?? 0}';
        row.cells[2].value = '${data['imported'] ?? 0}';
      });
      perfGrid.draw(
        page: perfPage,
        bounds: Rect.fromLTWH(0, 0, perfPage.getClientSize().width, perfPage.getClientSize().height),
      );
    }

    final List<int> bytes = await document.save();
    document.dispose();
    if (kIsWeb) {
      await _downloadWebFile(Uint8List.fromList(bytes), 'analytics_report.pdf');
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final String path = '${directory.path}/analytics_report.pdf';
    final File file = File(path);
    await file.writeAsBytes(bytes);
    await FileSaver.instance.saveFile(
      'analytics_report.pdf',
      Uint8List.fromList(bytes),
      MimeType.PDF.toString(),
    );
  }
} 