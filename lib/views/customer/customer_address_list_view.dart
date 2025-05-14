import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';

class CustomerAddressListView extends StatefulWidget {
  const CustomerAddressListView({super.key});

  @override
  State<CustomerAddressListView> createState() => _CustomerAddressListViewState();
}

class _CustomerAddressListViewState extends State<CustomerAddressListView> {
  final _userService = Get.find<UserService>();
  final _authService = Get.find<AuthService>();
  final RxBool _isLoading = true.obs;
  final RxList<AddressModel> _addresses = <AddressModel>[].obs;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    _isLoading.value = true;
    try {
      final user = _authService.currentUser;
      if (user == null) {
        Get.offAllNamed(AppRoutes.login);
        return;
      }

      final userData = await _userService.getUser(user.id);
      if (userData != null) {
        _addresses.value = userData.addresses;
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load addresses');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _deleteAddress(String id) async {
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
      _loadAddresses();
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete address');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed(AppRoutes.customerAddressForm);
                _loadAddresses();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Address'),
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
      body: Obx(() {
        if (_isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_addresses.isEmpty) {
          return const Center(
            child: Text(
              'No addresses found',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _addresses.length,
          itemBuilder: (context, index) {
            final address = _addresses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Block ${address.block}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (address.road != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Road ${address.road}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Building ${address.building}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            await Get.toNamed(
                              AppRoutes.customerAddressForm,
                              arguments: address,
                            );
                            _loadAddresses();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteAddress(address.id),
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
    );
  }
} 