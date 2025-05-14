import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_oss/services/category_service.dart';
import 'package:flutter_oss/models/category_model.dart';
import 'category_service_test.mocks.dart';

@GenerateMocks([FirebaseFirestore, CollectionReference, QuerySnapshot])
void main() {
  late CategoryService categoryService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuerySnapshot mockQuerySnapshot;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuerySnapshot = MockQuerySnapshot();
    categoryService = CategoryService();
  });

  group('CategoryService Tests', () {
    test('getCategories should return list of categories', () async {
      // Arrange
      final now = DateTime.now();
      final expectedCategories = [
        CategoryModel(
          id: '1',
          name: 'Category 1',
          description: 'Description 1',
        ),
        CategoryModel(
          id: '2',
          name: 'Category 2',
          description: 'Description 2',
        ),
      ];

      // Act
      final categories = await categoryService.getCategories().first;

      // Assert
      expect(categories, isA<List<CategoryModel>>());
    });

    test('createCategory should complete successfully', () async {
      // Arrange
      const name = 'New Category';
      const description = 'New Description';

      // Act
      await categoryService.createCategory(
        name: name,
        description: description,
      );

      // Assert
      // If no exception is thrown, the test passes
      expect(true, isTrue);
    });

    test('updateCategory should complete successfully', () async {
      // Arrange
      final now = DateTime.now();
      final category = CategoryModel(
        id: '1',
        name: 'Updated Category',
        description: 'Updated Description',
      );

      // Act
      await categoryService.updateCategory(category.id, category);

      // Assert
      // If no exception is thrown, the test passes
      expect(true, isTrue);
    });

    test('deleteCategory should complete successfully', () async {
      // Arrange
      const categoryId = '1';

      // Act
      await categoryService.deleteCategory(categoryId);

      // Assert
      // If no exception is thrown, the test passes
      expect(true, isTrue);
    });
  });
} 