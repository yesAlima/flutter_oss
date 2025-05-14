import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class FirestoreService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Generic CRUD operations
  Future<void> createDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(id).set(data);
    } catch (e) {
      debugPrint('Error creating document: $e');
      rethrow;
    }
  }

  Future<DocumentSnapshot> getDocument({
    required String collection,
    required String id,
  }) async {
    try {
      return await _firestore.collection(collection).doc(id).get();
    } catch (e) {
      debugPrint('Error getting document: $e');
      rethrow;
    }
  }

  Future<void> updateDocument({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection(collection).doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating document: $e');
      rethrow;
    }
  }

  Future<void> deleteDocument({
    required String collection,
    required String id,
  }) async {
    try {
      await _firestore.collection(collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting document: $e');
      rethrow;
    }
  }

  // Query operations
  Stream<QuerySnapshot> getCollectionStream({
    required String collection,
    Query Function(Query query)? queryBuilder,
  }) {
    Query query = _firestore.collection(collection);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots();
  }

  Future<QuerySnapshot> getCollection({
    required String collection,
    Query Function(Query query)? queryBuilder,
  }) async {
    try {
      Query query = _firestore.collection(collection);
      if (queryBuilder != null) {
        query = queryBuilder(query);
      }
      return await query.get();
    } catch (e) {
      debugPrint('Error getting collection: $e');
      rethrow;
    }
  }

  // Batch operations
  Future<void> batchCreate({
    required String collection,
    required List<Map<String, dynamic>> dataList,
  }) async {
    try {
      final batch = _firestore.batch();
      for (var data in dataList) {
        final docRef = _firestore.collection(collection).doc();
        batch.set(docRef, data);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error in batch create: $e');
      rethrow;
    }
  }

  Future<void> batchUpdate({
    required String collection,
    required Map<String, Map<String, dynamic>> updates,
  }) async {
    try {
      final batch = _firestore.batch();
      updates.forEach((id, data) {
        final docRef = _firestore.collection(collection).doc(id);
        batch.update(docRef, data);
      });
      await batch.commit();
    } catch (e) {
      debugPrint('Error in batch update: $e');
      rethrow;
    }
  }
} 