import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_with_details.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin mã theo dõi
class TrackingCodeSection extends StatelessWidget {
  /// Đối tượng chứa thông tin đơn hàng
  final OrderWithDetails order;

  const TrackingCodeSection({Key? key, required this.order}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (order.orderDetails.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderDetail = order.orderDetails.first;
    final trackingCode = orderDetail.trackingCode;
    final vehicleAssignment = orderDetail.vehicleAssignment;
    final tripTrackingCode = vehicleAssignment?.trackingCode;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mã theo dõi', style: AppTextStyles.titleMedium),
            SizedBox(height: 12.h),

            // Mã theo dõi đơn hàng
            _buildTrackingCodeRow(
              context: context,
              icon: Icons.qr_code,
              label: 'Mã đơn hàng:',
              code: trackingCode,
            ),

            // Mã theo dõi chuyến xe
            if (tripTrackingCode != null && tripTrackingCode.isNotEmpty) ...[
              SizedBox(height: 12.h),
              _buildTrackingCodeRow(
                context: context,
                icon: Icons.local_shipping,
                label: 'Mã chuyến xe:',
                code: tripTrackingCode,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingCodeRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String code,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16.r, color: AppColors.textSecondary),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
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
}
