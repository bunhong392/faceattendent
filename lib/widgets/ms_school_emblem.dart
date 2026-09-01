import 'package:flutter/material.dart';

class MsSchoolEmblem extends StatelessWidget {
  final double size;
  const MsSchoolEmblem({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _EmblemPainter(),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Gold Border
    final goldBorderPaint = Paint()
      ..color = const Color(0xFFE5A623)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.05;
    canvas.drawCircle(center, radius * 0.96, goldBorderPaint);

    // 2. Red Outer Ring
    final redRingPaint = Paint()
      ..color = const Color(0xFFD32F2F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.93, redRingPaint);

    // 3. Inner White Ring Separator
    final whiteRingPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03;
    canvas.drawCircle(center, radius * 0.76, whiteRingPaint);

    // 4. Inner Quadrants Base
    final innerRadius = radius * 0.74;

    // Top-Left: Light Cyan/Blue Quadrant
    final cyanPaint = Paint()..color = const Color(0xFFE3F2FD);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -3.14159,
      1.5708,
      true,
      cyanPaint,
    );

    // Top-Right: Red/Pink Quadrant
    final pinkPaint = Paint()..color = const Color(0xFFFFCDD2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -1.5708,
      1.5708,
      true,
      pinkPaint,
    );

    // Bottom-Left: Amber Quadrant
    final amberPaint = Paint()..color = const Color(0xFFFFF8E1);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      3.14159 / 2,
      1.5708,
      true,
      amberPaint,
    );

    // Bottom-Right: Soft Coral Quadrant
    final coralPaint = Paint()..color = const Color(0xFFFFEBEE);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      0,
      1.5708,
      true,
      coralPaint,
    );

    // Quadrant Dividing Lines
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = radius * 0.035;
    canvas.drawLine(
      Offset(center.dx - innerRadius, center.dy),
      Offset(center.dx + innerRadius, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - innerRadius),
      Offset(center.dx, center.dy + innerRadius),
      linePaint,
    );

    // 5. Center Brain & Lightbulb Circle
    final centerGlow = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.32, centerGlow);
    final centerBorder = Paint()
      ..color = const Color(0xFFFBC02D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.025;
    canvas.drawCircle(center, radius * 0.32, centerBorder);

    // Draw central lightbulb & brain icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Center icon
    textPainter.text = TextSpan(
      text: '💡',
      style: TextStyle(fontSize: radius * 0.28),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    // Top-Left: Science icon (Atom / Gear)
    textPainter.text = TextSpan(
      text: '⚛️',
      style: TextStyle(fontSize: radius * 0.2),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - innerRadius * 0.58 - textPainter.width / 2, center.dy - innerRadius * 0.55 - textPainter.height / 2),
    );

    // Top-Right: Math icon (Pi / Sigma)
    textPainter.text = TextSpan(
      text: 'π ∫',
      style: TextStyle(
        fontSize: radius * 0.18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFFB71C1C),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + innerRadius * 0.55 - textPainter.width / 2, center.dy - innerRadius * 0.55 - textPainter.height / 2),
    );

    // Bottom-Left: Biology icon (DNA / Microscope)
    textPainter.text = TextSpan(
      text: '🧬',
      style: TextStyle(fontSize: radius * 0.2),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - innerRadius * 0.58 - textPainter.width / 2, center.dy + innerRadius * 0.48 - textPainter.height / 2),
    );

    // Bottom-Right: Chemistry icon (Flask)
    textPainter.text = TextSpan(
      text: '🧪',
      style: TextStyle(fontSize: radius * 0.2),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx + innerRadius * 0.55 - textPainter.width / 2, center.dy + innerRadius * 0.48 - textPainter.height / 2),
    );

    // Bottom Open Book Banner
    final bookRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + innerRadius * 0.85),
      width: radius * 0.8,
      height: radius * 0.32,
    );
    final bookPaint = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(bookRect, const Radius.circular(8)), bookPaint);
    final bookBorder = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(bookRect, const Radius.circular(8)), bookBorder);

    // Text "M S" on the book
    textPainter.text = TextSpan(
      text: 'M  S',
      style: TextStyle(
        fontSize: radius * 0.16,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF0D47A1),
        letterSpacing: 2,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy + innerRadius * 0.85 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
