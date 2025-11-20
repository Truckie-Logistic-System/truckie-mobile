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

    // Kiểm tra trạng thái đăng nhập
    if (_authViewModel.status == AuthStatus.authenticated) {
      // CRITICAL: Don't call forceRefreshToken() right after login!
      // Token was just obtained from login, and calling refresh immediately
      // will cause the backend to revoke the new token (token rotation)
      // Just navigate to main screen directly
      _navigateToMain();
    } else if (_authViewModel.status == AuthStatus.unauthenticated) {
      // Nếu chưa đăng nhập, chuyển đến trang đăng nhập
      _navigateToLogin();
    } else {
      // Nếu đang trong trạng thái loading, đợi cho đến khi hoàn tất
      await _authViewModel.checkAuthStatus();
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
