import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/firestore_service.dart';
import 'services/config_service.dart';
import 'services/category_service.dart';
import 'services/product_service.dart';
import 'services/order_service.dart';
import 'services/source_service.dart';
import 'firebase_options.dart';
import 'controllers/auth_controller.dart';
import 'controllers/category_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/product_controller.dart';
import 'controllers/user_controller.dart';
import 'middleware/auth_middleware.dart';
import 'services/analytics_service.dart';
import 'services/user_service.dart';
import 'services/export_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ConfigService
  await ConfigService.initialize();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set persistence for web
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }
  
  // Create and register services
  final authService = AuthService();
  final storageService = StorageService();
  final firestoreService = FirestoreService();
  final categoryService = CategoryService();
  final productService = ProductService();
  final sourceService = SourceService();
  final analyticsService = AnalyticsService();
  final userService = UserService();
  final exportService = ExportService();
  final orderService = OrderService(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    productService,
    userService,
  );

  // Register services in dependency order
  Get.put<AuthService>(authService, permanent: true);
  Get.put<StorageService>(storageService, permanent: true);
  Get.put<FirestoreService>(firestoreService, permanent: true);
  Get.put<CategoryService>(categoryService, permanent: true);
  Get.put<ProductService>(productService, permanent: true);
  Get.put<SourceService>(sourceService, permanent: true);
  Get.put<AnalyticsService>(analyticsService, permanent: true);
  Get.put<UserService>(userService, permanent: true);
  Get.put<OrderService>(orderService, permanent: true);
  Get.put<ExportService>(exportService, permanent: true);
  // Register controllers after all services are registered
  Get.put(AuthController(), permanent: true);
  Get.put(CategoryController(), permanent: true);
  Get.put(ProductController(), permanent: true);
  Get.put(UserController(), permanent: true);
  Get.put(OrderController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Flutter OSS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.login,
      getPages: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
      routingCallback: (routing) {
        if (routing?.current == AppRoutes.login) {
          Get.find<AuthService>().signOut();
        }
      },
    );
  }
}
