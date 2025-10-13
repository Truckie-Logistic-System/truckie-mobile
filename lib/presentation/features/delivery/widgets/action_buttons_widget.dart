import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';

class ActionButtonsWidget extends StatelessWidget {
  final VoidCallback onViewMapPressed;
  final VoidCallback onCompleteDeliveryPressed;
  final VoidCallback onReportIssuePressed;

  const ActionButtonsWidget({
    super.key,
    required this.onViewMapPressed,
    required this.onCompleteDeliveryPressed,
    required this.onReportIssuePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onViewMapPressed,
          icon: Icon(Icons.map, size: 20.r),
          label: const Text('Xem bản đồ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 48.h),
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
        SizedBox(height: 12.h),
        ElevatedButton.icon(
          onPressed: onCompleteDeliveryPressed,
          icon: Icon(Icons.check_circle, size: 20.r),
          label: const Text('Hoàn thành giao hàng'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            minimumSize: Size(double.infinity, 48.h),
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
        SizedBox(height: 12.h),
        OutlinedButton.icon(
          onPressed: onReportIssuePressed,
          icon: Icon(Icons.report_problem, size: 20.r),
          label: const Text('Báo cáo vấn đề'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error, width: 1.5.w),
            minimumSize: Size(double.infinity, 48.h),
            padding: EdgeInsets.symmetric(vertical: 12.h),
          ),
        ),
      ],
    );
  }
}
