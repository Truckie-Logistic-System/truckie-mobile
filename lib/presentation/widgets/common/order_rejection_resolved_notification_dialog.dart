import 'package:flutter/material.dart';

/// Dialog hiển thị thông báo từ chối đơn hàng đã được xử lý
/// Hiển thị khi driver nhận được notification ORDER_REJECTION_RESOLVED
class OrderRejectionResolvedNotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String issueId;
  final String? staffName;
  final String? returnFee;
  final String? paymentStatus;
  final VoidCallback? onConfirm;

  const OrderRejectionResolvedNotificationDialog({
    Key? key,
    required this.title,
    required this.message,
    required this.issueId,
    this.staffName,
    this.returnFee,
    this.paymentStatus,
    this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine color scheme based on payment status
    final isPaid = paymentStatus == 'PAID' || paymentStatus == 'COMPLETED';
    final headerColor = isPaid ? Colors.green : Colors.orange;
    final iconColor = isPaid ? Colors.green : Colors.orange;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [headerColor.shade600, headerColor.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPaid ? Icons.check_circle_outline : Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPaid ? 'Đã xử lý trả hàng' : 'Thông báo trả hàng',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Message
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconColor.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: iconColor.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: iconColor.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        if (staffName != null) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Nhân viên xử lý: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                staffName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        if (returnFee != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.monetization_on_outlined,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Phí trả hàng: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                returnFee!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: iconColor.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],

                        if (paymentStatus != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                isPaid ? Icons.check_circle : Icons.schedule,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Trạng thái: ',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _getPaymentStatusText(paymentStatus!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isPaid ? Colors.green.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.directions_car_outlined,
                          color: Colors.blue.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isPaid 
                              ? 'Bạn có thể tiếp tục hành trình vận chuyển hàng trả về'
                              : 'Vui lòng đợi khách hàng thanh toán để tiếp tục',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  // Primary button - Confirm and navigate
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {

                        // Close dialog
                        Navigator.of(context).pop();
                        
                        // Call callback if provided
                        onConfirm?.call();
                        
                        // Wait a bit
                        await Future.delayed(const Duration(milliseconds: 300));
                        
                        // Navigate to navigation screen
                        if (context.mounted) {

                          Navigator.of(context).pushNamedAndRemoveUntil(
                            '/navigation',
                            (route) => false,
                            arguments: {
                              'orderId': null, // Navigation screen will find current active order
                              'isSimulationMode': true, // Auto-start simulation if paid
                            },
                          );
                        }
                      },
                      icon: Icon(isPaid ? Icons.navigation : Icons.refresh, size: 20),
                      label: Text(
                        isPaid ? 'Xác nhận và tiếp tục' : 'Làm mới',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: headerColor.shade600,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Secondary button - Close only
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      onPressed: () {

                        Navigator.of(context).pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  String _getPaymentStatusText(String status) {
    switch (status) {
      case 'PAID':
      case 'COMPLETED':
        return 'Đã thanh toán';
      case 'PENDING':
        return 'Chờ thanh toán';
      case 'REJECTED':
        return 'Đã từ chối';
      case 'TIMEOUT':
        return 'Hết hạn';
      default:
        return status;
    }
  }
}
