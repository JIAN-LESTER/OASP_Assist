import 'dart:math' as math;

import 'package:flutter/material.dart';

class GreenSnowAnimation extends StatelessWidget {
  final Animation<double> animation;
  final Color color;
  final int flakeCount;

  const GreenSnowAnimation({
    Key? key,
    required this.animation,
    required this.color,
    this.flakeCount = 46,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return RepaintBoundary(
              child: CustomPaint(
                painter: _GreenSnowPainter(
                  progress: animation.value,
                  color: color,
                  flakeCount: flakeCount,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GreenSnowPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int flakeCount;

  const _GreenSnowPainter({
    required this.progress,
    required this.color,
    required this.flakeCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < flakeCount; i++) {
      final seed = i * 37.0;
      final baseX = ((seed * 19) % 100) / 100;
      final baseY = ((seed * 23) % 100) / 100;
      final speed = 0.35 + ((i % 6) * 0.09);
      final drift = math.sin((progress * math.pi * 2) + i) * (10 + (i % 5) * 3);
      final x = (baseX * size.width + drift) % size.width;
      final y = ((baseY + progress * speed) % 1.15) * size.height - 24;
      final radius = 2.0 + (i % 4) * 0.8;

      paint.color = color.withOpacity(0.12 + (i % 5) * 0.025);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_GreenSnowPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.flakeCount != flakeCount;
  }
}
