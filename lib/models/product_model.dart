import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final int? alert;
  final String? imageUrl;
  final String? categoryId;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.alert,
    this.imageUrl,
    this.categoryId,
    required this.isActive,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      price: (data['price'] as num).toDouble(),
      stock: data['stock'] ?? 0,
      alert: data['alert'],
      imageUrl: data['imageUrl'],
      categoryId: data['categoryId'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'alert': alert,
      'imageUrl': imageUrl,
      'categoryId': categoryId,
      'isActive': isActive,
    };
  }
} 