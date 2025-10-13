import 'package:flutter/material.dart';

import '../../../../../presentation/theme/app_colors.dart';

class MapActionButtons extends StatelessWidget {
  final VoidCallback onLocationPressed;
  final VoidCallback onDirectionsPressed;

  const MapActionButtons({
    super.key,
    required this.onLocationPressed,
    required this.onDirectionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          onPressed: onLocationPressed,
          heroTag: 'location',
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: onDirectionsPressed,
          heroTag: 'directions',
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.directions, color: Colors.white),
        ),
      ],
    );
  }
}
