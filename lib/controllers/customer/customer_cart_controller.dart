import 'package:get/get.dart';
import '../../models/order_model.dart';
import '../../models/product_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';
import '../../services/user_service.dart';
import '../../services/order_service.dart';
import '../../routes/app_routes.dart';

class CustomerCartController extends GetxController {
  final AuthService _authService = Get.find<AuthService>();
  final ProductService _productService = Get.find<ProductService>();
  final UserService _userService = Get.find<UserService>();
  final OrderService _orderService = Get.find<OrderService>();
  
  final cart = Rx<OrderModel?>(null);
  final isLoading = true.obs;
  final products = <String, ProductModel>{}.obs;
  final addresses = <AddressModel>[].obs;
  final selectedAddress = Rx<AddressModel?>(null);
  final isAddressExpanded = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadCart();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _userService.getUser(user.id);
      if (userData != null) {
        addresses.value = userData.addresses;
        // If cart has an address, select it
        if (cart.value?.address != null) {
          final matchingAddress = addresses.firstWhere(
            (a) => a.block == cart.value!.address!.block && 
                  a.building == cart.value!.address!.building,
            orElse: () => addresses.first,
          );
          selectedAddress.value = matchingAddress;
        } else {
          selectedAddress.value = addresses.firstOrNull;
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load addresses');
    }
  }

  Future<void> loadCart() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      // Get draft order (cart)
      final draftOrder = await _orderService.getOrCreateDraftOrder();
      cart.value = draftOrder;

      // Load product details for each orderline
      for (final line in cart.value!.orderlines) {
        if (!products.containsKey(line.id)) {
          final product = await _productService.getProduct(line.id);
          if (product != null) {
            products[line.id] = product;
          }
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load cart: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateQuantity(String productId, int newQuantity) async {
    try {
      if (cart.value == null) return;

      final user = _authService.currentUser;
      if (user == null) return;

      await _orderService.updateDraftOrderQuantity(user.id, productId, newQuantity);
      loadCart(); // Reload cart to reflect changes
    } catch (e) {
      Get.snackbar('Error', 'Failed to update quantity: $e');
    }
  }

  Future<void> updateCartAddress(AddressModel? address) async {
    try {
      if (cart.value == null) return;

      final user = _authService.currentUser;
      if (user == null) return;

      if (address != null) {
        await _orderService.updateDraftOrderAddress(user.id, address);
      }

      selectedAddress.value = address;
      loadCart(); // Reload cart to reflect changes
    } catch (e) {
      Get.snackbar('Error', 'Failed to update delivery address');
    }
  }

  Future<void> placeOrder() async {
    try {
      if (cart.value == null || cart.value!.orderlines.isEmpty) {
        Get.snackbar('Error', 'Cart is empty');
        return;
      }

      if (selectedAddress.value == null) {
        Get.snackbar('Error', 'Please select a delivery address');
        return;
      }

      // Update cart address before placing order
      await updateCartAddress(selectedAddress.value);

      // Place the order
      await _orderService.placeOrder();

      Get.snackbar('Success', 'Order placed successfully');
      Get.offAllNamed(AppRoutes.customer);
    } catch (e) {
      Get.snackbar('Error', 'Failed to place order: $e');
    }
  }

  double getCartTotal() {
    if (cart.value == null) return 0;
    return cart.value!.orderlines.fold(0.0, (sums, line) => sums + (line.price ?? 0));
  }

  int getItemCount() {
    if (cart.value == null) return 0;
    return cart.value!.orderlines.fold(0, (sums, line) => sums + line.quantity);
  }

  void toggleAddressExpanded() {
    isAddressExpanded.value = !isAddressExpanded.value;
  }
} 