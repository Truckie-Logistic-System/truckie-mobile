import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';
import 'driver_info.dart';

/// Widget hiển thị thông tin Vehicle Assignment (xe và tài xế)
class OrderDetailsSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const OrderDetailsSection({super.key, required this.order});

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
        VehicleAssignment? vehicleAssignment;
        try {
          vehicleAssignment = order.vehicleAssignments.firstWhere(
            (va) {
              if (va.primaryDriver == null) return false;
              return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
            },
          );
        } catch (e) {
          // Fallback: try to find by orderDetail vehicleAssignmentId
          final vehicleAssignmentId = order.orderDetails.first.vehicleAssignmentId;
          if (vehicleAssignmentId != null) {
            try {
              vehicleAssignment = order.vehicleAssignments.firstWhere(
                (va) => va.id == vehicleAssignmentId,
              );
            } catch (e) {
              vehicleAssignment = null;
            }
          }
        }
        
        if (vehicleAssignment == null) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Text(
                'Chưa có thông tin phân công xe',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }

        return _buildVehicleAssignmentCard(context, vehicleAssignment);
      },
    );
  }

  Widget _buildVehicleAssignmentCard(
    BuildContext context,
    VehicleAssignment vehicleAssignment,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: _buildVehicleAssignmentSection(context, vehicleAssignment),
      ),
    );
  }

  Widget _buildVehicleAssignmentSection(
    BuildContext context,
    VehicleAssignment vehicleAssignment,
  ) {
    final vehicle = vehicleAssignment.vehicle;
    final primaryDriver = vehicleAssignment.primaryDriver;
    final secondaryDriver = vehicleAssignment.secondaryDriver;

    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        // Use phone number for reliable matching (ID có thể khác giữa auth và order response)
        final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
        final isPrimaryDriver =
            primaryDriver != null && 
            currentUserPhone != null &&
            currentUserPhone.isNotEmpty &&
            primaryDriver.phoneNumber.isNotEmpty &&
            currentUserPhone.trim() == primaryDriver.phoneNumber.trim();
        final isSecondaryDriver =
            secondaryDriver != null && 
            currentUserPhone != null &&
            currentUserPhone.isNotEmpty &&
            secondaryDriver.phoneNumber.isNotEmpty &&
            currentUserPhone.trim() == secondaryDriver.phoneNumber.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mã chuyến xe
            Row(
              children: [
                Icon(Icons.local_shipping, size: 20.r, color: AppColors.primary),
                SizedBox(width: 8.w),
                Text('Thông tin chuyến xe', style: AppTextStyles.titleMedium),
              ],
            ),
            SizedBox(height: 12.h),

            // Tracking code của vehicle assignment
            _buildTrackingCodeDisplay(
              context: context,
              code: vehicleAssignment.trackingCode,
            ),

            if (vehicle != null) ...[
              SizedBox(height: 12.h),
              
              // Thông tin xe
              _buildInfoRow(
                icon: Icons.directions_car,
                label: 'Biển số xe:',
                value: vehicle.licensePlateNumber,
              ),
              SizedBox(height: 8.h),
              _buildInfoRow(
                icon: Icons.car_repair,
                label: 'Loại xe:',
                value: vehicle.vehicleTypeDescription ?? vehicle.vehicleType,
              ),
              SizedBox(height: 8.h),
              _buildInfoRow(
                icon: Icons.info_outline,
                label: 'Hãng xe:',
                value: '${vehicle.manufacturer} ${vehicle.model}',
              ),
            ],

            SizedBox(height: 16.h),

            // Thông tin tài xế
            Text('Tài xế phụ trách', style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            )),
            SizedBox(height: 8.h),

            if (primaryDriver != null) ...[
              DriverInfo(
                role: 'Tài xế chính',
                driver: primaryDriver,
                isHighlighted: isPrimaryDriver,
                isCurrentUser: isPrimaryDriver,
              ),
              if (secondaryDriver != null) SizedBox(height: 8.h),
            ],

            if (secondaryDriver != null) ...[
              DriverInfo(
                role: 'Tài xế phụ',
                driver: secondaryDriver,
                isHighlighted: isSecondaryDriver,
                isCurrentUser: isSecondaryDriver,
              ),
            ],

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
        );
      },
    );
  }

  Widget _buildTrackingCodeDisplay({
    required BuildContext context,
    required String code,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.route, size: 16.r, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã chuyến xe:',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        code,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontFamily: 'Courier',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép: $code'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(Icons.copy, color: Colors.white, size: 20.r),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.r, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium,
              children: [
                TextSpan(
                  text: label,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(text: ' $value'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
