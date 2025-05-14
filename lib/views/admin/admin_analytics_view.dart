import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/analytics_service.dart';
import '../../widgets/analytics_card.dart';

class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({Key? key}) : super(key: key);

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  final _analyticsService = Get.find<AnalyticsService>();
  bool _isLoading = false;
  Map<String, dynamic> _analytics = {};
  String _selectedTimeRange = 'Last 30 Days';
  final List<String> _timeRanges = ['Last 7 Days', 'Last 30 Days', 'Last 90 Days', 'Last Year'];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final DateTime endDate = DateTime.now();
      DateTime startDate;
      
      switch (_selectedTimeRange) {
        case 'Last 7 Days':
          startDate = endDate.subtract(const Duration(days: 7));
          break;
        case 'Last 30 Days':
          startDate = endDate.subtract(const Duration(days: 30));
          break;
        case 'Last 90 Days':
          startDate = endDate.subtract(const Duration(days: 90));
          break;
        case 'Last Year':
          startDate = endDate.subtract(const Duration(days: 365));
          break;
        default:
          startDate = endDate.subtract(const Duration(days: 30));
      }

      final analytics = await _analyticsService.getSalesAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      setState(() => _analytics = analytics);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load analytics: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButton<String>(
        value: _selectedTimeRange,
        isExpanded: true,
        items: _timeRanges.map((String range) {
          return DropdownMenuItem<String>(
            value: range,
            child: Text(range),
          );
        }).toList(),
        onChanged: (String? newValue) {
          if (newValue != null) {
            setState(() => _selectedTimeRange = newValue);
            _loadAnalytics();
          }
        },
      ),
    );
  }

  Widget _buildSalesChart() {
    final salesData = _analytics['salesByDay'] as Map<String, dynamic>? ?? {};
    if (salesData.isEmpty) {
      return const Center(child: Text('No sales data available'));
    }
    // Sort by date
    final sortedKeys = salesData.keys.toList()
      ..sort((a, b) => DateTime.parse(a).compareTo(DateTime.parse(b)));
    final List<FlSpot> spots = [];
    final List<String> labels = [];
    for (int i = 0; i < sortedKeys.length; i++) {
      final date = DateTime.parse(sortedKeys[i]);
      spots.add(FlSpot(i.toDouble(), salesData[sortedKeys[i]].toDouble()));
      labels.add('${date.month}/${date.day}');
    }
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  // Show only every 5th label to avoid crowding
                  if (idx % 5 == 0 && idx < labels.length) {
                    return Text(labels[idx], style: const TextStyle(fontSize: 10));
                  }
                  return const SizedBox.shrink();
                },
                reservedSize: 28,
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blue,
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    final categoryData = _analytics['categoryRevenue'] as Map<String, dynamic>? ?? {};
    final List<PieChartSectionData> sections = [];
    
    categoryData.forEach((category, revenue) {
      sections.add(
        PieChartSectionData(
          value: revenue.toDouble(),
          title: category.substring(0, 3),
          radius: 100,
          titleStyle: const TextStyle(fontSize: 12, color: Colors.white),
        ),
      );
    });

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: sections,
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 16),
                  const Text(
                    'Performance Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      AnalyticsCard(
                        title: 'Total Revenue',
                        data: '\$${(_analytics['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                        icon: Icons.attach_money,
                        color: Colors.green,
                        onExport: () {},
                      ),
                      AnalyticsCard(
                        title: 'Total Cost',
                        data: '\$${(_analytics['totalCost'] ?? 0.0).toStringAsFixed(2)}',
                        icon: Icons.import_export,
                        color: Colors.blueGrey,
                        onExport: () {},
                      ),
                      AnalyticsCard(
                        title: 'Total Profit',
                        data: '\$${(_analytics['totalProfit'] ?? 0.0).toStringAsFixed(2)}',
                        icon: Icons.trending_up,
                        color: Colors.deepPurple,
                        onExport: () {},
                      ),
                      AnalyticsCard(
                        title: 'Total Orders',
                        data: (_analytics['totalOrders'] ?? 0).toString(),
                        icon: Icons.shopping_cart,
                        color: Colors.blue,
                        onExport: () {},
                      ),
                      AnalyticsCard(
                        title: 'Average Order Value',
                        data: '\$${(_analytics['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
                        icon: Icons.analytics,
                        color: Colors.orange,
                        onExport: () {},
                      ),
                      AnalyticsCard(
                        title: 'Conversion Rate',
                        data: '${(_analytics['conversionRate'] ?? 0.0).toStringAsFixed(1)}%',
                        icon: Icons.percent,
                        color: Colors.purple,
                        onExport: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sales Trend',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSalesChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Category Distribution',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryDistribution(),
                  const SizedBox(height: 24),
                  const Text(
                    'Product Performance (Sales vs. Imports)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProductPerformanceTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildProductPerformanceTable() {
    final Map<String, dynamic> performance = _analytics['productPerformance'] as Map<String, dynamic>? ?? {};
    if (performance.isEmpty) {
      return const Text('No product performance data available');
    }
    final headers = ['Product', 'Sold', 'Imported'];
    final rows = performance.entries.map((entry) {
      final product = entry.key;
      final sold = entry.value['sold'] ?? 0;
      final imported = entry.value['imported'] ?? 0;
      return DataRow(cells: [
        DataCell(Text(product)),
        DataCell(Text(sold.toString())),
        DataCell(Text(imported.toString())),
      ]);
    }).toList();
    return DataTable(
      columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
      rows: rows,
      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey[200]),
      dataRowColor: WidgetStateProperty.resolveWith((states) => Colors.white),
      columnSpacing: 24,
      horizontalMargin: 12,
      showBottomBorder: true,
    );
  }
}
