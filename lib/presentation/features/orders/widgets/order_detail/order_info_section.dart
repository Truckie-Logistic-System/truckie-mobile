import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../domain/entities/order_status.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin cơ bản của đơn hàng
class OrderInfoSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const OrderInfoSection({super.key, required this.order});

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
            // Hiển thị mã đơn đầy đủ
            Text(
              'Mã đơn: #${order.orderCode}',
              style: AppTextStyles.titleLarge,
            ),
            SizedBox(height: 8.h),
            // Status badge
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
                    'Loại hàng: ${order.categoryDescription ?? order.categoryName}',
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
    final orderStatus = OrderStatus.fromString(status);
    switch (orderStatus) {
      case OrderStatus.pending:
      case OrderStatus.processing:
        return Colors.grey;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.contractDraft:
      case OrderStatus.contractSigned:
      case OrderStatus.onPlanning:
        return Colors.blue;
      case OrderStatus.assignedToDriver:
      case OrderStatus.fullyPaid:
        return AppColors.warning;
      case OrderStatus.pickingUp:
        return Colors.orange;
      case OrderStatus.onDelivered:
      case OrderStatus.ongoingDelivered:
        return AppColors.inProgress;
      case OrderStatus.delivered:
      case OrderStatus.successful:
        return AppColors.success;
      case OrderStatus.inTroubles:
        return AppColors.error;
      case OrderStatus.resolved:
      case OrderStatus.compensation:
        return Colors.orange;
      case OrderStatus.rejectOrder:
        return AppColors.error;
      case OrderStatus.returning:
        return Colors.orange;
      case OrderStatus.returned:
        return Colors.grey;
    }
  }

  /// Chuyển đổi mã trạng thái thành text hiển thị
  String _getStatusText(String status) {
    final orderStatus = OrderStatus.fromString(status);
    return orderStatus.toVietnamese();
  }
}
