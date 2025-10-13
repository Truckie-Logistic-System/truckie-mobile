import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class CustomerInfoWidget extends StatelessWidget {
  final String customerName;
  final String phoneNumber;
  final VoidCallback? onCallPressed;

  const CustomerInfoWidget({
    super.key,
    required this.customerName,
    required this.phoneNumber,
    this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Thông tin khách hàng', style: AppTextStyles.headlineSmall),
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
                _buildInfoRow(
                  icon: Icons.person,
                  label: 'Tên khách hàng',
                  value: customerName,
                ),
                SizedBox(height: 12.h),
                _buildInfoRow(
                  icon: Icons.phone,
                  label: 'Số điện thoại',
                  value: phoneNumber,
                  isPhone: true,
                  onCallPressed: onCallPressed,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isPhone = false,
    VoidCallback? onCallPressed,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isPhone && onCallPressed != null)
          IconButton(
            onPressed: onCallPressed,
            icon: Icon(Icons.call, color: AppColors.primary, size: 24.r),
          ),
      ],
    );
  }
}
