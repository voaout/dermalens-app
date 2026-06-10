import 'package:flutter/material.dart';

/// Vintage hand-mirror icon: an oval frame with a handle.
class MirrorIcon extends StatelessWidget {
  final double size;
  final Color color;
  const MirrorIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MirrorPainter(color),
    );
  }
}

class _MirrorPainter extends CustomPainter {
  final Color color;
  _MirrorPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    // Oval mirror frame
    final center = Offset(w * 0.5, h * 0.36);
    final frame = Rect.fromCenter(
      center: center,
      width: w * 0.56,
      height: h * 0.60,
    );
    canvas.drawOval(frame, stroke);

    // Inner glass highlight (subtle)
    final glass = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: 0.18);
    final inner = Rect.fromCenter(
      center: center,
      width: w * 0.40,
      height: h * 0.44,
    );
    canvas.drawOval(inner, glass);

    // Handle
    final handle = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        w * 0.5 - w * 0.055,
        center.dy + h * 0.27,
        w * 0.11,
        h * 0.30,
      ),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(handle, fill);
  }

  @override
  bool shouldRepaint(covariant _MirrorPainter old) => old.color != color;
}
