import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../../services/auth_service.dart';
import '../../routes/app_routes.dart';
import 'delivery_orders_view.dart';
import '../auth/logout_view.dart';

class DeliveryView extends StatefulWidget {
  const DeliveryView({Key? key}) : super(key: key);

  @override
  State<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<DeliveryView> {
  final _authService = Get.find<AuthService>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Get.toNamed(AppRoutes.profile),
          ),
          const LogoutView(),
        ],
      ),
      body: const DeliveryOrdersView(),
    );
  }
} 