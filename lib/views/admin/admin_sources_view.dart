import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/order_controller.dart';
import '../../models/source_model.dart';
import '../../routes/app_routes.dart';

class AdminSourcesView extends StatefulWidget {
  const AdminSourcesView({Key? key}) : super(key: key);

  @override
  State<AdminSourcesView> createState() => _AdminSourcesViewState();
}

class _AdminSourcesViewState extends State<AdminSourcesView> {
  final OrderController _orderController = Get.find<OrderController>();
  final _searchController = TextEditingController();
  final RxBool _isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    _isLoading.value = true;
    try {
      await _orderController.loadSources();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load sources');
    } finally {
      _isLoading.value = false;
    }
  }

  List<SourceModel> get _filteredSources {
    final searchTerm = _searchController.text.toLowerCase();
    return _orderController.sources.where((source) {
      final name = source.name.toLowerCase();
      final description = source.description?.toLowerCase() ?? '';
      return name.contains(searchTerm) || description.contains(searchTerm);
    }).toList();
  }

  Future<void> _deleteSource(String id) async {
    try {
      await _orderController.deleteSource(id);
      Get.snackbar('Success', 'Source deleted successfully');
      _loadSources();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete source');
    }
  }

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
                _loadSources(); // Reload after returning from form
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
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_orderController.sources.isEmpty) {
          return const Center(
            child: Text(
              'No sources found',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredSources.length,
          itemBuilder: (context, index) {
            final source = _filteredSources[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Get.toNamed(AppRoutes.sourceForm,
                              arguments: source.id,
                            );
                            _loadSources();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteSource(source.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
} 