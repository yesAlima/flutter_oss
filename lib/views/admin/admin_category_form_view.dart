import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin/admin_category_form_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminCategoryFormView extends GetView<AdminCategoryFormController> {
  const AdminCategoryFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.isEditing.value ? 'Edit Category' : 'New Category')),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImagePicker(context),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: controller.name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: controller.validateName,
                  onChanged: (value) => controller.name = value,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: controller.description,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: controller.validateDescription,
                  onChanged: (value) => controller.description = value,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: controller.isLoading.value ? null : controller.saveCategory,
                    child: Obx(() => Text(
                      controller.isEditing.value ? 'Update Category' : 'Create Category',
                    )),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Obx(() => controller.imageUrl.value != null && controller.imageUrl.value!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: controller.imageUrl.value!,
                          fit: BoxFit.cover,
                          width: 200,
                          height: 200,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          Icons.category,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      )),
                Obx(() => controller.isImageLoading.value
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(128),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : const SizedBox.shrink()),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: controller.isImageLoading.value ? null : controller.pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
              ),
              Obx(() => controller.imageUrl.value != null && controller.imageUrl.value!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: ElevatedButton.icon(
                        onPressed: controller.isImageLoading.value ? null : controller.removeImage,
                        icon: const Icon(Icons.delete),
                        label: const Text('Remove Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
        ],
      ),
    );
  }
} 