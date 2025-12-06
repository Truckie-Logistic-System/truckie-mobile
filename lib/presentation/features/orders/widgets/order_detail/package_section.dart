import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/utils/order_detail_status_helper.dart';
import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/features/auth/viewmodels/auth_viewmodel.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin hàng hóa
class PackageSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const PackageSection({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, _) {
        // Get current user phone number
        final currentUserPhone = authViewModel.driver?.userResponse.phoneNumber;
        
        // For multi-trip orders: Find all order details that belong to current driver's vehicle assignment
        List<OrderDetail> currentOrderDetails = [];
        if (currentUserPhone != null && currentUserPhone.isNotEmpty && order.vehicleAssignments.isNotEmpty) {
          try {
            // Find vehicle assignment where current user is primary driver
            final vehicleAssignment = order.vehicleAssignments.firstWhere(
              (va) {
                if (va.primaryDriver == null) return false;
                return currentUserPhone.trim() == va.primaryDriver!.phoneNumber.trim();
              },
            );
            
            // Find ALL order details that belong to this vehicle assignment
            currentOrderDetails = order.orderDetails
                .where((od) => od.vehicleAssignmentId == vehicleAssignment.id)
                .toList();
          } catch (e) {
            // Fallback to all order details
            currentOrderDetails = order.orderDetails;
          }
        } else {
          // Fallback to all order details
          currentOrderDetails = order.orderDetails;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.inventory_2, color: Colors.white, size: 24.r),
                  SizedBox(width: 12.w),
                  Text(
                    'Danh sách hàng hóa',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      '${currentOrderDetails.length} kiện',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            
            // Hiển thị tất cả order details của chuyến xe hiện tại
            if (currentOrderDetails.isNotEmpty) ...[
              ...currentOrderDetails.asMap().entries.map((entry) {
                final index = entry.key;
                final orderDetail = entry.value;
                return Column(
                  children: [
                    if (index > 0) SizedBox(height: 12.h),
                    _buildPackageCard(context, orderDetail, index + 1),
                  ],
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  /// Widget hiển thị card của từng package
  Widget _buildPackageCard(
    BuildContext context,
    OrderDetail orderDetail,
    int packageNumber,
  ) {
    final statusColor = OrderDetailStatusHelper.getStatusColor(orderDetail.status);
    final statusText = OrderDetailStatusHelper.getStatusText(orderDetail.status);
    final statusIcon = OrderDetailStatusHelper.getStatusIcon(orderDetail.status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge header
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10.r),
                topRight: Radius.circular(10.r),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: Colors.white, size: 20.r),
                SizedBox(width: 8.w),
                Text(
                  statusText,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Kiện #$packageNumber',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Package details
          Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tracking code
                _buildInfoRow(
                  context: context,
                  icon: Icons.qr_code_2,
                  label: 'Mã theo dõi',
                  value: orderDetail.trackingCode,
                  isCopyable: true,
                ),
                SizedBox(height: 12.h),
                
                // Description
                _buildInfoRow(
                  context: context,
                  icon: Icons.description,
                  label: 'Mô tả',
                  value: orderDetail.description,
                ),
                SizedBox(height: 12.h),
                
                // Weight
                _buildInfoRow(
                  context: context,
                  icon: Icons.monitor_weight,
                  label: 'Trọng lượng',
                  value: '${orderDetail.weightBaseUnit} ${orderDetail.unit}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget hiển thị thông tin dạng row
  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool isCopyable = false,
  }) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              size: 20.r,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (isCopyable) ...[
            SizedBox(width: 8.w),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã sao chép: $value'),
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
                child: Icon(Icons.copy, color: Colors.white, size: 18.r),
              ),
            ),
          ],
        ],
      ),
    );
  }

}
