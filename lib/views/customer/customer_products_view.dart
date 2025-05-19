import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../controllers/customer/customer_products_controller.dart';
import '../../models/product_model.dart';
import 'package:flutter/services.dart';

class CustomerProductsView extends StatefulWidget {
  const CustomerProductsView({Key? key}) : super(key: key);

  @override
  State<CustomerProductsView> createState() => _CustomerProductsViewState();
}

class _CustomerProductsViewState extends State<CustomerProductsView> with SingleTickerProviderStateMixin {
  final CustomerProductsController _controller = Get.find<CustomerProductsController>();
  final _searchController = TextEditingController();
  late final AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingController.dispose();
    super.dispose();
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

  void _showFilterDialog() {
    // Create temporary variables to store filter values
    final tempMinPrice = _controller.minPrice.value;
    final tempMaxPrice = _controller.maxPrice.value;
    final tempSelectedCategories = List<String>.from(_controller.selectedCategories);
    final tempShowOutOfStock = _controller.showOutOfStock.value;
    final tempSortBy = _controller.sortBy.value;
    final tempSortAscending = _controller.sortAscending.value;

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
                min: _controller.fullMinPrice.value,
                max: _controller.fullMaxPrice.value,
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
              Obx(() => Wrap(
                spacing: 8,
                children: _controller.categories.map((category) {
                  return FilterChip(
                    label: Text(category.name),
                    selected: dialogSelectedCategories.contains(category.id),
                    onSelected: (selected) {
                      if (selected) {
                        dialogSelectedCategories.add(category.id);
                      } else {
                        dialogSelectedCategories.remove(category.id);
                      }
                    },
                  );
                }).toList(),
              )),
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
              _controller.resetFilters();
              Get.back();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              _controller.updateFilters(
                minPrice: dialogMinPrice.value,
                maxPrice: dialogMaxPrice.value,
                selectedCategories: dialogSelectedCategories,
                showOutOfStock: dialogShowOutOfStock.value,
                sortBy: dialogSortBy.value,
                sortAscending: dialogSortAscending.value,
              );
              Get.back();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddToCartDialog(ProductModel product) async {
    final maxQuantity = product.stock;
    int quantity = 1;
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
              await _controller.addToCart(product, quantity);
              Get.back();
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
                  onChanged: _controller.updateSearchText,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (_controller.isLoading.value) {
              return _buildLoadingIndicator();
            }

            final products = _controller.filteredProducts;
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
                              if (product.description != null)
                                Text(
                                  product.description!,
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
                              ? () => _showAddToCartDialog(product)
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