import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../services/product_service.dart';
import '../../controllers/category_controller.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminProductFormView extends StatefulWidget {
  const AdminProductFormView({Key? key}) : super(key: key);

  @override
  State<AdminProductFormView> createState() => AdminProductFormViewState();
}

class AdminProductFormViewState extends State<AdminProductFormView> {
  final _productService = Get.find<ProductService>();
  final _categoryController = Get.find<CategoryController>();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _alertController = TextEditingController();
  
  final RxBool _isLoading = false.obs;
  final RxBool _isImageLoading = false.obs;
  final RxBool _isEditing = false.obs;
  final Rx<String?> _imageUrl = Rx<String?>(null);
  final Rx<String?> _pendingImageUrl = Rx<String?>(null);
  final Rx<String?> _oldImageUrl = Rx<String?>(null);
  final Rx<String?> _categoryId = Rx<String?>(null);
  final RxBool _isActive = true.obs;
  final RxList<CategoryModel> _categories = <CategoryModel>[].obs;
  String? _productId;

  @override
  void initState() {
    super.initState();
    _productId = Get.arguments as String?;
    _loadCategories();
    if (_productId != null) {
      _loadProduct();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _alertController.dispose();
    // Clean up any pending images if the form is closed without saving
    if (_pendingImageUrl.value != null) {
      _cleanupPendingImage();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      _categoryController.getCategories().listen((categories) {
        _categories.value = categories;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load categories: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _loadProduct() async {
    _isLoading.value = true;
    try {
      final product = await _productService.getProductById(_productId!);
      _nameController.text = product.name;
      _descriptionController.text = product.description;
      _priceController.text = product.price.toStringAsFixed(3);
      _stockController.text = product.stock.toString();
      _alertController.text = product.alert?.toString() ?? '';
      _categoryId.value = product.categoryId;
      _isActive.value = product.isActive;
      _imageUrl.value = product.imageUrl;
      _oldImageUrl.value = product.imageUrl;
      _isEditing.value = true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load product: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> _cleanupOldImage() async {
    if (_oldImageUrl.value != null && _oldImageUrl.value!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(_oldImageUrl.value!).delete();
      } catch (e) {
        print('Error cleaning up old image: $e');
      }
    }
  }

  Future<void> _cleanupPendingImage() async {
    if (_pendingImageUrl.value != null && _pendingImageUrl.value!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(_pendingImageUrl.value!).delete();
      } catch (e) {
        print('Error cleaning up pending image: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      _isImageLoading.value = true;
      try {
        // If we're editing and have an existing image, store it for cleanup
        if (_isEditing.value && _imageUrl.value != null && _oldImageUrl.value == null) {
          _oldImageUrl.value = _imageUrl.value;
        }
        
        // Clean up any pending image first
        await _cleanupPendingImage();
        
        final ref = FirebaseStorage.instance
            .ref()
            .child('product_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}');
        
        // Upload the image data
        final uploadTask = await ref.putData(
          await image.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'),
        );
        
        // Get the download URL
        final url = await uploadTask.ref.getDownloadURL();
        
        // Update both the display URL and pending URL
        _pendingImageUrl.value = url;
        _imageUrl.value = url;
      } catch (e) {
        debugPrint('Error uploading image: $e');
        Get.snackbar(
          'Error',
          'Failed to upload image: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        _isImageLoading.value = false;
      }
    }
  }

  Future<void> _removeImage() async {
    if (_imageUrl.value == null || _imageUrl.value!.isEmpty) return;
    
    _isImageLoading.value = true;
    try {
      // If we're editing and have an existing image, store it for cleanup
      if (_isEditing.value && _oldImageUrl.value == null) {
        _oldImageUrl.value = _imageUrl.value;
      }
      
      // Clean up any pending image
      await _cleanupPendingImage();
      
      _imageUrl.value = null;
      _pendingImageUrl.value = null;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove image: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isImageLoading.value = false;
    }
  }

  Future<bool> _isProductNameUnique(String name) async {
    final allProducts = await _productService.exportProducts();
    final lowerName = name.trim().toLowerCase();
    return !allProducts.any((p) =>
      p.name.trim().toLowerCase() == lowerName &&
      (!_isEditing.value || p.id != _productId)
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      final isUnique = await _isProductNameUnique(_nameController.text);
      if (!isUnique) {
        _isLoading.value = false;
        Get.snackbar(
          'Error',
          'A product with this name already exists.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // If we're editing and the image was removed, clean up the old image
      if (_isEditing.value && _oldImageUrl.value != null && _imageUrl.value == null) {
        await _cleanupOldImage();
      }

      final alertStock = _alertController.text.isNotEmpty ? int.tryParse(_alertController.text) : null;
      final product = ProductModel(
        id: _productId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        alert: alertStock,
        categoryId: _categoryId.value,
        imageUrl: _imageUrl.value,
        isActive: _isActive.value,
      );

      if (_isEditing.value) {
        await _productService.updateProduct(_productId!, product);
      } else {
        await _productService.addProduct(product);
      }

      // Clear all image states after successful save
      _pendingImageUrl.value = null;
      _oldImageUrl.value = null;

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Product ${_isEditing.value ? 'updated' : 'added'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error saving product: $e');
      Get.snackbar(
        'Error',
        'Failed to save product: $e',
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
        title: Obx(() => Text(_isEditing.value ? 'Edit Product' : 'Add Product')),
      ),
      body: buildBody(),
    );
  }

  Widget buildBody() {
    return Obx(() => _isLoading.value
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  _buildNameField(),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildPriceField(),
                  const SizedBox(height: 16),
                  _buildStockField(),
                  const SizedBox(height: 16),
                  _buildAlertStockField(),
                  const SizedBox(height: 16),
                  _buildCategoryField(),
                  const SizedBox(height: 16),
                  _buildActiveSwitch(),
                  const SizedBox(height: 16),
                  _buildSaveButton(),
                ],
              ),
            ),
          ));
  }

  Widget _buildImagePicker() {
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
                Obx(() => _imageUrl.value != null && _imageUrl.value!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _imageUrl.value!,
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
                Obx(() => _isImageLoading.value
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
                onPressed: _isImageLoading.value ? null : _pickImage,
                icon: const Icon(Icons.image),
                label: const Text('Pick Image'),
              ),
              Obx(() => _imageUrl.value != null && _imageUrl.value!.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: ElevatedButton.icon(
                        onPressed: _isImageLoading.value ? null : _removeImage,
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

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
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
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      decoration: const InputDecoration(
        labelText: 'Price',
        border: OutlineInputBorder(),
        suffixText: 'BD',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a price';
        }
        if (double.tryParse(value) == null) {
          return 'Please enter a valid price';
        }
        return null;
      },
    );
  }

  Widget _buildStockField() {
    return TextFormField(
      controller: _stockController,
      decoration: const InputDecoration(
        labelText: 'Stock',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter stock quantity';
        }
        if (int.tryParse(value) == null) {
          return 'Please enter a valid quantity';
        }
        return null;
      },
    );
  }

  Widget _buildAlertStockField() {
    return TextFormField(
      controller: _alertController,
      decoration: const InputDecoration(
        labelText: 'Alert Stock',
        hintText: 'Enter alert stock',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildCategoryField() {
    if (_categoryId.value == null || _categoryId.value!.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showCategoryPicker,
          icon: const Icon(Icons.category),
          label: const Text('Select Category'),
        ),
      );
    } else {
      final selectedCat = _categories.value.firstWhere(
        (cat) => cat.id == _categoryId.value,
        orElse: () => CategoryModel(
          id: '',
          name: 'Unknown',
          description: '',
        ),
      );
      return Card(
        elevation: 1,
        child: InkWell(
          onTap: _showCategoryPicker,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (selectedCat.imageUrl != null && selectedCat.imageUrl!.isNotEmpty)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: selectedCat.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedCat.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (selectedCat.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedCat.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () {
                    setState(() => _categoryId.value = null);
                  },
                  tooltip: 'Deselect Category',
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showCategoryPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    return InkWell(
                      onTap: () => Navigator.pop(context, category.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _categoryId.value == category.id
                                ? Theme.of(context).primaryColor
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              flex: 3,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                                child: category.imageUrl != null && category.imageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: category.imageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        placeholder: (context, url) => Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Theme.of(context).primaryColor,
                                            ),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) => Icon(
                                          Icons.category,
                                          size: 24,
                                          color: Colors.grey[400],
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.category,
                                          size: 24,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    category.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _categoryId.value == category.id
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: _categoryId.value == category.id
                                          ? Theme.of(context).primaryColor
                                          : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      setState(() => _categoryId.value = selected);
    }
  }

  Widget _buildActiveSwitch() {
    return SwitchListTile(
      title: const Text('Active'),
      subtitle: const Text('Make this product visible to customers'),
      value: _isActive.value,
      onChanged: (value) {
        setState(() {
          _isActive.value = value;
        });
      },
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading.value ? null : _saveProduct,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _isEditing.value ? 'Update Product' : 'Add Product',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  ProductModel? get currentProduct {
    if (_isEditing.value && _productId != null) {
      return ProductModel(
        id: _productId!,
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        stock: int.tryParse(_stockController.text) ?? 0,
        alert: _alertController.text.isNotEmpty ? int.tryParse(_alertController.text) : null,
        categoryId: _categoryId.value,
        imageUrl: _imageUrl.value,
        isActive: _isActive.value,
      );
    }
    return null;
  }
} 