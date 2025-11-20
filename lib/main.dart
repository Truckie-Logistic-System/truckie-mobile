import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_routes.dart';
import 'app/di/service_locator.dart';
import 'core/services/hot_reload_helper.dart';
import 'core/services/vietmap_service.dart';
import 'core/services/notification_service.dart';
import 'presentation/common_widgets/vietmap/vietmap_viewmodel.dart';
import 'presentation/features/auth/index.dart';

void main() async {
  // Đảm bảo binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for offline storage
  await Hive.initFlutter();
  // Reset problematic instances for hot reload
  HotReloadHelper.resetProblematicInstances();

  // Khởi tạo service locator (includes enhanced location services)
  try {
    await setupServiceLocator();
    // Verify AuthViewModel is registered
    try {
      final authVM = getIt<AuthViewModel>();
    } catch (e) {
      rethrow;
    }
  } catch (e) {
    rethrow;
  }

  // NOTE: Recovery features removed as part of architecture simplification
  // GlobalLocationManager now handles all location tracking directly
  // 

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
        // Get instances from service locator (already initialized in main())
        final authViewModel = getIt<AuthViewModel>();
        final vietMapService = getIt<VietMapService>();
        final notificationService = getIt<NotificationService>();
        
        // Đặt navigatorKey cho AuthViewModel (sử dụng cùng key với TruckieApp)
        AuthViewModel.setNavigatorKey(navigatorKey);
        
        // Initialize NotificationService with navigator key
        notificationService.initialize(navigatorKey);
        
        return MultiProvider(
          providers: [
            // AuthViewModel is already a LazySingleton in GetIt
            // Access it directly without creating new instance
            ChangeNotifierProvider<AuthViewModel>.value(
              value: authViewModel,
            ),
            // Provide VietMapService
            Provider<VietMapService>.value(
              value: vietMapService,
            ),
            // Provide VietMapViewModel
            ChangeNotifierProvider<VietMapViewModel>(
              create: (context) => VietMapViewModel(
                vietMapService: context.read<VietMapService>(),
              ),
            ),
          ],
          child: TruckieApp(navigatorKey: navigatorKey),
        );
      },
    );
  }
}
