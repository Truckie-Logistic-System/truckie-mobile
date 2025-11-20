import 'package:flutter/material.dart';

/// Static vehicle marker - TUYỆT ĐỐI TĨNH (NO INTERNAL ROTATION)
/// Used for North-Up Rotating mode where outer Transform.rotate handles all rotation
/// Design: Blue dot with white arrow pointing UP (North)
class StaticVehicleMarker extends StatelessWidget {
  final double size;

  const StaticVehicleMarker({
    Key? key,
    this.size = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      // NO Transform.rotate - marker luôn pointing UP
      child: CustomPaint(
        painter: _StaticVehicleMarkerPainter(),
        child: Container(),
      ),
    );
  }
}

/// Custom painter for static vehicle marker
/// Arrow ALWAYS points UP (no rotation)
class _StaticVehicleMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw shadow for depth
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(
      Offset(center.dx + 1, center.dy + 2),
      radius - 1,
      shadowPaint,
    );

    // 2. Draw main blue circle (Google Maps blue)
    final circlePaint = Paint()
      ..color = const Color(0xFF1A73E8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 2, circlePaint);

    // 3. Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // 4. Draw white arrow pointing UP (North) - ALWAYS STATIC
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final arrowPath = Path();
    
    // Arrow pointing UP (0°, North)
    final arrowTip = Offset(center.dx, center.dy - radius * 0.5); // Top
    final arrowLeft = Offset(center.dx - radius * 0.3, center.dy + radius * 0.2); // Bottom left
    final arrowRight = Offset(center.dx + radius * 0.3, center.dy + radius * 0.2); // Bottom right
    
    arrowPath.moveTo(arrowTip.dx, arrowTip.dy);
    arrowPath.lineTo(arrowLeft.dx, arrowLeft.dy);
    arrowPath.lineTo(arrowRight.dx, arrowRight.dy);
    arrowPath.close();

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
