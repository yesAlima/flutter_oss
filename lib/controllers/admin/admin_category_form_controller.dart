import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';

class AdminCategoryFormController extends GetxController {
  final CategoryService _categoryService = Get.find<CategoryService>();

  final formKey = GlobalKey<FormState>();
  final isLoading = false.obs;
  final isEditing = false.obs;
  final isImageLoading = false.obs;
  final imageUrl = Rx<String?>(null);
  final pendingImageUrl = Rx<String?>(null);
  final oldImageUrl = Rx<String?>(null);

  String? categoryId;
  String? name;
  String? description;

  @override
  void onInit() {
    super.onInit();
    loadCategory();
  }

  @override
  void onClose() {
    // Clean up any pending images if the form is closed without saving
    if (pendingImageUrl.value != null) {
      cleanupPendingImage();
    }
    super.onClose();
  }

  Future<void> loadCategory() async {
    final id = Get.arguments as String?;
    if (id == null) return;

    isLoading.value = true;
    isEditing.value = true;
    categoryId = id;

    try {
      final category = await _categoryService.getCategoryById(id);
      if (category != null) {
        name = category.name;
        description = category.description;
        imageUrl.value = category.imageUrl;
        oldImageUrl.value = category.imageUrl;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load category: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> cleanupOldImage() async {
    if (oldImageUrl.value != null && oldImageUrl.value!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(oldImageUrl.value!).delete();
      } catch (e) {
        if (e is FirebaseException && e.code == 'object-not-found') {
          // Ignore, file already deleted
        } else {
          debugPrint('Error cleaning up old image: $e');
        }
      }
    }
  }

  Future<void> cleanupPendingImage() async {
    if (pendingImageUrl.value != null && pendingImageUrl.value!.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(pendingImageUrl.value!).delete();
      } catch (e) {
        if (e is FirebaseException && e.code == 'object-not-found') {
          // Ignore, file already deleted
        } else {
          debugPrint('Error cleaning up pending image: $e');
        }
      }
    }
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      isImageLoading.value = true;
      try {
        // If we're editing and have an existing image, store it for cleanup
        if (isEditing.value && imageUrl.value != null && oldImageUrl.value == null) {
          oldImageUrl.value = imageUrl.value;
        }

        // Clean up any pending image first
        await cleanupPendingImage();

        final ref = FirebaseStorage.instance
            .ref()
            .child('category_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}');

        // Upload the image data
        final uploadTask = await ref.putData(
          await image.readAsBytes(),
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // Get the download URL
        final url = await uploadTask.ref.getDownloadURL();

        // Update both the display URL and pending URL
        pendingImageUrl.value = url;
        imageUrl.value = url;
      } catch (e) {
        debugPrint('Error uploading image: $e');
        Get.snackbar(
          'Error',
          'Failed to upload image: $e',
          snackPosition: SnackPosition.BOTTOM,
        );
      } finally {
        isImageLoading.value = false;
      }
    }
  }

  Future<void> removeImage() async {
    if (imageUrl.value == null || imageUrl.value!.isEmpty) return;

    isImageLoading.value = true;
    try {
      // If we're editing and have an existing image, store it for cleanup
      if (isEditing.value && oldImageUrl.value == null) {
        oldImageUrl.value = imageUrl.value;
      }

      // Clean up any pending image
      await cleanupPendingImage();

      imageUrl.value = null;
      pendingImageUrl.value = null;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to remove image: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isImageLoading.value = false;
    }
  }

  Future<bool> isCategoryNameUnique(String name) async {
    final allCategories = await _categoryService.getCategories().first;
    final lowerName = name.trim().toLowerCase();
    return !allCategories.any((c) =>
      c.name.trim().toLowerCase() == lowerName &&
      (!isEditing.value || c.id != categoryId)
    );
  }

  Future<void> saveCategory() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final isUnique = await isCategoryNameUnique(name!);
      if (!isUnique) {
        isLoading.value = false;
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
      if (isEditing.value && oldImageUrl.value != null && imageUrl.value == null) {
        await cleanupOldImage();
      }

      final category = CategoryModel(
        id: categoryId ?? '',
        name: name!,
        description: description,
        imageUrl: imageUrl.value,
      );

      if (isEditing.value) {
        await _categoryService.updateCategory(category.id, category);
      } else {
        await _categoryService.createCategory(
          name: category.name,
          description: category.description,
          imageUrl: category.imageUrl,
        );
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Category ${isEditing.value ? 'updated' : 'created'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save category: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a name';
    }
    return null;
  }

  String? validateDescription(String? value) {
    // Description is optional, so no validation needed
    return null;
  }
} 