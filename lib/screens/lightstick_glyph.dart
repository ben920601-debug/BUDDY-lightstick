import 'package:flutter/material.dart';

/// 原創的手燈裝飾圖案：發光球體 + 握把，純幾何抽象設計，
/// 不含任何官方商標或特定團體標誌，純粹用來裝飾、營造應援手燈的氛圍。
class LightstickGlyph extends StatelessWidget {
  final double size;
  final List<Color> glowColors;

  const LightstickGlyph({
    super.key,
    this.size = 120,
    this.glowColors = const [Colors.white, Color(0xFF00ABC0), Color(0xFF5F4B8B)],
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.35,
      child: CustomPaint(
        painter: _LightstickPainter(glowColors),
      ),
    );
  }
}

class _LightstickPainter extends CustomPainter {
  final List<Color> glowColors;
  _LightstickPainter(this.glowColors);

  @override
  void paint(Canvas canvas, Size size) {
    final orbRadius = size.width * 0.42;
    final orbCenter = Offset(size.width / 2, orbRadius + 4);

    // 光暈
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowColors[1].withOpacity(0.35), glowColors[1].withOpacity(0)],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius * 1.9))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(orbCenter, orbRadius * 1.9, glowPaint);

    // 發光球體本體
    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [glowColors[0], glowColors[1], glowColors[2]],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: orbCenter, radius: orbRadius));
    canvas.drawCircle(orbCenter, orbRadius, orbPaint);

    // 球體邊緣線
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(orbCenter, orbRadius, ringPaint);

    // 小星芒點綴
    _drawSpark(canvas, Offset(orbCenter.dx - orbRadius * 0.35, orbCenter.dy - orbRadius * 0.3), orbRadius * 0.18);
    _drawSpark(canvas, Offset(orbCenter.dx + orbRadius * 0.4, orbCenter.dy + orbRadius * 0.15), orbRadius * 0.12);

    // 握把
    final handleTop = orbCenter.dy + orbRadius * 0.85;
    final handleWidth = size.width * 0.16;
    final handleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width / 2 - handleWidth / 2, handleTop, handleWidth, size.height - handleTop),
      const Radius.circular(6),
    );
    final handlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [glowColors[2], glowColors[2].withOpacity(0.7)],
      ).createShader(handleRect.outerRect);
    canvas.drawRRect(handleRect, handlePaint);
  }

  void _drawSpark(Canvas canvas, Offset center, double r) {
    final paint = Paint()..color = Colors.white.withOpacity(0.85);
    final path = Path();
    path.moveTo(center.dx, center.dy - r);
    path.lineTo(center.dx + r * 0.28, center.dy - r * 0.28);
    path.lineTo(center.dx + r, center.dy);
    path.lineTo(center.dx + r * 0.28, center.dy + r * 0.28);
    path.lineTo(center.dx, center.dy + r);
    path.lineTo(center.dx - r * 0.28, center.dy + r * 0.28);
    path.lineTo(center.dx - r, center.dy);
    path.lineTo(center.dx - r * 0.28, center.dy - r * 0.28);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LightstickPainter oldDelegate) => false;
}
