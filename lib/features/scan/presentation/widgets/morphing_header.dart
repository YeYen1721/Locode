import 'package:flutter/material.dart';
import '../../domain/entities/verdict.dart';

class MorphingHeader extends StatefulWidget {
  final Verdict verdict;
  final double progress;
  final double confidence;

  const MorphingHeader({
    required this.verdict,
    required this.progress,
    required this.confidence,
    super.key,
  });

  @override
  State<MorphingHeader> createState() => _MorphingHeaderState();
}

class _MorphingHeaderState extends State<MorphingHeader> {
  @override
  Widget build(BuildContext context) {
    // Accessibility: Respect reduce motion
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final displayProgress = reduceMotion ? 1.0 : widget.progress;

    return Semantics(
      label: _getSemanticLabel(),
      liveRegion: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, 120),
          painter: MorphingHeaderPainter(
            verdict: widget.verdict,
            progress: displayProgress,
            color: _getColor(context),
          ),
        ),
      ),
    );
  }

  String _getSemanticLabel() {
    final confPercent = (widget.confidence * 100).round();
    switch (widget.verdict) {
      case Verdict.safe:
        return "Safety check complete. This link appears safe with $confPercent percent confidence.";
      case Verdict.suspicious:
        return "Caution. Some risk indicators were found with $confPercent percent confidence. Proceed with care.";
      case Verdict.danger:
        return "Warning! This link is dangerous with $confPercent percent confidence. Do not open.";
      case Verdict.loading:
        return "Analyzing link safety. Please wait.";
      default:
        return "Analysis could not be completed.";
    }
  }

  Color _getColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (widget.verdict) {
      case Verdict.safe: return Colors.green;
      case Verdict.suspicious: return Colors.orange;
      case Verdict.danger: return colors.error;
      default: return Colors.grey;
    }
  }
}

class MorphingHeaderPainter extends CustomPainter {
  final Verdict verdict;
  final double progress;
  final Color color;

  MorphingHeaderPainter({required this.verdict, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path();

    switch (verdict) {
      case Verdict.danger:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height * 0.7);
        int teeth = 10;
        double step = size.width / teeth;
        for (int i = teeth; i > 0; i--) {
          path.lineTo(i * step - step/2, size.height * (0.7 + 0.3 * progress));
          path.lineTo((i - 1) * step, size.height * 0.7);
        }
        path.close();
        break;
      case Verdict.suspicious:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height * 0.8);
        for (double x = size.width; x >= 0; x -= 20) {
          path.quadraticBezierTo(x - 10, size.height * (0.8 + 0.1 * progress), x - 20, size.height * 0.8);
        }
        path.close();
        break;
      default:
        path.addRRect(RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, size.width, size.height),
          bottomLeft: Radius.circular(32 * progress),
          bottomRight: Radius.circular(32 * progress),
        ));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MorphingHeaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.verdict != verdict || oldDelegate.color != color;
  }
}