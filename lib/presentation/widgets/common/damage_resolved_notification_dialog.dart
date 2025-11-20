import 'package:flutter/material.dart';

/// Dialog hiển thị thông báo đền bù hàng hóa đã được xử lý
/// Hiển thị khi driver nhận được notification DAMAGE_RESOLVED
class DamageResolvedNotificationDialog extends StatelessWidget {
  final String message;
  final VoidCallback? onConfirm;

  const DamageResolvedNotificationDialog({
    Key? key,
    required this.message,
    this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 48,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF424242),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {

                  Navigator.of(context).pop();
                  onConfirm?.call();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
