import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_oss/services/auth_service.dart';
import 'package:flutter_oss/controllers/user_controller.dart';
import 'package:flutter_oss/models/user_model.dart';

void main() {
  late AuthService authService;
  late UserController userController;

  setUp(() {
    authService = AuthService();
    userController = UserController();
    Get.put(authService);
    Get.put(userController);
  });

  tearDown(() {
    Get.reset();
  });

  group('Auth-User Integration Tests', () {
    test('User profile should be updated after successful sign in', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      
      // Act
      final user = await authService.signIn(email, password);
      
      // Assert
      expect(user, isA<UserModel>());
      expect(authService.currentUser, isNotNull);
      expect(authService.currentUser?.email, email);
    });

    test('User should be signed out when auth service signs out', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password123';
      await authService.signIn(email, password);
      
      // Act
      await authService.signOut();
      
      // Assert
      expect(authService.currentUser, isNull);
    });
  });
} 