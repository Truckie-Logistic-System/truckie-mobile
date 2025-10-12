import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin cơ bản của đơn hàng
class OrderInfoSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const OrderInfoSection({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final formattedDate = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(order.createdAt);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mã đơn: #${order.orderCode}',
                    style: AppTextStyles.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14.sp,
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
                  size: 16.r,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Ngày tạo: $formattedDate',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.category,
                  size: 16.r,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'Loại hàng: ${order.categoryName}',
                    style: AppTextStyles.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Lấy màu tương ứng với trạng thái đơn hàng
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ASSIGNED_TO_DRIVER':
        return AppColors.warning;
      case 'FULLY_PAID':
      case 'PICKING_UP':
        return Colors.orange;
      case 'IN_PROGRESS':
      case 'DELIVERING':
        return AppColors.inProgress;
      case 'COMPLETED':
      case 'DELIVERED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Chuyển đổi mã trạng thái thành text hiển thị
  String _getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'ASSIGNED_TO_DRIVER':
        return 'Chờ lấy hàng';
      case 'FULLY_PAID':
      case 'PICKING_UP':
        return 'Đang lấy hàng';
      case 'IN_PROGRESS':
      case 'DELIVERING':
        return 'Đang giao';
      case 'COMPLETED':
      case 'DELIVERED':
        return 'Hoàn thành';
      case 'CANCELLED':
        return 'Đã hủy';
      default:
        return status;
    }
  }
}
