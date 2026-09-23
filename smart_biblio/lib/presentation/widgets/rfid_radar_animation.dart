import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class RfidRadarAnimation extends StatefulWidget {
  final double size;
  final String label;

  const RfidRadarAnimation({
    super.key,
    this.size = 280,
    this.label = 'TAP STUDENT CARD',
  });

  @override
  State<RfidRadarAnimation> createState() => _RfidRadarAnimationState();
}

class _RfidRadarAnimationState extends State<RfidRadarAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadarWavePainter(
            progress: _controller.value,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFF00E5FF),
                      Color(0xFF0072FF),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.contactless_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final double progress;
  final Paint _wavePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5;

  _RadarWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + (i * 0.33)) % 1.0;
      final radius = 45 + (maxRadius - 45) * waveProgress;
      final opacity = math.sin(waveProgress * math.pi) * 0.45;

      _wavePaint.color = AppColors.primary.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, radius, _wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
