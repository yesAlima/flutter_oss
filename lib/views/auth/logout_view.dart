import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth/logout_controller.dart';

class LogoutView extends GetView<LogoutController> {
  const LogoutView({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      onPressed: controller.handleLogout,
      tooltip: 'Logout',
    );
  }
}