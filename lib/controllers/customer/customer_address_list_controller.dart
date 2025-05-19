import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

class CustomerAddressListController extends GetxController {
  final UserService _userService = Get.find<UserService>();
  final AuthService _authService = Get.find<AuthService>();
  
  final isLoading = true.obs;
  final addresses = <AddressModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAddresses();
  }

  Future<void> loadAddresses() async {
    isLoading.value = true;
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      final userData = await _userService.getUser(user.id);
      if (userData != null) {
        addresses.value = userData.addresses;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load addresses');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteAddress(String id) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;

      final userData = await _userService.getUser(user.id);
      if (userData == null) return;

      final updatedAddresses = List<AddressModel>.from(userData.addresses)
        ..removeWhere((a) => a.id == id);

      await _userService.updateUser(user.id, userData.copyWith(
        addresses: updatedAddresses,
      ));

      Get.snackbar('Success', 'Address deleted successfully');
      loadAddresses();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete address');
    }
  }

  void navigateToAddAddress() async {
    await Get.toNamed(AppRoutes.customerAddressForm);
    loadAddresses();
  }

  void navigateToEditAddress(AddressModel address) async {
    await Get.toNamed(
      AppRoutes.customerAddressForm,
      arguments: address,
    );
    loadAddresses();
  }

  String formatAddress(AddressModel address) {
    final parts = [
      'Block ${address.block}',
      if (address.road != null) 'Road ${address.road}',
      'Building ${address.building}',
    ];
    return parts.join(', ');
  }
} 