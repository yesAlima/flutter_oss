import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../controllers/category_controller.dart';
import '../../routes/app_routes.dart';
import 'package:flutter/services.dart';

class CustomerProductsView extends StatefulWidget {
  const CustomerProductsView({Key? key}) : super(key: key);

  @override
  State<CustomerProductsView> createState() => _CustomerProductsViewState();
}

class _CustomerProductsViewState extends State<CustomerProductsView> with SingleTickerProviderStateMixin {
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
  final RxList<String> _selectedCategories = <String>[].obs;
  final RxBool _showOutOfStock = false.obs;

  // Sort states
  final RxString _sortBy = 'name'.obs; // 'name', 'price'
  final RxBool _sortAscending = true.obs;

  // Add these variables to store the full range values
  final RxDouble _fullMinPrice = 0.0.obs;
  final RxDouble _fullMaxPrice = 0.0.obs;

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
        // Only show active products to customers
        _products.value = productList.where((p) => p.isActive).toList();
        
        // Initialize filter ranges
        if (_products.isNotEmpty) {
          // Set full range values
          _fullMinPrice.value = _products.map((p) => p.price).reduce((a, b) => a < b ? a : b).floorToDouble();
          _fullMaxPrice.value = _products.map((p) => p.price).reduce((a, b) => a > b ? a : b).ceilToDouble();
          
          // Set current filter values to full range
          _minPrice.value = _fullMinPrice.value;
          _maxPrice.value = _fullMaxPrice.value;
        }
        // Preload images
        for (var product in _products) {
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
          _getCategoryName(product.categoryId).toLowerCase().contains(searchTerm);
        if (!matchesSearch) return false;
      }

      // Price range filter
      if (product.price < _minPrice.value || product.price > _maxPrice.value) {
        return false;
      }

      // Category filter
      if (_selectedCategories.isNotEmpty && !_selectedCategories.contains(product.categoryId)) {
        return false;
      }

      // Out of stock filter
      if (!_showOutOfStock.value && product.stock <= 0) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy.value) {
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        default: // 'name'
          comparison = a.name.compareTo(b.name);
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
    final tempSelectedCategories = List<String>.from(_selectedCategories);
    final tempShowOutOfStock = _showOutOfStock.value;
    final tempSortBy = _sortBy.value;
    final tempSortAscending = _sortAscending.value;

    // Create Rx variables for the dialog
    final dialogMinPrice = tempMinPrice.obs;
    final dialogMaxPrice = tempMaxPrice.obs;
    final dialogSelectedCategories = tempSelectedCategories.obs;
    final dialogShowOutOfStock = tempShowOutOfStock.obs;
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
              Obx(() => SwitchListTile(
                title: const Text('Show out of stock'),
                value: dialogShowOutOfStock.value,
                onChanged: (value) => dialogShowOutOfStock.value = value,
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
              dialogSelectedCategories.clear();
              dialogShowOutOfStock.value = false;
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
              _selectedCategories.value = List<String>.from(dialogSelectedCategories);
              _showOutOfStock.value = dialogShowOutOfStock.value;
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
        memCacheWidth: 320,
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

  Future<void> _addToCart(ProductModel product) async {
    final maxQuantity = product.stock;
    final authService = Get.find<AuthService>();
    final user = authService.currentUser;
    if (user == null) {
      Get.toNamed('/login');
      return;
    }

    // Get or create draft order (cart)
    final ordersRef = FirebaseFirestore.instance.collection('orders');
    final draftOrderQuery = await ordersRef
        .where('cid', isEqualTo: user.id)
        .where('fulfillment', isEqualTo: 'draft')
        .get();

    String orderId;
    List<Map<String, dynamic>> orderlines = [];
    int initialQuantity = 1;
    if (draftOrderQuery.docs.isEmpty) {
      // Create new draft order
      final newOrder = await ordersRef.add({
        'cid': user.id,
        'orderlines': [],
        'fulfillment': 'draft',
        'paid': false,
      });
      orderId = newOrder.id;
    } else {
      orderId = draftOrderQuery.docs.first.id;
      final orderData = draftOrderQuery.docs.first.data();
      orderlines = List<Map<String, dynamic>>.from(orderData['orderlines'] ?? []);
      final existingItem = orderlines.firstWhere(
        (item) => item['id'] == product.id,
        orElse: () => {},
      );
      if (existingItem.isNotEmpty) {
        initialQuantity = existingItem['quantity'] ?? 1;
      }
    }

    int quantity = initialQuantity;
    final textController = TextEditingController(text: quantity.toString());

    await Get.dialog(
      AlertDialog(
        title: Text('Add ${product.name} to Cart'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: quantity > 1
                          ? () {
                              setState(() {
                                quantity--;
                                textController.text = quantity.toString();
                              });
                            }
                          : null,
                    ),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        controller: textController,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (value) {
                          value = value.replaceAll(RegExp(r'[^0-9]'), '');
                          if (value.isEmpty) {
                            setState(() {
                              quantity = 1;
                              textController.text = '1';
                            });
                            return;
                          }
                          final newValue = int.tryParse(value);
                          if (newValue != null) {
                            if (newValue > maxQuantity) {
                              setState(() {
                                quantity = maxQuantity;
                                textController.text = maxQuantity.toString();
                              });
                            } else if (newValue < 1) {
                              setState(() {
                                quantity = 1;
                                textController.text = '1';
                              });
                            } else {
                              setState(() {
                                quantity = newValue;
                              });
                            }
                          }
                        },
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: quantity < maxQuantity
                          ? () {
                              setState(() {
                                quantity++;
                                textController.text = quantity.toString();
                              });
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Available: $maxQuantity',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Check if product already in cart
                final existingItemIndex = orderlines.indexWhere((item) => item['id'] == product.id);
                if (existingItemIndex >= 0) {
                  // Update existing item quantity
                  orderlines[existingItemIndex]['quantity'] = quantity;
                  // Pop dialog immediately after updating
                  await ordersRef.doc(orderId).update({
                    'orderlines': orderlines,
                  });
                  Get.back();
                  Get.snackbar(
                    'Success',
                    'Cart updated',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                  return;
                } else {
                  // Add new item
                  orderlines.add({
                    'id': product.id,
                    'quantity': quantity,
                  });
                }

                // Update order
                await ordersRef.doc(orderId).update({
                  'orderlines': orderlines,
                });

                Get.back();
                Get.snackbar(
                  'Success',
                  'Product added to cart',
                  snackPosition: SnackPosition.BOTTOM,
                );
              } catch (e) {
                Get.snackbar(
                  'Error',
                  'Failed to add product to cart: $e',
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search products',
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
                        // Add to cart button
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart),
                          onPressed: product.stock > 0
                              ? () => _addToCart(product)
                              : null,
                          tooltip: product.stock > 0
                              ? 'Add to cart'
                              : 'Out of stock',
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
    );
  }
} 