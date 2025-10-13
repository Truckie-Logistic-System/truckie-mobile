import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin người nhận hàng
class ReceiverSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const ReceiverSection({super.key, required this.order});

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
            Text('Thông tin người nhận', style: AppTextStyles.titleMedium),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.person, size: 16.r, color: AppColors.textSecondary),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Tên: ${order.receiverName}',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.phone, size: 16.r, color: AppColors.textSecondary),
                SizedBox(width: 8.w),
                Text(
                  'SĐT: ${order.receiverPhone}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(Icons.badge, size: 16.r, color: AppColors.textSecondary),
                SizedBox(width: 8.w),
                Text(
                  'CMND/CCCD: ${order.receiverIdentity}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
