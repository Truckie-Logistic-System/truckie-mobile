import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/di/service_locator.dart';
import 'core/services/hot_reload_helper.dart';
import 'core/services/notification_service.dart';
import 'core/services/global_dialog_service.dart';
import 'presentation/features/auth/index.dart';

void main() async {
  print('🚀 [Main] main() started at ${DateTime.now()}');
  
  // Đảm bảo binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ [Main] WidgetsFlutterBinding initialized at ${DateTime.now()}');

  // Debug paint disabled - will enable if needed
  // debugPaintSizeEnabled = true; // Requires: import 'package:flutter/rendering.dart';

  // Initialize Hive for offline storage
  print('⏰ [Main] Initializing Hive at ${DateTime.now()}...');
  await Hive.initFlutter();
  print('✅ [Main] Hive initialized at ${DateTime.now()}');
  
  // Reset problematic instances for hot reload
  HotReloadHelper.resetProblematicInstances();

  // Khởi tạo service locator (includes enhanced location services)
  try {
    print('⏰ [Main] Starting setupServiceLocator at ${DateTime.now()}...');
    await setupServiceLocator();
    print('✅ [Main] setupServiceLocator completed at ${DateTime.now()}');
    
    // Verify AuthViewModel is registered
    try {
      print('⏰ [Main] Verifying AuthViewModel registration...');
      final authVM = getIt<AuthViewModel>();
      print('✅ [Main] AuthViewModel verified at ${DateTime.now()}');
    } catch (e) {
      print('❌ [Main] AuthViewModel verification failed: $e');
      rethrow;
    }
  } catch (e) {
    print('❌ [Main] setupServiceLocator failed: $e');
    rethrow;
  }

  // NOTE: Recovery features removed as part of architecture simplification
  // GlobalLocationManager now handles all location tracking directly
  //

  // Token refresh callback is now handled in ApiClient via interceptor

  print('⏰ [Main] About to call runApp() at ${DateTime.now()}...');
  runApp(const MyApp());
  print('✅ [Main] runApp() completed at ${DateTime.now()}');
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
        final notificationService = getIt<NotificationService>();
        final globalDialogService = getIt<GlobalDialogService>();

        // Đặt navigatorKey cho AuthViewModel (sử dụng cùng key với TruckieApp)
        AuthViewModel.setNavigatorKey(navigatorKey);

        // Initialize NotificationService with navigator key
        notificationService.initialize(navigatorKey);
        
        // Initialize GlobalDialogService with navigator key
        globalDialogService.initialize(navigatorKey);

        return TruckieApp(navigatorKey: navigatorKey);
      },
    );
  }
}
