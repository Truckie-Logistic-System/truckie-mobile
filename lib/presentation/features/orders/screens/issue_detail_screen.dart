import 'package:flutter/material.dart';
import '../../../../app/di/service_locator.dart';
import '../../../../core/services/vietmap_service.dart';
import '../../../../domain/entities/order_detail.dart';
import '../../../theme/app_colors.dart';
import '../widgets/issue_detail/seal_replacement_detail_widget.dart';
import '../widgets/issue_detail/damage_detail_widget.dart';
import '../widgets/issue_detail/penalty_detail_widget.dart';
import '../widgets/issue_detail/order_rejection_detail_widget.dart';
import '../widgets/order_detail/issue_location_widget.dart';

/// Màn hình chi tiết vấn đề cho driver
/// Hiển thị thông tin linh hoạt theo loại issueCategory
/// Driver chỉ xem thông tin cần thiết, không có thông tin tài chính
class IssueDetailScreen extends StatelessWidget {
  final VehicleIssue issue;

  const IssueDetailScreen({
    Key? key,
    required this.issue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết vấn đề',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Issue info card - Common for all types
            _buildIssueInfoCard(context),
            const SizedBox(height: 16),

            // Category-specific details
            _buildCategorySpecificContent(context),
          ],
        ),
      ),
    );
  }

  /// Build common issue info card
  Widget _buildIssueInfoCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getIssueCategoryColor(issue.issueCategory)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: _getIssueCategoryColor(issue.issueCategory),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.issueTypeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (issue.issueTypeDescription != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          issue.issueTypeDescription!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getIssueStatusColor(issue.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getIssueStatusLabel(issue.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (issue.description.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Mô tả',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  issue.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],

            // Reported time
            if (issue.reportedAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Báo cáo lúc: ${_formatDateTime(issue.reportedAt!)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],

            // Location with reverse geocoding
            if (issue.locationLatitude != null &&
                issue.locationLongitude != null) ...[
              const SizedBox(height: 8),
              IssueLocationWidget(
                latitude: issue.locationLatitude!,
                longitude: issue.locationLongitude!,
                cachedAddress: _getCachedAddress(
                  issue.locationLatitude!,
                  issue.locationLongitude!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build content specific to issue category
  Widget _buildCategorySpecificContent(BuildContext context) {
    switch (issue.issueCategory) {
      case 'SEAL_REPLACEMENT':
        return SealReplacementDetailWidget(issue: issue);
      case 'DAMAGE':
        return DamageDetailWidget(issue: issue);
      case 'PENALTY':
        return PenaltyDetailWidget(issue: issue);
      case 'ORDER_REJECTION':
        return OrderRejectionDetailWidget(issue: issue);
      default:
        // For other types, show empty state or basic info
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Thông tin chi tiết',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vui lòng liên hệ với điều phối viên để biết thêm chi tiết về vấn đề này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  /// Get color based on issue category
  Color _getIssueCategoryColor(String category) {
    switch (category) {
      case 'ORDER_REJECTION':
        return Colors.red;
      case 'SEAL_REPLACEMENT':
        return Colors.orange;
      case 'DAMAGE':
        return Colors.deepOrange;
      case 'PENALTY':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  /// Get color based on issue status
  Color _getIssueStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return AppColors.primary;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'RESOLVED':
        return Colors.green;
      case 'PAYMENT_OVERDUE':
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  /// Get label for issue status
  String _getIssueStatusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Chờ xử lý';
      case 'IN_PROGRESS':
        return 'Đang xử lý';
      case 'RESOLVED':
        return 'Đã giải quyết';
      case 'PAYMENT_OVERDUE':
        return 'Quá hạn thanh toán';
      default:
        return status;
    }
  }

  /// Format DateTime to Vietnamese format
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Get cached address from VietMapService
  String? _getCachedAddress(double latitude, double longitude) {
    try {
      final vietMapService = getIt<VietMapService>();
      return vietMapService.getCachedAddress(latitude, longitude);
    } catch (e) {
      return null;
    }
  }
}
