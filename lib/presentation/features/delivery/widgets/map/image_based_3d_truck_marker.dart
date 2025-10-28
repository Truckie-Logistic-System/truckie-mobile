import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Image-Based 3D Truck Marker Widget
/// Uses 8 pre-rendered PNG images for 3D perspective at different angles
/// Shows the colorful delivery truck with proper 3D depth
class ImageBased3DTruckMarker extends StatelessWidget {
  final double bearing;
  final double size;

  const ImageBased3DTruckMarker({
    Key? key,
    required this.bearing,
    this.size = 60,
  }) : super(key: key);

  /// Get the closest direction index (0-7) based on bearing
  /// Bearing from API: 0° = N, 90° = E, 180° = S, 270° = W
  /// Maps to 8 directions: 0=N, 1=NE, 2=E, 3=SE, 4=S, 5=SW, 6=W, 7=NW
  int _getDirectionIndex() {
    // Normalize bearing to 0-360
    var normalizedBearing = bearing % 360;
    if (normalizedBearing < 0) {
      normalizedBearing += 360;
    }
    
    // Map bearing to 8 directions using floor division
    // Each direction covers 45° centered at: 0, 45, 90, 135, 180, 225, 270, 315
    // Add 22.5° offset so ranges are:
    // N (0): 337.5-22.5, NE (1): 22.5-67.5, E (2): 67.5-112.5, etc.
    final index = ((normalizedBearing + 22.5) / 45).floor() % 8;
    
    return index;
  }

  /// Get image path based on direction index
  String _getImagePath(int directionIndex) {
    switch (directionIndex) {
      case 0: // N - North (0°)
        return 'assets/icons/truck_marker_icon/truck_north.png';
      case 1: // NE - Northeast (45°)
        return 'assets/icons/truck_marker_icon/truck_northeast.png';
      case 2: // E - East (90°)
        return 'assets/icons/truck_marker_icon/truck_east.png';
      case 3: // SE - Southeast (135°)
        return 'assets/icons/truck_marker_icon/truck_southeast.png';
      case 4: // S - South (180°)
        return 'assets/icons/truck_marker_icon/truck_south.png';
      case 5: // SW - Southwest (225°)
        return 'assets/icons/truck_marker_icon/truck_southwest.png';
      case 6: // W - West (270°)
        return 'assets/icons/truck_marker_icon/truck_west.png';
      case 7: // NW - Northwest (315°)
        return 'assets/icons/truck_marker_icon/truck_northwest.png';
      default:
        return 'assets/icons/truck_marker_icon/truck_south.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final directionIndex = _getDirectionIndex();
    final imagePath = _getImagePath(directionIndex);

    // Use Transform to ensure perfect centering
    // Offset by half size to center the marker on the exact lat/lng point
    return Transform.translate(
      offset: Offset(-size / 2, -size / 2),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Shadow - at the bottom center
            Positioned(
              left: size * 0.15,
              bottom: size * 0.1,
              child: Container(
                width: size * 0.7,
                height: size * 0.15,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.15),
                  color: Colors.black.withOpacity(0.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 3,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),

            // 3D Truck Image - with proper perspective
            Center(
              child: Image.asset(
                imagePath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image not found
                  return Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(size * 0.1),
                    ),
                    child: Icon(
                      Icons.local_shipping,
                      size: size * 0.5,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
