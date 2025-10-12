import 'package:flutter/material.dart';

import '../../../../../presentation/theme/app_colors.dart';
import '../../../../../presentation/theme/app_text_styles.dart';

class MapContentWidget extends StatelessWidget {
  final String deliveryId;

  const MapContentWidget({Key? key, required this.deliveryId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // TODO: Thay thế bằng Google Maps thực tế
    return Container(
      color: const Color(0xFFE5E3DF),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map, size: 100, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Google Maps sẽ được hiển thị ở đây',
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Mã giao hàng: $deliveryId', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
