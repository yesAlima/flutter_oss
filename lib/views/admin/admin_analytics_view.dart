import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/admin/admin_analytics_controller.dart';
import '../../widgets/analytics_card.dart';

class AdminAnalyticsView extends GetView<AdminAnalyticsController> {
  const AdminAnalyticsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: controller.loadAnalytics,
          ),
        ],
      ),
      body: Obx(() => controller.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeRangeSelector(),
                  const SizedBox(height: 24),
                  _buildOverviewCards(),
                  const SizedBox(height: 24),
                  _buildSalesTrendChart(),
                  const SizedBox(height: 24),
                  _buildTopProducts(),
                ],
              ),
            )),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Obx(() {
      final start = controller.startDate.value;
      final end = controller.endDate.value;
      final minDate = controller.minDate ?? DateTime.now();
      final maxDate = controller.maxDate ?? DateTime.now();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'From:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: Get.context!,
                      initialDate: start ?? minDate,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                    if (picked != null) {
                      // Set to 00:00 of picked day
                      controller.setStartDate(DateTime(picked.year, picked.month, picked.day, 0, 0));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      start != null
                          ? '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}'
                          : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'To:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: Get.context!,
                      initialDate: end ?? maxDate,
                      firstDate: minDate,
                      lastDate: maxDate,
                    );
                    if (picked != null) {
                      // Set to 23:59 of picked day
                      controller.setEndDate(DateTime(picked.year, picked.month, picked.day, 23, 59));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      end != null
                          ? '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}'
                          : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        AnalyticsCard(
          title: 'Total Revenue',
          data: controller.formatCurrency(controller.totalRevenue),
          icon: Icons.attach_money,
          color: Colors.blue,
          subtitle: 'From ${controller.totalOrders} orders',
        ),
        AnalyticsCard(
          title: 'Total Profit',
          data: controller.formatCurrency(controller.totalProfit),
          icon: Icons.trending_up,
          color: Colors.green,
          subtitle: '${controller.formatPercentage(controller.profitMargin)} margin',
        ),
        AnalyticsCard(
          title: 'Import Costs',
          data: controller.formatCurrency(controller.totalImportCost),
          icon: Icons.shopping_cart,
          color: Colors.orange,
          subtitle: 'Total cost of imports',
        ),
        AnalyticsCard(
          title: 'Average Order',
          data: controller.formatCurrency(controller.averageOrderValue),
          icon: Icons.analytics,
          color: Colors.purple,
          subtitle: 'Per order',
        ),
      ],
    );
  }

  Widget _buildSalesTrendChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(100),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Trend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          controller.formatCurrency(value),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final data = controller.salesTrendData;
                        if (value.toInt() >= 0 && value.toInt() < data.length) {
                          final date = data[value.toInt()]['date'] as String;
                          return Text(
                            date.split('-').last,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: controller.salesTrendData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value['revenue'] as double);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withAlpha(100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(100),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...controller.topProducts.map((product) {
            final data = product.value as Map<String, dynamic>;
            final profit = controller.getProductProfit(data);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.key,
                          style: const TextStyle(fontSize: 16),
                        ),
                        Text(
                          'Sold: ${data['sold']} | Imported: ${data['imported']}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '+${controller.formatCurrency(profit)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
