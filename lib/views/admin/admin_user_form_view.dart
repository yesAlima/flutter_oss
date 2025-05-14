import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

class AdminUserFormView extends StatefulWidget {
  const AdminUserFormView({Key? key}) : super(key: key);

  @override
  State<AdminUserFormView> createState() => _AdminUserFormViewState();
}

class _AdminUserFormViewState extends State<AdminUserFormView> with SingleTickerProviderStateMixin {
  final _userService = Get.find<UserService>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final RxBool _isLoading = false.obs;
  final RxBool _isEditing = false.obs;
  String? _userId;
  final Rx<String> _selectedRole = 'supplier'.obs;
  final RxBool _isActive = true.obs;
  late final AnimationController _loadingController;
  
  // Add password visibility states
  final RxBool _showPassword = false.obs;
  final RxBool _showConfirmPassword = false.obs;
  final RxBool _showNewPassword = false.obs;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _userId = Get.arguments as String?;
    if (_userId != null) {
      _loadUser();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordController.dispose();
    _phoneController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    _isLoading.value = true;
    try {
      final user = await _userService.getUser(_userId!);
      if (user != null) {
        _nameController.text = user.name;
        _emailController.text = user.email;
        _selectedRole.value = user.role;
        _isActive.value = user.isActive;
        _isEditing.value = true;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load user: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _resetUserPassword(String id, String newPassword) async {
    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('adminSetUserPassword');
      await callable.call(<String, dynamic>{
        'uid': id,
        'newPassword': newPassword,
      });
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      final user = UserModel(
        id: _userId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        email: _emailController.text,
        name: _nameController.text,
        role: _selectedRole.value,
        isActive: _isActive.value,
        phone: _phoneController.text,
      );

      if (_isEditing.value) {
        await _userService.updateUser(_userId!, user);
        if (_newPasswordController.text.isNotEmpty) {
          await _resetUserPassword(_userId!, _newPasswordController.text);
        }
      } else {
        await _userService.createUser(user, _passwordController.text);
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'User ${_isEditing.value ? 'updated' : 'added'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save user: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_isEditing.value ? 'Edit User' : 'Add User')),
      ),
      body: Obx(() => _isLoading.value
          ? _buildLoadingIndicator()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'User Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a name';
                                }
                                return null;
                              },
                            ),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                }
                                if (!GetUtils.isEmail(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                                hintText: '3XXXXXXX or 6XXXXXXX',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a phone number';
                                }
                                if (!RegExp(r'^[36]\d{7}$').hasMatch(value)) {
                                  return 'Phone number must be 8 digits starting with 3 or 6';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Authentication',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!_isEditing.value) ...[
                              TextFormField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: Obx(() => IconButton(
                                    icon: Icon(
                                      _showPassword.value ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () => _showPassword.value = !_showPassword.value,
                                  )),
                                ),
                                obscureText: !_showPassword.value,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: Obx(() => IconButton(
                                    icon: Icon(
                                      _showConfirmPassword.value ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () => _showConfirmPassword.value = !_showConfirmPassword.value,
                                  )),
                                ),
                                obscureText: !_showConfirmPassword.value,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                            ] else ...[
                              TextFormField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'New Password (leave empty to keep current)',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: Obx(() => IconButton(
                                    icon: Icon(
                                      _showNewPassword.value ? Icons.visibility_off : Icons.visibility,
                                    ),
                                    onPressed: () => _showNewPassword.value = !_showNewPassword.value,
                                  )),
                                ),
                                obscureText: !_showNewPassword.value,
                                validator: (value) {
                                  if (value != null && value.isNotEmpty && value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Role & Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            buildRoleToggle(context),
                            const SizedBox(height: 16),
                            Obx(() => SwitchListTile(
                              title: const Text('Active'),
                              value: _isActive.value,
                              onChanged: (value) => _isActive.value = value,
                              activeColor: Theme.of(context).primaryColor,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading.value ? null : _saveUser,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Obx(() => Text(
                          _isEditing.value ? 'Update User' : 'Add User',
                          style: const TextStyle(fontSize: 16),
                        )),
                      ),
                    ),
                  ],
                ),
              ),
            )),
    );
  }

  Widget buildRoleToggle(BuildContext context) {
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
            final isSupplier = _selectedRole.value == 'supplier';
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
                          onTap: () => _selectedRole.value = 'supplier',
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
                          onTap: () => _selectedRole.value = 'delivery',
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