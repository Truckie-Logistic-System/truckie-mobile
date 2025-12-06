import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../data/models/driver_dashboard_model.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị chuyến đi hiện tại
class CurrentTripCard extends StatelessWidget {
  final CurrentTrip? currentTrip;
  final bool isLoading;
  final VoidCallback? onTap;

  const CurrentTripCard({
    super.key,
    this.currentTrip,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: currentTrip?.hasActiveTrip == true ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.route,
                        color: AppColors.primary,
                        size: 24.r,
                      ),
                      SizedBox(width: 8.w),
                      Text('Chuyến đi hiện tại', style: AppTextStyles.titleMedium),
                    ],
                  ),
                  if (currentTrip?.hasActiveTrip == true)
                    Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                      size: 24.r,
                    ),
                ],
              ),
              SizedBox(height: 12.h),
              if (isLoading)
                _buildLoadingState()
              else if (currentTrip == null || !currentTrip!.hasActiveTrip)
                _buildEmptyState()
              else
                _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Container(
          height: 20.h,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          height: 60.h,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
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
              'Không có chuyến đi nào đang thực hiện',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trip info header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentTrip!.trackingCode ?? 'N/A',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            _buildStatusChip(currentTrip!.status ?? 'UNKNOWN'),
          ],
        ),
        SizedBox(height: 12.h),

        // Progress
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiến độ giao hàng',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '${currentTrip!.completedStops}/${currentTrip!.totalStops} điểm',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: currentTrip!.progress / 100,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 8.h,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),

        // Current stop
        if (currentTrip!.currentStop != null) ...[
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    currentTrip!.currentStop!.isPickup
                        ? Icons.inventory_2
                        : Icons.location_on,
                    color: Colors.white,
                    size: 16.r,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentTrip!.currentStop!.isPickup
                            ? 'Điểm lấy hàng'
                            : 'Điểm giao hàng',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        currentTrip!.currentStop!.address ?? 'Không có địa chỉ',
                        style: AppTextStyles.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Vehicle plate
        if (currentTrip!.vehiclePlate != null) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(
                Icons.directions_car,
                size: 16.r,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 4.w),
              Text(
                currentTrip!.vehiclePlate!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'IN_PROGRESS':
        color = AppColors.inProgress;
        label = 'Đang thực hiện';
        break;
      case 'PICKING_UP':
        color = AppColors.warning;
        label = 'Đang lấy hàng';
        break;
      case 'DELIVERING':
        color = AppColors.primary;
        label = 'Đang giao';
        break;
      case 'COMPLETED':
        color = AppColors.success;
        label = 'Hoàn thành';
        break;
      default:
        color = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
