import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin tài xế
class DriverInfo extends StatelessWidget {
  /// Vai trò của tài xế (tài xế chính hoặc tài xế phụ)
  final String role;

  /// Thông tin tài xế
  final Driver driver;

  /// Có đánh dấu là tài xế hiện tại không
  final bool isHighlighted;

  /// Có phải là người dùng hiện tại không
  final bool isCurrentUser;

  const DriverInfo({
    super.key,
    required this.role,
    required this.driver,
    this.isHighlighted = false,
    this.isCurrentUser = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: isHighlighted ? AppColors.primary : AppColors.border,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                size: 16.r,
                color: isHighlighted
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              SizedBox(width: 8.w),
              Text(
                role,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHighlighted
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
              if (isCurrentUser) ...[
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Bạn',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.only(left: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tên: ${driver.fullName}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: isCurrentUser
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isCurrentUser
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'SĐT: ${driver.phoneNumber}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isCurrentUser
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
