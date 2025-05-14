import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';

class CustomerAddressFormView extends StatefulWidget {
  const CustomerAddressFormView({Key? key}) : super(key: key);

  @override
  State<CustomerAddressFormView> createState() => _CustomerAddressFormViewState();
}

class _CustomerAddressFormViewState extends State<CustomerAddressFormView> {
  final _userService = Get.find<UserService>();
  final _authService = Get.find<AuthService>();
  final _formKey = GlobalKey<FormState>();
  final RxBool _isLoading = false.obs;
  final RxBool _isEditing = false.obs;
  String? _addressId;
  String? _block;
  String? _road;
  String? _building;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final address = Get.arguments as AddressModel?;
    if (address == null) return;

    _isEditing.value = true;
    _addressId = address.id;
    setState(() {
      _block = address.block;
      _road = address.road;
      _building = address.building;
    });
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed('/login');
        return;
      }

      final userData = await _userService.getUser(user.id);
      if (userData == null) return;

      final newAddress = AddressModel(
        id: _addressId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        block: _block!,
        road: _road,
        building: _building!,
      );

      final updatedAddresses = List<AddressModel>.from(userData.addresses);
      if (_isEditing.value) {
        final index = updatedAddresses.indexWhere((a) => a.id == _addressId);
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
        'Address ${_isEditing.value ? 'updated' : 'added'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to ${_isEditing.value ? 'update' : 'add'} address: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_isEditing.value ? 'Edit Address' : 'New Address')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBlockField(),
              const SizedBox(height: 16),
              _buildRoadField(),
              const SizedBox(height: 16),
              _buildBuildingField(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockField() {
    return TextFormField(
      initialValue: _block,
      decoration: const InputDecoration(
        labelText: 'Block *',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a block';
        }
        return null;
      },
      onChanged: (value) => _block = value,
    );
  }

  Widget _buildRoadField() {
    return TextFormField(
      initialValue: _road,
      decoration: const InputDecoration(
        labelText: 'Road (Optional)',
        border: OutlineInputBorder(),
      ),
      onChanged: (value) => _road = value.isEmpty ? null : value,
    );
  }

  Widget _buildBuildingField() {
    return TextFormField(
      initialValue: _building,
      decoration: const InputDecoration(
        labelText: 'Building *',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a building';
        }
        return null;
      },
      onChanged: (value) => _building = value,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading.value ? null : _saveAddress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() => Text(
            _isEditing.value ? 'Update Address' : 'Add Address',
            style: const TextStyle(fontSize: 16),
          )),
        ),
      ),
    );
  }
} 