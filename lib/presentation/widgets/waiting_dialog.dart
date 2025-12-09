import 'package:flutter/material.dart';

/// Generic waiting dialog for various waiting scenarios
/// Used for seal assignment and return payment waiting
class WaitingDialog extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;

  const WaitingDialog({
    Key? key,
    required this.title,
    required this.description,
    this.icon = Icons.hourglass_empty,
    this.iconColor = Colors.blue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            // Loading indicator with icon
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                  ),
                ),
                Icon(
                  icon,
                  size: 40,
                  color: iconColor,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
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
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        // ❌ NO ACTIONS - User cannot cancel or dismiss
        // Must wait for completion
      ),
    );
  }
}

/// Waiting dialog specifically for seal assignment
class WaitingSealAssignmentDialog extends StatelessWidget {
  const WaitingSealAssignmentDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WaitingDialog(
      title: 'Đang chờ nhân viên',
      description: 'Nhân viên đang xử lý và gán seal mới. Vui lòng đợi trong giây lát...',
      icon: Icons.lock_open,
      iconColor: Colors.blue.shade600,
    );
  }
}

/// Waiting dialog specifically for return payment
class WaitingReturnPaymentDialog extends StatelessWidget {
  const WaitingReturnPaymentDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WaitingDialog(
      title: 'Đang chờ thanh toán',
      description: 'Đang chờ khách hàng thanh toán cước trả hàng. Vui lòng đợi...',
      icon: Icons.payment,
      iconColor: Colors.orange.shade600,
    );
  }
}
