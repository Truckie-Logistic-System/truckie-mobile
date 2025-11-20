import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../../app/di/service_locator.dart';
import '../../../../core/services/system_ui_service.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../domain/entities/driver.dart';
import '../../../../domain/entities/user.dart';
import '../../../../presentation/common_widgets/responsive_layout_builder.dart';
import '../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';
import '../../../features/auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/account_viewmodel.dart';
import '../widgets/index.dart';

/// Màn hình tài khoản người dùng
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // Use the singleton instances from GetIt
  late final AuthViewModel _authViewModel;
  late final AccountViewModel _accountViewModel;

  @override
  void initState() {
    super.initState();
    _authViewModel = getIt<AuthViewModel>();
    _accountViewModel = getIt<AccountViewModel>();

    // Đảm bảo token được refresh khi vào màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_authViewModel.status == AuthStatus.authenticated) {
        _authViewModel.forceRefreshToken().then((success) {
          if (success && _authViewModel.user != null) {
            _accountViewModel.getDriverInfo(_authViewModel.user!.id);
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Tải lại dữ liệu khi màn hình được hiển thị lại
    if (_authViewModel.status == AuthStatus.authenticated &&
        _authViewModel.user != null) {

      _accountViewModel.getDriverInfo(_authViewModel.user!.id);
    }
  }

  // Public method để refresh data từ bên ngoài
  void refreshAccountData() {

    if (_authViewModel.status == AuthStatus.authenticated &&
        _authViewModel.user != null) {
      // Force refresh token trước, sau đó force refresh driver info
      _authViewModel.forceRefreshToken().then((success) {

        if (success && _authViewModel.user != null) {
          _accountViewModel.refreshDriverInfo(_authViewModel.user!.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản'),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {

              refreshAccountData();
            },
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: _authViewModel),
          ChangeNotifierProvider.value(value: _accountViewModel),
        ],
        child: Consumer2<AuthViewModel, AccountViewModel>(
          builder: (context, authViewModel, accountViewModel, _) {
            if (authViewModel.status == AuthStatus.loading) {
              return const AccountLoadingWidget();
            } else if (authViewModel.status == AuthStatus.error) {
              return _buildErrorState(context, authViewModel.errorMessage);
            } else if (authViewModel.status == AuthStatus.authenticated) {
              final user = authViewModel.user!;

              return ResponsiveLayoutBuilder(
                builder: (context, sizingInformation) {
                  // If driver info is already available in AuthViewModel, use it
                  if (authViewModel.driver != null) {
                    final driver = authViewModel.driver!;
                    return SingleChildScrollView(
                      padding: SystemUiService.getContentPadding(context),
                      child: _buildAccountContent(
                        context,
                        user,
                        driver,
                        authViewModel,
                        sizingInformation,
                      ),
                    );
                  }

                  // Otherwise, fetch driver info if not already loaded
                  if (accountViewModel.status == AccountStatus.initial) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      accountViewModel.getDriverInfo(user.id);
                    });
                  }

                  if (accountViewModel.status == AccountStatus.loading) {
                    return const AccountLoadingWidget();
                  } else if (accountViewModel.status == AccountStatus.error) {
                    return _buildErrorState(
                      context,
                      accountViewModel.errorMessage,
                    );
                  } else if (accountViewModel.status == AccountStatus.loaded) {
                    final driver = accountViewModel.driver!;
                    return SingleChildScrollView(
                      padding: SystemUiService.getContentPadding(context),
                      child: _buildAccountContent(
                        context,
                        user,
                        driver,
                        authViewModel,
                        sizingInformation,
                      ),
                    );
                  } else {
                    // Initial state, show user info only with skeleton for driver info
                    return SingleChildScrollView(
                      padding: SystemUiService.getContentPadding(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserHeaderWidget(user: user),
                          SizedBox(height: 24.h),
                          UserInfoWidget(user: user),
                          SizedBox(height: 24.h),
                          AccountActionsWidget(
                            onChangePassword: () =>
                                _navigateToChangePassword(context),
                          ),
                          SizedBox(height: 24.h),
                          // Skeleton for driver info while waiting
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.r),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Thông tin tài xế',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 16.h),
                                  const SkeletonLoader(height: 200),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 32.h),
                          LogoutButtonWidget(authViewModel: authViewModel),
                        ],
                      ),
                    );
                  }
                },
              );
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bạn chưa đăng nhập'),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('Đăng nhập'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }

  /// Hiển thị trạng thái lỗi
  Widget _buildErrorState(BuildContext context, String errorMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 48.r),
          SizedBox(height: 16.h),
          Text('Đã xảy ra lỗi', style: AppTextStyles.titleLarge),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Text(
              errorMessage,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Đăng nhập lại'),
          ),
        ],
      ),
    );
  }

  /// Điều hướng đến màn hình đổi mật khẩu
  void _navigateToChangePassword(BuildContext context) {
    Navigator.pushNamed(context, '/change-password');
  }

  /// Điều hướng đến màn hình chỉnh sửa thông tin tài xế
  void _navigateToEditDriverInfo(BuildContext context, Driver driver) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-driver-info',
      arguments: driver,
    );

    // If we got a successful result, refresh the data
    if (result == true) {
      if (_authViewModel.user != null) {
        // Refresh driver info in both view models
        await _accountViewModel.getDriverInfo(_authViewModel.user!.id);
        await _authViewModel.refreshDriverInfo();
      }
    }
  }

  /// Xây dựng nội dung chính của màn hình tài khoản
  Widget _buildAccountContent(
    BuildContext context,
    User user,
    Driver driver,
    AuthViewModel authViewModel,
    SizingInformation sizingInformation,
  ) {
    // Tablet layout with 2 columns
    if (sizingInformation.isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserHeaderWidget(user: user),
          SizedBox(height: 24.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    UserInfoWidget(user: user),
                    SizedBox(height: 24.h),
                    DriverInfoWidget(
                      driver: driver,
                      onEdit: () => _navigateToEditDriverInfo(context, driver),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16.w),
              // Right column
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    AccountActionsWidget(
                      onChangePassword: () =>
                          _navigateToChangePassword(context),
                    ),
                    SizedBox(height: 24.h),
                    LogoutButtonWidget(authViewModel: authViewModel),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // Phone layout with single column
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserHeaderWidget(user: user),
          SizedBox(height: 24.h),
          UserInfoWidget(user: user),
          SizedBox(height: 24.h),
          DriverInfoWidget(
            driver: driver,
            onEdit: () => _navigateToEditDriverInfo(context, driver),
          ),
          SizedBox(height: 24.h),
          AccountActionsWidget(
            onChangePassword: () => _navigateToChangePassword(context),
          ),
          SizedBox(height: 24.h),
          LogoutButtonWidget(authViewModel: authViewModel),
        ],
      );
    }
  }
}
