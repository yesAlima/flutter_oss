import 'package:get/get.dart';
import '../middleware/auth_middleware.dart';
import '../models/user_model.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/profile_view.dart';
import '../views/admin/admin_view.dart';
import '../views/admin/admin_products_view.dart';
import '../views/admin/admin_category_list_view.dart';
import '../views/admin/admin_users_view.dart';
import '../views/admin/admin_user_form_view.dart';
import '../views/admin/admin_product_form_view.dart';
import '../views/admin/admin_category_form_view.dart';
import '../views/admin/admin_analytics_view.dart';
import '../views/admin/admin_export_view.dart';
import '../views/customer/customer_view.dart';
import '../views/customer/customer_cart_view.dart';
import '../views/customer/customer_orders_view.dart';
import '../views/customer/customer_order_details_view.dart';
import '../views/customer/customer_address_list_view.dart';
import '../views/customer/customer_address_form_view.dart';
import '../views/supplier/supplier_view.dart';
import '../views/supplier/supplier_order_details_view.dart';
import '../views/delivery/delivery_view.dart';
import '../views/delivery/delivery_orders_view.dart';
import '../views/delivery/delivery_order_details_view.dart';
import '../views/admin/admin_orders_view.dart';
import '../views/admin/admin_order_details_view.dart';
import '../views/admin/admin_sources_view.dart';
import '../views/admin/admin_source_form_view.dart';
import '../controllers/admin/admin_category_form_controller.dart';
import '../controllers/admin/admin_category_list_controller.dart';
import '../controllers/admin/admin_product_form_controller.dart';
import '../controllers/profile_controller.dart';
import '../controllers/delivery/delivery_orders_controller.dart';
import '../controllers/delivery/delivery_order_details_controller.dart';
import '../controllers/supplier/supplier_order_details_controller.dart';
import '../controllers/customer/customer_products_controller.dart';
import '../controllers/customer/customer_orders_controller.dart';
import '../controllers/customer/customer_order_details_controller.dart';
import '../controllers/customer/customer_cart_controller.dart';
import '../controllers/customer/customer_address_list_controller.dart';
import '../controllers/customer/customer_address_form_controller.dart';
import '../views/import_view.dart';
import '../controllers/import_controller.dart';
import '../controllers/admin/admin_order_details_controller.dart';
import '../controllers/admin/admin_sources_controller.dart';
import '../controllers/admin/admin_source_form_controller.dart';
import '../controllers/admin/admin_analytics_controller.dart';
import '../controllers/admin/admin_export_controller.dart';
import '../controllers/auth/login_controller.dart';
import '../controllers/admin/admin_controller.dart';
import '../controllers/auth/logout_controller.dart';
import '../controllers/admin/admin_users_controller.dart';
import '../controllers/admin/admin_user_form_controller.dart';
import '../controllers/admin/admin_products_controller.dart';
import '../controllers/supplier/supplier_controller.dart';
import '../controllers/supplier/supplier_orders_controller.dart';
import '../controllers/supplier/supplier_products_controller.dart';
import '../controllers/delivery/delivery_controller.dart';
import '../controllers/auth/register_controller.dart';
import '../bindings/admin/admin_orders_binding.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String profile = '/profile';
  static const String admin = '/admin';
  static const String adminProducts = '/admin/products';
  static const String adminProductForm = '/admin/product-form';
  static const String adminUsers = '/admin/users';
  static const String adminUserForm = '/admin/user-form';
  static const String adminCategories = '/admin/categories';
  static const String adminCategoryForm = '/admin/category-form';
  static const String adminAnalytics = '/admin/analytics';
  static const String adminExport = '/admin/export';
  static const String adminOrders = '/admin/orders';
  static const String adminOrderDetails = '/admin/order-details';
  static const String customer = '/customer';
  static const String customerCart = '/customer/cart';
  static const String customerOrders = '/customer/orders';
  static const String customerOrderDetails = '/customer/order-details';
  static const String customerAddresses = '/customer/addresses';
  static const String customerAddressForm = '/customer/address-form';
  static const String supplier = '/supplier';
  static const String supplierOrderDetails = '/supplier/order-details';
  static const String delivery = '/delivery';
  static const String deliveryOrders = '/delivery/orders';
  static const String deliveryOrderDetails = '/delivery/order-details';
  static const String sources = '/admin/sources';
  static const String sourceForm = '/admin/source-form';
  static const String import = '/import';
  static final routes = [
    GetPage(
      name: login,
      page: () => const LoginView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<LoginController>(() => LoginController());
      }),
    ),
    GetPage(
      name: register,
      page: () => const RegisterView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<RegisterController>(() => RegisterController());
      }),
    ),
    GetPage(
      name: profile,
      page: () => const ProfileView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ProfileController>(() => ProfileController());
      }),
      middlewares: [
        AuthMiddleware(
          allowedRoles: [
            UserRole.admin,
            UserRole.supplier,
            UserRole.delivery,
            UserRole.customer,
          ],
        ),
      ],
    ),
    GetPage(
      name: admin,
      page: () => const AdminView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminController>(() => AdminController());
        Get.lazyPut<LogoutController>(() => LogoutController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminProducts,
      page: () => const AdminProductsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminProductsController>(() => AdminProductsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminProductForm,
      page: () => const AdminProductFormView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminProductFormController>(() => AdminProductFormController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminCategories,
      page: () => const AdminCategoryListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminCategoryListController>(() => AdminCategoryListController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminCategoryForm,
      page: () => const AdminCategoryFormView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminCategoryFormController>(() => AdminCategoryFormController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminUsers,
      page: () => const AdminUsersView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminUsersController>(() => AdminUsersController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminUserForm,
      page: () => const AdminUserFormView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminUserFormController>(() => AdminUserFormController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminAnalytics,
      page: () => const AdminAnalyticsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminAnalyticsController>(() => AdminAnalyticsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminExport,
      page: () => const AdminExportView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminExportController>(() => AdminExportController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: sources,
      page: () => const AdminSourcesView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminSourcesController>(() => AdminSourcesController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminOrders,
      page: () => const AdminOrdersView(),
      binding: AdminOrdersBinding(),
    ),
    GetPage(
      name: adminOrderDetails,
      page: () => const AdminOrderDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminOrderDetailsController>(() => AdminOrderDetailsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: sourceForm,
      page: () => const AdminSourceForm(),
      binding: BindingsBuilder(() {
        Get.lazyPut<AdminSourceFormController>(() => AdminSourceFormController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: customer,
      page: () => const CustomerView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerProductsController>(() => CustomerProductsController());
        Get.lazyPut<LogoutController>(() => LogoutController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerCart,
      page: () => const CustomerCartView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerCartController>(() => CustomerCartController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerOrders,
      page: () => const CustomerOrdersView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerOrdersController>(() => CustomerOrdersController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerOrderDetails,
      page: () => const CustomerOrderDetailsView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerOrderDetailsController>(() => CustomerOrderDetailsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerAddresses,
      page: () => const CustomerAddressListView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerAddressListController>(() => CustomerAddressListController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerAddressForm,
      page: () => const CustomerAddressFormView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<CustomerAddressFormController>(() => CustomerAddressFormController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: supplier,
      page: () => const SupplierView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<SupplierController>(() => SupplierController());
        Get.lazyPut<SupplierOrdersController>(() => SupplierOrdersController());
        Get.lazyPut<SupplierProductsController>(() => SupplierProductsController());
        Get.lazyPut<LogoutController>(() => LogoutController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.supplier])],
    ),
    GetPage(
      name: supplierOrderDetails,
      page: () => const SupplierOrderDetailsView(),
      binding: BindingsBuilder(() {
        Get.put(SupplierOrderDetailsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.supplier])],
    ),
    GetPage(
      name: delivery,
      page: () => const DeliveryView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<DeliveryController>(() => DeliveryController());
        Get.lazyPut<DeliveryOrdersController>(() => DeliveryOrdersController());
        Get.lazyPut<LogoutController>(() => LogoutController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
    GetPage(
      name: deliveryOrders,
      page: () => const DeliveryOrdersView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<DeliveryOrdersController>(() => DeliveryOrdersController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
    GetPage(
      name: deliveryOrderDetails,
      page: () => DeliveryOrderDetailsView(orderId: Get.arguments),
      binding: BindingsBuilder(() {
        Get.lazyPut<DeliveryOrderDetailsController>(() => DeliveryOrderDetailsController());
      }),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
    GetPage(
      name: import,
      page: () => const ImportView(),
      binding: BindingsBuilder(() {
        Get.lazyPut<ImportController>(() => ImportController());
      }),
    ),
  ];
} 