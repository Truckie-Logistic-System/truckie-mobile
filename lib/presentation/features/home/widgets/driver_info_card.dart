import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/driver.dart';
import '../../../../../domain/entities/user.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin tài xế trên màn hình home
class DriverInfoCard extends StatelessWidget {
  final dynamic user;
  final dynamic driver;

  const DriverInfoCard({super.key, required this.user, required this.driver});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thông tin tài xế', style: AppTextStyles.titleMedium),
            SizedBox(height: 16.h),
            Row(
              children: [
                CircleAvatar(
                  radius: 32.r,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    driver.userResponse.fullName.isNotEmpty
                        ? driver.userResponse.fullName[0].toUpperCase()
                        : 'T',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24.sp,
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
                        driver.userResponse.fullName,
                        style: AppTextStyles.titleMedium,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'Tài xế ${driver.licenseClass}',
                        style: AppTextStyles.bodyMedium,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'GPLX: ${driver.driverLicenseNumber}',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
