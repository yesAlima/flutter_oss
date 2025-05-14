import 'package:flutter/material.dart';
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
  static final routes = [
    GetPage(
      name: login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: register,
      page: () => const RegisterView(),
    ),
    GetPage(
      name: profile,
      page: () => const ProfileView(),
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
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminProducts,
      page: () => const AdminProductsView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminProductForm,
      page: () => const AdminProductFormView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminCategories,
      page: () => const AdminCategoryListView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminCategoryForm,
      page: () => const AdminCategoryFormView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminUsers,
      page: () => const AdminUsersView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminUserForm,
      page: () => const AdminUserFormView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminAnalytics,
      page: () => const AdminAnalyticsView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminExport,
      page: () => const AdminExportView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: sources,
      page: () => const AdminSourcesView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminOrders,
      page: () => const AdminOrdersView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: adminOrderDetails,
      page: () => AdminOrderDetailsView(orderId: Get.arguments),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: sourceForm,
      page: () => const AdminSourceForm(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.admin])],
    ),
    GetPage(
      name: customer,
      page: () => const CustomerView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerCart,
      page: () => const CustomerCartView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerOrders,
      page: () => const CustomerOrdersView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerOrderDetails,
      page: () => CustomerOrderDetailsView(orderId: Get.arguments),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerAddresses,
      page: () => const CustomerAddressListView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: customerAddressForm,
      page: () => const CustomerAddressFormView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.customer])],
    ),
    GetPage(
      name: supplier,
      page: () => const SupplierView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.supplier])],
    ),
    GetPage(
      name: supplierOrderDetails,
      page: () => SupplierOrderDetailsView(orderId: Get.arguments),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.supplier])],
    ),
    GetPage(
      name: delivery,
      page: () => const DeliveryView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
    GetPage(
      name: deliveryOrders,
      page: () => const DeliveryOrdersView(),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
    GetPage(
      name: deliveryOrderDetails,
      page: () => DeliveryOrderDetailsView(orderId: Get.arguments),
      middlewares: [AuthMiddleware(allowedRoles: [UserRole.delivery])],
    ),
  ];
} 