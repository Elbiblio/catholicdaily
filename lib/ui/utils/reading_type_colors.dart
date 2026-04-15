import 'dart:math' as math;
import 'package:flutter/material.dart';

class ReadingTypeColors {
  /// Returns the accent color for a reading type label.
  ///
  /// [background] should be the effective card/row background so that the
  /// returned color is guaranteed to have ≥ 3:1 contrast ratio against it
  /// (suitable for large/bold label text per WCAG AA Large).  When no
  /// [background] is supplied the raw palette color is returned unchanged —
  /// callers that know the background should always pass it.
  static Color forType(
    String type,
    BuildContext context, {
    Color? liturgicalColor,
    Color? background,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color raw;
    switch (type.toLowerCase()) {
      case 'gospel':
        raw = isDark ? const Color(0xFFEF5350) : const Color(0xFFE53935);
      case 'responsorial psalm':
        raw = liturgicalColor ??
            (isDark ? const Color(0xFF42A5F5) : const Color(0xFF2196F3));
      case 'first reading':
        raw = isDark ? const Color(0xFFAB47BC) : const Color(0xFF9C27B0);
      case 'second reading':
        raw = isDark ? const Color(0xFF26A69A) : const Color(0xFF009688);
      case 'gospel acclamation':
        // Amber: dark mode uses bright gold, light uses deeper amber that passes AA on white natively
        raw = isDark ? const Color(0xFFFFCA28) : const Color(0xFF9A5D0A);
      default:
        raw = theme.colorScheme.onSurfaceVariant;
    }

    if (background != null) {
      return ensureContrast(raw, background, minRatio: 3.0);
    }
    return raw;
  }

  /// Darkens or lightens [color] until it has at least [minRatio]:1 contrast
  /// against [background].  Falls back to pure black or white if needed.
  static Color ensureContrast(
    Color color,
    Color background, {
    double minRatio = 3.0,
  }) {
    if (_contrastRatio(color, background) >= minRatio) return color;

    // Decide whether to darken or lighten based on background luminance
    final bgLum = _luminance(background);
    final darken = bgLum > 0.5;

    Color adjusted = color;
    for (int step = 0; step < 20; step++) {
      adjusted = darken ? _darken(adjusted, 0.08) : _lighten(adjusted, 0.08);
      if (_contrastRatio(adjusted, background) >= minRatio) return adjusted;
    }

    // Ultimate fallback
    return darken ? Colors.black : Colors.white;
  }

  static double _luminance(Color c) {
    double lin(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  }

  static double _contrastRatio(Color fg, Color bg) {
    final l1 = _luminance(fg);
    final l2 = _luminance(bg);
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static Color _darken(Color c, double amount) => Color.fromARGB(
        (c.a * 255).round(),
        ((c.r * 255) * (1 - amount)).round().clamp(0, 255),
        ((c.g * 255) * (1 - amount)).round().clamp(0, 255),
        ((c.b * 255) * (1 - amount)).round().clamp(0, 255),
      );

  static Color _lighten(Color c, double amount) => Color.fromARGB(
        (c.a * 255).round(),
        ((c.r * 255) + (255 - c.r * 255) * amount).round().clamp(0, 255),
        ((c.g * 255) + (255 - c.g * 255) * amount).round().clamp(0, 255),
        ((c.b * 255) + (255 - c.b * 255) * amount).round().clamp(0, 255),
      );
}
