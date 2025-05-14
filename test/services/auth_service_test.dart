import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_oss/services/auth_service.dart';
import 'package:flutter_oss/models/user_model.dart';
import 'auth_service_test.mocks.dart';

@GenerateMocks([FirebaseAuth, FirebaseFirestore, DocumentSnapshot])
void main() {
  late AuthService authService;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockDocumentSnapshot mockDocSnapshot;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockDocSnapshot = MockDocumentSnapshot();
    authService = AuthService();
  });

  group('AuthService Tests', () {
    test('signIn should return UserModel for valid credentials', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      
      // Act
      final result = await authService.signIn(email, password);
      
      // Assert
      expect(result, isA<UserModel>());
    });

    test('signOut should complete successfully', () async {
      // Act
      await authService.signOut();
      
      // Assert
      expect(authService.currentUser, isNull);
    });

    test('resetPassword should complete successfully', () async {
      // Arrange
      const email = 'test@example.com';
      
      // Act
      await authService.resetPassword(email);
      
      // Assert
      // If no exception is thrown, the test passes
      expect(true, isTrue);
    });
  });
} 