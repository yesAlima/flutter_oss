import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../services/product_service.dart';
import '../../controllers/category_controller.dart';
import '../../routes/app_routes.dart';
import '../import_view.dart';
import '../../controllers/order_controller.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({Key? key}) : super(key: key);

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> with SingleTickerProviderStateMixin {
  final _productService = Get.find<ProductService>();
  final _categoryController = Get.find<CategoryController>();
  final _searchController = TextEditingController();
  final RxBool _isLoading = true.obs;
  final RxList<ProductModel> _products = <ProductModel>[].obs;
  late final AnimationController _loadingController;
  final Map<String, bool> _imageLoadingStates = {};

  // Filter states
  final RxDouble _minPrice = 0.0.obs;
  final RxDouble _maxPrice = 0.0.obs;
  final RxInt _minStock = 0.obs;
  final RxInt _maxStock = 0.obs;
  final RxList<String> _selectedCategories = <String>[].obs;
  final RxBool _showActive = true.obs;
  final RxBool _showInactive = true.obs;
  final RxBool _showLowStockOnly = false.obs;

  // Sort states
  final RxString _sortBy = 'name'.obs; // 'name', 'price', 'stock'
  final RxBool _sortAscending = true.obs;

  // Add these variables to store the full range values
  final RxDouble _fullMinPrice = 0.0.obs;
  final RxDouble _fullMaxPrice = 0.0.obs;
  final RxInt _fullMinStock = 0.obs;
  final RxInt _fullMaxStock = 0.obs;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    _isLoading.value = true;
    try {
      final products = _productService.getProducts();
      products.listen((productList) {
        _products.value = productList;
        // Initialize filter ranges
        if (productList.isNotEmpty) {
          // Set full range values
          _fullMinPrice.value = productList.map((p) => p.price).reduce((a, b) => a < b ? a : b).floorToDouble();
          _fullMaxPrice.value = productList.map((p) => p.price).reduce((a, b) => a > b ? a : b).ceilToDouble();
          _fullMinStock.value = productList.map((p) => p.stock).reduce((a, b) => a < b ? a : b);
          _fullMaxStock.value = productList.map((p) => p.stock).reduce((a, b) => a > b ? a : b);
          
          // Set current filter values to full range
          _minPrice.value = _fullMinPrice.value;
          _maxPrice.value = _fullMaxPrice.value;
          _minStock.value = _fullMinStock.value;
          _maxStock.value = _fullMaxStock.value;
        }
        // Preload images
        for (var product in productList) {
          if (product.imageUrl != null) {
            _preloadImage(product.imageUrl!);
          }
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load products: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
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

  List<ProductModel> get _filteredProducts {
    var filtered = _products.where((product) {
      // Search text filter
      final searchTerm = _searchController.text.toLowerCase();
      if (searchTerm.isNotEmpty) {
        final matchesSearch = 
          product.name.toLowerCase().contains(searchTerm) ||
          product.description.toLowerCase().contains(searchTerm) ||
          product.price.toString().contains(searchTerm) ||
          product.stock.toString().contains(searchTerm) ||
          _getCategoryName(product.categoryId).toLowerCase().contains(searchTerm);
        if (!matchesSearch) return false;
      }

      // Price range filter
      if (product.price < _minPrice.value || product.price > _maxPrice.value) {
        return false;
      }

      // Stock range filter
      if (product.stock < _minStock.value || product.stock > _maxStock.value) {
        return false;
      }

      // Category filter
      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(product.categoryId)) {
        return false;
      }

      // Active/Inactive filter
      if (!_showActive.value && product.isActive) return false;
      if (!_showInactive.value && !product.isActive) return false;

      // Low stock filter
      if (_showLowStockOnly.value && (product.alert == null || product.stock > product.alert!)) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy.value) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        case 'stock':
          comparison = a.stock.compareTo(b.stock);
          break;
      }
      return _sortAscending.value ? comparison : -comparison;
    });

    return filtered;
  }

  String _getCategoryName(String? categoryId) {
    if (categoryId == null) return 'Not specified';
    final category = _categoryController.categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => CategoryModel(
        id: '',
        name: 'Not specified',
        description: '',
      ),
    );
    return category.name;
  }

  void _showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinPrice = _minPrice.value;
    final tempMaxPrice = _maxPrice.value;
    final tempMinStock = _minStock.value;
    final tempMaxStock = _maxStock.value;
    final tempSelectedCategories = List<String>.from(_selectedCategories);
    final tempShowActive = _showActive.value;
    final tempShowInactive = _showInactive.value;
    final tempShowLowStockOnly = _showLowStockOnly.value;
    final tempSortBy = _sortBy.value;
    final tempSortAscending = _sortAscending.value;

    // Create Rx variables for the dialog
    final dialogMinPrice = tempMinPrice.obs;
    final dialogMaxPrice = tempMaxPrice.obs;
    final dialogMinStock = tempMinStock.obs;
    final dialogMaxStock = tempMaxStock.obs;
    final dialogSelectedCategories = tempSelectedCategories.obs;
    final dialogShowActive = tempShowActive.obs;
    final dialogShowInactive = tempShowInactive.obs;
    final dialogShowLowStockOnly = tempShowLowStockOnly.obs;
    final dialogSortBy = tempSortBy.obs;
    final dialogSortAscending = tempSortAscending.obs;

    Get.dialog(
      AlertDialog(
        title: const Text('Filter Products'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinPrice.value, dialogMaxPrice.value),
                min: _fullMinPrice.value,
                max: _fullMaxPrice.value,
                divisions: 100,
                labels: RangeLabels(
                  '${dialogMinPrice.value.floor()} BD',
                  '${dialogMaxPrice.value.ceil()} BD',
                ),
                onChanged: (values) {
                  dialogMinPrice.value = values.start;
                  dialogMaxPrice.value = values.end;
                },
              )),
              const SizedBox(height: 16),
              const Text('Stock Range', style: TextStyle(fontWeight: FontWeight.bold)),
              Obx(() => RangeSlider(
                values: RangeValues(dialogMinStock.value.toDouble(), dialogMaxStock.value.toDouble()),
                min: _fullMinStock.value.toDouble(),
                max: _fullMaxStock.value.toDouble(),
                divisions: _fullMaxStock.value - _fullMinStock.value,
                labels: RangeLabels(
                  dialogMinStock.value.toString(),
                  dialogMaxStock.value.toString(),
                ),
                onChanged: (values) {
                  dialogMinStock.value = values.start.round();
                  dialogMaxStock.value = values.end.round();
                },
              )),
              const SizedBox(height: 16),
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _categoryController.categories.map((category) {
                  return Obx(() => FilterChip(
                    label: Text(category.name),
                    selected: dialogSelectedCategories.contains(category.id),
                    onSelected: (selected) {
                      if (selected) {
                        dialogSelectedCategories.add(category.id);
                      } else {
                        dialogSelectedCategories.remove(category.id);
                      }
                    },
                  ));
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Active'),
                      value: dialogShowActive.value,
                      onChanged: (value) => dialogShowActive.value = value,
                    )),
                  ),
                  Expanded(
                    child: Obx(() => SwitchListTile(
                      title: const Text('Inactive'),
                      value: dialogShowInactive.value,
                      onChanged: (value) => dialogShowInactive.value = value,
                    )),
                  ),
                ],
              ),
              Obx(() => SwitchListTile(
                title: const Text('Low Stock Only'),
                value: dialogShowLowStockOnly.value,
                onChanged: (value) => dialogShowLowStockOnly.value = value,
              )),
              const SizedBox(height: 16),
              const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: [
                  Obx(() => ChoiceChip(
                    label: const Text('Name'),
                    selected: dialogSortBy.value == 'name',
                    onSelected: (selected) {
                      if (selected) {
                        dialogSortBy.value = 'name';
                      }
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Price'),
                    selected: dialogSortBy.value == 'price',
                    onSelected: (selected) {
                      if (selected) {
                        dialogSortBy.value = 'price';
                      }
                    },
                  )),
                  Obx(() => ChoiceChip(
                    label: const Text('Stock'),
                    selected: dialogSortBy.value == 'stock',
                    onSelected: (selected) {
                      if (selected) {
                        dialogSortBy.value = 'stock';
                      }
                    },
                  )),
                ],
              ),
              const SizedBox(height: 8),
              Obx(() => SwitchListTile(
                title: const Text('Sort Ascending'),
                value: dialogSortAscending.value,
                onChanged: (value) => dialogSortAscending.value = value,
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Clear all filters to their default values
              dialogMinPrice.value = _fullMinPrice.value;
              dialogMaxPrice.value = _fullMaxPrice.value;
              dialogMinStock.value = _fullMinStock.value;
              dialogMaxStock.value = _fullMaxStock.value;
              dialogSelectedCategories.clear();
              dialogShowActive.value = true;
              dialogShowInactive.value = true;
              dialogShowLowStockOnly.value = false;
              dialogSortBy.value = 'name';
              dialogSortAscending.value = true;
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              // Apply the temporary values to the actual filter states
              _minPrice.value = dialogMinPrice.value;
              _maxPrice.value = dialogMaxPrice.value;
              _minStock.value = dialogMinStock.value;
              _maxStock.value = dialogMaxStock.value;
              _selectedCategories.value = List<String>.from(dialogSelectedCategories);
              _showActive.value = dialogShowActive.value;
              _showInactive.value = dialogShowInactive.value;
              _showLowStockOnly.value = dialogShowLowStockOnly.value;
              _sortBy.value = dialogSortBy.value;
              _sortAscending.value = dialogSortAscending.value;
              Get.back();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
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

  Widget _buildProductImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.category,
          size: 64,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
                size: 64,
                color: Colors.grey[400],
              ),
            ),
          );
        },
        fadeInDuration: const Duration(milliseconds: 300),
        fadeOutDuration: const Duration(milliseconds: 300),
        memCacheWidth: 320, // 2x display size for retina displays
        memCacheHeight: 320,
        maxWidthDiskCache: 320,
        maxHeightDiskCache: 320,
      ),
    );
  }

  Widget _buildStockIndicator(ProductModel product) {
    Color stockColor;
    if (product.stock == 0) {
      stockColor = Colors.red;
    } else if (product.alert != null && product.stock <= product.alert!) {
      stockColor = Colors.orange;
    } else {
      stockColor = Colors.grey;
    }

    return Row(
      children: [
        Icon(
          Icons.inventory_2,
          size: 16,
          color: stockColor,
        ),
        const SizedBox(width: 4),
        Text(
          'Stock: ${product.stock}',
          style: TextStyle(
            color: stockColor,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceIndicator(double price) {
    return Text(
      '${price.toStringAsFixed(3)} BD',
      style: const TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
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
              onPressed: () async {
                await Get.toNamed(AppRoutes.adminProductForm);
                setState(() {}); // Reload after returning from form
              },
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
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search by name, category, price, stock, or description',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showFilterDialog,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return _buildLoadingIndicator();
              }

              final products = _filteredProducts;
              if (products.isEmpty) {
                return const Center(child: Text('No products found'));
              }

              return ListView.builder(
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Product image or icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _buildProductImage(product.imageUrl),
                          ),
                          const SizedBox(width: 16),
                          // Product info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  product.description,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildPriceIndicator(product.price),
                                    const SizedBox(width: 16),
                                    _buildStockIndicator(product),
                                  ],
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
                                        AppRoutes.adminProductForm,
                                        arguments: product.id,
                                  );
                                  setState(() {}); // Reload after returning from form
                                },
                                    ),
                                    IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteProduct(product.id),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.input),
                                      tooltip: 'Import',
                                      onPressed: () async {
                                        await Get.find<OrderController>().loadSources();
                                        showDialog(
                                          context: context,
                                          builder: (context) => ImportView(
                                            productId: product.id,
                                            productName: product.name,
                                          ),
                                        );
                                      },
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
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    _isLoading.value = true;
    try {
      await _productService.deleteProduct(productId);
      await _loadProducts();
      Get.snackbar(
        'Success',
        'Product deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete product: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }
} 