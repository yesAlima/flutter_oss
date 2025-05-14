import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalyticsCard extends StatelessWidget {
  final String title;
  final String data;
  final IconData icon;
  final Color color;
  final VoidCallback onExport;

  const AnalyticsCard({
    super.key,
    required this.title,
    required this.data,
    required this.icon,
    required this.color,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: onExport,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  data,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 