import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin hàng hóa
class PackageSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const PackageSection({Key? key, required this.order}) : super(key: key);

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
            Text('Thông tin hàng hóa', style: AppTextStyles.titleMedium),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 16.r,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Mô tả: ${order.packageDescription}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.format_list_numbered,
                  size: 16.r,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Số lượng: ${order.totalQuantity}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            if (order.notes.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.note, size: 16.r, color: AppColors.textSecondary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Ghi chú: ${order.notes}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
            if (order.orderDetails.isNotEmpty &&
                order.orderDetails.first.orderSize != null) ...[
              SizedBox(height: 16.h),
              _buildSizeInfo(order.orderDetails.first.orderSize!),
            ],
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị thông tin kích thước hàng hóa
  Widget _buildSizeInfo(OrderSize size) {
    // Format kích thước theo yêu cầu: min d x min r x min c - max d x max r x max c
    // d: chiều dài (length), r: chiều rộng (width), c: chiều cao (height)
    final minDimensions =
        '${size.minLength} x ${size.minWidth} x ${size.minHeight}';
    final maxDimensions =
        '${size.maxLength} x ${size.maxWidth} x ${size.maxHeight}';
    final dimensionsText = '$minDimensions - $maxDimensions cm';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.straighten, size: 16.r, color: AppColors.textSecondary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Kích thước: $dimensionsText',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
