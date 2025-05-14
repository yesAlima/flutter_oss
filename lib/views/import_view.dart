import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/order_controller.dart';
import '../models/source_model.dart';
import '../models/order_model.dart';

class ImportView extends StatefulWidget {
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
  State<ImportView> createState() => _ImportViewState();
}

class _ImportViewState extends State<ImportView> {
  final OrderController _orderController = Get.find<OrderController>();
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  SourceModel? _selectedSource;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      // Editing existing import order
      final order = widget.order!;
      if (order.orderlines.isNotEmpty) {
        _quantityController.text = order.orderlines[0].quantity.toString();
        _priceController.text = order.orderlines[0].price?.toString() ?? '';
      }
      if (order.sourceId != null) {
        // Try to pre-select the source if available in controller
        final source = _orderController.sources.firstWhereOrNull((s) => s.id == order.sourceId);
        if (source != null) {
          _selectedSource = source;
        }
      }
    }
  }

  double get _totalPrice {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    return qty * price;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.order != null;
    return AlertDialog(
      title: Text(isEditing
          ? 'Edit Import Order'
          : 'Import ${widget.productName ?? ''}'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                final sources = _orderController.sources;
                if (sources.isEmpty) {
                  return const Text('No sources available. Please add a source first.');
                }
                return DropdownButtonFormField<SourceModel>(
                  value: _selectedSource,
                  decoration: const InputDecoration(
                    labelText: 'Source',
                    border: OutlineInputBorder(),
                  ),
                  items: sources.map((source) {
                    return DropdownMenuItem(
                      value: source,
                      child: Text(source.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSource = value;
                    });
                  },
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
                controller: _quantityController,
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
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
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
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isEditing ? _submitEditForm : _submitForm,
          child: Text(isEditing ? 'Update Import Order' : 'Create Import Order'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedSource == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a source')),
        );
        return;
      }

      _orderController.createImportOrder(
        productId: widget.productId!,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        sourceId: _selectedSource!.id,
      );

      Navigator.of(context).pop();
    }
  }

  void _submitEditForm() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedSource == null || widget.order == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a source')),
        );
        return;
      }
      // Call update method on controller (you need to implement this)
      _orderController.updateImportOrder(
        order: widget.order!,
        quantity: int.parse(_quantityController.text),
        price: double.parse(_priceController.text),
        sourceId: _selectedSource!.id,
      );
      Navigator.of(context).pop();
    }
  }
} 