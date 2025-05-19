import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_sources_controller.dart';
import '../../models/source_model.dart';
import '../../routes/app_routes.dart';

class AdminSourcesView extends GetView<AdminSourcesController> {
  const AdminSourcesView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sources'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed(AppRoutes.sourceForm);
                controller.loadSources(); // Reload after returning from form
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Source'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: controller.searchController,
              decoration: InputDecoration(
                hintText: 'Search sources...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.searchController.clear();
                    controller.loadSources();
                  },
                ),
              ),
              onChanged: (_) => controller.loadSources(),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.sources.isEmpty) {
                return const Center(
                  child: Text(
                    'No sources found',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }

              final filteredSources = controller.filteredSources;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredSources.length,
                itemBuilder: (context, index) {
                  final source = filteredSources[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: InkWell(
                      onTap: () async {
                        final result = await Get.toNamed(AppRoutes.sourceForm,
                          arguments: source.id,
                        );
                        if (result is SourceModel) {
                          controller.updateSourceInList(result);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Source info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    source.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    source.description ?? '',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Action buttons
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => controller.deleteSource(source.id),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
} 