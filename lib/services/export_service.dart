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
import '../models/category_model.dart';
import 'package:get/get.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' if (dart.library.io) 'dart:io' as platform;
import 'package:flutter/services.dart' show rootBundle;
import '../services/analytics_service.dart';

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

  Future<void> exportOrdersToExcel({DateTime? startDate, DateTime? endDate, String? status}) async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Ref');
      sheet.getRangeByName('B1').setText('Name');
      sheet.getRangeByName('C1').setText('Status');
      sheet.getRangeByName('D1').setText('Total');
      sheet.getRangeByName('E1').setText('Date');

      // Get top/bottom 5 orders
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomOrders(startDate: startDate, endDate: endDate);
      final orders = <OrderModel>[];
      orders.addAll(topBottom['top'] ?? []);
      // Add a blank order as separator
      orders.add(OrderModel(id: '', orderlines: [], fulfillment: OrderFulfillment.fulfilled));
      orders.addAll(topBottom['bottom'] ?? []);

      // Preload all users and sources for name mapping
      final usersSnapshot = await _firestore.collection('users').get();
      final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      final sourcesSnapshot = await _firestore.collection('sources').get();
      final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};

      for (var i = 0; i < orders.length; i++) {
        final order = orders[i];
        final row = i + 2;
        if (order.id == '') {
          // Blank separator row
          sheet.getRangeByName('A$row:E$row').setText('');
          continue;
        }
        String name = '';
        if (order.fulfillment == OrderFulfillment.import) {
          name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
        } else {
          name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
        }
        final statusStr = order.fulfillment.toString().split('.').last;
        double total = 0;
        for (final line in order.orderlines) {
          if (line.price != null) total += line.price!;
        }
        final totalStr = order.fulfillment == OrderFulfillment.import
            ? '-${total.toStringAsFixed(3)}'
            : '+${total.toStringAsFixed(3)}';
        final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
        final refStr = order.ref?.toString() ?? '';
        sheet.getRangeByName('A$row').setText(refStr);
        sheet.getRangeByName('B$row').setText(name);
        sheet.getRangeByName('C$row').setText(statusStr);
        sheet.getRangeByName('D$row').setText(totalStr);
        sheet.getRangeByName('E$row').setText(dateStr);
      }
      sheet.getRangeByName('A1:E${orders.length + 1}').autoFitColumns();
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

  Future<void> exportOrdersToPdf({DateTime? startDate, DateTime? endDate, String? status}) async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 5);
      grid.headers.add(1);
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Ref';
      header.cells[1].value = 'Name';
      header.cells[2].value = 'Status';
      header.cells[3].value = 'Total';
      header.cells[4].value = 'Date';

      // Load Unicode font
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final PdfFont unicodeFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
      grid.style = PdfGridStyle(font: unicodeFont);

      // Get top/bottom 5 orders
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomOrders(startDate: startDate, endDate: endDate);
      final topOrders = topBottom['top'] ?? [];
      final bottomOrders = topBottom['bottom'] ?? [];

      // Preload all users and sources for name mapping
      final usersSnapshot = await _firestore.collection('users').get();
      final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
      final sourcesSnapshot = await _firestore.collection('sources').get();
      final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};

      // Top 5 section
      final PdfGrid topGrid = PdfGrid();
      topGrid.columns.add(count: 5);
      topGrid.headers.add(1);
      final PdfGridRow topHeader = topGrid.headers[0];
      topHeader.cells[0].value = 'Ref';
      topHeader.cells[1].value = 'Name';
      topHeader.cells[2].value = 'Status';
      topHeader.cells[3].value = 'Total';
      topHeader.cells[4].value = 'Date';
      topGrid.style = PdfGridStyle(font: unicodeFont);
      for (final order in topOrders) {
        final PdfGridRow row = topGrid.rows.add();
        String name = '';
        if (order.fulfillment == OrderFulfillment.import) {
          name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
        } else {
          name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
        }
        final statusStr = order.fulfillment.toString().split('.').last;
        double total = 0;
        for (final line in order.orderlines) {
          if (line.price != null) total += line.price!;
        }
        final totalStr = order.fulfillment == OrderFulfillment.import
            ? '-${total.toStringAsFixed(3)}'
            : '+${total.toStringAsFixed(3)}';
        final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
        final refStr = order.ref?.toString() ?? '';
        row.cells[0].value = refStr;
        row.cells[1].value = name;
        row.cells[2].value = statusStr;
        row.cells[3].value = totalStr;
        row.cells[4].value = dateStr;
      }
      // Bottom 5 section
      final PdfGrid bottomGrid = PdfGrid();
      bottomGrid.columns.add(count: 5);
      bottomGrid.headers.add(1);
      final PdfGridRow bottomHeader = bottomGrid.headers[0];
      bottomHeader.cells[0].value = 'Ref';
      bottomHeader.cells[1].value = 'Name';
      bottomHeader.cells[2].value = 'Status';
      bottomHeader.cells[3].value = 'Total';
      bottomHeader.cells[4].value = 'Date';
      bottomGrid.style = PdfGridStyle(font: unicodeFont);
      for (final order in bottomOrders) {
        final PdfGridRow row = bottomGrid.rows.add();
        String name = '';
        if (order.fulfillment == OrderFulfillment.import) {
          name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
        } else {
          name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
        }
        final statusStr = order.fulfillment.toString().split('.').last;
        double total = 0;
        for (final line in order.orderlines) {
          if (line.price != null) total += line.price!;
        }
        final totalStr = order.fulfillment == OrderFulfillment.import
            ? '-${total.toStringAsFixed(3)}'
            : '+${total.toStringAsFixed(3)}';
        final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
        final refStr = order.ref?.toString() ?? '';
        row.cells[0].value = refStr;
        row.cells[1].value = name;
        row.cells[2].value = statusStr;
        row.cells[3].value = totalStr;
        row.cells[4].value = dateStr;
      }
      // Draw top 5
      page.graphics.drawString('Top 5 Orders', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      topGrid.draw(page: page, bounds: Rect.fromLTWH(0, 20, page.getClientSize().width, page.getClientSize().height - 20));
      // Draw bottom 5 on new page
      final PdfPage page2 = document.pages.add();
      page2.graphics.drawString('Bottom 5 Orders', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      bottomGrid.draw(page: page2, bounds: Rect.fromLTWH(0, 20, page2.getClientSize().width, page2.getClientSize().height - 20));
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

  Future<void> exportOrdersToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Get top/bottom 5 orders
    final analyticsService = Get.find<AnalyticsService>();
    final topBottom = await analyticsService.getTopBottomOrders(startDate: startDate, endDate: endDate);
    final orders = <OrderModel>[];
    orders.addAll(topBottom['top'] ?? []);
    // Add a blank order as separator
    orders.add(OrderModel(id: '', orderlines: [], fulfillment: OrderFulfillment.fulfilled));
    orders.addAll(topBottom['bottom'] ?? []);

    // Preload all users and sources for name mapping
    final usersSnapshot = await _firestore.collection('users').get();
    final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final sourcesSnapshot = await _firestore.collection('sources').get();
    final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};

    final csv = StringBuffer();
    csv.writeln('Ref,Name,Status,Total,Date');
    for (var order in orders) {
      if (order.id == '') {
        csv.writeln('');
        continue;
      }
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      final status = order.fulfillment.toString().split('.').last;
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      final dateStr = order.orderedAt?.toIso8601String() ?? '';
      final refStr = order.ref?.toString() ?? '';
      csv.writeln([
        refStr,
        name,
        status,
        totalStr,
        dateStr
      ].join(','));
    }
    await saveRawCsv('orders_export.csv', csv.toString());
  }

  Future<void> exportProductsToExcel({DateTime? startDate, DateTime? endDate}) async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Product Name');
      sheet.getRangeByName('B1').setText('Stock');
      sheet.getRangeByName('C1').setText('Revenue');
      sheet.getRangeByName('D1').setText('Cost');
      sheet.getRangeByName('E1').setText('Profit/Loss');

      // Get top/bottom 5 products
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomProducts(startDate: startDate, endDate: endDate);
      final products = <Map<String, dynamic>>[];
      products.addAll(topBottom['top'] ?? []);
      // Add a blank as separator
      products.add({'name': '', 'stock': '', 'revenue': '', 'cost': '', 'profit': ''});
      products.addAll(topBottom['bottom'] ?? []);

      for (var i = 0; i < products.length; i++) {
        final product = products[i];
        final row = i + 2;
        sheet.getRangeByName('A$row').setText(product['name'].toString());
        sheet.getRangeByName('B$row').setText(product['stock'].toString());
        sheet.getRangeByName('C$row').setText(product['revenue'].toStringAsFixed(3));
        sheet.getRangeByName('D$row').setText(product['cost'].toStringAsFixed(3));
        final profit = product['profit'];
        final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
        sheet.getRangeByName('E$row').setText(profitStr);
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

  Future<void> exportProductsToPdf({DateTime? startDate, DateTime? endDate}) async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      // Load Unicode font
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final PdfFont unicodeFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);

      // Get top/bottom 5 products
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomProducts(startDate: startDate, endDate: endDate);
      final topProducts = topBottom['top'] ?? [];
      final bottomProducts = topBottom['bottom'] ?? [];

      // Top 5 section
      final PdfGrid topGrid = PdfGrid();
      topGrid.columns.add(count: 5);
      topGrid.headers.add(1);
      final PdfGridRow topHeader = topGrid.headers[0];
      topHeader.cells[0].value = 'Product Name';
      topHeader.cells[1].value = 'Stock';
      topHeader.cells[2].value = 'Revenue';
      topHeader.cells[3].value = 'Cost';
      topHeader.cells[4].value = 'Profit/Loss';
      topGrid.style = PdfGridStyle(font: unicodeFont);
      for (final product in topProducts) {
        final PdfGridRow row = topGrid.rows.add();
        row.cells[0].value = product['name'].toString();
        row.cells[1].value = product['stock'].toString();
        row.cells[2].value = (product['revenue'] as num?)?.toStringAsFixed(3) ?? '';
        row.cells[3].value = (product['cost'] as num?)?.toStringAsFixed(3) ?? '';
        final profit = product['profit'];
        final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
        row.cells[4].value = profitStr;
      }
      // Bottom 5 section
      final PdfGrid bottomGrid = PdfGrid();
      bottomGrid.columns.add(count: 5);
      bottomGrid.headers.add(1);
      final PdfGridRow bottomHeader = bottomGrid.headers[0];
      bottomHeader.cells[0].value = 'Product Name';
      bottomHeader.cells[1].value = 'Stock';
      bottomHeader.cells[2].value = 'Revenue';
      bottomHeader.cells[3].value = 'Cost';
      bottomHeader.cells[4].value = 'Profit/Loss';
      bottomGrid.style = PdfGridStyle(font: unicodeFont);
      for (final product in bottomProducts) {
        final PdfGridRow row = bottomGrid.rows.add();
        row.cells[0].value = product['name'].toString();
        row.cells[1].value = product['stock'].toString();
        row.cells[2].value = (product['revenue'] as num?)?.toStringAsFixed(3) ?? '';
        row.cells[3].value = (product['cost'] as num?)?.toStringAsFixed(3) ?? '';
        final profit = product['profit'];
        final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
        row.cells[4].value = profitStr;
      }
      // Draw top 5
      page.graphics.drawString('Top 5 Products', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      topGrid.draw(page: page, bounds: Rect.fromLTWH(0, 20, page.getClientSize().width, page.getClientSize().height - 20));
      // Draw bottom 5 on new page
      final PdfPage page2 = document.pages.add();
      page2.graphics.drawString('Bottom 5 Products', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      bottomGrid.draw(page: page2, bounds: Rect.fromLTWH(0, 20, page2.getClientSize().width, page2.getClientSize().height - 20));
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

  Future<void> exportProductsToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Get top/bottom 5 products
    final analyticsService = Get.find<AnalyticsService>();
    final topBottom = await analyticsService.getTopBottomProducts(startDate: startDate, endDate: endDate);
    final products = <Map<String, dynamic>>[];
    products.addAll(topBottom['top'] ?? []);
    // Add a blank as separator
    products.add({'name': '', 'stock': '', 'revenue': '', 'cost': '', 'profit': ''});
    products.addAll(topBottom['bottom'] ?? []);

    final csv = StringBuffer();
    csv.writeln('Product Name,Stock,Revenue,Cost,Profit/Loss');
    for (final product in products) {
      final profit = product['profit'];
      final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
      csv.writeln([
        product['name'],
        product['stock'],
        (product['revenue'] is num) ? product['revenue'].toStringAsFixed(3) : '',
        (product['cost'] is num) ? product['cost'].toStringAsFixed(3) : '',
        profitStr,
      ].join(','));
    }
    await saveRawCsv('products_export.csv', csv.toString());
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

  Future<void> exportUsersToExcel({DateTime? startDate, DateTime? endDate}) async {
    try {
      final Workbook workbook = Workbook();
      final Worksheet sheet = workbook.worksheets[0];
      sheet.getRangeByName('A1').setText('Name');
      sheet.getRangeByName('B1').setText('Email');
      sheet.getRangeByName('C1').setText('Phone');
      sheet.getRangeByName('D1').setText('Role');
      sheet.getRangeByName('E1').setText('Deliveries');

      // Get top/bottom 5 delivery users
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomDeliveryUsers(startDate: startDate, endDate: endDate);
      final users = <Map<String, dynamic>>[];
      users.addAll(topBottom['top'] ?? []);
      // Add a blank as separator
      users.add({'name': '', 'email': '', 'phone': '', 'role': '', 'deliveries': ''});
      users.addAll(topBottom['bottom'] ?? []);

      for (var i = 0; i < users.length; i++) {
        final user = users[i];
        final row = i + 2;
        sheet.getRangeByName('A$row').setText(user['name'].toString());
        sheet.getRangeByName('B$row').setText(user['email'].toString());
        sheet.getRangeByName('C$row').setText(user['phone'].toString());
        sheet.getRangeByName('D$row').setText(user['role'].toString());
        sheet.getRangeByName('E$row').setText(user['deliveries'].toString());
      }
      sheet.getRangeByName('A1:E${users.length + 1}').autoFitColumns();
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

  Future<void> exportUsersToPdf({DateTime? startDate, DateTime? endDate}) async {
    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      // Load Unicode font
      final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
      final PdfFont unicodeFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);

      // Get top/bottom 5 delivery users
      final analyticsService = Get.find<AnalyticsService>();
      final topBottom = await analyticsService.getTopBottomDeliveryUsers(startDate: startDate, endDate: endDate);
      final topUsers = topBottom['top'] ?? [];
      final bottomUsers = topBottom['bottom'] ?? [];

      // Top 5 section
      final PdfGrid topGrid = PdfGrid();
      topGrid.columns.add(count: 5);
      topGrid.headers.add(1);
      final PdfGridRow topHeader = topGrid.headers[0];
      topHeader.cells[0].value = 'Name';
      topHeader.cells[1].value = 'Email';
      topHeader.cells[2].value = 'Phone';
      topHeader.cells[3].value = 'Role';
      topHeader.cells[4].value = 'Deliveries';
      topGrid.style = PdfGridStyle(font: unicodeFont);
      for (final user in topUsers) {
        final PdfGridRow row = topGrid.rows.add();
        row.cells[0].value = user['name'].toString();
        row.cells[1].value = user['email'].toString();
        row.cells[2].value = user['phone'].toString();
        row.cells[3].value = user['role'].toString();
        row.cells[4].value = user['deliveries'].toString();
      }
      // Bottom 5 section
      final PdfGrid bottomGrid = PdfGrid();
      bottomGrid.columns.add(count: 5);
      bottomGrid.headers.add(1);
      final PdfGridRow bottomHeader = bottomGrid.headers[0];
      bottomHeader.cells[0].value = 'Name';
      bottomHeader.cells[1].value = 'Email';
      bottomHeader.cells[2].value = 'Phone';
      bottomHeader.cells[3].value = 'Role';
      bottomHeader.cells[4].value = 'Deliveries';
      bottomGrid.style = PdfGridStyle(font: unicodeFont);
      for (final user in bottomUsers) {
        final PdfGridRow row = bottomGrid.rows.add();
        row.cells[0].value = user['name'].toString();
        row.cells[1].value = user['email'].toString();
        row.cells[2].value = user['phone'].toString();
        row.cells[3].value = user['role'].toString();
        row.cells[4].value = user['deliveries'].toString();
      }
      // Draw top 5
      page.graphics.drawString('Top 5 Delivery Users', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      topGrid.draw(page: page, bounds: Rect.fromLTWH(0, 20, page.getClientSize().width, page.getClientSize().height - 20));
      // Draw bottom 5 on new page
      final PdfPage page2 = document.pages.add();
      page2.graphics.drawString('Bottom 5 Delivery Users', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
      bottomGrid.draw(page: page2, bounds: Rect.fromLTWH(0, 20, page2.getClientSize().width, page2.getClientSize().height - 20));
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

  Future<void> exportUsersToCSV({DateTime? startDate, DateTime? endDate}) async {
    // Get top/bottom 5 delivery users
    final analyticsService = Get.find<AnalyticsService>();
    final topBottom = await analyticsService.getTopBottomDeliveryUsers(startDate: startDate, endDate: endDate);
    final users = <Map<String, dynamic>>[];
    users.addAll(topBottom['top'] ?? []);
    // Add a blank as separator
    users.add({'name': '', 'email': '', 'phone': '', 'role': '', 'deliveries': ''});
    users.addAll(topBottom['bottom'] ?? []);

    final csv = StringBuffer();
    csv.writeln('Name,Email,Phone,Role,Deliveries');
    for (final user in users) {
      csv.writeln([
        user['name'],
        user['email'],
        user['phone'],
        user['role'],
        user['deliveries'],
      ].join(','));
    }
    await saveRawCsv('users_export.csv', csv.toString());
  }

  Future<void> exportToCsv(String fileName, List<Map<String, dynamic>> data, {DateTime? startDate, DateTime? endDate}) async {
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

  Future<void> exportAnalyticsToExcel(List<Map<String, dynamic>> analytics, {DateTime? startDate, DateTime? endDate}) async {
    final Workbook workbook = Workbook();
    final analyticsService = Get.find<AnalyticsService>();

    // --- ORDERS SECTION ---
    final topBottomOrders = await analyticsService.getTopBottomOrders(startDate: startDate, endDate: endDate);
    final topOrders = topBottomOrders['top'] ?? [];
    final bottomOrders = topBottomOrders['bottom'] ?? [];
    final usersSnapshot = await _firestore.collection('users').get();
    final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final sourcesSnapshot = await _firestore.collection('sources').get();
    final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final Worksheet ordersSheet = workbook.worksheets[0];
    ordersSheet.name = 'Orders';
    ordersSheet.getRangeByName('A1').setText('Ref');
    ordersSheet.getRangeByName('B1').setText('Name');
    ordersSheet.getRangeByName('C1').setText('Status');
    ordersSheet.getRangeByName('D1').setText('Total');
    ordersSheet.getRangeByName('E1').setText('Date');
    int row = 2;
    for (final order in topOrders) {
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      final statusStr = order.fulfillment.toString().split('.').last;
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
      final refStr = order.ref?.toString() ?? '';
      ordersSheet.getRangeByName('A$row').setText(refStr);
      ordersSheet.getRangeByName('B$row').setText(name);
      ordersSheet.getRangeByName('C$row').setText(statusStr);
      ordersSheet.getRangeByName('D$row').setText(totalStr);
      ordersSheet.getRangeByName('E$row').setText(dateStr);
      row++;
    }
    // Blank row
    row++;
    for (final order in bottomOrders) {
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      final statusStr = order.fulfillment.toString().split('.').last;
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
      final refStr = order.ref?.toString() ?? '';
      ordersSheet.getRangeByName('A$row').setText(refStr);
      ordersSheet.getRangeByName('B$row').setText(name);
      ordersSheet.getRangeByName('C$row').setText(statusStr);
      ordersSheet.getRangeByName('D$row').setText(totalStr);
      ordersSheet.getRangeByName('E$row').setText(dateStr);
      row++;
    }
    ordersSheet.getRangeByName('A1:E$row').autoFitColumns();

    // --- PRODUCTS SECTION ---
    final topBottomProducts = await analyticsService.getTopBottomProducts(startDate: startDate, endDate: endDate);
    final topProducts = topBottomProducts['top'] ?? [];
    final bottomProducts = topBottomProducts['bottom'] ?? [];
    final Worksheet productsSheet = workbook.worksheets.addWithName('Products');
    productsSheet.getRangeByName('A1').setText('Product Name');
    productsSheet.getRangeByName('B1').setText('Stock');
    productsSheet.getRangeByName('C1').setText('Revenue');
    productsSheet.getRangeByName('D1').setText('Cost');
    productsSheet.getRangeByName('E1').setText('Profit/Loss');
    row = 2;
    for (final product in topProducts) {
      productsSheet.getRangeByName('A$row').setText(product['name'].toString());
      productsSheet.getRangeByName('B$row').setText(product['stock'].toString());
      productsSheet.getRangeByName('C$row').setText(product['revenue'].toStringAsFixed(3));
      productsSheet.getRangeByName('D$row').setText(product['cost'].toStringAsFixed(3));
      final profit = product['profit'];
      final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
      productsSheet.getRangeByName('E$row').setText(profitStr);
      row++;
    }
    // Blank row
    row++;
    for (final product in bottomProducts) {
      productsSheet.getRangeByName('A$row').setText(product['name'].toString());
      productsSheet.getRangeByName('B$row').setText(product['stock'].toString());
      productsSheet.getRangeByName('C$row').setText(product['revenue'].toStringAsFixed(3));
      productsSheet.getRangeByName('D$row').setText(product['cost'].toStringAsFixed(3));
      final profit = product['profit'];
      final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
      productsSheet.getRangeByName('E$row').setText(profitStr);
      row++;
    }
    productsSheet.getRangeByName('A1:E$row').autoFitColumns();

    // --- USERS SECTION ---
    final topBottomUsers = await analyticsService.getTopBottomDeliveryUsers(startDate: startDate, endDate: endDate);
    final topUsers = topBottomUsers['top'] ?? [];
    final bottomUsers = topBottomUsers['bottom'] ?? [];
    final Worksheet usersSheet = workbook.worksheets.addWithName('Delivery Users');
    usersSheet.getRangeByName('A1').setText('Name');
    usersSheet.getRangeByName('B1').setText('Email');
    usersSheet.getRangeByName('C1').setText('Phone');
    usersSheet.getRangeByName('D1').setText('Role');
    usersSheet.getRangeByName('E1').setText('Deliveries');
    row = 2;
    for (final user in topUsers) {
      usersSheet.getRangeByName('A$row').setText(user['name'].toString());
      usersSheet.getRangeByName('B$row').setText(user['email'].toString());
      usersSheet.getRangeByName('C$row').setText(user['phone'].toString());
      usersSheet.getRangeByName('D$row').setText(user['role'].toString());
      usersSheet.getRangeByName('E$row').setText(user['deliveries'].toString());
      row++;
    }
    // Blank row
    row++;
    for (final user in bottomUsers) {
      usersSheet.getRangeByName('A$row').setText(user['name'].toString());
      usersSheet.getRangeByName('B$row').setText(user['email'].toString());
      usersSheet.getRangeByName('C$row').setText(user['phone'].toString());
      usersSheet.getRangeByName('D$row').setText(user['role'].toString());
      usersSheet.getRangeByName('E$row').setText(user['deliveries'].toString());
      row++;
    }
    usersSheet.getRangeByName('A1:E$row').autoFitColumns();

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

  Future<void> exportAnalyticsToPdf(List<Map<String, dynamic>> analytics, {DateTime? startDate, DateTime? endDate}) async {
    final PdfDocument document = PdfDocument();
    // Load Unicode font
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final PdfFont unicodeFont = PdfTrueTypeFont(fontData.buffer.asUint8List(), 12);
    final analyticsService = Get.find<AnalyticsService>();

    // --- ORDERS SECTION ---
    final topBottomOrders = await analyticsService.getTopBottomOrders(startDate: startDate, endDate: endDate);
    final topOrders = topBottomOrders['top'] ?? [];
    final bottomOrders = topBottomOrders['bottom'] ?? [];
    final usersSnapshot = await _firestore.collection('users').get();
    final userIdToName = {for (var doc in usersSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};
    final sourcesSnapshot = await _firestore.collection('sources').get();
    final sourceIdToName = {for (var doc in sourcesSnapshot.docs) doc.id: doc.data()['name'] ?? doc.id};

    // Top 5 Orders
    final PdfPage ordersPage = document.pages.add();
    ordersPage.graphics.drawString('Top 5 Orders', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid topOrdersGrid = PdfGrid();
    topOrdersGrid.columns.add(count: 5);
    topOrdersGrid.headers.add(1);
    final PdfGridRow topOrdersHeader = topOrdersGrid.headers[0];
    topOrdersHeader.cells[0].value = 'Ref';
    topOrdersHeader.cells[1].value = 'Name';
    topOrdersHeader.cells[2].value = 'Status';
    topOrdersHeader.cells[3].value = 'Total';
    topOrdersHeader.cells[4].value = 'Date';
    topOrdersGrid.style = PdfGridStyle(font: unicodeFont);
    for (final order in topOrders) {
      final PdfGridRow row = topOrdersGrid.rows.add();
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      final statusStr = order.fulfillment.toString().split('.').last;
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
      final refStr = order.ref?.toString() ?? '';
      row.cells[0].value = refStr;
      row.cells[1].value = name;
      row.cells[2].value = statusStr;
      row.cells[3].value = totalStr;
      row.cells[4].value = dateStr;
    }
    topOrdersGrid.draw(page: ordersPage, bounds: Rect.fromLTWH(0, 20, ordersPage.getClientSize().width, ordersPage.getClientSize().height - 20));

    // Bottom 5 Orders
    final PdfPage ordersPage2 = document.pages.add();
    ordersPage2.graphics.drawString('Bottom 5 Orders', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid bottomOrdersGrid = PdfGrid();
    bottomOrdersGrid.columns.add(count: 5);
    bottomOrdersGrid.headers.add(1);
    final PdfGridRow bottomOrdersHeader = bottomOrdersGrid.headers[0];
    bottomOrdersHeader.cells[0].value = 'Ref';
    bottomOrdersHeader.cells[1].value = 'Name';
    bottomOrdersHeader.cells[2].value = 'Status';
    bottomOrdersHeader.cells[3].value = 'Total';
    bottomOrdersHeader.cells[4].value = 'Date';
    bottomOrdersGrid.style = PdfGridStyle(font: unicodeFont);
    for (final order in bottomOrders) {
      final PdfGridRow row = bottomOrdersGrid.rows.add();
      String name = '';
      if (order.fulfillment == OrderFulfillment.import) {
        name = order.sourceId != null ? (sourceIdToName[order.sourceId] ?? order.sourceId!) : '';
      } else {
        name = order.cid != null ? (userIdToName[order.cid] ?? order.cid!) : '';
      }
      final statusStr = order.fulfillment.toString().split('.').last;
      double total = 0;
      for (final line in order.orderlines) {
        if (line.price != null) total += line.price!;
      }
      final totalStr = order.fulfillment == OrderFulfillment.import
          ? '-${total.toStringAsFixed(3)}'
          : '+${total.toStringAsFixed(3)}';
      final dateStr = order.orderedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(order.orderedAt!) : '';
      final refStr = order.ref?.toString() ?? '';
      row.cells[0].value = refStr;
      row.cells[1].value = name;
      row.cells[2].value = statusStr;
      row.cells[3].value = totalStr;
      row.cells[4].value = dateStr;
    }
    bottomOrdersGrid.draw(page: ordersPage2, bounds: Rect.fromLTWH(0, 20, ordersPage2.getClientSize().width, ordersPage2.getClientSize().height - 20));

    // --- PRODUCTS SECTION ---
    final topBottomProducts = await analyticsService.getTopBottomProducts(startDate: startDate, endDate: endDate);
    final topProducts = topBottomProducts['top'] ?? [];
    final bottomProducts = topBottomProducts['bottom'] ?? [];
    final PdfPage productsPage = document.pages.add();
    productsPage.graphics.drawString('Top 5 Products', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid topProductsGrid = PdfGrid();
    topProductsGrid.columns.add(count: 5);
    topProductsGrid.headers.add(1);
    final PdfGridRow topProductsHeader = topProductsGrid.headers[0];
    topProductsHeader.cells[0].value = 'Product Name';
    topProductsHeader.cells[1].value = 'Stock';
    topProductsHeader.cells[2].value = 'Revenue';
    topProductsHeader.cells[3].value = 'Cost';
    topProductsHeader.cells[4].value = 'Profit/Loss';
    topProductsGrid.style = PdfGridStyle(font: unicodeFont);
    for (final product in topProducts) {
      final PdfGridRow row = topProductsGrid.rows.add();
      row.cells[0].value = product['name'].toString();
      row.cells[1].value = product['stock'].toString();
      row.cells[2].value = (product['revenue'] as num?)?.toStringAsFixed(3) ?? '';
      row.cells[3].value = (product['cost'] as num?)?.toStringAsFixed(3) ?? '';
      final profit = product['profit'];
      final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
      row.cells[4].value = profitStr;
    }
    topProductsGrid.draw(page: productsPage, bounds: Rect.fromLTWH(0, 20, productsPage.getClientSize().width, productsPage.getClientSize().height - 20));

    final PdfPage productsPage2 = document.pages.add();
    productsPage2.graphics.drawString('Bottom 5 Products', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid bottomProductsGrid = PdfGrid();
    bottomProductsGrid.columns.add(count: 5);
    bottomProductsGrid.headers.add(1);
    final PdfGridRow bottomProductsHeader = bottomProductsGrid.headers[0];
    bottomProductsHeader.cells[0].value = 'Product Name';
    bottomProductsHeader.cells[1].value = 'Stock';
    bottomProductsHeader.cells[2].value = 'Revenue';
    bottomProductsHeader.cells[3].value = 'Cost';
    bottomProductsHeader.cells[4].value = 'Profit/Loss';
    bottomProductsGrid.style = PdfGridStyle(font: unicodeFont);
    for (final product in bottomProducts) {
      final PdfGridRow row = bottomProductsGrid.rows.add();
      row.cells[0].value = product['name'].toString();
      row.cells[1].value = product['stock'].toString();
      row.cells[2].value = (product['revenue'] as num?)?.toStringAsFixed(3) ?? '';
      row.cells[3].value = (product['cost'] as num?)?.toStringAsFixed(3) ?? '';
      final profit = product['profit'];
      final profitStr = profit is num ? (profit >= 0 ? '+${profit.toStringAsFixed(3)}' : profit.toStringAsFixed(3)) : '';
      row.cells[4].value = profitStr;
    }
    bottomProductsGrid.draw(page: productsPage2, bounds: Rect.fromLTWH(0, 20, productsPage2.getClientSize().width, productsPage2.getClientSize().height - 20));

    // --- USERS SECTION ---
    final topBottomUsers = await analyticsService.getTopBottomDeliveryUsers(startDate: startDate, endDate: endDate);
    final topUsers = topBottomUsers['top'] ?? [];
    final bottomUsers = topBottomUsers['bottom'] ?? [];
    final PdfPage usersPage = document.pages.add();
    usersPage.graphics.drawString('Top 5 Delivery Users', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid topUsersGrid = PdfGrid();
    topUsersGrid.columns.add(count: 5);
    topUsersGrid.headers.add(1);
    final PdfGridRow topUsersHeader = topUsersGrid.headers[0];
    topUsersHeader.cells[0].value = 'Name';
    topUsersHeader.cells[1].value = 'Email';
    topUsersHeader.cells[2].value = 'Phone';
    topUsersHeader.cells[3].value = 'Role';
    topUsersHeader.cells[4].value = 'Deliveries';
    topUsersGrid.style = PdfGridStyle(font: unicodeFont);
    for (final user in topUsers) {
      final PdfGridRow row = topUsersGrid.rows.add();
      row.cells[0].value = user['name'].toString();
      row.cells[1].value = user['email'].toString();
      row.cells[2].value = user['phone'].toString();
      row.cells[3].value = user['role'].toString();
      row.cells[4].value = user['deliveries'].toString();
    }
    topUsersGrid.draw(page: usersPage, bounds: Rect.fromLTWH(0, 20, usersPage.getClientSize().width, usersPage.getClientSize().height - 20));

    final PdfPage usersPage2 = document.pages.add();
    usersPage2.graphics.drawString('Bottom 5 Delivery Users', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold));
    final PdfGrid bottomUsersGrid = PdfGrid();
    bottomUsersGrid.columns.add(count: 5);
    bottomUsersGrid.headers.add(1);
    final PdfGridRow bottomUsersHeader = bottomUsersGrid.headers[0];
    bottomUsersHeader.cells[0].value = 'Name';
    bottomUsersHeader.cells[1].value = 'Email';
    bottomUsersHeader.cells[2].value = 'Phone';
    bottomUsersHeader.cells[3].value = 'Role';
    bottomUsersHeader.cells[4].value = 'Deliveries';
    bottomUsersGrid.style = PdfGridStyle(font: unicodeFont);
    for (final user in bottomUsers) {
      final PdfGridRow row = bottomUsersGrid.rows.add();
      row.cells[0].value = user['name'].toString();
      row.cells[1].value = user['email'].toString();
      row.cells[2].value = user['phone'].toString();
      row.cells[3].value = user['role'].toString();
      row.cells[4].value = user['deliveries'].toString();
    }
    bottomUsersGrid.draw(page: usersPage2, bounds: Rect.fromLTWH(0, 20, usersPage2.getClientSize().width, usersPage2.getClientSize().height - 20));

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

  Future<void> saveRawCsv(String fileName, String csv) async {
    if (csv.isEmpty) return;
    if (kIsWeb) {
      final bytes = utf8.encode(csv);
      await _downloadWebFile(Uint8List.fromList(bytes), fileName);
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)]);
  }
} 