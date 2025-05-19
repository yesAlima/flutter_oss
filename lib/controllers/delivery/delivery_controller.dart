import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class DeliveryController extends GetxController {

  void refreshOrders() {
    update();
  }

  void navigateToProfile() {
    Get.toNamed(AppRoutes.profile);
  }
} 