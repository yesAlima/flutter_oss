import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_export_controller.dart';

class AdminExportView extends GetView<AdminExportController> {
  const AdminExportView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
      ),
      body: Obx(() => controller.isLoading.value
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
                                  value: controller.selectedFormat.value,
                                  decoration: const InputDecoration(
                                    labelText: 'Format',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: controller.formats.map((String format) {
                                    return DropdownMenuItem<String>(
                                      value: format,
                                      child: Text(format),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      controller.setFormat(newValue);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Obx(() {
                                  final start = controller.startDate.value;
                                  final end = controller.endDate.value;
                                  final minDate = controller.minDate ?? DateTime(2020, 1, 1);
                                  final maxDate = controller.maxDate ?? DateTime.now();
                                  return Row(
                                    children: [
                                      const Text('From:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: start ?? minDate,
                                            firstDate: minDate,
                                            lastDate: maxDate,
                                          );
                                          if (picked != null) {
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
                                      const SizedBox(width: 12),
                                      const Text('To:', style: TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate: end ?? maxDate,
                                            firstDate: minDate,
                                            lastDate: maxDate,
                                          );
                                          if (picked != null) {
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
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Export Data',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildExportCard(
                        title: 'Orders',
                        icon: Icons.shopping_cart,
                        color: Colors.blue,
                        onTap: controller.exportOrders,
                      ),
                      _buildExportCard(
                        title: 'Products',
                        icon: Icons.inventory,
                        color: Colors.green,
                        onTap: controller.exportProducts,
                      ),
                      _buildExportCard(
                        title: 'Users',
                        icon: Icons.people,
                        color: Colors.orange,
                        onTap: controller.exportUsers,
                      ),
                      _buildExportCard(
                        title: 'Analytics',
                        icon: Icons.analytics,
                        color: Colors.purple,
                        onTap: controller.exportAnalytics,
                      ),
                    ],
                  ),
                ],
              ),
            )),
    );
  }

  Widget _buildExportCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 