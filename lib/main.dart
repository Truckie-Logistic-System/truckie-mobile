import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_routes.dart';
import 'app/di/service_locator.dart';
import 'core/services/hot_reload_helper.dart';
import 'core/services/vietmap_service.dart';
import 'presentation/common_widgets/vietmap/vietmap_viewmodel.dart';
import 'presentation/features/auth/index.dart';

void main() async {
  // Đảm bảo binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  debugPrint('🔧 Initializing Hive...');
  await Hive.initFlutter();
  debugPrint('✅ Hive initialized');

  // Reset problematic instances for hot reload
  HotReloadHelper.resetProblematicInstances();

  // Khởi tạo service locator (includes enhanced location services)
  debugPrint('🔧 Setting up service locator...');
  await setupServiceLocator();
  // debugPrint('✅ Service locator setup complete');

  // NOTE: Recovery features removed as part of architecture simplification
  // GlobalLocationManager now handles all location tracking directly
  // debugPrint('ℹ️ Location tracking will be managed by GlobalLocationManager');

  // Đặt navigatorKey cho AuthViewModel
  AuthViewModel.setNavigatorKey(navigatorKey);

  // Token refresh callback is now handled in ApiClient via interceptor

  runApp(const MyApp());
}

// GlobalKey để điều hướng mà không cần context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // Adjust design size to match your design
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      // Use builder with context to ensure proper initialization
      builder: (context, child) {
        return MultiProvider(
          providers: [
            // Create a new AuthViewModel instance each time
            ChangeNotifierProvider<AuthViewModel>(
              create: (_) => getIt<AuthViewModel>(),
              // Don't dispose the ViewModel when the provider is disposed
              // This prevents errors during hot reload
              lazy: false,
            ),
            // Provide VietMapService
            Provider<VietMapService>(
              create: (_) => getIt<VietMapService>(),
              lazy: false,
            ),
            // Provide VietMapViewModel
            ChangeNotifierProvider<VietMapViewModel>(
              create: (context) => VietMapViewModel(
                vietMapService: context.read<VietMapService>(),
              ),
              lazy: false,
            ),
          ],
          child: TruckieApp(navigatorKey: navigatorKey),
        );
      },
    );
  }
}
