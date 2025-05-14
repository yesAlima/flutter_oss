import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_oss/services/category_service.dart';
import 'package:flutter_oss/controllers/category_controller.dart';
import 'package:flutter_oss/models/category_model.dart';

void main() {
  late CategoryService categoryService;
  late CategoryController categoryController;

  setUp(() {
    categoryService = CategoryService();
    categoryController = CategoryController();
    Get.put(categoryService);
    Get.put(categoryController);
  });

  tearDown(() {
    Get.reset();
  });

  group('Category Integration Tests', () {
    test('Category list should be updated when new category is created', () async {
      // Arrange
      final now = DateTime.now();
      final newCategory = CategoryModel(
        id: '1',
        name: 'New Category',
        description: 'New Description',
      );

      // Act
      await categoryService.addCategory(newCategory);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for stream to update

      // Assert
      expect(categoryController.categories, isNotEmpty);
      expect(categoryController.categories.first.name, 'New Category');
    });

    test('Category should be updated when modified', () async {
      // Arrange
      final now = DateTime.now();
      final category = CategoryModel(
        id: '1',
        name: 'Original Category',
        description: 'Original Description',
      );
      await categoryService.addCategory(category);

      // Act
      final updatedCategory = CategoryModel(
        id: '1',
        name: 'Updated Category',
        description: 'Updated Description',
      );
      await categoryService.updateCategory(category.id, updatedCategory);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for stream to update

      // Assert
      expect(categoryController.categories.first.name, 'Updated Category');
    });

    test('Category should be removed when deleted', () async {
      // Arrange
      final now = DateTime.now();
      final category = CategoryModel(
        id: '1',
        name: 'Category to Delete',
        description: 'Description',
      );
      await categoryService.addCategory(category);

      // Act
      await categoryService.deleteCategory(category.id);
      await Future.delayed(const Duration(milliseconds: 100)); // Wait for stream to update

      // Assert
      expect(categoryController.categories.where((c) => c.id == category.id), isEmpty);
    });
  });
} 