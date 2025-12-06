import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Simple Rotatable Truck Marker
/// Uses a single icon with CSS rotation for smooth, accurate direction
/// Better for 2D map view than isometric 3D images
class SimpleTruckMarker extends StatelessWidget {
  final double bearing;
  final double size;

  const SimpleTruckMarker({
    Key? key,
    required this.bearing,
    this.size = 60,
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
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Shadow
              Positioned(
                left: size * 0.2,
                top: size * 0.2,
                child: Container(
                  width: size * 0.6,
                  height: size * 0.6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.15),
                    // Slightly offset shadow for depth
                  ),
                ),
              ),

              // Rotatable truck icon
              Center(
                child: Transform.rotate(
                  // Rotate based on bearing
                  // Subtract 90° because icon points right (East) by default
                  // Map bearing: 0°=North, 90°=East, 180°=South, 270°=West
                  angle: (bearing - 90) * math.pi / 180,
                  child: Container(
                    width: size * 0.8,
                    height: size * 0.8,
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(size * 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Truck body (cargo area - back)
                        Positioned(
                          left: size * 0.05,
                          top: size * 0.2,
                          child: Container(
                            width: size * 0.45,
                            height: size * 0.4,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade300,
                              borderRadius: BorderRadius.circular(size * 0.04),
                            ),
                          ),
                        ),
                        
                        // Truck cab (driver area - front)
                        Positioned(
                          right: size * 0.05,
                          top: size * 0.25,
                          child: Container(
                            width: size * 0.25,
                            height: size * 0.3,
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(size * 0.08),
                                bottomRight: Radius.circular(size * 0.04),
                                topLeft: Radius.circular(size * 0.02),
                                bottomLeft: Radius.circular(size * 0.02),
                              ),
                            ),
                          ),
                        ),
                        
                        // Front wheel
                        Positioned(
                          right: size * 0.15,
                          bottom: size * 0.1,
                          child: Container(
                            width: size * 0.12,
                            height: size * 0.12,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        
                        // Back wheel
                        Positioned(
                          left: size * 0.15,
                          bottom: size * 0.1,
                          child: Container(
                            width: size * 0.12,
                            height: size * 0.12,
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        
                        // Direction indicator (small arrow at front)
                        Positioned(
                          right: size * 0.02,
                          top: size * 0.35,
                          child: Icon(
                            Icons.arrow_forward,
                            size: size * 0.15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
