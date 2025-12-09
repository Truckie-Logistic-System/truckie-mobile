import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../app/di/service_locator.dart';
import '../core/utils/responsive_size_utils.dart';
import '../core/services/chat_notification_service.dart';
import '../core/services/notification_service.dart';
import '../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../presentation/features/notification/viewmodels/notification_viewmodel.dart';
import '../presentation/features/onboarding/viewmodels/driver_onboarding_viewmodel.dart';
import '../presentation/theme/app_theme.dart';
import 'app_routes.dart';

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print('🔄 [AppLifecycleObserver] App lifecycle state changed to: $state');
    
    switch (state) {
      case AppLifecycleState.resumed:
        print('🚀 [AppLifecycleObserver] App resumed - forcing WebSocket reconnect');
        // Force WebSocket reconnect when app resumes to ensure stability
        _forceWebSocketReconnect();
        break;
      case AppLifecycleState.paused:
        print('⏸️ [AppLifecycleObserver] App paused');
        break;
      case AppLifecycleState.detached:
        print('🔌 [AppLifecycleObserver] App detached');
        break;
      case AppLifecycleState.inactive:
        print('😴 [AppLifecycleObserver] App inactive');
        break;
      case AppLifecycleState.hidden:
        print('👁️ [AppLifecycleObserver] App hidden');
        break;
    }
  }
  
  void _forceWebSocketReconnect() {
    try {
      final notificationService = getIt<NotificationService>();
      // Force reconnect to ensure stable connection after resume
      notificationService.forceReconnect();
    } catch (e) {
      print('❌ [AppLifecycleObserver] Failed to force WebSocket reconnect: $e');
    }
  }
}

class TruckieApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const TruckieApp({super.key, required this.navigatorKey});

  @override
  State<TruckieApp> createState() => _TruckieAppState();
}

class _TruckieAppState extends State<TruckieApp> with WidgetsBindingObserver {
  final _AppLifecycleObserver _lifecycleObserver = _AppLifecycleObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    print('✅ [TruckieApp] Lifecycle observer added');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    print('🔌 [TruckieApp] Lifecycle observer removed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize ResponsiveSizeUtils here
    ResponsiveSizeUtils().init(context);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(
          create: (_) => getIt<AuthViewModel>(),
        ),
        ChangeNotifierProvider<NotificationViewModel>(
          create: (_) {
            try {
              print('🔧 [TruckieApp] Creating NotificationViewModel...');
              final vm = getIt<NotificationViewModel>();
              print(
                '✅ [TruckieApp] NotificationViewModel created successfully',
              );
              return vm;
            } catch (e, stackTrace) {
              print(
                '❌ [TruckieApp] Failed to create NotificationViewModel: $e',
              );
              print('❌ [TruckieApp] Stack trace: $stackTrace');
              rethrow;
            }
          },
        ),
        ChangeNotifierProvider<ChatNotificationService>(
          create: (_) => getIt<ChatNotificationService>(),
        ),
        ChangeNotifierProvider<DriverOnboardingViewModel>(
          create: (_) => getIt<DriverOnboardingViewModel>(),
        ),
      ],
      child: Consumer<AuthViewModel>(
        builder: (context, authViewModel, child) {
          // Luôn bắt đầu từ splash screen
          const String initialRoute = AppRoutes.splash;

          return MaterialApp(
            title: 'Truckie Driver',
            navigatorKey: widget.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: AppTheme.lightTheme.appBarTheme.copyWith(
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                ),
              ),
              // Cấu hình để xử lý bottom padding cho navigation bar
              bottomNavigationBarTheme: AppTheme
                  .lightTheme
                  .bottomNavigationBarTheme
                  .copyWith(elevation: 0),
            ),
            darkTheme: AppTheme.darkTheme.copyWith(
              appBarTheme: AppTheme.darkTheme.appBarTheme.copyWith(
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                ),
              ),
              // Cấu hình để xử lý bottom padding cho navigation bar trong dark mode
              bottomNavigationBarTheme: AppTheme
                  .darkTheme
                  .bottomNavigationBarTheme
                  .copyWith(elevation: 0),
            ),
            themeMode: ThemeMode.light,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('vi', 'VN'), // Vietnamese
            ],
            locale: const Locale('vi', 'VN'),
            initialRoute: initialRoute,
            onGenerateRoute: AppRoutes.generateRoute,
            builder: (context, child) {
              // Re-initialize ResponsiveSizeUtils on each rebuild to handle orientation changes
              ResponsiveSizeUtils().init(context);

              // Đảm bảo toàn bộ ứng dụng được padding đúng với system insets
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  // Apply text scaling factor limit to ensure text doesn't get too large
                  padding: MediaQuery.of(context).padding.copyWith(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  textScaler: TextScaler.linear(
                    MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
                  ),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}
