import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_user_form_controller.dart';

class AdminUserFormView extends GetView<AdminUserFormController> {
  const AdminUserFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.isEditing.value ? 'Edit User' : 'Add User')),
      ),
      body: Obx(() => controller.isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: controller.formKey,
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
                              controller: controller.nameController,
                              decoration: const InputDecoration(
                                labelText: 'Name *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
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
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                PhoneNumberFormatter(),
                              ],
                              validator: controller.validatePhone,
                            ),
                            const SizedBox(height: 16),
                            Obx(() => Padding(
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
                                  child: Stack(
                                    children: [
                                      AnimatedAlign(
                                        alignment: controller.selectedRole.value == 'supplier'
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
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
                                                onTap: () => controller.selectedRole.value = 'supplier',
                                                child: Container(
                                                  height: 44,
                                                  alignment: Alignment.center,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.store,
                                                          color: controller.selectedRole.value == 'supplier'
                                                              ? Colors.white
                                                              : Theme.of(context).primaryColor),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Supplier',
                                                        style: TextStyle(
                                                          color: controller.selectedRole.value == 'supplier'
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
                                                onTap: () => controller.selectedRole.value = 'delivery',
                                                child: Container(
                                                  height: 44,
                                                  alignment: Alignment.center,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.local_shipping,
                                                          color: controller.selectedRole.value == 'delivery'
                                                              ? Colors.white
                                                              : Theme.of(context).primaryColor),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'Delivery',
                                                        style: TextStyle(
                                                          color: controller.selectedRole.value == 'delivery'
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
                                  ),
                                ),
                              ),
                            )),
                            const SizedBox(height: 16),
                            Obx(() => SwitchListTile(
                                  title: const Text('Active'),
                                  value: controller.isActive.value,
                                  onChanged: (value) => controller.isActive.value = value,
                                )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!controller.isEditing.value) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Set Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: controller.passwordController,
                                obscureText: !controller.showPassword.value,
                                decoration: const InputDecoration(
                                  labelText: 'Password *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock),
                                  suffixIcon: Icon(Icons.visibility),
                                  hintText: 'At least 8 characters with uppercase, lowercase, number and special character',
                                ),
                                validator: controller.validatePassword,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: controller.confirmPasswordController,
                                obscureText: !controller.showConfirmPassword.value,
                                decoration: const InputDecoration(
                                  labelText: 'Confirm Password *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock),
                                  suffixIcon: Icon(Icons.visibility),
                                ),
                                validator: controller.validateConfirmPassword,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (controller.isEditing.value) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: controller.newPasswordController,
                                obscureText: !controller.showNewPassword.value,
                                decoration: const InputDecoration(
                                  labelText: 'New Password',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.lock),
                                  suffixIcon: Icon(Icons.visibility),
                                  hintText: 'At least 8 characters with uppercase, lowercase, number and special character',
                                ),
                                validator: controller.validateNewPassword,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: controller.saveUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Obx(() => Text(controller.isEditing.value ? 'Update' : 'Add')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )),
    );
  }
} 