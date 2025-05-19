import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_source_form_controller.dart';

class AdminSourceForm extends GetView<AdminSourceFormController> {
  const AdminSourceForm({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.isEditing.value ? 'Edit Source' : 'New Source')),
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
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildDescriptionField(),
                    const SizedBox(height: 16),
                    _buildSaveButton(),
                  ],
                ),
              ),
            )),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: controller.name,
      decoration: const InputDecoration(
        labelText: 'Name',
        border: OutlineInputBorder(),
      ),
      validator: controller.validateName,
      onChanged: (value) => controller.name = value,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      initialValue: controller.description,
      decoration: const InputDecoration(
        labelText: 'Description (Optional)',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: controller.validateDescription,
      onChanged: (value) => controller.description = value,
    );
  }

  Widget _buildSaveButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: controller.isLoading.value ? null : controller.saveSource,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(Get.context!).primaryColor,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Obx(() => Text(
              controller.isEditing.value ? 'Update Source' : 'Create Source',
              style: const TextStyle(fontSize: 16),
            )),
          ),
        ),
      ],
    );
  }
} 