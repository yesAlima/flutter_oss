import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';

class CategoryController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<CategoryModel> categories = <CategoryModel>[].obs;
  final RxBool isLoading = false.obs;
  final CategoryService _categoryService = Get.find<CategoryService>();

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    isLoading.value = true;
    try {
      final snapshot = await _firestore.collection('categories').get();
      categories.value = snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      Get.snackbar('Error', 'Failed to load categories: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Stream<List<CategoryModel>> getCategories() {
    return _firestore.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList();
    });
  }

  Future<void> createCategory({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    isLoading.value = true;
    try {
      await _categoryService.createCategory(
        name: name,
        description: description,
        imageUrl: imageUrl,
      );
      await _loadCategories();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    isLoading.value = true;
    try {
      await _categoryService.updateCategory(category.id, category);
      await _loadCategories();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    isLoading.value = true;
    try {
      await _categoryService.deleteCategory(categoryId);
      await _loadCategories();
    } finally {
      isLoading.value = false;
    }
  }
} 