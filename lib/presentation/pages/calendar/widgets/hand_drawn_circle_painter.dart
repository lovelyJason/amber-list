import 'package:flutter/material.dart';

/// 手绘圆圈画笔 - 用于日历标记有任务的日期
class HandDrawnCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8) // Red marker style
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    // Draw a slightly irregular circle
    final radius = size.width / 2.5;

    // Start top-rightish
    path.moveTo(center.dx + radius * 0.8, center.dy - radius * 0.5);
    // Curve top-left
    path.quadraticBezierTo(
      center.dx,
      center.dy - radius * 1.2,
      center.dx - radius * 0.8,
      center.dy - radius * 0.2,
    );
    // Curve bottom-left
    path.quadraticBezierTo(
      center.dx - radius * 1.1,
      center.dy + radius * 0.8,
      center.dx,
      center.dy + radius * 0.9,
    );
    // Curve bottom-right
    path.quadraticBezierTo(
      center.dx + radius * 1.1,
      center.dy + radius * 0.8,
      center.dx + radius * 0.9,
      center.dy,
    );
    // Loop back up and overlap slightly
    path.quadraticBezierTo(
      center.dx + radius * 0.8,
      center.dy - radius * 0.5,
      center.dx + radius * 0.6,
      center.dy - radius * 0.7,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
