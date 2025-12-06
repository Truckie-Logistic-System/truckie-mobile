import 'package:flutter/material.dart';
import '../../../../../domain/entities/order_detail.dart';
import '../../../../theme/app_colors.dart';

/// Widget hiển thị chi tiết thay thế seal cho driver
/// Driver chỉ xem thông tin, không có quyền thao tác
class SealReplacementDetailWidget extends StatelessWidget {
  final VehicleIssue issue;

  const SealReplacementDetailWidget({
    Key? key,
    required this.issue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status message based on issue status
        _buildStatusMessage(),
        const SizedBox(height: 16),

        // Seal comparison card - show both seals side by side
        _buildSealComparisonCard(context),
      ],
    );
  }

  /// Build seal comparison card showing old and new seal side by side
  Widget _buildSealComparisonCard(BuildContext context) {
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_alt,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thông tin seal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Seals comparison row
            Row(
              children: [
                // Old seal
                if (issue.oldSeal != null)
                  Expanded(
                    child: _buildCompactSealInfo(
                      label: 'Seal cũ',
                      sealCode: issue.oldSeal?['sealCode'] ?? 'N/A',
                      imageUrl: issue.sealRemovalImage,
                      color: Colors.red,
                      icon: Icons.lock_open,
                      context: context,
                    ),
                  ),

                // Arrow separator
                if (issue.oldSeal != null && issue.newSeal != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.grey,
                      size: 24,
                    ),
                  ),
                ],

                // New seal
                if (issue.newSeal != null)
                  Expanded(
                    child: _buildCompactSealInfo(
                      label: 'Seal mới',
                      sealCode: issue.newSeal?['sealCode'] ?? 'N/A',
                      imageUrl: issue.newSealAttachedImage,
                      color: Colors.green,
                      icon: Icons.lock,
                      context: context,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build compact seal info for side-by-side display
  Widget _buildCompactSealInfo({
    required String label,
    required String sealCode,
    String? imageUrl,
    required Color color,
    required IconData icon,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label with icon
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Seal code
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              sealCode,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Image thumbnail
          if (imageUrl != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Show full screen image
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                        backgroundColor: Colors.black,
                        iconTheme: const IconThemeData(color: Colors.white),
                        title: Text(
                          label,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      body: Center(
                        child: InteractiveViewer(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(
                  children: [
                    Image.network(
                      imageUrl,
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 80,
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 80,
                          color: Colors.grey[200],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                size: 24,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Lỗi tải ảnh',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // Tap to view indicator
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 12,
                            ),
                            SizedBox(width: 2),
                            Text(
                              'Xem',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build status message based on issue status
  Widget _buildStatusMessage() {
    IconData icon;
    Color color;
    String title;
    String description;

    switch (issue.status) {
      case 'OPEN':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        title = 'Chờ xử lý';
        description =
            'Seal đã bị gỡ. Vui lòng đợi nhân viên gán seal mới để tiếp tục.';
        break;
      case 'IN_PROGRESS':
        icon = Icons.autorenew;
        color = Colors.blue;
        title = 'Seal mới đã được gán';
        description = 'Vui lòng gắn seal mới và xác nhận để hoàn thành.';
        break;
      case 'RESOLVED':
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'Đã hoàn thành';
        description = 'Seal mới đã được gắn thành công. Chuyến xe có thể tiếp tục.';
        break;
      default:
        icon = Icons.info;
        color = AppColors.primary;
        title = 'Thông tin';
        description = 'Vui lòng liên hệ điều phối viên để biết thêm chi tiết.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
