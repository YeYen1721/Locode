import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'morphing_header.dart';
import '../../data/models/safety_result_model.dart';

/// A Material 3 Expressive Bottom Sheet featuring Spring Physics and Morphing Header.
class SafetyBottomSheet extends StatefulWidget {
  final LocodeResult result;

  const SafetyBottomSheet({super.key, required this.result});

  @override
  State<SafetyBottomSheet> createState() => _SafetyBottomSheetState();
}

class _SafetyBottomSheetState extends State<SafetyBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _morphAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _morphAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // M3 Expressive Fast Spatial Token (Stiffness: 800, Damping: 0.7)
    final spring = SpringDescription(
      mass: 1,
      stiffness: 800,
      damping: 0.7,
    );

    final simulation = SpringSimulation(spring, 0, 1, 0);
    _controller.animateWith(simulation);

    // KILLER FEATURE: State-Driven Haptics
    _triggerHaptics();
  }

  void _triggerHaptics() async {
    if (widget.result.status == 'Danger') {
      // Alarm pattern: Heavy impact series
      for (int i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 150));
      }
    } else {
      await HapticFeedback.lightImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDanger = widget.result.status == 'Danger';
    final accentColor = isDanger ? theme.colorScheme.error : const Color(0xFF388E3C);

    return ScaleTransition(
      scale: _controller,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: RepaintBoundary(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // KILLER FEATURE: Morphing Header
              AnimatedBuilder(
                animation: _morphAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(60, 8),
                    painter: MorphingHeaderPainter(
                      animationValue: isDanger ? _morphAnimation.value : 0.0,
                      color: accentColor.withOpacity(0.3),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Icon(
                isDanger ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                size: 84,
                color: accentColor,
              ),
              const SizedBox(height: 24),
              Text(
                widget.result.status.toUpperCase(),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "Gemini Contextual Risk: ${widget.result.riskScore}%",
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  widget.result.reasoning,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    "ACKNOWLEDGE VERDICT",
                    style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
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
