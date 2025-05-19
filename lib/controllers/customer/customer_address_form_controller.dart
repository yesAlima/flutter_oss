import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

class CustomerAddressFormController extends GetxController {
  final UserService _userService = Get.find<UserService>();
  final AuthService _authService = Get.find<AuthService>();
  
  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final isEditing = false.obs;
  
  final block = ''.obs;
  final road = Rx<String?>(null);
  final building = ''.obs;
  String? addressId;

  @override
  void onInit() {
    super.onInit();
    loadAddress();
  }

  void loadAddress() {
    final address = Get.arguments as AddressModel?;
    if (address == null) return;

    isEditing.value = true;
    addressId = address.id;
    block.value = address.block;
    road.value = address.road;
    building.value = address.building;
  }

  Future<void> saveAddress() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed('/login');
        return;
      }

      final userData = await _userService.getUser(user.id);
      if (userData == null) return;

      final newAddress = AddressModel(
        id: addressId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        block: block.value,
        road: road.value,
        building: building.value,
      );

      final updatedAddresses = List<AddressModel>.from(userData.addresses);
      if (isEditing.value) {
        final index = updatedAddresses.indexWhere((a) => a.id == addressId);
        if (index >= 0) {
          updatedAddresses[index] = newAddress;
        }
      } else {
        updatedAddresses.add(newAddress);
      }

      await _userService.updateUser(user.id, userData.copyWith(
        addresses: updatedAddresses,
      ));

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Address ${isEditing.value ? 'updated' : 'added'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to ${isEditing.value ? 'update' : 'add'} address: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  String? validateBlock(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a block';
    }
    return null;
  }

  String? validateBuilding(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a building';
    }
    return null;
  }

  void setBlock(String value) => block.value = value;
  void setRoad(String? value) => road.value = value?.isEmpty == true ? null : value;
  void setBuilding(String value) => building.value = value;
} 