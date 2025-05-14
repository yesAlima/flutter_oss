import 'package:get/get.dart';
import '../services/analytics_service.dart';

class AnalyticsController extends GetxController {
  final AnalyticsService _analyticsService = Get.find<AnalyticsService>();
  
  final RxDouble totalSales = 0.0.obs;
  final RxInt totalOrders = 0.obs;
  final RxInt totalProducts = 0.obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    isLoading.value = true;
    try {
      totalSales.value = await _analyticsService.getTotalSales();
      totalOrders.value = await _analyticsService.getTotalOrders();
      totalProducts.value = await _analyticsService.getTotalProducts();
    } finally {
      isLoading.value = false;
    }
  }
} 