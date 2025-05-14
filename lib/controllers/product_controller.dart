import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductController extends GetxController {
  final RxList<ProductModel> products = <ProductModel>[].obs;
  final RxBool isLoading = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    isLoading.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();
      
      products.value = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required double price,
    required int stock,
    required int minStock,
    required String categoryId,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('products').doc();
    await docRef.set({
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'minStock': minStock,
      'categoryId': categoryId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _loadProducts();
  }
} 