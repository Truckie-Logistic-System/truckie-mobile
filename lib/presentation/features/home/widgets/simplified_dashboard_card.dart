import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../theme/app_colors.dart';
import '../../../../data/models/driver_dashboard_model.dart';

/// Card hiển thị dashboard đơn giản với 5 chỉ số chính
class SimplifiedDashboardCard extends StatelessWidget {
  final DriverDashboardModel? dashboard;
  final bool isLoading;
  final String periodLabel;

  const SimplifiedDashboardCard({
    super.key,
    this.dashboard,
    this.isLoading = false,
    this.periodLabel = 'Hôm nay',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildSkeleton();
    }

    if (dashboard == null) {
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with period
          Row(
            children: [
              Icon(
                Icons.dashboard_outlined,
                color: AppColors.primary,
                size: 20.w,
              ),
              SizedBox(width: 8.w),
              Text(
                'Tổng quan $periodLabel',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Key metrics grid
          Row(
            children: [
              // Completed trips
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                  title: 'Chuyến hoàn thành',
                  value: dashboard!.completedTripsCount.toString(),
                  subtitle: 'chuyến',
                ),
              ),
              SizedBox(width: 12.w),

              // Incidents
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.warning,
                  iconColor: AppColors.warning,
                  title: 'Sự cố',
                  value: dashboard!.incidentsCount.toString(),
                  subtitle: 'sự cố',
                ),
              ),
              SizedBox(width: 12.w),

              // Traffic violations
              Expanded(
                child: _buildMetricCard(
                  icon: Icons.gavel_outlined,
                  iconColor: AppColors.error,
                  title: 'Vi phạm giao thông',
                  value: dashboard!.trafficViolationsCount.toString(),
                  subtitle: 'vi phạm',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24.w,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
            ),
          ),
        ],
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
            color: Colors.black.withOpacity(0.05),
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
                width: 120.w,
                height: 16.h,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Metrics skeleton
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  height: 80.h,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.dashboard_outlined,
              color: Colors.grey[400],
              size: 48.w,
            ),
            SizedBox(height: 16.h),
            Text(
              'Không có dữ liệu',
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
