import 'dart:math';
import 'package:flutter/material.dart';

/// Professional vehicle marker for navigation
/// Mimics Google Maps style: Blue dot with white directional arrow
/// Optimized for smooth rotation and visibility
class VehicleNavigationMarker extends StatelessWidget {
  final double bearing; // 0-360 degrees
  final double size;

  const VehicleNavigationMarker({
    Key? key,
    required this.bearing,
    this.size = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform.rotate(
        angle: bearing * pi / 180,
        child: CustomPaint(
          painter: _VehicleMarkerPainter(),
          child: Container(),
        ),
      ),
    );
  }
}

/// Custom painter for vehicle marker
/// Design: Blue circle with white arrow + shadow for depth
class _VehicleMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      Offset(center.dx + 1, center.dy + 2), // Slight offset for shadow
      radius - 1,
      shadowPaint,
    );

    // 2. Draw outer border (darker blue)
    final borderPaint = Paint()
      ..color = const Color(0xFF1557B0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, borderPaint);

    // 3. Draw main blue circle (Google Maps blue)
    final circlePaint = Paint()
      ..color = const Color(0xFF1A73E8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, circlePaint);

    // 4. Draw white directional arrow (pointing up = north)
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final arrowPath = Path();
    
    // Arrow pointing upward (north)
    final arrowTop = Offset(center.dx, center.dy - radius * 0.5); // Top point
    final arrowBottomLeft = Offset(center.dx - radius * 0.3, center.dy + radius * 0.3);
    final arrowBottomRight = Offset(center.dx + radius * 0.3, center.dy + radius * 0.3);
    final arrowMiddle = Offset(center.dx, center.dy + radius * 0.1);

    arrowPath.moveTo(arrowTop.dx, arrowTop.dy);
    arrowPath.lineTo(arrowBottomLeft.dx, arrowBottomLeft.dy);
    arrowPath.lineTo(arrowMiddle.dx, arrowMiddle.dy);
    arrowPath.lineTo(arrowBottomRight.dx, arrowBottomRight.dy);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);

    // 5. Draw subtle highlight for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - radius * 0.3, center.dy - radius * 0.3),
      radius * 0.25,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
