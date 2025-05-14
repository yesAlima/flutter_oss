import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'categories';

  Stream<List<CategoryModel>> getCategories() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc))
            .toList());
  }

  Future<void> createCategory({
    required String name,
    required String description,
    String? imageUrl,
  }) async {
    try {
      await _firestore.collection(_collection).add({
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateCategory(String id, CategoryModel category) async {
    try {
      await _firestore.collection(_collection).doc(id).update(category.toMap());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        final category = CategoryModel.fromFirestore(doc);
        if (category.imageUrl != null && category.imageUrl!.isNotEmpty) {
          await FirebaseStorage.instance.refFromURL(category.imageUrl!).delete();
        }
      }
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }

  Future<CategoryModel?> getCategoryById(String id) async {
    try {
      final doc = await _firestore.collection('categories').doc(id).get();
      if (!doc.exists) return null;
      final category = CategoryModel.fromFirestore(doc);
      return category;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> addCategory(CategoryModel category) async {
    try {
      await _firestore.collection('categories').add(category.toMap());
    } catch (e) {
      rethrow;
    }
  }
} 