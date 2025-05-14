import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toggle_switch/toggle_switch.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../routes/app_routes.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({Key? key}) : super(key: key);

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> with SingleTickerProviderStateMixin {
  final _userService = Get.find<UserService>();
  final _searchController = TextEditingController();
  final Rx<UserRole> _selectedRole = UserRole.supplier.obs;
  final RxList<UserModel> _suppliers = <UserModel>[].obs;
  final RxList<UserModel> _deliveries = <UserModel>[].obs;
  final RxBool _isLoading = true.obs;
  late final AnimationController _loadingController;
  final Map<String, bool> _imageLoadingStates = {};

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    _isLoading.value = true;
    try {
      final users = await _userService.getAllUsers();
      _suppliers.value = users.where((user) => user.role == 'supplier').toList();
      _deliveries.value = users.where((user) => user.role == 'delivery').toList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load users');
    } finally {
      _isLoading.value = false;
    }
  }

  List<UserModel> get _filteredUsers {
    final searchTerm = _searchController.text.toLowerCase();
    final users = _selectedRole.value == UserRole.supplier ? _suppliers : _deliveries;
    return users.where((user) {
      final email = user.email.toLowerCase();
      return email.contains(searchTerm);
    }).toList();
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

  Widget _buildUserAvatar(String? name, String email) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          name?.isNotEmpty == true ? name![0].toUpperCase() : email[0].toUpperCase(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user?'),
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
      await _userService.deleteUser(userId);
      await _loadUsers();
      Get.snackbar(
        'Success',
        'User deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete user: $e',
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
        title: const Text('Users'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () async {
                await Get.toNamed(AppRoutes.adminUserForm);
                _loadUsers();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add User'),
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
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          buildToggle(context),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(() {
              if (_isLoading.value) {
                return _buildLoadingIndicator();
              }

              final users = _filteredUsers;
              if (users.isEmpty) {
                return const Center(child: Text('No users found'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _buildUserAvatar(null, user.email),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.role == 'supplier' ? 'Supplier' : 'Delivery',
                                  style: TextStyle(
                                    color: user.role == 'supplier'
                                        ? Colors.blue
                                        : Colors.orange,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: true,
                                onChanged: (value) async {
                                },
                                activeColor: Theme.of(context).primaryColor,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () async {
                                      await Get.toNamed(
                                        AppRoutes.adminUserForm,
                                        arguments: user.id,
                                      );
                                      _loadUsers();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUser(user.id),
                                  ),
                                ],
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

  Widget buildToggle(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 260,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          child: Obx(() {
            final isSupplier = _selectedRole.value == UserRole.supplier;
            return Stack(
              children: [
                AnimatedAlign(
                  alignment: isSupplier ? Alignment.centerLeft : Alignment.centerRight,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: 130,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _selectedRole.value = UserRole.supplier,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store,
                                    color: isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Supplier',
                                  style: TextStyle(
                                    color: isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _selectedRole.value = UserRole.delivery,
                          child: Container(
                            height: 44,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping,
                                    color: !isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Delivery',
                                  style: TextStyle(
                                    color: !isSupplier
                                        ? Colors.white
                                        : Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
} 