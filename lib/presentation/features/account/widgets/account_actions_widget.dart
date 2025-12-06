import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị các hành động quản lý tài khoản
class AccountActionsWidget extends StatelessWidget {
  final VoidCallback onChangePassword;

  const AccountActionsWidget({super.key, required this.onChangePassword});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppColors.primary, size: 24.r),
                SizedBox(width: 8.w),
                Text(
                  'Quản lý tài khoản',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Column(
                children: [
                  _buildActionItem(
                    context: context,
                    icon: Icons.password,
                    title: 'Đổi mật khẩu',
                    subtitle: 'Cập nhật mật khẩu đăng nhập của bạn',
                    onTap: onChangePassword,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một hành động
  Widget _buildActionItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      leading: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24.r),
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.r),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      onTap: onTap,
    );
  }
}
