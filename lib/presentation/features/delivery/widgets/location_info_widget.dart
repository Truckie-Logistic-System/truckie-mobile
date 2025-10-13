import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class LocationInfoWidget extends StatelessWidget {
  const LocationInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin địa điểm', style: AppTextStyles.headlineSmall),
        SizedBox(height: 16.h),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              children: [
                _buildLocationItem(
                  icon: Icons.location_on,
                  iconColor: AppColors.error,
                  title: 'Điểm lấy hàng',
                  address: '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                  time: '09:00 - 15/09/2025',
                  isCompleted: true,
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  child: const Divider(),
                ),
                _buildLocationItem(
                  icon: Icons.flag,
                  iconColor: AppColors.success,
                  title: 'Điểm giao hàng',
                  address: '456 Lê Văn Lương, Quận 7, TP.HCM',
                  time: '10:30 - 15/09/2025',
                  isCompleted: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
    required String time,
    required bool isCompleted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  const Spacer(),
                  if (isCompleted)
                    Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 16.r,
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(address, style: AppTextStyles.bodyMedium),
              SizedBox(height: 4.h),
              Text(time, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
