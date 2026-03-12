import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that renders a parchment/aged paper texture background.
/// Only active in light mode; in dark mode it returns the child with no decoration.
class ParchmentBackground extends StatelessWidget {
  final Widget child;

  const ParchmentBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return child;
    }

    return CustomPaint(
      painter: _ParchmentPainter(),
      child: child,
    );
  }
}

class _ParchmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base warm parchment color
    final baseColor = const Color(0xFFF5ECD7);
    final basePaint = Paint()..color = baseColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Subtle radial gradient for aged vignette effect
    final vignetteGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.2,
      colors: [
        const Color(0x00000000),
        const Color(0x08A08050),
      ],
    );
    final vignettePaint = Paint()
      ..shader = vignetteGradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);

    // Subtle noise/speckle pattern for texture
    final random = Random(42); // Fixed seed for consistent texture
    final specklePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 800; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = random.nextDouble() * 0.06 + 0.01;
      final radius = random.nextDouble() * 1.5 + 0.3;
      
      // Mix of warm browns and lighter spots
      if (random.nextBool()) {
        specklePaint.color = Color.fromRGBO(160, 128, 80, opacity);
      } else {
        specklePaint.color = Color.fromRGBO(200, 180, 140, opacity * 1.5);
      }
      canvas.drawCircle(Offset(x, y), radius, specklePaint);
    }

    // Subtle horizontal streaks for paper fiber effect
    final streakPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 30; i++) {
      final y = random.nextDouble() * size.height;
      final startX = random.nextDouble() * size.width * 0.3;
      final endX = startX + random.nextDouble() * size.width * 0.4 + 20;
      final opacity = random.nextDouble() * 0.03 + 0.01;
      streakPaint.color = Color.fromRGBO(180, 150, 100, opacity);
      canvas.drawLine(Offset(startX, y), Offset(endX, y), streakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
