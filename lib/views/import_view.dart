import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/import_controller.dart';
import '../models/source_model.dart';
import '../models/order_model.dart';

class ImportView extends GetView<ImportController> {
  final String? productId;
  final String? productName;
  final OrderModel? order;

  const ImportView({
    Key? key,
    this.productId,
    this.productName,
    this.order,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isEditing = order != null;
    if (isEditing && order != null) {
      controller.initializeForEdit(order!);
    }
    return AlertDialog(
      title: Text(isEditing
          ? 'Edit Import Order'
          : 'Import ${productName ?? ''}'),
      content: Form(
        key: controller.formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                if (controller.sources.isEmpty) {
                  return const Text('No sources available. Please add a source first.');
                }
                return DropdownButtonFormField<SourceModel>(
                  value: controller.selectedSource.value,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  items: controller.sources.map((source) {
                    return DropdownMenuItem(
                      value: source,
                      child: Text(source.name),
                    );
                  }).toList(),
                  onChanged: controller.setSource,
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a source';
                    }
                    return null;
                  },
                );
              }),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller.priceController,
                decoration: const InputDecoration(
                  labelText: 'Total Price (BD)',
                  border: OutlineInputBorder(),
                  suffixText: 'BD',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter total price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            controller.clearForm();
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        Obx(() => ElevatedButton(
          onPressed: controller.isLoading.value ? null : () {
            if (controller.validateForm()) {
              if (isEditing && order != null) {
                controller.updateImportOrder(
                  order: order!,
                  quantity: int.parse(controller.quantityController.text),
                  price: double.parse(controller.priceController.text),
                  sourceId: controller.selectedSource.value!.id,
                );
              } else {
                controller.createImportOrder(
                  productId: productId!,
                  quantity: int.parse(controller.quantityController.text),
                  price: double.parse(controller.priceController.text),
                  sourceId: controller.selectedSource.value!.id,
                );
              }
            }
          },
          child: Text(isEditing ? 'Update Import Order' : 'Create Import Order'),
        )),
      ],
    );
  }
} 