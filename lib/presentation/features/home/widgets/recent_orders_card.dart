import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import '../../../../../domain/entities/order.dart';
import '../../../../../app/app_routes.dart';

/// Widget hiển thị các đơn hàng gần đây trên màn hình home
class RecentOrdersCard extends StatelessWidget {
  final List<Order> orders;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const RecentOrdersCard({
    super.key,
    required this.orders,
    this.isLoading = false,
    this.onViewAll,
  });

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
                    // Ưu tiên callback từ bên ngoài (HomeScreen) để điều hướng theo cấu trúc tab
                    if (onViewAll != null) {
                      onViewAll!();
                    } else {
                      // Fallback: điều hướng tới MainScreen với tab Đơn hàng, giữ nguyên bottom navigation
                      Navigator.pushNamed(
                        context,
                        AppRoutes.main,
                        arguments: const {
                          'initialTab': 1, // 0 = Home, 1 = Orders
                        },
                      );
                    }
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
            if (isLoading)
              _buildLoadingState()
            else if (orders.isEmpty)
              _buildEmptyState()
            else
              ...orders.map((order) => _buildOrderItem(order: order, context: context)),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một mục đơn hàng
  Widget _buildOrderItem({required Order order, required BuildContext context}) {
    final status = _getOrderStatusText(order.status);
    final statusColor = _getOrderStatusColor(order.status);
    final time = _formatTime(order.createdAt);
    final address = _getOrderAddress(order);

    return Column(
      children: [
        InkWell(
          onTap: () {
            // Navigate to order detail screen
            Navigator.pushNamed(
              context,
              AppRoutes.orderDetail,
              arguments: order.id,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.local_shipping, color: statusColor, size: 24.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Đơn hàng #${order.orderCode}',
                            style: AppTextStyles.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      address,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 12.r,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            time,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (orders.last != order) SizedBox(height: 12.h),
        if (orders.last != order) Divider(height: 1.h),
        if (orders.last != order) SizedBox(height: 12.h),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: List.generate(
        3,
        (index) => Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 120.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: double.infinity,
                        height: 14.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Container(
                        width: 60.w,
                        height: 12.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index < 2) SizedBox(height: 12.h),
            if (index < 2) Divider(height: 1.h),
            if (index < 2) SizedBox(height: 12.h),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.local_shipping_outlined,
              size: 48.r,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 8.h),
            Text(
              'Chưa có đơn hàng gần đây',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getOrderStatusText(String? status) {
    switch (status?.toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESSFUL':
        return 'Hoàn thành';
      case 'DELIVERING':
      case 'ONGOING_DELIVERED':
        return 'Đang giao';
      case 'PICKING_UP':
        return 'Đang lấy hàng';
      case 'CANCELLED':
        return 'Đã hủy';
      case 'ASSIGNED_TO_DRIVER':
        return 'Đã phân công';
      default:
        return status ?? 'Không xác định';
    }
  }

  Color _getOrderStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'COMPLETED':
      case 'SUCCESSFUL':
        return AppColors.success;
      case 'DELIVERING':
      case 'ONGOING_DELIVERED':
        return AppColors.inProgress;
      case 'PICKING_UP':
        return AppColors.warning;
      case 'CANCELLED':
        return AppColors.error;
      case 'ASSIGNED_TO_DRIVER':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _getOrderAddress(Order order) {
    // For now, use receiver info as address since Order entity doesn't have address field
    // This can be enhanced when address is added to the entity
    return '${order.receiverName} - ${order.receiverPhone}';
  }
}
