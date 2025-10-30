import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin thời gian vận chuyển
class JourneyTimeSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const JourneyTimeSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.orderDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        // Get current user phone number
        final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
        
        // For multi-trip orders: Find the order detail that belongs to current driver's vehicle assignment
        var orderDetail = order.orderDetails.first;
        if (currentUserPhone != null && currentUserPhone.isNotEmpty && order.vehicleAssignments.isNotEmpty) {
          try {
            // Find vehicle assignment where current user is primary driver
            final vehicleAssignment = order.vehicleAssignments.firstWhere(
              (va) {
                if (va.primaryDriver == null) return false;
                return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
              },
            );
            
            // Find order detail that belongs to this vehicle assignment
            orderDetail = order.orderDetails.firstWhere(
              (od) => od.vehicleAssignmentId == vehicleAssignment.id,
            );
          } catch (e) {
            // Fallback to first order detail
            orderDetail = order.orderDetails.first;
          }
        }

        final estimatedStartTime = orderDetail.estimatedStartTime;
        final startTime = orderDetail.startTime;
        final estimatedEndTime = orderDetail.estimatedEndTime;
        final endTime = orderDetail.endTime;

        if (estimatedStartTime == null &&
            startTime == null &&
            estimatedEndTime == null &&
            endTime == null) {
          return const SizedBox.shrink();
        }

        return _buildContent(estimatedStartTime, startTime, estimatedEndTime, endTime);
      },
    );
  }

  Widget _buildContent(
    DateTime? estimatedStartTime,
    DateTime? startTime,
    DateTime? estimatedEndTime,
    DateTime? endTime,
  ) {

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thời gian vận chuyển', style: AppTextStyles.titleMedium),
            SizedBox(height: 12.h),

            // Thời gian bắt đầu dự kiến
            if (estimatedStartTime != null) ...[
              _buildTimeRow(
                icon: Icons.access_time,
                label: 'Thời gian lấy hàng dự kiến:',
                time: estimatedStartTime,
                isEstimated: true,
              ),
              SizedBox(height: 8.h),
            ],

            // Thời gian bắt đầu thực tế
            if (startTime != null) ...[
              _buildTimeRow(
                icon: Icons.check_circle,
                label: 'Thời gian lấy hàng thực tế:',
                time: startTime,
                isEstimated: false,
              ),
              SizedBox(height: 8.h),
            ],

            // Thời gian kết thúc dự kiến
            if (estimatedEndTime != null) ...[
              _buildTimeRow(
                icon: Icons.access_time,
                label: 'Thời gian giao hàng dự kiến:',
                time: estimatedEndTime,
                isEstimated: true,
              ),
              SizedBox(height: 8.h),
            ],

            // Thời gian kết thúc thực tế
            if (endTime != null) ...[
              _buildTimeRow(
                icon: Icons.check_circle,
                label: 'Thời gian giao hàng thực tế:',
                time: endTime,
                isEstimated: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required DateTime time,
    required bool isEstimated,
  }) {
    final dateFormatter = DateFormat('dd/MM/yyyy');
    final timeFormatter = DateFormat('HH:mm');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16.r,
          color: isEstimated ? AppColors.warning : AppColors.success,
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14.r,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    dateFormatter.format(time),
                    style: AppTextStyles.bodyMedium,
                  ),
                  SizedBox(width: 12.w),
                  Icon(
                    Icons.access_time,
                    size: 14.r,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    timeFormatter.format(time),
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
