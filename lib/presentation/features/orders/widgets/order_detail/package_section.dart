import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          child: Padding(
            padding: EdgeInsets.all(16.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin hàng hóa', style: AppTextStyles.titleMedium),
                SizedBox(height: 12.h),
                
                // Hiển thị tất cả order details của chuyến xe hiện tại
                if (currentOrderDetails.isNotEmpty) ...[
                  ...currentOrderDetails.asMap().entries.map((entry) {
                    final index = entry.key;
                    final orderDetail = entry.value;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index > 0) ...[
                          SizedBox(height: 16.h),
                          Divider(color: AppColors.border),
                          SizedBox(height: 12.h),
                        ],
                        _buildTrackingCodeRow(
                          context: context,
                          code: orderDetail.trackingCode,
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              Icons.description,
                              size: 16.r,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: Text(
                                'Mô tả: ${orderDetail.description}',
                                style: AppTextStyles.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Icon(
                              Icons.scale,
                              size: 16.r,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Trọng lượng: ${orderDetail.weightBaseUnit} ${orderDetail.unit}',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                      ],
                    );
                  }).toList(),
                ],
                
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.format_list_numbered,
                      size: 16.r,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Số lượng: ${currentOrderDetails.length}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
                if (currentOrderDetails.isNotEmpty && currentOrderDetails.first.orderSize != null) ...[
                  SizedBox(height: 16.h),
                  _buildSizeInfo(currentOrderDetails.first.orderSize!),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Widget hiển thị mã theo dõi order detail
  Widget _buildTrackingCodeRow({
    required BuildContext context,
    required String code,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.qr_code, size: 16.r, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mã theo dõi:',
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

  /// Widget hiển thị thông tin kích thước hàng hóa
  Widget _buildSizeInfo(OrderSize size) {
    // Format kích thước theo yêu cầu: min d x min r x min c - max d x max r x max c
    // d: chiều dài (length), r: chiều rộng (width), c: chiều cao (height)
    final minDimensions =
        '${size.minLength} x ${size.minWidth} x ${size.minHeight}';
    final maxDimensions =
        '${size.maxLength} x ${size.maxWidth} x ${size.maxHeight}';
    final dimensionsText = '$minDimensions - $maxDimensions cm';

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(Icons.straighten, size: 16.r, color: AppColors.textSecondary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'Kích thước: $dimensionsText',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
