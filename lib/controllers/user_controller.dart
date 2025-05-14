import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserController extends GetxController {
  final RxList<UserModel> users = <UserModel>[].obs;
  final RxBool isLoading = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    _loadUsers();
  }
  
  Future<void> _loadUsers() async {
    isLoading.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      users.value = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('users').doc();
    await docRef.set({
      'name': name,
      'email': email,
      'role': role,
      'isActive': true,
    });
    await _loadUsers();
  }
} 