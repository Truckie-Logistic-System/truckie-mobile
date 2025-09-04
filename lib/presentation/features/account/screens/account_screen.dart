import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/service_locator.dart';
import '../../../../domain/entities/user.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => getIt<AuthViewModel>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tài khoản'),
          centerTitle: true,
          automaticallyImplyLeading: false, // Loại bỏ nút back
        ),
        body: Consumer<AuthViewModel>(
          builder: (context, authViewModel, _) {
            switch (authViewModel.status) {
              case AuthStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case AuthStatus.error:
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
              case AuthStatus.authenticated:
                final user = authViewModel.user!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserHeader(user),
                      const SizedBox(height: 24),
                      _buildUserInfo(user),
                      const SizedBox(height: 32),
                      _buildLogoutButton(context, authViewModel),
                    ],
                  ),
                );
              default:
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

  Widget _buildUserHeader(User user) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withOpacity(0.2),
            backgroundImage: user.imageUrl.isNotEmpty
                ? NetworkImage(user.imageUrl)
                : null,
            child: user.imageUrl.isEmpty
                ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : user.username[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName,
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            user.role.roleName,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
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
        onPressed: () => _confirmLogout(context, authViewModel),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Đăng xuất', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Future<void> _confirmLogout(
    BuildContext context,
    AuthViewModel authViewModel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final success = await authViewModel.logout();
      if (success && context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
}
