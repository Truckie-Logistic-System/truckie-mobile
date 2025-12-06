import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../data/models/driver_dashboard_model.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị KPI cá nhân của tài xế
class PersonalKpiCard extends StatelessWidget {
  final PersonalKpi? kpi;
  final bool isLoading;

  const PersonalKpiCard({
    super.key,
    this.kpi,
    this.isLoading = false,
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
              children: [
                Icon(Icons.analytics, color: AppColors.primary, size: 24.r),
                SizedBox(width: 8.w),
                Text('Hiệu suất cá nhân', style: AppTextStyles.titleMedium),
              ],
            ),
            SizedBox(height: 16.h),
            if (isLoading)
              _buildLoadingState()
            else if (kpi == null)
              _buildEmptyState()
            else
              _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 2,
      children: List.generate(
        4,
        (index) => Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: Text(
          'Chưa có dữ liệu KPI',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Main KPIs
        Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                icon: Icons.local_shipping,
                value: '${kpi!.totalTripsCompleted}',
                label: 'Chuyến hoàn thành',
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildKpiItem(
                icon: Icons.inventory_2,
                value: '${kpi!.totalDeliveriesCompleted}',
                label: 'Đơn giao thành công',
                color: AppColors.success,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildKpiItem(
                icon: Icons.timer,
                value: '${kpi!.onTimeRate.toStringAsFixed(0)}%',
                label: 'Đúng giờ',
                color: kpi!.onTimeRate >= 90
                    ? AppColors.success
                    : kpi!.onTimeRate >= 70
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildKpiItem(
                icon: Icons.star,
                value: kpi!.rating.toStringAsFixed(1),
                label: 'Đánh giá',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Additional stats
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMiniStat(
                Icons.warning_amber,
                '${kpi!.issuesReported}',
                'Sự cố',
                kpi!.issuesReported > 0 ? AppColors.error : AppColors.success,
              ),
              Container(
                width: 1,
                height: 30.h,
                color: Colors.grey[300],
              ),
              _buildMiniStat(
                Icons.local_gas_station,
                '${kpi!.fuelEfficiency.toStringAsFixed(1)}',
                'L/100km',
                AppColors.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18.r),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16.r),
            SizedBox(width: 4.w),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
          ),
        ),
      ],
    );
  }
}
