import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LionLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const LionLogo({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _LionPainter(color: color ?? AppTheme.primary),
    );
  }
}

class _LionPainter extends CustomPainter {
  final Color color;
  _LionPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Draw a stylized lion head using paths
    // Head/face base
    final headPath = Path()
      ..moveTo(w * 0.5, h * 0.1)
      ..cubicTo(w * 0.25, h * 0.1, w * 0.1, h * 0.35, w * 0.12, h * 0.55)
      ..cubicTo(w * 0.14, h * 0.75, w * 0.3, h * 0.88, w * 0.5, h * 0.9)
      ..cubicTo(w * 0.7, h * 0.88, w * 0.86, h * 0.75, w * 0.88, h * 0.55)
      ..cubicTo(w * 0.9, h * 0.35, w * 0.75, h * 0.1, w * 0.5, h * 0.1)
      ..close();
    canvas.drawPath(headPath, paint);

    // Mane spikes
    final manePaint = Paint()
      ..color = color.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final manePath = Path()
      // Top spike
      ..moveTo(w * 0.5, h * 0.0)
      ..lineTo(w * 0.44, h * 0.12)
      ..lineTo(w * 0.56, h * 0.12)
      ..close();
    canvas.drawPath(manePath, manePaint);

    // Left spikes
    final maneLeft = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.18, h * 0.35)
      ..lineTo(w * 0.15, h * 0.45)
      ..close();
    canvas.drawPath(maneLeft, manePaint);

    // Right spikes
    final maneRight = Path()
      ..moveTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.82, h * 0.35)
      ..lineTo(w * 0.85, h * 0.45)
      ..close();
    canvas.drawPath(maneRight, manePaint);

    // Face highlights (dark areas for face features)
    final darkPaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.fill;

    // Left eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.42),
        width: w * 0.12,
        height: h * 0.1,
      ),
      darkPaint,
    );
    // Right eye
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.42),
        width: w * 0.12,
        height: h * 0.1,
      ),
      darkPaint,
    );

    // Nose
    final nosePath = Path()
      ..moveTo(w * 0.5, h * 0.56)
      ..lineTo(w * 0.44, h * 0.63)
      ..lineTo(w * 0.56, h * 0.63)
      ..close();
    canvas.drawPath(nosePath, darkPaint);

    // Mouth lines
    final mouthPaint = Paint()
      ..color = const Color(0xFF0A0A0A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.63),
      Offset(w * 0.5, h * 0.72),
      mouthPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.38, h * 0.72),
        width: w * 0.24,
        height: h * 0.1,
      ),
      0,
      3.14,
      false,
      mouthPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.62, h * 0.72),
        width: w * 0.24,
        height: h * 0.1,
      ),
      0,
      3.14,
      false,
      mouthPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
