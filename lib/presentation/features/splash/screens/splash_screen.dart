import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_routes.dart';
import '../../../../app/di/service_locator.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../../theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final AuthViewModel _authViewModel;
  final bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Đợi một chút để hiển thị splash screen
    await Future.delayed(const Duration(milliseconds: 500));

    // Kiểm tra trạng thái đăng nhập và refresh token nếu cần
    if (_authViewModel.status == AuthStatus.authenticated) {
      // Nếu đã đăng nhập, thử refresh token
      // debugPrint('🔄 [SplashScreen] Status is authenticated, forcing token refresh...');
      final refreshed = await _authViewModel.forceRefreshToken();
      // debugPrint('🔄 [SplashScreen] Token refresh result: $refreshed');
      // debugPrint('👤 [SplashScreen] Driver info loaded: ${_authViewModel.driver != null}');

      if (refreshed) {
        // Nếu refresh token thành công, chuyển đến trang chính
        _navigateToMain();
      } else {
        // Nếu refresh token thất bại, chuyển đến trang đăng nhập
        _navigateToLogin();
      }
    } else if (_authViewModel.status == AuthStatus.unauthenticated) {
      // Nếu chưa đăng nhập, chuyển đến trang đăng nhập
      // debugPrint('🔓 [SplashScreen] Status is unauthenticated, navigating to login');
      _navigateToLogin();
    } else {
      // Nếu đang trong trạng thái loading, đợi cho đến khi hoàn tất
      // debugPrint('⏳ [SplashScreen] Status is loading, waiting for checkAuthStatus...');
      await _authViewModel.checkAuthStatus();
      // debugPrint('✅ [SplashScreen] checkAuthStatus completed');
      // debugPrint('👤 [SplashScreen] Driver info loaded: ${_authViewModel.driver != null}');
      
      if (_authViewModel.status == AuthStatus.authenticated) {
        _navigateToMain();
      } else {
        _navigateToLogin();
      }
    }
  }

  void _navigateToMain() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo hoặc icon của ứng dụng
            Icon(Icons.local_shipping, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text(
              'Truckie Driver',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
