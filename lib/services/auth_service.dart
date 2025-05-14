import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:get/get.dart';
import 'package:web/web.dart' if (dart.library.io) 'dart:io' as platform;
import 'dart:convert';

class AuthService extends GetxService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final Rx<User?> _user = Rx<User?>(null);
  final Rx<UserModel?> _currentUser = Rx<UserModel?>(null);
  final Rx<String?> _idToken = Rx<String?>(null);
  final Rx<bool> _isInitialized = Rx<bool>(false);

  User? get user => _user.value;
  Stream<User?> get userStream => _auth.authStateChanges();
  UserModel? get currentUser => _currentUser.value;
  String? get idToken => _idToken.value;
  bool get isInitialized => _isInitialized.value;

  @override
  void onInit() async {
    super.onInit();
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }
    await _initializeAuth();
    _isInitialized.value = true;
  }

  Future<void> _initializeAuth() async {
    try {
      // Try to restore session from storage
      if (kIsWeb) {
        final storedUser = platform.window.localStorage['currentUser'];
        final storedToken = platform.window.localStorage['idToken'];
        if (storedUser != null && storedToken != null) {
          print('Stored user data: $storedUser');
          try {
            final userData = json.decode(storedUser) as Map<String, dynamic>;
            _currentUser.value = UserModel.fromJson(userData, _auth.currentUser!.uid);
            _idToken.value = storedToken;
            _user.value = _auth.currentUser;
          } catch (e) {
            print('Error decoding stored user data: $e');
            await _clearSession();
          }
        }
      }

      // If no stored session, initialize normally
      _user.value = _auth.currentUser;
      if (_user.value != null) {
        await _refreshSession();
      }

      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) async {
        if (user == null) {
          await _clearSession();
        } else {
          _user.value = user;
          await _refreshSession();
        }
      });
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      await _clearSession();
    }
  }

  Future<void> _refreshSession() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        await _clearSession();
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _currentUser.value = UserModel.fromFirestore(doc);
        _idToken.value = await user.getIdToken(true);
        if (kIsWeb) {
          platform.window.localStorage['currentUser'] = json.encode(_currentUser.value!.toJson());
          platform.window.localStorage['idToken'] = _idToken.value!;
        }
      } else {
        await _clearSession();
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
      await _clearSession();
    }
  }

  Future<void> _clearSession() async {
    _currentUser.value = null;
    _user.value = null;
    _idToken.value = null;
    if (kIsWeb) {
      platform.window.localStorage.removeItem('currentUser');
      platform.window.localStorage.removeItem('idToken');
    }
  }

  Future<UserModel> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Firebase Auth returned null user!');
      }

      // Set the Firebase user immediately
      _user.value = userCredential.user;

      final doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!doc.exists) {
        await _clearSession();
        throw Exception('User not found in Firestore');
      }

      final user = UserModel.fromFirestore(doc);
      if (!user.isActive) {
        await _clearSession();
        throw Exception('User account is inactive');
      }

      _currentUser.value = user;
      _idToken.value = await userCredential.user!.getIdToken(true);
      if (kIsWeb) {
        platform.window.localStorage['currentUser'] = json.encode(user.toJson());
        platform.window.localStorage['idToken'] = _idToken.value!;
      }

      // Listen to auth state changes
      _auth.authStateChanges().listen((User? user) {
        if (user == null) {
          _clearSession();
        } else {
          _user.value = user;
        }
      });

      return user;
    } catch (e) {
      await _clearSession();
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearSession();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  Future<void> updatePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      // Reauthenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.sendEmailVerification();
    } catch (e) {
      throw Exception('Failed to send email verification: $e');
    }
  }

  Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }
      await user.reload();
      return user.emailVerified;
    } catch (e) {
      throw Exception('Failed to check email verification status: $e');
    }
  }

  bool get isSignedIn => _currentUser.value != null;
  bool get isAdmin => _currentUser.value?.isAdmin ?? false;
  bool get isSupplier => _currentUser.value?.isSupplier ?? false;
  bool get isDelivery => _currentUser.value?.isDelivery ?? false;
  bool get isCustomer => _currentUser.value?.isCustomer ?? false;

  bool canManageProducts() => isAdmin || isSupplier;
  bool canManageOrders() => isAdmin || isDelivery;
  bool canManageUsers() => isAdmin;
  bool canManageCategories() => isAdmin;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } catch (e) {
      debugPrint('Error registering: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      await _auth.currentUser?.updateDisplayName(displayName);
      if (photoURL != null) {
        await _auth.currentUser?.updatePhotoURL(photoURL);
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  Future<List<UserModel>> getDeliveryUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'delivery')
          .where('isActive', isEqualTo: true)
          .get();
      
      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting delivery users: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      return null;
    }
  }
} 