import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

class OrderInfoWidget extends StatelessWidget {
  final String orderId;
  final String status;
  final String pickupTime;
  final String deliveryTime;

  const OrderInfoWidget({
    super.key,
    required this.orderId,
    required this.status,
    required this.pickupTime,
    required this.deliveryTime,
  });

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mã đơn: #$orderId', style: AppTextStyles.titleLarge),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: AppColors.inProgress.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: AppColors.inProgress,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: AppColors.textSecondary,
                  size: 16.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Thời gian lấy hàng: $pickupTime',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              children: [
                Icon(
                  Icons.local_shipping,
                  color: AppColors.textSecondary,
                  size: 16.r,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Dự kiến giao: $deliveryTime',
                  style: TextStyle(fontSize: 14.sp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
