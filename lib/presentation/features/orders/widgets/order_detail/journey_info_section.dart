import 'package:flutter/material.dart';

import '../../../../../core/utils/responsive_extensions.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

/// Widget hiển thị thông tin journey (khoảng cách, phí cầu đường, v.v.)
class JourneyInfoSection extends StatelessWidget {
  /// Danh sách journey histories
  final List<JourneyHistory> journeyHistories;

  const JourneyInfoSection({super.key, required this.journeyHistories});

  @override
  Widget build(BuildContext context) {
    if (journeyHistories.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get the first (initial) journey
    final journey = journeyHistories.first;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.route, size: 20.r, color: AppColors.primary),
                SizedBox(width: 8.w),
                Text('Thông tin lộ trình', style: AppTextStyles.titleMedium),
              ],
            ),
            SizedBox(height: 12.h),

            // Journey info grid
            _buildInfoGrid(journey),

            // Journey segments if available
            if (journey.journeySegments.isNotEmpty) ...[
              SizedBox(height: 16.h),
              _buildSegmentsSection(journey.journeySegments),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(JourneyHistory journey) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12.h,
      crossAxisSpacing: 12.w,
      childAspectRatio: 1.2,
      children: [
        _buildInfoCard(
          icon: Icons.straighten,
          label: 'Khoảng cách',
          value: '${journey.totalDistance ?? 0} km',
          color: Colors.blue,
        ),
        _buildInfoCard(
          icon: Icons.toll,
          label: 'Số trạm thu phí',
          value: '${journey.totalTollCount ?? 0}',
          color: Colors.orange,
        ),
        _buildInfoCard(
          icon: Icons.attach_money,
          label: 'Phí cầu đường',
          value: '${(journey.totalTollFee).toStringAsFixed(0)} đ',
          color: Colors.green,
        ),
        _buildInfoCard(
          icon: Icons.info_outline,
          label: 'Trạng thái',
          value: _getStatusLabel(journey.status),
          color: _getStatusColor(journey.status),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24.r, color: color),
          SizedBox(height: 6.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentsSection(List<JourneySegment> segments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chi tiết các đoạn lộ trình',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: segments.length,
          separatorBuilder: (context, index) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            final segment = segments[index];
            return _buildSegmentItem(segment, index + 1);
          },
        ),
      ],
    );
  }

  Widget _buildSegmentItem(JourneySegment segment, int order) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Order number
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$order',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          // Segment info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_translatePointName(segment.startPointName)} → ${_translatePointName(segment.endPointName)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${segment.distanceMeters} km',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getSegmentStatusColor(segment.status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Text(
              _getSegmentStatusLabel(segment.status),
              style: AppTextStyles.bodySmall.copyWith(
                color: _getSegmentStatusColor(segment.status),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'ACTIVE':
        return 'Đang hoạt động';
      case 'PENDING':
        return 'Chờ xử lý';
      case 'COMPLETED':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  Color _getSegmentStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getSegmentStatusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Chờ xử lý';
      case 'IN_PROGRESS':
        return 'Đang thực hiện';
      case 'COMPLETED':
        return 'Hoàn thành';
      default:
        return status;
    }
  }

  /// Dịch tên điểm từ tiếng Anh sang tiếng Việt
  String _translatePointName(String pointName) {
    final translations = {
      'Carrier': 'Kho hàng',
      'Pickup': 'Lấy hàng',
      'Delivery': 'Giao hàng',
      'carrier': 'Kho hàng',
      'pickup': 'Lấy hàng',
      'delivery': 'Giao hàng',
    };
    
    return translations[pointName] ?? pointName;
  }
}
