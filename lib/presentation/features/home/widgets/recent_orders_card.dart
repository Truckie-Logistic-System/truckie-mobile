import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị các đơn hàng gần đây trên màn hình home
class RecentOrdersCard extends StatelessWidget {
  const RecentOrdersCard({Key? key}) : super(key: key);

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Đơn hàng gần đây', style: AppTextStyles.titleMedium),
                TextButton(
                  onPressed: () {
                    // Navigate to orders screen using bottom navigation
                  },
                  child: Text(
                    'Xem tất cả',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            _buildOrderItem(
              orderId: 'DH001',
              status: 'Hoàn thành',
              address: '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
              time: '10:30',
            ),
            Divider(height: 16.h),
            _buildOrderItem(
              orderId: 'DH002',
              status: 'Hoàn thành',
              address: '456 Lê Văn Lương, Quận 7, TP.HCM',
              time: '11:45',
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một mục đơn hàng
  Widget _buildOrderItem({
    required String orderId,
    required String status,
    required String address,
    required String time,
  }) {
    Color statusColor;
    switch (status) {
      case 'Hoàn thành':
        statusColor = AppColors.success;
        break;
      case 'Đang giao':
        statusColor = AppColors.inProgress;
        break;
      case 'Chờ lấy hàng':
        statusColor = AppColors.warning;
        break;
      case 'Đã hủy':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_shipping, color: statusColor, size: 24.r),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Đơn hàng #$orderId', style: AppTextStyles.titleSmall),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(address, style: AppTextStyles.bodyMedium),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14.r,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4.w),
                  Text(time, style: AppTextStyles.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
