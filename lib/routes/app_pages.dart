import 'package:get/get.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/profile_view.dart';
import '../views/admin/admin_products_view.dart';
import '../views/admin/admin_product_form_view.dart';
import '../views/admin/admin_users_view.dart';
import '../views/admin/admin_user_form_view.dart';
import '../views/admin/admin_category_list_view.dart';
import '../views/admin/admin_category_form_view.dart';
import '../views/customer/customer_view.dart';
import '../views/customer/customer_cart_view.dart';
import '../views/customer/customer_orders_view.dart';
import '../views/customer/customer_order_details_view.dart';
import '../views/delivery/delivery_view.dart';
import '../views/delivery/delivery_orders_view.dart';
import '../views/delivery/delivery_order_details_view.dart';
import '../views/supplier/supplier_view.dart';
import '../views/supplier/supplier_order_details_view.dart';
import '../views/admin/admin_orders_view.dart';
import '../views/admin/admin_order_details_view.dart';
import '../views/admin/admin_sources_view.dart';
import '../views/admin/admin_source_form_view.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = [
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginView(),
    ),
    GetPage(
      name: AppRoutes.register,
      page: () => const RegisterView(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: () => const ProfileView(),
    ),
    GetPage(
      name: AppRoutes.adminProducts,
      page: () => const AdminProductsView(),
    ),
    GetPage(
      name: AppRoutes.adminProductForm,
      page: () => const AdminProductFormView(),
    ),
    GetPage(
      name: AppRoutes.adminUsers,
      page: () => const AdminUsersView(),
    ),
    GetPage(
      name: AppRoutes.adminUserForm,
      page: () => const AdminUserFormView(),
    ),
    GetPage(
      name: AppRoutes.adminCategories,
      page: () => const AdminCategoryListView(),
    ),
    GetPage(
      name: AppRoutes.adminCategoryForm,
      page: () => const AdminCategoryFormView(),
    ),
    GetPage(
      name: AppRoutes.adminOrders,
      page: () => const AdminOrdersView(),
    ),
    GetPage(
      name: AppRoutes.adminOrderDetails,
      page: () => const AdminOrderDetailsView(),
    ),
    GetPage(
      name: AppRoutes.sources,
      page: () => const AdminSourcesView(),
    ),
    GetPage(
      name: AppRoutes.sourceForm,
      page: () => const AdminSourceForm(),
    ),
    GetPage(
      name: AppRoutes.customer,
      page: () => const CustomerView(),
    ),
    GetPage(
      name: AppRoutes.customerCart,
      page: () => const CustomerCartView(),
    ),
    GetPage(
      name: AppRoutes.customerOrders,
      page: () => const CustomerOrdersView(),
    ),
    GetPage(
      name: AppRoutes.customerOrderDetails,
      page: () => const CustomerOrderDetailsView(),
    ),
    GetPage(
      name: AppRoutes.delivery,
      page: () => const DeliveryView(),
    ),
    GetPage(
      name: AppRoutes.deliveryOrders,
      page: () => const DeliveryOrdersView(),
    ),
    GetPage(
      name: AppRoutes.deliveryOrderDetails,
      page: () => DeliveryOrderDetailsView(orderId: Get.arguments),
    ),
    GetPage(
      name: AppRoutes.supplier,
      page: () => const SupplierView(),
    ),
    GetPage(
      name: AppRoutes.supplierOrderDetails,
      page: () => const SupplierOrderDetailsView(),
    ),
  ];
} 