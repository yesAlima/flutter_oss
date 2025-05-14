import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/order_controller.dart';
import '../../models/source_model.dart';

class AdminSourceForm extends StatefulWidget {
  const AdminSourceForm({Key? key}) : super(key: key);

  @override
  State<AdminSourceForm> createState() => _AdminSourceFormState();
}

class _AdminSourceFormState extends State<AdminSourceForm> {
  final OrderController _orderController = Get.find<OrderController>();
  final _formKey = GlobalKey<FormState>();
  final RxBool _isLoading = false.obs;
  final RxBool _isEditing = false.obs;
  String? _sourceId;
  String? _name;
  String? _description;

  @override
  void initState() {
    super.initState();
    _loadSource();
  }

  Future<void> _loadSource() async {
    final sourceId = Get.arguments as String?;
    if (sourceId == null) return;

    _isLoading.value = true;
    _isEditing.value = true;
    _sourceId = sourceId;

    try {
      // Find the source in the existing sources list
      final source = _orderController.sources.firstWhere(
        (s) => s.id == sourceId,
        orElse: () => throw Exception('Source not found'),
      );
      
      setState(() {
        _name = source.name;
        _description = source.description;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load source: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<bool> _isSourceNameUnique(String name) async {
    final lowerName = name.trim().toLowerCase();
    return !_orderController.sources.any((s) =>
      s.name.trim().toLowerCase() == lowerName &&
      (!_isEditing.value || s.id != _sourceId)
    );
  }

  Future<void> _saveSource() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      final isUnique = await _isSourceNameUnique(_name!);
      if (!isUnique) {
        _isLoading.value = false;
        Get.snackbar(
          'Error',
          'A source with this name already exists.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      if (_isEditing.value) {
        await _orderController.updateSource(
          _sourceId!,
          _name!,
          description: _description,
        );
      } else {
        await _orderController.createSource(
          _name!,
          description: _description,
        );
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Source ${_isEditing.value ? 'updated' : 'created'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error saving source: $e');
      Get.snackbar(
        'Error',
        'Failed to ${_isEditing.value ? 'update' : 'create'} source: $e',
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
        title: Obx(() => Text(_isEditing.value ? 'Edit Source' : 'New Source')),
      ),
      body: Obx(() => _isLoading.value
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
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
      initialValue: _name,
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
      onChanged: (value) => _name = value,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      initialValue: _description,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a description';
        }
        return null;
      },
      onChanged: (value) => _description = value,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading.value ? null : _saveSource,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() => Text(
                _isEditing.value ? 'Update Source' : 'Create Source',
                style: const TextStyle(fontSize: 16),
              )),
        ),
      ),
    );
  }
} 