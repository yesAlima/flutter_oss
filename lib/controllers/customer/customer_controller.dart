import 'package:get/get.dart';
import '../../routes/app_routes.dart';

class CustomerController extends GetxController {

  void navigateToCart() {
    Get.toNamed(AppRoutes.customerCart);
  }

  void navigateToOrders() {
    Get.toNamed(AppRoutes.customerOrders);
  }

  void navigateToAddresses() {
    Get.toNamed(AppRoutes.customerAddresses);
  }

  void navigateToProfile() {
    Get.toNamed(AppRoutes.profile);
  }
} 