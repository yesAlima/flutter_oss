import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../services/product_service.dart';
import '../../services/category_service.dart';

class AdminProductFormController extends GetxController {
  final ProductService _productService = Get.find<ProductService>();
  final CategoryService _categoryService = Get.find<CategoryService>();

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final alertController = TextEditingController();

  final isLoading = false.obs;
  final isImageLoading = false.obs;
  final isEditing = false.obs;
  final imageUrl = Rx<String?>(null);
  final pendingImageUrl = Rx<String?>(null);
  final oldImageUrl = Rx<String?>(null);
  final categoryId = Rx<String?>(null);
  final isActive = true.obs;
  final categories = <CategoryModel>[].obs;

  String? productId;

  @override
  void onInit() {
    super.onInit();
    productId = Get.arguments as String?;
    loadCategories();
    if (productId != null) {
      loadProduct();
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    stockController.dispose();
    alertController.dispose();
    // Clean up any pending images if the form is closed without saving
    if (pendingImageUrl.value != null) {
      cleanupPendingImage();
    }
    super.onClose();
  }

  Future<void> loadCategories() async {
    try {
      _categoryService.getCategories().listen((categoryList) {
        categories.value = categoryList;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load categories: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadProduct() async {
    isLoading.value = true;
    try {
      final product = await _productService.getProductById(productId!);
      nameController.text = product.name;
      descriptionController.text = product.description ?? '';
      priceController.text = product.price.toStringAsFixed(3);
      stockController.text = product.stock.toString();
      alertController.text = product.alert?.toString() ?? '';
      categoryId.value = product.categoryId;
      isActive.value = product.isActive;
      imageUrl.value = product.imageUrl;
      oldImageUrl.value = product.imageUrl;
      isEditing.value = true;
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load product: $e',
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
            .child('product_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}');
        
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

  Future<bool> isProductNameUnique(String name) async {
    final allProducts = await _productService.exportProducts();
    final lowerName = name.trim().toLowerCase();
    return !allProducts.any((p) =>
      p.name.trim().toLowerCase() == lowerName &&
      (!isEditing.value || p.id != productId)
    );
  }

  Future<void> saveProduct() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final isUnique = await isProductNameUnique(nameController.text);
      if (!isUnique) {
        isLoading.value = false;
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
      if (isEditing.value && oldImageUrl.value != null && imageUrl.value == null) {
        await cleanupOldImage();
      }

      final product = ProductModel(
        id: productId ?? '',
        name: nameController.text,
        description: descriptionController.text.isEmpty ? null : descriptionController.text,
        price: double.parse(priceController.text),
        stock: int.parse(stockController.text),
        alert: alertController.text.isNotEmpty ? int.parse(alertController.text) : null,
        imageUrl: imageUrl.value,
        categoryId: categoryId.value,
        isActive: isActive.value,
      );

      if (isEditing.value) {
        await _productService.updateProduct(product.id, product);
      } else {
        await _productService.addProduct(product);
      }

      Get.back(result: true);
      Get.snackbar(
        'Success',
        'Product ${isEditing.value ? 'updated' : 'created'} successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save product: $e',
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

  String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a price';
    }
    final price = double.tryParse(value);
    if (price == null || price < 0) {
      return 'Please enter a valid price';
    }
    if (!RegExp(r'^\d*\.?\d{0,3}').hasMatch(value)) {
      return 'Up to 3 decimal places allowed';
    }
    return null;
  }

  String? validateStock(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter stock quantity';
    }
    final stock = int.tryParse(value);
    if (stock == null || stock < 0) {
      return 'Please enter a valid stock quantity';
    }
    return null;
  }

  String? validateAlert(String? value) {
    if (value == null || value.isEmpty) return null;
    final alert = int.tryParse(value);
    if (alert == null || alert < 0) {
      return 'Please enter a valid alert threshold';
    }
    return null;
  }
} 