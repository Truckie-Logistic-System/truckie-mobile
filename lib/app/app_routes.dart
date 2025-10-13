import 'package:flutter/material.dart';

import '../core/utils/responsive_size_utils.dart';
import '../domain/entities/driver.dart';
import '../domain/entities/order_with_details.dart';
import '../presentation/features/account/screens/account_screen.dart';
import '../presentation/features/account/screens/change_password_screen.dart';
import '../presentation/features/account/screens/edit_driver_info_screen.dart';
import '../presentation/features/auth/screens/login_screen.dart';
import '../presentation/features/delivery/screens/active_delivery_screen.dart';
import '../presentation/features/delivery/screens/delivery_map_screen.dart';
import '../presentation/features/delivery/screens/navigation_screen.dart';
import '../presentation/features/home/screens/home_screen.dart';
import '../presentation/features/location_tracking/screens/driver_location_screen.dart';
import '../presentation/features/location_tracking/screens/websocket_test_screen.dart';
import '../presentation/features/main/screens/main_screen.dart';
import '../presentation/features/orders/screens/order_detail_screen.dart';
import '../presentation/features/orders/screens/orders_screen.dart';
import '../presentation/features/orders/screens/pre_delivery_documentation_screen.dart';
import '../presentation/features/orders/screens/route_details_screen.dart';
import '../presentation/features/orders/viewmodels/order_detail_viewmodel.dart';
import '../presentation/features/splash/screens/splash_screen.dart';

class AppRoutes {
  // Route names
  static const String root = '/';
  static const String splash = '/splash';
  static const String login = '/login';
  static const String main = '/main';
  static const String home = '/home';
  static const String orders = '/orders';
  static const String account = '/account';
  static const String editDriverInfo = '/edit-driver-info';
  static const String changePassword = '/change-password';
  static const String orderDetail = '/order-detail';
  static const String activeDelivery = '/active-delivery';
  static const String deliveryMap = '/delivery-map';
  static const String preDeliveryDocumentation = '/pre-delivery-documentation';
  static const String driverLocation = '/driver-location';
  static const String websocketTest = '/websocket-test';
  static const String routeDetails = '/route-details';
  static const String navigation = '/navigation';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case root:
      case splash:
        return MaterialPageRoute(
          builder: (_) => const ResponsiveWrapper(child: SplashScreen()),
        );

      case main:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResponsiveWrapper(child: MainScreen()),
        );

      case home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResponsiveWrapper(child: HomeScreen()),
        );

      case orders:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResponsiveWrapper(child: OrdersScreen()),
        );

      case account:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const ResponsiveWrapper(child: AccountScreen()),
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const ResponsiveWrapper(child: LoginScreen()),
        );

      case editDriverInfo:
        final Driver driver = settings.arguments as Driver;
        return MaterialPageRoute(
          builder: (_) =>
              ResponsiveWrapper(child: EditDriverInfoScreen(driver: driver)),
        );

      case changePassword:
        return MaterialPageRoute(
          builder: (_) =>
              const ResponsiveWrapper(child: ChangePasswordScreen()),
        );

      case orderDetail:
        final String orderId = settings.arguments as String;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) =>
              ResponsiveWrapper(child: OrderDetailScreen(orderId: orderId)),
        );

      case activeDelivery:
        return MaterialPageRoute(
          builder: (_) =>
              const ResponsiveWrapper(child: ActiveDeliveryScreen()),
        );

      case deliveryMap:
        final String deliveryId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: DeliveryMapScreen(deliveryId: deliveryId),
          ),
        );

      case preDeliveryDocumentation:
        final OrderWithDetails order = settings.arguments as OrderWithDetails;
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: PreDeliveryDocumentationScreen(order: order),
          ),
        );

      case routeDetails:
        final OrderDetailViewModel viewModel =
            settings.arguments as OrderDetailViewModel;
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: RouteDetailsScreen(viewModel: viewModel),
          ),
        );

      case navigation:
        final Map<String, dynamic> args =
            settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: NavigationScreen(
              orderId: args['orderId'] as String,
              isSimulationMode: args['isSimulationMode'] as bool? ?? false,
            ),
          ),
        );

      case driverLocation:
        final Map<String, dynamic> args =
            settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: DriverLocationScreen(
              vehicleId: args['vehicleId'] as String,
              licensePlateNumber: args['licensePlateNumber'] as String,
              jwtToken: args['jwtToken'] as String,
            ),
          ),
        );

      case websocketTest:
        return MaterialPageRoute(
          builder: (_) => const ResponsiveWrapper(child: WebSocketTestScreen()),
        );

      default:
        // Nếu route không được định nghĩa, trả về màn hình lỗi
        return MaterialPageRoute(
          builder: (_) => ResponsiveWrapper(
            child: Scaffold(
              body: Center(
                child: Text('Không tìm thấy trang: ${settings.name}'),
              ),
            ),
          ),
        );
    }
  }
}

/// Wrapper để khởi tạo ResponsiveSizeUtils cho mọi màn hình
class ResponsiveWrapper extends StatelessWidget {
  final Widget child;

  const ResponsiveWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Khởi tạo ResponsiveSizeUtils
    ResponsiveSizeUtils().init(context);
    return child;
  }
}
