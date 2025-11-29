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

  const VehicleSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.orderDetails.isEmpty || order.vehicleAssignments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        // Get current user phone number
        final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
        if (currentUserPhone == null || currentUserPhone.isEmpty) {
          return const SizedBox.shrink();
        }

        // For multi-trip orders: Find the vehicle assignment where current user is primary driver
        final vehicleAssignment = order.vehicleAssignments.cast<VehicleAssignment?>().firstWhere(
          (va) {
            if (va == null) return false;
            final primaryDriver = va.primaryDriver;
            if (primaryDriver == null) return false;
            return currentUserPhone.trim() == primaryDriver.phoneNumber.trim();
          },
          orElse: () => null,
        );

        if (vehicleAssignment == null || vehicleAssignment.vehicle == null) {
          return const SizedBox.shrink();
        }

        final vehicle = vehicleAssignment.vehicle!;
        final primaryDriver = vehicleAssignment.primaryDriver;
        final secondaryDriver = vehicleAssignment.secondaryDriver;

        // Use phone number for reliable matching (ID có thể khác giữa auth và order response)
        final isPrimaryDriver =
            primaryDriver != null && 
            currentUserPhone.isNotEmpty &&
            primaryDriver.phoneNumber.isNotEmpty &&
            currentUserPhone.trim() == primaryDriver.phoneNumber.trim();
        final isSecondaryDriver =
            secondaryDriver != null && 
            currentUserPhone.isNotEmpty &&
            secondaryDriver.phoneNumber.isNotEmpty &&
            currentUserPhone.trim() == secondaryDriver.phoneNumber.trim();

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
                        'Loại xe: ${vehicle.vehicleTypeDescription ?? vehicle.vehicleType}',
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
