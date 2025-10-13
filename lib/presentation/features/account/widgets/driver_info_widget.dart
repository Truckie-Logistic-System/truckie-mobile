import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/driver.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin tài xế
class DriverInfoWidget extends StatelessWidget {
  final Driver driver;
  final VoidCallback onEdit;

  const DriverInfoWidget({
    super.key,
    required this.driver,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.drive_eta, color: AppColors.primary, size: 24.r),
                    SizedBox(width: 8.w),
                    Text(
                      'Thông tin tài xế',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: AppColors.primary, size: 20.r),
                  onPressed: onEdit,
                  tooltip: 'Chỉnh sửa thông tin',
                ),
              ],
            ),
            SizedBox(height: 16.h),

            // Thông tin giấy phép
            _buildDriverInfoSection('Thông tin giấy phép', [
              _buildInfoItem(
                Icons.badge,
                'Số CMND/CCCD',
                driver.identityNumber,
              ),
              const Divider(),
              _buildInfoItem(
                Icons.credit_card,
                'Số GPLX',
                driver.driverLicenseNumber,
              ),
              const Divider(),
              _buildInfoItem(
                Icons.confirmation_number,
                'Số seri',
                driver.cardSerialNumber,
              ),
            ]),

            SizedBox(height: 16.h),

            // Chi tiết giấy phép
            _buildDriverInfoSection('Chi tiết giấy phép', [
              _buildInfoItem(
                Icons.location_city,
                'Nơi cấp',
                driver.placeOfIssue,
              ),
              const Divider(),
              _buildInfoItem(
                Icons.calendar_today,
                'Ngày cấp',
                dateFormat.format(driver.dateOfIssue),
              ),
              const Divider(),
              _buildInfoItem(
                Icons.event_busy,
                'Ngày hết hạn',
                dateFormat.format(driver.dateOfExpiry),
              ),
              const Divider(),
              _buildInfoItem(Icons.class_, 'Hạng bằng', driver.licenseClass),
              const Divider(),
              _buildInfoItem(
                Icons.date_range,
                'Ngày sát hạch',
                dateFormat.format(driver.dateOfPassing),
              ),
            ]),

            SizedBox(height: 16.h),

            // Trạng thái
            Container(
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              decoration: BoxDecoration(
                color: driver.status.toLowerCase() == "active"
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: driver.status.toLowerCase() == "active"
                      ? Colors.green.withOpacity(0.3)
                      : Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: driver.status.toLowerCase() == "active"
                        ? Colors.green
                        : Colors.orange,
                    size: 20.r,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Trạng thái: ${driver.status}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                      color: driver.status.toLowerCase() == "active"
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget hiển thị một phần thông tin tài xế
  Widget _buildDriverInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// Widget hiển thị một dòng thông tin
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20.r),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value.isEmpty ? 'Chưa cập nhật' : value,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
