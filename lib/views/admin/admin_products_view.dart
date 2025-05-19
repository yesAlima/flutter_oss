import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/admin/admin_products_controller.dart';
import '../import_view.dart';
import '../../routes/app_routes.dart';
import '../../controllers/import_controller.dart';

class AdminProductsView extends GetView<AdminProductsController> {
  const AdminProductsView({Key? key}) : super(key: key);

  Color _getStockColor(int stock, int? alert) {
    if (stock == 0) return Colors.red;
    if (alert != null && stock <= alert) return Colors.orange[700]!;
    return Colors.grey[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.adminProductForm),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
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
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showFilterDialog(context),
                ),
              ),
              onChanged: (_) => controller.loadProducts(),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = controller.filteredProducts;
              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    'No products found',
                    style: TextStyle(fontSize: 18),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () => Get.toNamed(AppRoutes.adminProductForm, arguments: product.id),
                      child: ListTile(
                        leading: SizedBox(
                          width: 56,
                          height: 56,
                          child: _buildProductImage(product.imageUrl),
                        ),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.description != null && product.description!.isNotEmpty)
                              Text(product.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  controller.getCategoryName(product.categoryId),
                                  style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${product.price.toStringAsFixed(3)} BD',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                                ),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    Icon(Icons.inventory_2, size: 16, color: _getStockColor(product.stock, product.alert)),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Stock: ${product.stock}',
                                      style: TextStyle(
                                        color: _getStockColor(product.stock, product.alert),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Delete',
                              onPressed: () => controller.deleteProduct(product.id),
                            ),
                            IconButton(
                              icon: const Icon(Icons.input, color: Colors.purple),
                              tooltip: 'Import',
                              onPressed: () {
                                if (!Get.isRegistered<ImportController>()) {
                                  Get.put(ImportController());
                                }
                                Get.dialog(
                                  ImportView(
                                    productId: product.id,
                                    productName: product.name,
                                  ),
                                  barrierDismissible: true,
                                );
                              },
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

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.image_not_supported,
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
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading image: $error for URL: $url');
          return Container(
            color: Colors.grey[200],
            child: Center(
              child: Icon(
                Icons.image_not_supported,
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

  void _showFilterDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter Products', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(controller.minPrice.value, controller.maxPrice.value),
                min: controller.fullMinPrice.value,
                max: controller.fullMaxPrice.value,
                divisions: 100,
                labels: RangeLabels(
                  '${controller.minPrice.value.floor()} BD',
                  '${controller.maxPrice.value.ceil()} BD',
                ),
                onChanged: (values) {
                  controller.setMinPrice(values.start);
                  controller.setMaxPrice(values.end);
                },
              )),
              const SizedBox(height: 16),
              const Text('Stock Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(controller.minStock.value.toDouble(), controller.maxStock.value.toDouble()),
                min: controller.fullMinStock.value.toDouble(),
                max: controller.fullMaxStock.value.toDouble(),
                divisions: controller.fullMaxStock.value - controller.fullMinStock.value,
                labels: RangeLabels(
                  controller.minStock.value.toString(),
                  controller.maxStock.value.toString(),
                ),
                onChanged: (values) {
                  controller.setMinStock(values.start.round());
                  controller.setMaxStock(values.end.round());
                },
              )),
              const SizedBox(height: 16),
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: controller.categories.map((category) {
                  return Obx(() => FilterChip(
                    label: Text(category.name),
                    selected: controller.selectedCategories.contains(category.id),
                    onSelected: (selected) => controller.toggleCategory(category.id),
                  ));
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Active'),
                      value: controller.showActive.value,
                      onChanged: (value) => controller.toggleShowActive(),
                    )),
                  ),
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Inactive'),
                      value: controller.showInactive.value,
                      onChanged: (value) => controller.toggleShowInactive(),
                    )),
                  ),
                ],
              ),
              Obx(() => SwitchListTile(
                title: const Text('Low Stock Only'),
                value: controller.showLowStockOnly.value,
                onChanged: (value) => controller.toggleShowLowStockOnly(),
              )),
              const SizedBox(height: 16),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  Obx(() => ChoiceChip(
                    label: const Text('Name'),
                    selected: controller.sortBy.value == 'name',
                    onSelected: (selected) {
                      if (selected) {
                        controller.setSortBy('name');
                      }
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Price'),
                    selected: controller.sortBy.value == 'price',
                    onSelected: (selected) {
                      if (selected) {
                        controller.setSortBy('price');
                      }
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Stock'),
                    selected: controller.sortBy.value == 'stock',
                    onSelected: (selected) {
                      if (selected) {
                        controller.setSortBy('stock');
                      }
                    },
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => SwitchListTile(
                title: const Text('Sort Ascending'),
                value: controller.sortAscending.value,
                onChanged: (value) => controller.toggleSortAscending(),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearFilters();
              Get.back();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
} 