import 'package:flutter/material.dart';

import '../../../../core/utils/responsive_extensions.dart';
import '../../../../presentation/theme/app_colors.dart';

class DeliveryProgressWidget extends StatelessWidget {
  final String remainingTime;
  final String distance;
  final double progress;

  const DeliveryProgressWidget({
    super.key,
    required this.remainingTime,
    required this.distance,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      color: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đang giao hàng',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.white, size: 16.r),
              SizedBox(width: 8.w),
              Text(
                'Thời gian còn lại: $remainingTime',
                style: TextStyle(color: Colors.white, fontSize: 14.sp),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white, size: 12.r),
                    SizedBox(width: 4.w),
                    Text(
                      distance,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white30,
            color: Colors.white,
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã lấy hàng',
                style: TextStyle(color: Colors.white, fontSize: 12.sp),
              ),
              Text(
                'Đang giao',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Đã giao hàng',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
