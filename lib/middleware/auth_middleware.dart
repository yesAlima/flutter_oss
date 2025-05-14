import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../routes/app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  final List<UserRole> allowedRoles;
  final String? redirectRoute;
  final AuthService _authService = Get.find<AuthService>();

  AuthMiddleware({
    required this.allowedRoles,
    this.redirectRoute,
  });

  @override
  RouteSettings? redirect(String? route) {
    
    if (!_authService.isInitialized) {
      return const RouteSettings(name: '/login');
    }

    final user = _authService.currentUser;
    if (user == null) {
      return const RouteSettings(name: '/login');
    }

    if (!allowedRoles.contains(UserRole.values.firstWhere((r) => r.toString().split('.').last == user.role))) {
      if (user.role == 'supplier') {
        return const RouteSettings(name: AppRoutes.supplier);
      } else if (user.role == 'delivery') {
        return const RouteSettings(name: AppRoutes.delivery);
      } else if (user.role == 'admin') {
        return const RouteSettings(name: AppRoutes.admin);
      }
      return RouteSettings(
        name: redirectRoute ?? '/',
      );
    }
    return null;
  }

  @override
  Future<GetNavConfig?> redirectDelegate(GetNavConfig route) async {
    
    // Wait for auth service to initialize
    if (!_authService.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      return redirectDelegate(route);
    }

    // If user is not authenticated and trying to access protected route
    if (_authService.currentUser == null && _isProtectedRoute(route.currentPage?.name)) {
      return GetNavConfig.fromRoute(AppRoutes.login);
    }

    // If user is authenticated and trying to access auth route
    if (_authService.currentUser != null && _isAuthRoute(route.currentPage?.name)) {
      final user = _authService.currentUser;
      if (user?.role == 'admin') {
        return GetNavConfig.fromRoute(AppRoutes.admin);
      } else if (user?.role == 'supplier') {
        return GetNavConfig.fromRoute(AppRoutes.supplier);
      } else if (user?.role == 'delivery') {
        return GetNavConfig.fromRoute(AppRoutes.delivery);
      }
      return GetNavConfig.fromRoute(AppRoutes.customer);
    }

    return await super.redirectDelegate(route);
  }

  bool _isProtectedRoute(String? route) {
    if (route == null) return false;
    return ![
      AppRoutes.login,
      AppRoutes.register,
    ].contains(route);
  }

  bool _isAuthRoute(String? route) {
    if (route == null) return false;
    return [
      AppRoutes.login,
      AppRoutes.register,
    ].contains(route);
  }
} 