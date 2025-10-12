import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị đơn hàng hiện tại trên màn hình home
class CurrentDeliveryCard extends StatelessWidget {
  const CurrentDeliveryCard({Key? key}) : super(key: key);

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
            Text('Đơn hàng hiện tại', style: AppTextStyles.titleMedium),
            SizedBox(height: 16.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.inProgress.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping,
                    color: AppColors.inProgress,
                    size: 24.r,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Đơn hàng #DH001', style: AppTextStyles.titleSmall),
                      SizedBox(height: 4.h),
                      Text(
                        '123 Nguyễn Văn Linh, Quận 7, TP.HCM',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to delivery details
                Navigator.pushNamed(context, '/delivery/active');
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
              ),
              child: const Text('Xem chi tiết'),
            ),
          ],
        ),
      ),
    );
  }
}
