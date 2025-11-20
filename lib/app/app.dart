import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/utils/responsive_size_utils.dart';
import '../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../presentation/theme/app_theme.dart';
import 'app_routes.dart';

class TruckieApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const TruckieApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    // Initialize ResponsiveSizeUtils here
    ResponsiveSizeUtils().init(context);

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        // Luôn bắt đầu từ splash screen
        const String initialRoute = AppRoutes.splash;

        // 

        return MaterialApp(
          title: 'Truckie Driver',
          navigatorKey: navigatorKey,
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
    );
  }
}
