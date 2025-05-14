import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';
import '../../services/export_service.dart';

class AdminExportView extends StatefulWidget {
  const AdminExportView({Key? key}) : super(key: key);

  @override
  State<AdminExportView> createState() => _AdminExportViewState();
}

class _AdminExportViewState extends State<AdminExportView> {
  final _analyticsService = Get.find<AnalyticsService>();
  final _exportService = Get.find<ExportService>();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFormat = 'CSV';
  final List<String> _formats = ['CSV', 'Excel', 'PDF'];

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _exportOrders() async {
    setState(() => _isLoading = true);
    try {
      switch (_selectedFormat) {
        case 'CSV':
          await _analyticsService.exportOrdersToCSV();
          break;
        case 'Excel':
          await _exportService.exportOrdersToExcel(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'PDF':
          await _exportService.exportOrdersToPdf(
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
      }
      Get.snackbar('Success', 'Orders exported successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to export orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportProducts() async {
    setState(() => _isLoading = true);
    try {
      switch (_selectedFormat) {
        case 'CSV':
          await _analyticsService.exportProductsToCSV();
          break;
        case 'Excel':
          await _exportService.exportProductsToExcel();
          break;
        case 'PDF':
          await _exportService.exportProductsToPdf();
          break;
      }
      Get.snackbar('Success', 'Products exported successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to export products: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportUsers() async {
    setState(() => _isLoading = true);
    try {
      switch (_selectedFormat) {
        case 'CSV':
          await _analyticsService.exportUsersToCSV();
          break;
        case 'Excel':
          await _exportService.exportUsersToExcel();
          break;
        case 'PDF':
          await _exportService.exportUsersToPdf();
          break;
      }
      Get.snackbar('Success', 'Users exported successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to export users: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final analytics = await _analyticsService.exportAnalytics(
        type: 'sales',
        startDate: _startDate,
        endDate: _endDate,
      );
      switch (_selectedFormat) {
        case 'CSV':
          await _exportService.exportToCsv('analytics_report.csv', analytics);
          break;
        case 'Excel':
          await _exportService.exportAnalyticsToExcel(analytics);
          break;
        case 'PDF':
          await _exportService.exportAnalyticsToPdf(analytics);
          break;
      }
      Get.snackbar('Success', 'Analytics exported successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to export analytics: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Export Options',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedFormat,
                                  decoration: const InputDecoration(
                                    labelText: 'Format',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _formats.map((String format) {
                                    return DropdownMenuItem<String>(
                                      value: format,
                                      child: Text(format),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      setState(() => _selectedFormat = newValue);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _selectDateRange,
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    _startDate != null && _endDate != null
                                        ? '${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}'
                                        : 'Select Date Range',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildExportCard(
                    'Export Orders',
                    'Download all orders data with detailed information',
                    Icons.shopping_cart,
                    _exportOrders,
                  ),
                  const SizedBox(height: 16),
                  _buildExportCard(
                    'Export Products',
                    'Download complete product catalog with inventory status',
                    Icons.inventory,
                    _exportProducts,
                  ),
                  const SizedBox(height: 16),
                  _buildExportCard(
                    'Export Users',
                    'Download user database with roles and activity status',
                    Icons.people,
                    _exportUsers,
                  ),
                  const SizedBox(height: 16),
                  _buildExportCard(
                    'Export Analytics',
                    'Download comprehensive sales and performance analytics',
                    Icons.analytics,
                    _exportAnalytics,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildExportCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_selectedFormat),
            const SizedBox(width: 8),
            const Icon(Icons.download),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
} 