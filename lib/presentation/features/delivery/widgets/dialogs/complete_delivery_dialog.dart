import 'package:flutter/material.dart';

import '../../../../../core/utils/sound_utils.dart';
import '../../../../../presentation/theme/app_colors.dart';

class CompleteDeliveryDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const CompleteDeliveryDialog({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Xác nhận hoàn thành'),
      content: const Text('Bạn có chắc chắn muốn hoàn thành giao hàng này?'),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Hủy')),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }

  static Future<bool?> show(BuildContext context) {
    // Play warning sound when showing confirmation dialog
    SoundUtils.playWarningSound();
    
    return showDialog<bool>(
      context: context,
      builder: (context) => CompleteDeliveryDialog(
        onConfirm: () {
          // Play success sound when confirming delivery completion
          SoundUtils.playSuccessSound();
          Navigator.pop(context, true);
        },
        onCancel: () {
          Navigator.pop(context, false);
        },
      ),
    );
  }
}
