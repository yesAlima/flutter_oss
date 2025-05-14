import 'package:cloud_firestore/cloud_firestore.dart';

class SourceModel {
  final String id;
  final String name;
  final String? description;

  SourceModel({
    required this.id,
    required this.name,
    this.description,
  });

  factory SourceModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SourceModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }
} 