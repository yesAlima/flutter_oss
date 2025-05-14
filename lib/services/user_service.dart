import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<List<UserModel>> getUsers() {
    return _firestore
        .collection('users')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await _firestore.collection('users').doc(id).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<bool> isEmailUnique(String email, {String? excludeUserId}) async {
    final snapshot = await _firestore.collection('users')
      .where('email', isEqualTo: email.trim().toLowerCase())
      .get();
    if (snapshot.docs.isEmpty) return true;
    if (excludeUserId == null) return false;
    return snapshot.docs.every((doc) => doc.id == excludeUserId);
  }

  Future<void> addUser(UserModel user) async {
    final isUnique = await isEmailUnique(user.email);
    if (!isUnique) {
      throw Exception('A user with this email already exists.');
    }
    await _firestore.collection('users').add(user.toMap());
  }

  Future<void> updateUser(String id, UserModel user) async {
    final isUnique = await isEmailUnique(user.email, excludeUserId: id);
    if (!isUnique) {
      throw Exception('A user with this email already exists.');
    }
    await _firestore.collection('users').doc(id).update(user.toMap());
  }

  Future<void> updateUserStatus(String id, bool isActive) async {
    await _firestore.collection('users').doc(id).update({
      'isActive': isActive,
    });
  }

  Future<void> createUser(UserModel user, String password) async {
    try {
      // 1. Try to create the user in Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: user.email.trim().toLowerCase(),
        password: password,
      );

      // 2. Add the user to Firestore with the Auth UID
      await _firestore.collection('users').doc(credential.user!.uid).set({
        ...user.toMap(),
        'id': credential.user!.uid,
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('A user with this email already exists.');
      }
      throw Exception('Failed to create user: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> updateUserRole(String userId, UserRole role) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'role': role.toString().split('.').last,
      });
    } catch (e) {
      throw Exception('Failed to update user role: $e');
    }
  }

  Stream<List<UserModel>> getUsersByRole(UserRole role) {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: role.toString().split('.').last)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    });
  }

  Stream<List<UserModel>> searchUsers({
    String? name,
    String? email,
    UserRole? role,
    bool? isActive,
  }) {
    Query query = _firestore.collection('users');

    if (name != null && name.isNotEmpty) {
      query = query.where('name', isGreaterThanOrEqualTo: name);
    }

    if (email != null && email.isNotEmpty) {
      query = query.where('email', isGreaterThanOrEqualTo: email);
    }

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);
    }

    return query
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((user) => role == null || user.role == role.toString().split('.').last)
            .toList());
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  Future<List<UserModel>> getAllUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }
} 