import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminCategoryFormView extends StatefulWidget {
  const AdminCategoryFormView({Key? key}) : super(key: key);

  @override
  State<AdminCategoryFormView> createState() => _AdminCategoryFormViewState();
}

class _AdminCategoryFormViewState extends State<AdminCategoryFormView> {
  final _categoryService = Get.find<CategoryService>();
  final _formKey = GlobalKey<FormState>();
  final RxBool _isLoading = false.obs;
  final RxBool _isEditing = false.obs;
  final RxBool _isImageLoading = false.obs;
  String? _categoryId;
  String? _name;
  String? _description;
  final Rx<String?> _imageUrl = Rx<String?>(null);
  final Rx<String?> _pendingImageUrl = Rx<String?>(null);
  final Rx<String?> _oldImageUrl = Rx<String?>(null);

  @override
  void initState() {
    super.initState();
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    final categoryId = Get.arguments as String?;
    if (categoryId == null) return;

    _isLoading.value = true;
    _isEditing.value = true;
    _categoryId = categoryId;

    try {
      final category = await _categoryService.getCategoryById(categoryId);
      if (category != null) {
        setState(() {
          _name = category.name;
          _description = category.description;
          _imageUrl.value = category.imageUrl;
          _oldImageUrl.value = category.imageUrl;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load category: $e',
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
            .child('category_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}');
        
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

  Future<bool> _isCategoryNameUnique(String name) async {
    final allCategories = await _categoryService.getCategories().first;
    final lowerName = name.trim().toLowerCase();
    return !allCategories.any((c) =>
      c.name.trim().toLowerCase() == lowerName &&
      (!_isEditing.value || c.id != _categoryId)
    );
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      final isUnique = await _isCategoryNameUnique(_name!);
      if (!isUnique) {
        _isLoading.value = false;
        Get.snackbar(
          'Error',
          'A category with this name already exists.',
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

      final category = CategoryModel(
        id: _categoryId ?? '',
        name: _name!,
        description: _description!,
        imageUrl: _imageUrl.value,
      );

      if (_isEditing.value) {
        await _categoryService.updateCategory(category.id, category);
      } else {
        await _categoryService.createCategory(
          name: category.name,
          description: category.description,
          imageUrl: category.imageUrl,
        );
      }

      // Clear all image states after successful save
      _pendingImageUrl.value = null;
      _oldImageUrl.value = null;

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Category ${_isEditing.value ? 'updated' : 'created'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error saving category: $e');
      Get.snackbar(
        'Error',
        'Failed to ${_isEditing.value ? 'update' : 'create'} category: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  void dispose() {
    // Clean up any pending images that weren't saved
    if (_pendingImageUrl.value != null) {
      _cleanupPendingImage();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_isEditing.value ? 'Edit Category' : 'New Category')),
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
                    _buildImagePicker(),
                    const SizedBox(height: 16),
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
        onPressed: _isLoading.value ? null : _saveCategory,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Obx(() => Text(
                _isEditing.value ? 'Update Category' : 'Create Category',
            style: const TextStyle(fontSize: 16),
              )),
        ),
      ),
    );
  }
} 