import 'package:flutter/material.dart';
import '../../domain/entities/issue.dart';

/// Dialog showing while waiting for staff to resolve issue
/// Displays loading indicator - CANNOT be dismissed by user
/// Driver must wait for staff resolution
class WaitingForResolutionDialog extends StatelessWidget {
  final IssueCategory issueCategory;
  final int? pollCount;
  final int? maxPolls;

  const WaitingForResolutionDialog({
    Key? key,
    required this.issueCategory,
    this.pollCount,
    this.maxPolls,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final progress = pollCount != null && maxPolls != null
        ? pollCount! / maxPolls!
        : null;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button dismiss
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loading indicator
            Stack(
              alignment: Alignment.center,
              children: [
                if (progress != null)
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue.shade600,
                      ),
                    ),
                  ),
                Icon(
                  _getIconForCategory(issueCategory),
                  size: 40,
                  color: Colors.blue.shade600,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Đang chờ xử lý',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              _getDescriptionForCategory(issueCategory),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            if (pollCount != null && maxPolls != null) ...[
              const SizedBox(height: 12),
              Text(
                'Đang kiểm tra... (${_formatTime(pollCount!, maxPolls!)})',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
        // ❌ NO ACTIONS - Driver cannot cancel or dismiss
        // Must wait for staff resolution or timeout
      ),
    );
  }

  IconData _getIconForCategory(IssueCategory category) {
    switch (category) {
      case IssueCategory.reroute:
        return Icons.route;
      case IssueCategory.damage:
        return Icons.broken_image;
      case IssueCategory.orderRejection:
        return Icons.cancel;
      case IssueCategory.sealReplacement:
        return Icons.lock_open;
      case IssueCategory.penalty:
        return Icons.local_police;
      case IssueCategory.accident:
        return Icons.car_crash;
      case IssueCategory.missingItems:
        return Icons.inventory_2;
      case IssueCategory.wrongItems:
        return Icons.error_outline;
      case IssueCategory.general:
        return Icons.report_problem;
      case IssueCategory.offRouteRunaway:
        return Icons.gps_off;
    }
  }

  String _getDescriptionForCategory(IssueCategory category) {
    switch (category) {
      case IssueCategory.reroute:
        return 'Nhân viên đang tạo lộ trình mới cho bạn. Vui lòng đợi trong giây lát...';
      case IssueCategory.damage:
        return 'Nhân viên đang xác minh và xử lý sự cố hư hỏng. Vui lòng đợi trong giây lát...';
      case IssueCategory.orderRejection:
        return 'Đang chờ khách hàng thanh toán phí trả hàng. Vui lòng đợi...';
      case IssueCategory.sealReplacement:
        return 'Nhân viên đang xử lý và gán seal mới. Vui lòng đợi trong giây lát...';
      case IssueCategory.penalty:
        return 'Nhân viên đang xác minh và xử lý vi phạm giao thông. Vui lòng đợi...';
      case IssueCategory.accident:
        return 'Nhân viên đang xác minh và xử lý sự cố tai nạn. Vui lòng đợi trong giây lát...';
      case IssueCategory.missingItems:
        return 'Nhân viên đang xác minh và xử lý sự cố thiếu hàng. Vui lòng đợi...';
      case IssueCategory.wrongItems:
        return 'Nhân viên đang xác minh và xử lý sự cố sai hàng. Vui lòng đợi...';
      case IssueCategory.general:
        return 'Nhân viên đang xử lý sự cố của bạn. Vui lòng đợi trong giây lát...';
      case IssueCategory.offRouteRunaway:
        return 'Nhân viên đang xác minh tài xế đi lệch tuyến. Vui lòng đợi trong giây lát...';
    }
  }

  String _formatTime(int current, int max) {
    final remainingPolls = max - current;
    final remainingSeconds = remainingPolls * 5; // 5s per poll
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '~${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Timeout dialog when staff doesn't resolve within time limit
class ResolutionTimeoutDialog extends StatelessWidget {
  final IssueCategory issueCategory;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ResolutionTimeoutDialog({
    Key? key,
    required this.issueCategory,
    this.onRetry,
    this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time,
              size: 48,
              color: Colors.orange.shade600,
            ),
          ),
          
          const SizedBox(height: 20),
          
          const Text(
            '⏰ Chưa nhận được phản hồi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Nhân viên chưa xử lý sự cố trong thời gian quy định. '
            'Bạn có thể tiếp tục công việc và chờ thông báo sau.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ElevatedButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }
}
