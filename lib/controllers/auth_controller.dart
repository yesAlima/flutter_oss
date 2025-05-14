import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';

class AuthController extends ChangeNotifier {
  final AuthService _authService = Get.find<AuthService>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  UserModel? _currentUser;
  String? _idToken;
  StreamSubscription<User?>? _authStateSubscription;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get idToken => _idToken;

  AuthController() {
    _initializeAuth();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeAuth() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
    
    // Cancel any existing subscription
    await _authStateSubscription?.cancel();
    
    // Set up new subscription
    _authStateSubscription = _auth.authStateChanges().listen((User? user) async {
      if (user == null) {
        _currentUser = null;
        _idToken = null;
      } else {
        try {
          final doc = await _firestore.collection('users').doc(user.uid).get();
          if (doc.exists) {
            _currentUser = UserModel.fromFirestore(doc);
            _idToken = await user.getIdToken();
          } else {
            _currentUser = null;
            _idToken = null;
            await _auth.signOut();
          }
        } catch (e) {
          debugPrint('Error fetching user data: $e');
          _currentUser = null;
          _idToken = null;
        }
      }
      notifyListeners();
    });
  }

  UserModel? get currentUser => _currentUser;

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _authService.signIn(email, password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    UserRole role = UserRole.customer,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (result.user != null) {
        final user = UserModel(
          id: result.user!.uid,
          email: email,
          name: name,
          role: role.toString().split('.').last,
          isActive: true,
          phone: phone,
        );
        
        await _firestore.collection('users').doc(user.id).set(user.toMap());
        _currentUser = user;
      }
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      await _authService.updatePassword(currentPassword, newPassword);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> isEmailVerified() async {
    try {
      return await _authService.isEmailVerified();
    } catch (e) {
      rethrow;
    }
  }

  bool get isSignedIn => _authService.isSignedIn;
  bool get isAdmin => _authService.isAdmin;
  bool get isSupplier => _authService.isSupplier;
  bool get isDelivery => _authService.isDelivery;
  bool get isCustomer => _authService.isCustomer;
} 