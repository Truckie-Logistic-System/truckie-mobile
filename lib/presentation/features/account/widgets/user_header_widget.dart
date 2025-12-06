import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/user.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị phần header của user trong màn hình tài khoản
class UserHeaderWidget extends StatelessWidget {
  final User user;

  const UserHeaderWidget({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 36.r,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
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
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Icon(
                            Icons.local_shipping,
                            size: 16.r,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            user.role.roleName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 12.r,
                        color: user.status.toLowerCase() == "active"
                            ? Colors.green
                            : Colors.orange,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Trạng thái: ${user.status.isEmpty ? 'Chưa cập nhật' : user.status}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.verified_user, size: 18.r, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
