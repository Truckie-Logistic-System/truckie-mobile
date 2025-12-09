import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';
import '../../../../data/models/driver_dashboard_model.dart';
import '../../../../app/app_routes.dart';
import '../../../../domain/entities/order_status.dart';

/// Card hiển thị đơn hàng gần đây từ dashboard data
class SimplifiedRecentOrdersCard extends StatelessWidget {
  final List<RecentOrder> orders;
  final bool isLoading;
  final VoidCallback? onViewAll;

  const SimplifiedRecentOrdersCard({
    super.key,
    this.orders = const [],
    this.isLoading = false,
    this.onViewAll,
  });

  Widget _buildStatusBadge(String status) {
    final orderStatus = OrderStatus.fromString(status);
    final displayStatus = orderStatus.toVietnamese();
    final color = _getStatusColor(orderStatus);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.processing:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.contractDraft:
      case OrderStatus.contractSigned:
      case OrderStatus.onPlanning:
        return Colors.blue;
      case OrderStatus.assignedToDriver:
      case OrderStatus.fullyPaid:
        return Colors.blue;
      case OrderStatus.pickingUp:
        return Colors.orange;
      case OrderStatus.onDelivered:
      case OrderStatus.ongoingDelivered:
        return Colors.purple;
      case OrderStatus.delivered:
      case OrderStatus.successful:
        return Colors.green;
      case OrderStatus.inTroubles:
        return Colors.red;
      case OrderStatus.resolved:
      case OrderStatus.compensation:
        return Colors.orange;
      case OrderStatus.rejectOrder:
        return Colors.red;
      case OrderStatus.returning:
        return Colors.orange;
      case OrderStatus.returned:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeleton();
    }

    if (orders.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.primary,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Đơn hàng gần đây',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              if (onViewAll != null)
                TextButton(
                  onPressed: onViewAll,
                  child: Text(
                    'Xem tất cả',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),

          // Orders list
          ...orders.map((order) => _buildOrderItem(context, order)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, RecentOrder order) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to order detail screen
          if (order.orderId.isNotEmpty) {
            Navigator.pushNamed(context, AppRoutes.orderDetail, arguments: order.orderId);
          }
        },
        borderRadius: BorderRadius.circular(8.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with order code and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.orderCode.isNotEmpty ? order.orderCode : order.trackingCode,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            SizedBox(height: 8.h),

            // Receiver info
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16.w,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    order.receiverName.isNotEmpty ? order.receiverName : 'Chưa có thông tin',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),

            // Phone info
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 16.w,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4.w),
                Text(
                  order.receiverPhone.isNotEmpty ? order.receiverPhone : 'Chưa có số điện thoại',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 16.w),

                // Date
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16.w,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4.w),
                Text(
                  order.createdDate,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                width: 20.w,
                height: 20.w,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
              SizedBox(width: 8.w),
              Container(
                width: 100.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Order items skeleton
          ...List.generate(3, (index) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              height: 80.h,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: Colors.grey[400],
              size: 48.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'Chưa có đơn hàng nào',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
