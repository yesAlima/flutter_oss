import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/profile_controller.dart';
import '../services/auth_service.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Get.find<AuthService>().currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view your profile'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: Obx(() => Icon(controller.isEditing.value ? Icons.close : Icons.edit)),
            onPressed: controller.toggleEditing,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: controller.formKey,
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
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: controller.displayNameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        enabled: controller.isEditing.value,
                        validator: controller.validateName,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: controller.emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        enabled: controller.isEditing.value,
                        validator: controller.validateEmail,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: controller.phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '3XXXXXXX or 6XXXXXXX',
                        ),
                        enabled: controller.isEditing.value,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          PhoneNumberFormatter(),
                        ],
                        validator: controller.validatePhone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Obx(() {
                if (!controller.isEditing.value) return const SizedBox.shrink();
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Change Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: controller.prevPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Current Password *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.showPrevPassword.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: controller.togglePrevPasswordVisibility,
                            ),
                          ),
                          obscureText: !controller.showPrevPassword.value,
                          validator: controller.validatePrevPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: controller.newPasswordController,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.showNewPassword.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: controller.toggleNewPasswordVisibility,
                            ),
                            hintText: 'At least 8 characters with uppercase, lowercase, number and special character',
                          ),
                          obscureText: !controller.showNewPassword.value,
                          validator: controller.validateNewPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: controller.confPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                controller.showConfPassword.value
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: controller.toggleConfPasswordVisibility,
                            ),
                          ),
                          obscureText: !controller.showConfPassword.value,
                          validator: controller.validateConfPassword,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              Obx(() {
                if (!controller.isEditing.value) return const SizedBox.shrink();
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
} 