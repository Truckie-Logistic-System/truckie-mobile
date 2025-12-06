import 'package:flutter/material.dart';
import '../../../../core/utils/responsive_extensions.dart';
import '../../../../data/models/driver_dashboard_model.dart';
import '../../../../presentation/theme/app_colors.dart';
import '../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị tổng quan dashboard theo khoảng thời gian
class DashboardSummaryCard extends StatelessWidget {
  final PeriodSummary? summary;
  final bool isLoading;
  final String? periodLabel;

  const DashboardSummaryCard({
    super.key,
    this.summary,
    this.isLoading = false,
    this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.dashboard, color: Colors.white, size: 24.r),
                  SizedBox(width: 8.w),
                  Text(
                    periodLabel ?? 'Tổng quan',
                    style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (isLoading)
                _buildLoadingState()
              else if (summary == null)
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(
        3,
        (index) => Container(
          width: 80.w,
          height: 60.h,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Chưa có dữ liệu',
        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.local_shipping,
              value: '${summary!.totalTrips}',
              label: 'Tổng chuyến',
            ),
            _buildStatItem(
              icon: Icons.check_circle,
              value: '${summary!.completedTrips}',
              label: 'Hoàn thành',
            ),
            _buildStatItem(
              icon: Icons.pending,
              value: '${summary!.pendingTrips}',
              label: 'Đang chờ',
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.location_on,
              value: '${summary!.totalStops}',
              label: 'Tổng điểm dừng',
            ),
            _buildStatItem(
              icon: Icons.check_circle_outline,
              value: '${summary!.completedStops}',
              label: 'Hoàn thành',
            ),
            _buildStatItem(
              icon: Icons.trending_up,
              value: '${summary!.tripCompletionRate.toStringAsFixed(0)}%',
              label: 'Tỷ lệ hoàn thành',
            ),
          ],
        ),
        if (summary!.cancelledTrips > 0 || summary!.issuesEncountered > 0)
          Column(
            children: [
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (summary!.cancelledTrips > 0)
                    _buildStatItem(
                      icon: Icons.cancel,
                      value: '${summary!.cancelledTrips}',
                      label: 'Đã hủy',
                      color: Colors.red[300],
                    ),
                  if (summary!.issuesEncountered > 0)
                    _buildStatItem(
                      icon: Icons.warning,
                      value: '${summary!.issuesEncountered}',
                      label: 'Sự cố',
                      color: Colors.orange[300],
                    ),
                ],
              ),
            ],
          ),
        SizedBox(height: 16.h),
        // Progress bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tiến độ',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
                Text(
                  '${summary!.tripCompletionRate.toStringAsFixed(0)}%',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary!.tripCompletionRate / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8.h,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        // Additional stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniStat(
              Icons.location_on,
              '${summary!.completedStops}/${summary!.totalStops} điểm',
            ),
            _buildMiniStat(
              Icons.access_time,
              '${summary!.hoursWorked.toStringAsFixed(1)} giờ',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    Color? color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color ?? Colors.white, size: 32.r),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: AppTextStyles.headlineMedium.copyWith(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(color: (color ?? Colors.white).withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16.r),
        SizedBox(width: 4.w),
        Text(
          text,
          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}
