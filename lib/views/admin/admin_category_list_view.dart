import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import '../../routes/app_routes.dart';
import 'admin_category_form_view.dart';

class AdminCategoryListView extends StatefulWidget {
  const AdminCategoryListView({super.key});

  @override
  State<AdminCategoryListView> createState() => _AdminCategoryListViewState();
}

class _AdminCategoryListViewState extends State<AdminCategoryListView> with SingleTickerProviderStateMixin {
  final _categoryService = Get.find<CategoryService>();
  final _searchController = TextEditingController();
  final RxBool _isLoading = true.obs;
  final RxList<CategoryModel> _categories = <CategoryModel>[].obs;
  late final AnimationController _loadingController;
  final Map<String, bool> _imageLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    _isLoading.value = true;
    try {
      final categories = await _categoryService.getCategories().first;
      _categories.value = categories;
      // Preload images
      for (var category in categories) {
        if (category.imageUrl != null) {
          _preloadImage(category.imageUrl!);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load categories');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _preloadImage(String url) async {
    if (_imageLoadingStates[url] == true) return;
    _imageLoadingStates[url] = true;
    try {
      await precacheImage(NetworkImage(url), context);
    } catch (e) {
      print('Error preloading image: $e');
    } finally {
      _imageLoadingStates[url] = false;
    }
  }

  List<CategoryModel> get _filteredCategories {
    final searchTerm = _searchController.text.toLowerCase();
    return _categories.where((category) {
      final name = category.name.toLowerCase();
      final description = category.description.toLowerCase();
      return name.contains(searchTerm) || description.contains(searchTerm);
    }).toList();
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: AnimatedBuilder(
        animation: _loadingController,
        builder: (context, child) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor.withAlpha(128),
              ),
              strokeWidth: 3,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.category,
          size: 32,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildLoadingIndicator(),
        errorWidget: (context, url, error) {
          debugPrint('Error loading image: $error for URL: $url');
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.category,
                size: 32,
                color: Colors.grey[400],
              ),
            ),
          );
        },
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
        memCacheWidth: 160,
        memCacheHeight: 160,
        maxWidthDiskCache: 160,
        maxHeightDiskCache: 160,
      ),
    );
  }

  Future<void> _deleteCategory(String id) async {
    try {
      await _categoryService.deleteCategory(id);
      Get.snackbar('Success', 'Category deleted successfully');
      _loadCategories();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete category');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed('/admin/category/form');
                _loadCategories(); // Reload after returning from form
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Category'),
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

        if (_categories.isEmpty) {
          return const Center(
            child: Text(
              'No categories found',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Category image or icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _buildCategoryImage(category.imageUrl),
                    ),
                    const SizedBox(width: 16),
                    // Category info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category.description,
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
                            await Get.toNamed(
                              '/admin/category/form',
                              arguments: category.id,
                            );
                            _loadCategories();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCategory(category.id),
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