import 'package:get/get.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/order_model.dart';
import '../../services/product_service.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/category_service.dart';
import '../../routes/app_routes.dart';

class CustomerProductsController extends GetxController {
  final ProductService _productService = Get.find<ProductService>();
  final AuthService _authService = Get.find<AuthService>();
  final OrderService _orderService = Get.find<OrderService>();
  final CategoryService _categoryService = Get.find<CategoryService>();
  
  // State variables
  final isLoading = true.obs;
  final products = <ProductModel>[].obs;
  final searchText = ''.obs;
  final categories = <CategoryModel>[].obs;
  
  // Filter states
  final minPrice = 0.0.obs;
  final maxPrice = 0.0.obs;
  final selectedCategories = <String>[].obs;
  final showOutOfStock = false.obs;
  
  // Sort states
  final sortBy = 'name'.obs; // 'name', 'price'
  final sortAscending = true.obs;
  
  // Full range values for filters
  final fullMinPrice = 0.0.obs;
  final fullMaxPrice = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      final categoriesStream = _categoryService.getCategories();
      categoriesStream.listen((categoryList) {
        categories.value = categoryList;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load categories: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> loadProducts() async {
    isLoading.value = true;
    try {
      final productsStream = _productService.getProducts();
      productsStream.listen((productList) {
        // Only show active products to customers
        products.value = productList.where((p) => p.isActive).toList();
        
        // Initialize filter ranges
        if (products.isNotEmpty) {
          // Set full range values
          fullMinPrice.value = products.map((p) => p.price).reduce((a, b) => a < b ? a : b).floorToDouble();
          fullMaxPrice.value = products.map((p) => p.price).reduce((a, b) => a > b ? a : b).ceilToDouble();
          
          // Set current filter values to full range
          minPrice.value = fullMinPrice.value;
          maxPrice.value = fullMaxPrice.value;
        }
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load products: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<ProductModel> get filteredProducts {
    var filtered = products.where((product) {
      // Search text filter
      final searchTerm = searchText.value.toLowerCase();
      if (searchTerm.isNotEmpty) {
        final matchesSearch = 
          product.name.toLowerCase().contains(searchTerm) ||
          (product.description?.toLowerCase().contains(searchTerm) ?? false) ||
          product.price.toString().contains(searchTerm) ||
          getCategoryName(product.categoryId).toLowerCase().contains(searchTerm);
        if (!matchesSearch) return false;
      }

      // Price range filter
      if (product.price < minPrice.value || product.price > maxPrice.value) {
        return false;
      }

      // Category filter
      if (selectedCategories.isNotEmpty && !selectedCategories.contains(product.categoryId)) {
        return false;
      }

      // Out of stock filter
      if (!showOutOfStock.value && product.stock <= 0) {
        return false;
      }

      return true;
    }).toList();

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (sortBy.value) {
        case 'price':
          comparison = a.price.compareTo(b.price);
          break;
        default: // 'name'
          comparison = a.name.compareTo(b.name);
      }
      return sortAscending.value ? comparison : -comparison;
    });

    return filtered;
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

  Future<void> addToCart(ProductModel product, int quantity) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.toNamed(AppRoutes.login);
        return;
      }

      // Get the current draft order
      final draftOrder = await _orderService.getOrCreateDraftOrder();
      
      // Check if product already exists in cart
      final existingLine = draftOrder.orderlines.firstWhere(
        (line) => line.id == product.id,
        orElse: () => OrderLine(id: product.id, quantity: 0),
      );

      if (existingLine.quantity > 0) {
        // Update existing item quantity
        await _orderService.updateDraftOrderQuantity(user.id, product.id, quantity);
        Get.back(); // Close the dialog
        Get.snackbar(
          'Success',
          'Cart updated',
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        // Add new item
        await _orderService.addToDraftOrder(user.id, product.id, quantity);
        Get.back(); // Close the dialog
        Get.snackbar(
          'Success',
          'Product added to cart',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add product to cart: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void updateSearchText(String text) {
    searchText.value = text;
  }

  void updateFilters({
    double? minPrice,
    double? maxPrice,
    List<String>? selectedCategories,
    bool? showOutOfStock,
    String? sortBy,
    bool? sortAscending,
  }) {
    if (minPrice != null) this.minPrice.value = minPrice;
    if (maxPrice != null) this.maxPrice.value = maxPrice;
    if (selectedCategories != null) this.selectedCategories.value = selectedCategories;
    if (showOutOfStock != null) this.showOutOfStock.value = showOutOfStock;
    if (sortBy != null) this.sortBy.value = sortBy;
    if (sortAscending != null) this.sortAscending.value = sortAscending;
  }

  void resetFilters() {
    minPrice.value = fullMinPrice.value;
    maxPrice.value = fullMaxPrice.value;
    selectedCategories.clear();
    showOutOfStock.value = false;
    sortBy.value = 'name';
    sortAscending.value = true;
  }
} 