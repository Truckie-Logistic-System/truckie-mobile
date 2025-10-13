import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../presentation/common_widgets/skeleton_loader.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị trạng thái loading cho màn hình tài khoản
class AccountLoadingWidget extends StatelessWidget {
  const AccountLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User header skeleton
          Card(
            elevation: 2,
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Avatar skeleton
                      Shimmer.fromColors(
                        baseColor: AppColors.primary.withOpacity(0.7),
                        highlightColor: AppColors.primary.withOpacity(0.9),
                        child: Container(
                          width: 72.r,
                          height: 72.r,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name skeleton
                            Shimmer.fromColors(
                              baseColor: AppColors.primary.withOpacity(0.7),
                              highlightColor: AppColors.primary.withOpacity(
                                0.9,
                              ),
                              child: Container(
                                height: 24.h,
                                width: 150.w,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            ),
                            SizedBox(height: 8.h),
                            // Role skeleton
                            Shimmer.fromColors(
                              baseColor: AppColors.primary.withOpacity(0.7),
                              highlightColor: AppColors.primary.withOpacity(
                                0.9,
                              ),
                              child: Container(
                                height: 16.h,
                                width: 100.w,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Shimmer.fromColors(
                    baseColor: AppColors.primary.withOpacity(0.7),
                    highlightColor: AppColors.primary.withOpacity(0.9),
                    child: Container(
                      height: 40.h,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // User info skeleton
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(height: 24, width: 150),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Account actions skeleton
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(height: 24, width: 150),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 50),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Driver info skeleton
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLoader(height: 24, width: 150),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                  SizedBox(height: 16.h),
                  const SkeletonLoader(height: 20),
                ],
              ),
            ),
          ),
          SizedBox(height: 32.h),

          // Logout button skeleton
          const SkeletonLoader(height: 48),
        ],
      ),
    );
  }
}
