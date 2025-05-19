import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/category_model.dart';
import '../../services/category_service.dart';

class AdminCategoryListController extends GetxController with GetSingleTickerProviderStateMixin {
  final CategoryService _categoryService = Get.find<CategoryService>();

  final searchController = TextEditingController();
  final categories = <CategoryModel>[].obs;
  final isLoading = true.obs;
  final imageLoadingStates = <String, bool>{}.obs;

  late final AnimationController loadingController;

  @override
  void onInit() {
    super.onInit();
    loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    loadCategories();
  }

  @override
  void onClose() {
    searchController.dispose();
    loadingController.dispose();
    super.onClose();
  }

  Future<void> loadCategories() async {
    isLoading.value = true;
    try {
      final categoriesStream = _categoryService.getCategories();
      categoriesStream.listen((categoryList) {
        categories.value = categoryList;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load categories: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  List<CategoryModel> get filteredCategories {
    final searchTerm = searchController.text.toLowerCase();
    return categories.where((category) {
      final name = category.name.toLowerCase();
      final description = category.description?.toLowerCase() ?? '';
      return name.contains(searchTerm) || description.contains(searchTerm);
    }).toList();
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _categoryService.deleteCategory(id);
      categories.removeWhere((cat) => cat.id == id);
      Get.snackbar(
        'Success',
        'Category deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete category: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void updateCategoryInList(CategoryModel updatedCategory) {
    final index = categories.indexWhere((cat) => cat.id == updatedCategory.id);
    if (index != -1) {
      categories[index] = updatedCategory;
    }
  }

  void setImageLoadingState(String url, bool loading) {
    imageLoadingStates[url] = loading;
  }
} 