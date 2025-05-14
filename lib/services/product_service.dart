import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'products';

  Stream<List<ProductModel>> getProducts() {
    return _firestore
        .collection(_collection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addProduct(ProductModel product) async {
    await _firestore.collection(_collection).add(product.toMap());
  }

  Future<void> updateProduct(String productId, ProductModel product) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        ...product.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update product: $e');
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection('products').doc(productId).delete();
    } catch (e) {
      throw Exception('Failed to delete product: $e');
    }
  }

  Future<ProductModel?> getProduct(String id) async {
    final doc = await _firestore.collection('products').doc(id).get();
    if (doc.exists) {
      return ProductModel.fromFirestore(doc);
    }
    return null;
  }

  Future<ProductModel> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();
      if (!doc.exists) {
        throw Exception('Product not found');
      }
      return ProductModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get product: $e');
    }
  }

  Future<void> createProduct(ProductModel product) async {
    try {
      await _firestore.collection('products').doc(product.id).set({
        ...product.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to create product: $e');
    }
  }

  Stream<List<ProductModel>> getProductsByCategory(String categoryId) {
    return _firestore
        .collection('products')
        .where('categoryId', isEqualTo: categoryId)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ProductModel>> searchProducts({
    String? name,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    int? minStock,
    int? maxStock,
    bool? isActive,
  }) {
    Query query = _firestore.collection('products');

    if (name != null && name.isNotEmpty) {
      query = query.where('name', isGreaterThanOrEqualTo: name);
    }

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    if (minPrice != null) {
      query = query.where('price', isGreaterThanOrEqualTo: minPrice);
    }

    if (maxPrice != null) {
      query = query.where('price', isLessThanOrEqualTo: maxPrice);
    }

    if (minStock != null) {
      query = query.where('stock', isGreaterThanOrEqualTo: minStock);
    }

    if (maxStock != null) {
      query = query.where('stock', isLessThanOrEqualTo: maxStock);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  Stream<List<ProductModel>> getLowStockProducts(int threshold) {
    return _firestore
        .collection('products')
        .where('stock', isLessThanOrEqualTo: threshold)
        .where('isActive', isEqualTo: true)
        .orderBy('stock')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc))
            .toList());
  }

  Future<void> updateProductStock(String productId, int newStock) async {
    try {
      await _firestore.collection('products').doc(productId).update({
        'stock': newStock,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update product stock: $e');
    }
  }

  Future<void> bulkUpdateProductStatus(List<String> productIds, bool isActive) async {
    try {
      final batch = _firestore.batch();
      for (final productId in productIds) {
        final docRef = _firestore.collection('products').doc(productId);
        batch.update(docRef, {
          'isActive': isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update product status: $e');
    }
  }

  Future<void> bulkUpdateProductStock(List<String> productIds, int stock) async {
    try {
      final batch = _firestore.batch();
      for (final productId in productIds) {
        final docRef = _firestore.collection('products').doc(productId);
        batch.update(docRef, {
          'stock': stock,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to bulk update product stock: $e');
    }
  }

  Future<void> importProducts(List<ProductModel> products) async {
    try {
      final batch = _firestore.batch();
      for (final product in products) {
        final docRef = _firestore.collection('products').doc(product.id);
        batch.set(docRef, {
          ...product.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to import products: $e');
    }
  }

  Future<List<ProductModel>> exportProducts() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to export products: $e');
    }
  }

  Future<void> increaseStock(String productId, int quantity) async {
    try {
      final doc = await _firestore.collection(_collection).doc(productId).get();
      if (!doc.exists) {
        throw Exception('Product not found');
      }

      final currentStock = doc.data()?['stock'] as int? ?? 0;
      await _firestore.collection(_collection).doc(productId).update({
        'stock': currentStock + quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to increase stock: $e');
    }
  }

  Future<void> decreaseStock(String productId, int quantity) async {
    try {
      final doc = await _firestore.collection(_collection).doc(productId).get();
      if (!doc.exists) {
        throw Exception('Product not found');
      }

      final currentStock = doc.data()?['stock'] as int? ?? 0;
      if (currentStock < quantity) {
        throw Exception('Insufficient stock');
      }

      await _firestore.collection(_collection).doc(productId).update({
        'stock': currentStock - quantity,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to decrease stock: $e');
    }
  }
} 