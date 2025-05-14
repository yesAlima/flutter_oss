import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({Key? key}) : super(key: key);

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final AuthService _authService = Get.find<AuthService>();
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _displayNameController;
  late TextEditingController _emailController;
  late TextEditingController _prevPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confPasswordController;
  late TextEditingController _phoneController;
  bool _isEditing = false;
  bool _showPrevPassword = false;
  bool _showNewPassword = false;
  bool _showConfPassword = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(text: _authService.currentUser?.name ?? '');
    _emailController = TextEditingController(text: _authService.currentUser?.email ?? '');
    _phoneController = TextEditingController(text: _authService.currentUser?.phone ?? '');
    _prevPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _confPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _prevPasswordController.dispose();
    _newPasswordController.dispose();
    _confPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final user = _authService.currentUser;
        if (user != null) {
          // Update user profile
          await _userService.updateUser(user.id, UserModel(
            id: user.id,
            email: _emailController.text,
            name: _displayNameController.text,
            role: user.role.toString().split('.').last,
            isActive: user.isActive,
            phone: _phoneController.text,
          ));

          // Update password if provided
          if (_newPasswordController.text.isNotEmpty) {
            await _authService.updatePassword(
              _prevPasswordController.text,
              _newPasswordController.text,
            );
          }

          setState(() {
            _isEditing = false;
            _prevPasswordController.clear();
            _newPasswordController.clear();
            _confPasswordController.clear();
          });

          Get.snackbar(
            'Success',
            'Profile updated successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }
      } catch (e) {
        Get.snackbar(
          'Error',
          'Failed to update profile: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view your profile'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = !_isEditing;
                if (!_isEditing) {
                  _displayNameController.text = user.name;
                  _emailController.text = user.email;
                  _phoneController.text = user.phone;
                  _prevPasswordController.clear();
                  _newPasswordController.clear();
                  _confPasswordController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    user.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
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
                enabled: _isEditing,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  if (!RegExp(r'^[36]\d{7}$').hasMatch(value)) {
                    return 'Phone number must be 8 digits starting with 3 or 6';
                  }
                  return null;
                },
              ),
              if (_isEditing) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _prevPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPrevPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _showPrevPassword = !_showPrevPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showPrevPassword,
                  validator: (value) {
                    if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showNewPassword,
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      if (value != _confPasswordController.text) {
                        return 'Passwords do not match';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _showConfPassword = !_showConfPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: !_showConfPassword,
                  validator: (value) {
                    if (_newPasswordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                      return 'Please confirm your new password';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              // Role card: only show if not CUSTOMER
              if (user.role.toString().split('.').last.toUpperCase() != 'CUSTOMER')
                Card(
                  child: ListTile(
                    title: const Text('Role'),
                    subtitle: Text(user.role.toString().split('.').last.toUpperCase()),
                  ),
                ),
              if (_isEditing) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Save Changes'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 