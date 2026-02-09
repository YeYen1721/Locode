import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A CustomPainter that morphs between a smooth M3 pill and a jagged warning shape.
class MorphingHeaderPainter extends CustomPainter {
  final double animationValue; // 0.0 = Rounded, 1.0 = Jagged
  final Color color;

  MorphingHeaderPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    if (animationValue < 0.1) {
      // Standard M3 Pill
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width, height), const Radius.circular(2)),
        paint,
      );
      return;
    }

    // Morphing Logic: Transition from straight line to jagged spikes
    path.moveTo(0, height / 2);
    int spikes = 12;
    double step = width / spikes;

    for (int i = 0; i <= spikes; i++) {
      double x = i * step;
      // If animationValue is high, y oscillates to create "sharp" teeth
      double y = (i % 2 == 0) 
          ? (height / 2) - (10 * animationValue) 
          : (height / 2) + (10 * animationValue);
      path.lineTo(x, y);
    }

    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MorphingHeaderPainter oldDelegate) => 
      oldDelegate.animationValue != animationValue || oldDelegate.color != color;
}
