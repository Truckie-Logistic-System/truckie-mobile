import 'package:flutter/material.dart';
import '../../../../../domain/entities/order_detail.dart';

/// Widget hiển thị chi tiết người nhận từ chối cho driver
/// Driver chỉ xem thông tin cơ bản, KHÔNG có thông tin về pricing/routing
class OrderRejectionDetailWidget extends StatelessWidget {
  final VehicleIssue issue;

  const OrderRejectionDetailWidget({
    Key? key,
    required this.issue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status-based info banner
        _buildStatusBanner(),
        const SizedBox(height: 16),

        // Affected packages
        if (issue.affectedOrderDetails != null) ...[
          _buildAffectedPackages(),
          const SizedBox(height: 16),
        ],

        // Transaction status (if available)
        if (issue.transaction != null) ...[
          _buildTransactionStatus(),
          const SizedBox(height: 16),
        ],

        // Issue images - Return delivery confirmation photos
        if (issue.issueImages.isNotEmpty) ...[
          _buildIssueImages(),
        ],
      ],
    );
  }

  /// Build status banner based on issue status
  Widget _buildStatusBanner() {
    IconData icon;
    Color color;
    String title;
    String description;

    switch (issue.status) {
      case 'OPEN':
        icon = Icons.hourglass_empty;
        color = Colors.orange;
        title = 'Chờ xử lý';
        description =
            'Người nhận đã từ chối nhận hàng. Nhân viên đang xử lý lộ trình trả hàng.';
        break;
      case 'IN_PROGRESS':
        // Check if payment has been made
        final hasTransaction = issue.transaction != null;
        if (hasTransaction) {
          final transactionStatus = issue.transaction?['status'] ?? '';
          // Check for both PAID and COMPLETED status (backend uses PAID)
          if (transactionStatus == 'PAID' || transactionStatus == 'COMPLETED') {
            icon = Icons.local_shipping;
            color = Colors.blue;
            title = 'Đang trả hàng về';
            description =
                'Khách hàng đã thanh toán phí trả hàng. Vui lòng xác nhận khi đã trả hàng xong.';
          } else {
            icon = Icons.payment;
            color = Colors.amber;
            title = 'Chờ thanh toán';
            description =
                'Đang chờ khách hàng thanh toán cước phí trả hàng.';
          }
        } else {
          icon = Icons.payment;
          color = Colors.amber;
          title = 'Chờ thanh toán';
          description =
              'Đang chờ khách hàng thanh toán cước phí trả hàng.';
        }
        break;
      case 'RESOLVED':
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'Đã hoàn thành';
        description = 'Đã xác nhận trả hàng về điểm lấy hàng thành công.';
        break;
      case 'PAYMENT_OVERDUE':
        icon = Icons.warning_amber_rounded;
        color = Colors.red;
        title = 'Quá hạn thanh toán';
        description =
            'Khách hàng đã quá thời gian thanh toán phí trả hàng. Vui lòng liên hệ điều phối viên.';
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
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

  /// Build affected packages list
  Widget _buildAffectedPackages() {
    final packages = issue.affectedOrderDetails;
    if (packages == null) return const SizedBox.shrink();

    // Parse the packages - could be a list or a single item
    List<dynamic> packageList = [];
    if (packages is List) {
      packageList = packages;
    } else if (packages is Map) {
      packageList = [packages];
    }

    if (packageList.isEmpty) return const SizedBox.shrink();

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kiện hàng cần trả (${packageList.length} kiện)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Package list
            ...packageList.asMap().entries.map((entry) {
              final index = entry.key;
              final pkg = entry.value;
              final trackingCode = pkg['trackingCode'] ?? 'N/A';
              final description = pkg['description'];
              final weight = pkg['weightBaseUnit'];
              final unit = pkg['unit'] ?? 'kg';

              return Container(
                margin: EdgeInsets.only(bottom: index < packageList.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tracking code
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trackingCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (weight != null) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$weight $unit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  /// Build transaction status
  Widget _buildTransactionStatus() {
    final transaction = issue.transaction;
    if (transaction == null) return const SizedBox.shrink();

    final status = transaction['status'] ?? '';
    final amount = transaction['amount'];

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'COMPLETED':
        statusColor = Colors.green;
        statusLabel = 'Đã thanh toán';
        statusIcon = Icons.check_circle;
        break;
      case 'PENDING':
        statusColor = Colors.orange;
        statusLabel = 'Chờ thanh toán';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'FAILED':
        statusColor = Colors.red;
        statusLabel = 'Thanh toán thất bại';
        statusIcon = Icons.error;
        break;
      default:
        statusColor = Colors.grey;
        statusLabel = status;
        statusIcon = Icons.info;
    }

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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payment,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Trạng thái thanh toán',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (status == 'COMPLETED' && issue.paymentDeadline != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Khách hàng đã thanh toán. Bạn có thể bắt đầu trả hàng.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build issue images section (return delivery confirmation photos)
  Widget _buildIssueImages() {
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Ảnh xác nhận trả hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Image grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: issue.issueImages.length,
              itemBuilder: (context, index) {
                final imageUrl = issue.issueImages[index];
                return GestureDetector(
                  onTap: () {
                    // Show full-screen image
                    _showFullImage(context, imageUrl, index);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 48,
                                  ),
                                ),
                              );
                            },
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}/${issue.issueImages.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show full-screen image
  void _showFullImage(BuildContext context, String imageUrl, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              'Ảnh ${initialIndex + 1}/${issue.issueImages.length}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          body: PageView.builder(
            itemCount: issue.issueImages.length,
            controller: PageController(initialPage: initialIndex),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    issue.issueImages[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image,
                          color: Colors.white,
                          size: 64,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
