import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Google Maps Style Navigation Marker
/// Simple circle with arrow inside - rotates smoothly based on bearing
/// Camera follows the arrow direction for natural navigation experience
class GoogleMapsStyleMarker extends StatelessWidget {
  final double bearing;
  final double size;

  const GoogleMapsStyleMarker({
    Key? key,
    required this.bearing,
    this.size = 50,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Transform.translate(
        offset: Offset(-size / 2, -size / 2),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Google Maps style shadow - larger, softer
              Container(
                width: size * 1.2,
                height: size * 1.2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      spreadRadius: 3,
                      offset: const Offset(0, 3),
                    ),
                    // Second shadow for depth
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 6,
                      spreadRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),

              // White circle background with gradient
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFF1A73E8), // Google Blue
                    width: 3.5,
                  ),
                ),
              ),

              // Blue circle fill with gradient (Google Maps style)
              Container(
                width: size * 0.88,
                height: size * 0.88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF4285F4), // Google Blue (lighter center)
                      const Color(0xFF1A73E8), // Google Blue (darker edge)
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),

              // Rotating arrow inside - Google Maps style
              Transform.rotate(
                // Arrow points up by default (0°)
                // Bearing: 0°=North, 90°=East, 180°=South, 270°=West
                angle: bearing * math.pi / 180,
                child: Icon(
                  Icons.navigation,
                  size: size * 0.65,
                  color: Colors.white,
                  shadows: [
                    // Shadow for arrow to make it pop
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),

              // Accuracy indicator dot (optional, subtle)
              Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
