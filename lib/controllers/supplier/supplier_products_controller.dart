import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/product_service.dart';
import '../../services/category_service.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';

class SupplierProductsController extends GetxController with GetSingleTickerProviderStateMixin {
  final ProductService _productService = Get.find<ProductService>();
  final CategoryService _categoryService = Get.find<CategoryService>();
  final searchController = TextEditingController();
  
  final isLoading = true.obs;
  final products = <ProductModel>[].obs;
  final categories = <CategoryModel>[].obs;
  final imageLoadingStates = <String, bool>{}.obs;
  late final AnimationController loadingController;

  // Filter states
  final minPrice = 0.0.obs;
  final maxPrice = 0.0.obs;
  final minStock = 0.obs;
  final maxStock = 0.obs;
  final selectedCategories = <String>[].obs;
  final showActive = true.obs;
  final showInactive = true.obs;
  final showLowStockOnly = false.obs;

  // Sort states
  final sortBy = 'name'.obs; // 'name', 'price', 'stock'
  final sortAscending = true.obs;

  // Full range values
  final fullMinPrice = 0.0.obs;
  final fullMaxPrice = 0.0.obs;
  final fullMinStock = 0.obs;
  final fullMaxStock = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    loadProducts();
    loadCategories();
  }

  @override
  void onClose() {
    searchController.dispose();
    loadingController.dispose();
    super.onClose();
  }

  Future<void> loadCategories() async {
    try {
      _categoryService.getCategories().listen((categoryList) {
        categories.value = categoryList;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load categories: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadProducts() async {
    isLoading.value = true;
    try {
      final productsStream = _productService.getProducts();
      productsStream.listen((productList) {
        products.value = productList;
        // Initialize filter ranges
        if (productList.isNotEmpty) {
          final prices = productList.map((p) => p.price).toList();
          final stocks = productList.map((p) => p.stock).toList();
          fullMinPrice.value = prices.reduce((a, b) => a < b ? a : b).floorToDouble();
          fullMaxPrice.value = prices.reduce((a, b) => a > b ? a : b).ceilToDouble();
          fullMinStock.value = stocks.reduce((a, b) => a < b ? a : b);
          fullMaxStock.value = stocks.reduce((a, b) => a > b ? a : b);
          minPrice.value = fullMinPrice.value;
          maxPrice.value = fullMaxPrice.value;
          minStock.value = fullMinStock.value;
          maxStock.value = fullMaxStock.value;
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load products: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void applyFilters() {
    var filteredProducts = products.where((product) {
      // Category filter
      if (selectedCategories.isNotEmpty && !selectedCategories.contains(product.categoryId)) {
        return false;
      }

      // Price filter
      if (product.price < minPrice.value || product.price > maxPrice.value) {
        return false;
      }

      // Stock filter
      if (product.stock < minStock.value || product.stock > maxStock.value) {
        return false;
      }

      // Active/Inactive filter
      if (!showActive.value && product.isActive) {
        return false;
      }
      if (!showInactive.value && !product.isActive) {
        return false;
      }

      // Low stock filter
      if (showLowStockOnly.value && product.stock > (product.alert ?? 0)) {
        return false;
      }

      // Search filter
      if (searchController.text.isNotEmpty) {
        final searchLower = searchController.text.toLowerCase();
        if (!product.name.toLowerCase().contains(searchLower) &&
            !(product.description?.toLowerCase().contains(searchLower) ?? false) &&
            !getCategoryName(product.categoryId).toLowerCase().contains(searchLower)) {
          return false;
        }
      }

      return true;
    }).toList();

    // Apply sorting
    filteredProducts.sort((a, b) {
      int comparison;
      if (sortBy.value == 'name') {
        comparison = a.name.compareTo(b.name);
      } else if (sortBy.value == 'price') {
        comparison = a.price.compareTo(b.price);
      } else if (sortBy.value == 'stock') {
        comparison = a.stock.compareTo(b.stock);
      } else {
        comparison = 0;
      }
      return sortAscending.value ? comparison : -comparison;
    });

    products.value = filteredProducts;
  }

  String getCategoryName(String? categoryId) {
    if (categoryId == null) return 'Not specified';
    final category = categories.firstWhere(
      (cat) => cat.id == categoryId,
      orElse: () => CategoryModel(
        id: '',
        name: 'Not specified',
        description: '',
      ),
    );
    return category.name;
  }

  void setImageLoadingState(String productId, bool isLoading) {
    imageLoadingStates[productId] = isLoading;
  }

  void toggleCategory(String categoryId) {
    if (selectedCategories.contains(categoryId)) {
      selectedCategories.remove(categoryId);
    } else {
      selectedCategories.add(categoryId);
    }
    applyFilters();
  }

  void setPriceRange(double min, double max) {
    minPrice.value = min;
    maxPrice.value = max;
    applyFilters();
  }

  void setStockRange(int min, int max) {
    minStock.value = min;
    maxStock.value = max;
    applyFilters();
  }

  void toggleActive() {
    showActive.value = !showActive.value;
    applyFilters();
  }

  void toggleInactive() {
    showInactive.value = !showInactive.value;
    applyFilters();
  }

  void toggleLowStock() {
    showLowStockOnly.value = !showLowStockOnly.value;
    applyFilters();
  }

  void setSorting(String field, bool ascending) {
    sortBy.value = field;
    sortAscending.value = ascending;
    applyFilters();
  }

  Future<void> toggleProductStatus(String productId, bool isActive) async {
    try {
      final product = await _productService.getProduct(productId);
      if (product != null) {
        final updatedProduct = ProductModel(
          id: product.id,
          name: product.name,
          description: product.description,
          price: product.price,
          stock: product.stock,
          categoryId: product.categoryId,
          imageUrl: product.imageUrl,
          isActive: isActive,
          alert: product.alert,
        );
        await _productService.updateProduct(productId, updatedProduct);
        Get.snackbar(
          'Success',
          'Product ${isActive ? 'activated' : 'deactivated'} successfully',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update product status: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _productService.deleteProduct(productId);
      Get.snackbar('Success', 'Product deleted successfully');
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete product');
    }
  }

  void clearFilters() {
    selectedCategories.clear();
    minPrice.value = fullMinPrice.value;
    maxPrice.value = fullMaxPrice.value;
    minStock.value = fullMinStock.value;
    maxStock.value = fullMaxStock.value;
    showActive.value = true;
    showInactive.value = true;
    showLowStockOnly.value = false;
    sortBy.value = 'name';
    sortAscending.value = true;
    searchController.clear();
    applyFilters();
  }

  void resetFilters() {
    minPrice.value = fullMinPrice.value;
    maxPrice.value = fullMaxPrice.value;
    minStock.value = fullMinStock.value;
    maxStock.value = fullMaxStock.value;
    selectedCategories.clear();
    showActive.value = true;
    showInactive.value = true;
    showLowStockOnly.value = false;
    sortBy.value = 'name';
    sortAscending.value = true;
    searchController.clear();
    applyFilters();
  }

  List<ProductModel> get filteredProducts {
    var filtered = products.where((product) {
      // Search text filter
      final searchTerm = searchController.text.toLowerCase();
      if (searchTerm.isNotEmpty) {
        final matchesSearch = 
          product.name.toLowerCase().contains(searchTerm) ||
          (product.description?.toLowerCase().contains(searchTerm) ?? false) ||
          product.price.toString().contains(searchTerm) ||
          product.stock.toString().contains(searchTerm) ||
          getCategoryName(product.categoryId).toLowerCase().contains(searchTerm);
        if (!matchesSearch) return false;
      }

      // Price range filter
      if (product.price < minPrice.value || product.price > maxPrice.value) {
        return false;
      }

      // Stock range filter
      if (product.stock < minStock.value || product.stock > maxStock.value) {
        return false;
      }

      // Category filter
      if (selectedCategories.isNotEmpty && !selectedCategories.contains(product.categoryId)) {
        return false;
      }

      // Active/Inactive filter
      if (!showActive.value && product.isActive) return false;
      if (!showInactive.value && !product.isActive) return false;

      // Low stock filter
      if (showLowStockOnly.value && (product.alert == null || product.stock > product.alert!)) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy.value) {
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
      return sortAscending.value ? comparison : -comparison;
    });

    return filtered;
  }
} 