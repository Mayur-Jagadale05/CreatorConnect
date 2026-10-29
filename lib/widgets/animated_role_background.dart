import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedRoleBackground extends StatefulWidget {
  const AnimatedRoleBackground({super.key, required this.role});

  final String role;

  @override
  State<AnimatedRoleBackground> createState() => _AnimatedRoleBackgroundState();
}

class _AnimatedRoleBackgroundState extends State<AnimatedRoleBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ArtisticBackgroundPainter(
          colors: _paletteForRole(widget.role),
          animation: _controller,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

List<Color> _paletteForRole(String role) {
  switch (role) {
    case 'Businessman':
    case 'Influencer':
    case 'Editor':
    case 'Writer':
    default:
      return const [Color(0xFFFFFCFA), Color(0xFFECE7F4), Color(0xFFF7F5F3)];
  }
}

class _ArtisticBackgroundPainter extends CustomPainter {
  _ArtisticBackgroundPainter({required this.colors, required this.animation})
    : super(repaint: animation);

  final List<Color> colors;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final phase = animation.value * math.pi * 2;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
          stops: const [0, 0.52, 1],
        ).createShader(rect),
    );

    _drawAmbientGlow(
      canvas,
      size,
      Offset(
        size.width * (0.18 + math.sin(phase) * 0.025),
        size.height * (0.24 + math.cos(phase) * 0.035),
      ),
      size.shortestSide * 0.42,
      const Color(0xFFF2D39A),
      0.13,
    );
    _drawAmbientGlow(
      canvas,
      size,
      Offset(
        size.width * (0.88 + math.cos(phase * 0.7) * 0.04),
        size.height * (0.45 + math.sin(phase * 0.7) * 0.05),
      ),
      size.shortestSide * 0.46,
      const Color(0xFF35132F),
      0.10,
    );
    _drawAmbientGlow(
      canvas,
      size,
      Offset(
        size.width * (0.52 + math.sin(phase * 0.55) * 0.035),
        size.height * 0.98,
      ),
      size.shortestSide * 0.50,
      const Color(0xFFF2D39A),
      0.08,
    );

    _drawOrganicShape(
      canvas,
      size,
      Offset(size.width * 0.09, size.height * 0.78),
      size.width * 0.30,
      -0.32 + math.sin(phase * 0.5) * 0.025,
      const Color(0xFF35132F).withValues(alpha: 0.13),
    );
    _drawOrganicShape(
      canvas,
      size,
      Offset(size.width * 0.94, size.height * 0.16),
      size.width * 0.25,
      0.5 + math.cos(phase * 0.45) * 0.03,
      const Color(0xFF35132F).withValues(alpha: 0.08),
    );
    _drawEditorialLines(canvas, size);
  }

  void _drawAmbientGlow(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.48, 1],
        ).createShader(bounds),
    );
  }

  void _drawOrganicShape(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    double rotation,
    Color color,
  ) {
    final path = Path();
    for (var index = 0; index <= 32; index++) {
      final angle = index / 32 * math.pi * 2;
      final wave = 1 + 0.18 * math.sin(angle * 3 + rotation * 2);
      final point = Offset(
        center.dx + math.cos(angle + rotation) * radius * wave,
        center.dy + math.sin(angle + rotation) * radius * wave * 0.58,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawEditorialLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF35132F).withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (var index = 1; index < 7; index++) {
      final x = size.width * index / 7;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtisticBackgroundPainter oldDelegate) {
    return oldDelegate.colors != colors;
  }
}
