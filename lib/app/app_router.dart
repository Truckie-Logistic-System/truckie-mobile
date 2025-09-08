import 'package:flutter/material.dart';

import '../domain/entities/driver.dart';
import '../presentation/features/account/screens/account_screen.dart';
import '../presentation/features/account/screens/edit_driver_info_screen.dart';
import '../presentation/features/auth/screens/login_screen.dart';
import '../presentation/features/delivery/screens/active_delivery_screen.dart';
import '../presentation/features/delivery/screens/delivery_map_screen.dart';
import '../presentation/features/home/screens/home_screen.dart';
import '../presentation/features/main/screens/main_screen.dart';
import '../presentation/features/orders/screens/order_detail_screen.dart';
import '../presentation/features/orders/screens/orders_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case '/main':
        return MaterialPageRoute(builder: (_) => const MainScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/order-detail':
        final orderId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => OrderDetailScreen(orderId: orderId),
        );
      case '/active-delivery':
        return MaterialPageRoute(builder: (_) => const ActiveDeliveryScreen());
      case '/delivery-map':
        final deliveryId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => DeliveryMapScreen(deliveryId: deliveryId),
        );
      case '/edit-driver-info':
        final driver = settings.arguments as Driver;
        return MaterialPageRoute(
          builder: (_) => EditDriverInfoScreen(driver: driver),
        );
      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Không tìm thấy trang'))),
        );
    }
  }
}
