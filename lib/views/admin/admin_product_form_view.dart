import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/category_model.dart';
import '../../controllers/admin/admin_product_form_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';

class AdminProductFormView extends GetView<AdminProductFormController> {
  const AdminProductFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.isEditing.value ? 'Edit Product' : 'New Product')),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSection(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                    suffixText: ' BD',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'Please enter a valid price';
                    }
                    if (RegExp(r'^\d*\.?\d{0,3}').hasMatch(value) == false) {
                      return 'Up to 3 decimal places allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter stock quantity';
                    }
                    final stock = int.tryParse(value);
                    if (stock == null || stock < 0) {
                      return 'Please enter a valid stock quantity';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller.alertController,
                  decoration: const InputDecoration(
                    labelText: 'Alert Stock (Optional)',
                    hintText: 'Enter alert stock',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 16),
                _buildCategoryField(),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: controller.isActive.value,
                  onChanged: (value) => controller.isActive.value = value,
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: controller.isLoading.value ? null : controller.saveProduct,
                    child: Obx(() => Text(
                      controller.isEditing.value ? 'Update Product' : 'Create Product',
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

  Widget _buildImageSection() {
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

  Widget _buildCategoryField() {
    return Obx(() {
      if (controller.categoryId.value == null || controller.categoryId.value!.isEmpty) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _showCategoryPicker,
            icon: const Icon(Icons.category),
            label: const Text('Select Category'),
          ),
        );
      } else {
        final selectedCat = controller.categories.firstWhere(
          (cat) => cat.id == controller.categoryId.value,
          orElse: () => CategoryModel(
            id: '',
            name: 'Unknown',
            description: null,
          ),
        );
        return Card(
          child: ListTile(
            leading: const Icon(Icons.category),
            title: Text(selectedCat.name),
            subtitle: Text(selectedCat.description ?? ''),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showCategoryPicker,
            ),
          ),
        );
      }
    });
  }

  void _showCategoryPicker() {
    showDialog(
      context: Get.context!,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            if (controller.categories.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: controller.categories.length,
              itemBuilder: (context, index) {
                final category = controller.categories[index];
                return ListTile(
                  title: Text(category.name),
                  subtitle: Text(category.description ?? ''),
                  onTap: () {
                    controller.categoryId.value = category.id;
                    Get.back();
                  },
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
} 