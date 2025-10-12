import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import 'driver_info.dart';

/// Widget hiển thị thông tin phương tiện và tài xế
class VehicleSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const VehicleSection({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (order.orderDetails.isEmpty ||
        order.orderDetails.first.vehicleAssignment == null ||
        order.orderDetails.first.vehicleAssignment!.vehicle == null) {
      return const SizedBox.shrink();
    }

    final vehicleAssignment = order.orderDetails.first.vehicleAssignment!;
    final vehicle = vehicleAssignment.vehicle!;
    final primaryDriver = vehicleAssignment.primaryDriver;
    final secondaryDriver = vehicleAssignment.secondaryDriver;

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        // Kiểm tra xem người dùng hiện tại có phải là tài xế của đơn hàng này không
        final currentUserId = authViewModel.driver?.id;
        final isPrimaryDriver =
            primaryDriver != null && primaryDriver.id == currentUserId;
        final isSecondaryDriver =
            secondaryDriver != null && secondaryDriver.id == currentUserId;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin phương tiện', style: AppTextStyles.titleMedium),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      size: 16.r,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Biển số: ${vehicle.licensePlateNumber}',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.car_repair,
                      size: 16.r,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Loại xe: ${vehicle.vehicleType}',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16.r,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Hãng xe: ${vehicle.manufacturer} ${vehicle.model}',
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Text('Thông tin tài xế', style: AppTextStyles.titleMedium),
                SizedBox(height: 12.h),

                // Hiển thị tài xế chính
                if (primaryDriver != null) ...[
                  DriverInfo(
                    role: 'Tài xế chính',
                    driver: primaryDriver,
                    isHighlighted: isPrimaryDriver,
                    isCurrentUser: isPrimaryDriver,
                  ),
                  SizedBox(height: 12.h),
                ],

                // Hiển thị tài xế phụ nếu có
                if (secondaryDriver != null) ...[
                  DriverInfo(
                    role: 'Tài xế phụ',
                    driver: secondaryDriver,
                    isHighlighted: isSecondaryDriver,
                    isCurrentUser: isSecondaryDriver,
                  ),
                ],

                // Hiển thị thông báo nếu không có tài xế nào
                if (primaryDriver == null && secondaryDriver == null) ...[
                  Text(
                    'Chưa có thông tin tài xế',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
