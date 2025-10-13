import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_routes.dart';
import 'core/services/hot_reload_helper.dart';
import 'core/services/index.dart';
import 'core/services/vietmap_service.dart';
import 'core/services/integrated_location_service.dart';
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
  debugPrint('✅ Service locator setup complete');

  // Attempt to recover location tracking if app was killed during tracking
  debugPrint('🔄 Checking for location tracking recovery...');
  try {
    final wasTrackingActive = await IntegratedLocationService.instance
        .wasTrackingActiveBeforeKill();
    if (wasTrackingActive) {
      debugPrint(
        '📍 Previous tracking session detected, attempting recovery...',
      );
      final recovered = await IntegratedLocationService.instance
          .attemptRecovery();
      if (recovered) {
        debugPrint('✅ Location tracking recovered successfully');

        // Process background location queue
        await IntegratedLocationService.instance
            .processBackgroundLocationQueue();
      } else {
        debugPrint('⚠️ Location tracking recovery failed');
      }
    } else {
      debugPrint('ℹ️ No previous tracking session to recover');

      // Still process background queue in case there are pending locations
      await IntegratedLocationService.instance.processBackgroundLocationQueue();
    }
  } catch (e) {
    debugPrint('❌ Error during recovery check: $e');
  }

  // Đặt navigatorKey cho AuthViewModel
  AuthViewModel.setNavigatorKey(navigatorKey);

  // Đăng ký callback khi refresh token thất bại
  ApiService.setTokenRefreshFailedCallback(() {
    // Sử dụng GlobalKey<NavigatorState> để điều hướng mà không cần context
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  });

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
