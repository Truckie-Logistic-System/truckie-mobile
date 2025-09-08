import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/driver.dart';
import '../../../../domain/entities/user.dart';
import '../../../common_widgets/skeleton_loader.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../viewmodels/account_viewmodel.dart';
import 'edit_driver_info_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<AuthViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<AccountViewModel>()),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tài khoản'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Loại bỏ nút back
        ),
        body: Consumer2<AuthViewModel, AccountViewModel>(
          builder: (context, authViewModel, accountViewModel, _) {
            if (authViewModel.status == AuthStatus.loading) {
              return _buildLoadingState();
            } else if (authViewModel.status == AuthStatus.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text('Đã xảy ra lỗi', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      authViewModel.errorMessage,
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('Đăng nhập lại'),
                    ),
                  ],
                ),
              );
            } else if (authViewModel.status == AuthStatus.authenticated) {
              final user = authViewModel.user!;

              // If driver info is already available in AuthViewModel, use it
              if (authViewModel.driver != null) {
                final driver = authViewModel.driver!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user),
                      const SizedBox(height: 24),
                      _buildUserInfo(user),
                      const SizedBox(height: 24),
                      _buildDriverInfo(context, driver),
                      const SizedBox(height: 32),
                      _buildLogoutButton(context, authViewModel),
                    ],
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
                return _buildLoadingState();
              } else if (accountViewModel.status == AccountStatus.error) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text('Đã xảy ra lỗi', style: AppTextStyles.titleLarge),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          accountViewModel.errorMessage,
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          accountViewModel.getDriverInfo(user.id);
                        },
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              } else if (accountViewModel.status == AccountStatus.loaded) {
                final driver = accountViewModel.driver!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user),
                      const SizedBox(height: 24),
                      _buildUserInfo(user),
                      const SizedBox(height: 24),
                      _buildDriverInfo(context, driver),
                      const SizedBox(height: 32),
                      _buildLogoutButton(context, authViewModel),
                    ],
                  ),
                );
              } else {
                // Initial state, show user info only with skeleton for driver info
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user),
                      const SizedBox(height: 24),
                      _buildUserInfo(user),
                      const SizedBox(height: 24),
                      // Skeleton for driver info while waiting
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông tin tài xế',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SkeletonLoader(height: 200),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildLogoutButton(context, authViewModel),
                    ],
                  ),
                );
              }
            } else {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Bạn chưa đăng nhập'),
                    const SizedBox(height: 16),
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header skeleton
          Card(
            elevation: 2,
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Avatar skeleton
                  Shimmer.fromColors(
                    baseColor: AppColors.primary.withOpacity(0.7),
                    highlightColor: AppColors.primary.withOpacity(0.9),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name skeleton
                        Shimmer.fromColors(
                          baseColor: AppColors.primary.withOpacity(0.7),
                          highlightColor: AppColors.primary.withOpacity(0.9),
                          child: Container(
                            height: 24,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Role skeleton
                        Shimmer.fromColors(
                          baseColor: AppColors.primary.withOpacity(0.7),
                          highlightColor: AppColors.primary.withOpacity(0.9),
                          child: Container(
                            height: 16,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // User info skeleton
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(height: 24, width: 150),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Driver info skeleton
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(height: 24, width: 150),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                  const SizedBox(height: 16),
                  const SkeletonLoader(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Logout button skeleton
          const SkeletonLoader(height: 48),
        ],
      ),
    );
  }

  Widget _buildUserHeader(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white,
            child: user.imageUrl.isNotEmpty && user.imageUrl != "string"
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(36),
                    child: Image.network(
                      user.imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person,
                        size: 36,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : const Icon(Icons.person, size: 36, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.role.roleName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(User user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông tin cá nhân',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoItem(Icons.person, 'Tên đăng nhập', user.username),
            const Divider(),
            _buildInfoItem(Icons.email, 'Email', user.email),
            const Divider(),
            _buildInfoItem(Icons.phone, 'Số điện thoại', user.phoneNumber),
            if (user.status.isNotEmpty) ...[
              const Divider(),
              _buildInfoItem(Icons.info, 'Trạng thái', user.status),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo(BuildContext context, Driver driver) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thông tin tài xế',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () => _navigateToEditDriverInfo(context, driver),
                  tooltip: 'Chỉnh sửa thông tin',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(Icons.badge, 'Số CMND/CCCD', driver.identityNumber),
            const Divider(),
            _buildInfoItem(
              Icons.credit_card,
              'Số GPLX',
              driver.driverLicenseNumber,
            ),
            const Divider(),
            _buildInfoItem(
              Icons.credit_card,
              'Số thẻ',
              driver.cardSerialNumber,
            ),
            const Divider(),
            _buildInfoItem(Icons.location_city, 'Nơi cấp', driver.placeOfIssue),
            const Divider(),
            _buildInfoItem(
              Icons.date_range,
              'Ngày cấp',
              dateFormat.format(driver.dateOfIssue),
            ),
            const Divider(),
            _buildInfoItem(
              Icons.date_range,
              'Ngày hết hạn',
              dateFormat.format(driver.dateOfExpiry),
            ),
            const Divider(),
            _buildInfoItem(Icons.class_, 'Hạng bằng', driver.licenseClass),
            const Divider(),
            _buildInfoItem(
              Icons.date_range,
              'Ngày sát hạch',
              dateFormat.format(driver.dateOfPassing),
            ),
            const Divider(),
            _buildInfoItem(Icons.info, 'Trạng thái', driver.status),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToEditDriverInfo(
    BuildContext context,
    Driver driver,
  ) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-driver-info',
      arguments: driver,
    );

    // If edit was successful, refresh driver info
    if (result == true) {
      final authViewModel = Provider.of<AuthViewModel>(context, listen: false);
      final accountViewModel = Provider.of<AccountViewModel>(
        context,
        listen: false,
      );

      if (authViewModel.user != null) {
        // Force refresh from API
        await accountViewModel.getDriverInfo(authViewModel.user!.id);

        // Also update the driver info in AuthViewModel
        if (accountViewModel.driver != null) {
          authViewModel.updateDriverInfo(accountViewModel.driver!);
        }
      }
    }
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : 'Chưa cập nhật',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthViewModel authViewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // Chuyển ngay đến trang login trước khi gọi API logout
          Navigator.pushReplacementNamed(context, '/login');

          // Sau đó thực hiện logout ở background
          authViewModel.logout();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
