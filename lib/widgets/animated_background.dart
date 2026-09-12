import 'dart:math';

import 'package:flutter/material.dart';

/// A full-screen animated background with rotating gradient and drifting
/// translucent circles. The animation loops indefinitely and is suitable for
/// mobile apps where you want a lively but subtle backdrop.
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
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
          painter: _BackgroundPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double progress; // 0.0..1.0

  _BackgroundPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // rotating gradient
    final gradient = LinearGradient(
      colors: const [
        Color(0xffede7f6), // light
        Color(0xffd1c4e9), // medium
        Color(0xffb39ddb), // darker
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(progress * 2 * pi),
    );

    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // draw some drifting circles
    final paint = Paint()..style = PaintingStyle.fill;
    // also we will mark each circle with a little emoji representing juice/fruits/sweets
    const icons = ['🍊', '🥤', '🍰', '🍓', '🍋', '🍪'];
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    for (var i = 0; i < 6; i++) {
      final phase = (progress + i / 6) % 1;
      final dx = size.width * (0.2 + 0.6 * (sin(phase * 2 * pi) * 0.5 + 0.5));
      final dy = size.height * (0.2 + 0.6 * (cos(phase * 2 * pi) * 0.5 + 0.5));
      final radius =
          size.shortestSide * (0.15 + 0.05 * sin(phase * 2 * pi + i));
      paint.color = Color.fromRGBO(103, 58, 183, 0.04 + 0.02 * i);
      canvas.drawCircle(Offset(dx, dy), radius, paint);

      // draw icon in center of bubble
      final icon = icons[i % icons.length];
      textPainter.text = TextSpan(
        text: icon,
        style: TextStyle(fontSize: radius * 1.2),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => true;
}
