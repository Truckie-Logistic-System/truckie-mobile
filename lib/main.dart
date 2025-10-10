import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_routes.dart';
import 'core/services/hot_reload_helper.dart';
import 'core/services/index.dart';
import 'core/services/vietmap_service.dart';
import 'presentation/common_widgets/vietmap/vietmap_viewmodel.dart';
import 'presentation/features/auth/index.dart';

void main() async {
  // Đảm bảo binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Reset problematic instances for hot reload
  HotReloadHelper.resetProblematicInstances();

  // Khởi tạo service locator
  await setupServiceLocator();

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
  const MyApp({Key? key}) : super(key: key);

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
