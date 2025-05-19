import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/customer/customer_address_form_controller.dart';

class CustomerAddressFormView extends GetView<CustomerAddressFormController> {
  const CustomerAddressFormView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(controller.isEditing.value ? 'Edit Address' : 'New Address')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBlockField(),
              const SizedBox(height: 16),
              _buildRoadField(),
              const SizedBox(height: 16),
              _buildBuildingField(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBlockField() {
    return Obx(() => TextFormField(
      initialValue: controller.block.value,
      decoration: const InputDecoration(
        labelText: 'Block *',
        border: OutlineInputBorder(),
      ),
      validator: controller.validateBlock,
      onChanged: controller.setBlock,
    ));
  }

  Widget _buildRoadField() {
    return Obx(() => TextFormField(
      initialValue: controller.road.value,
      decoration: const InputDecoration(
        labelText: 'Road (Optional)',
        border: OutlineInputBorder(),
      ),
      onChanged: controller.setRoad,
    ));
  }

  Widget _buildBuildingField() {
    return Obx(() => TextFormField(
      initialValue: controller.building.value,
      decoration: const InputDecoration(
        labelText: 'Building *',
        border: OutlineInputBorder(),
      ),
      validator: controller.validateBuilding,
      onChanged: controller.setBuilding,
    ));
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: Obx(() => ElevatedButton(
        onPressed: controller.isLoading.value ? null : controller.saveAddress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            controller.isEditing.value ? 'Update Address' : 'Add Address',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      )),
    );
  }
} 