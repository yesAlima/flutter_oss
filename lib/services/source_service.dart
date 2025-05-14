import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/source_model.dart';

class SourceService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'sources';

  Future<List<SourceModel>> getAllSources() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      return snapshot.docs.map((doc) => SourceModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get sources: $e');
    }
  }

  Future<SourceModel> getSource(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) {
        throw Exception('Source not found');
      }
      return SourceModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get source: $e');
    }
  }

  Future<void> createSource(String name, {String? description}) async {
    try {
      final source = SourceModel(
        id: '',
        name: name,
        description: description,
      );
      await _firestore.collection(_collection).add(source.toMap());
    } catch (e) {
      throw Exception('Failed to create source: $e');
    }
  }

  Future<void> updateSource(String id, String name, {String? description}) async {
    try {
      final source = SourceModel(
        id: id,
        name: name,
        description: description,
      );
      await _firestore.collection(_collection).doc(id).update(source.toMap());
    } catch (e) {
      throw Exception('Failed to update source: $e');
    }
  }

  Future<void> deleteSource(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Failed to delete source: $e');
    }
  }
} 