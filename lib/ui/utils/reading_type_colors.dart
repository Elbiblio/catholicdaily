import 'package:flutter/material.dart';

class ReadingTypeColors {
  static Color forType(
    String type,
    BuildContext context, {
    Color? liturgicalColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (type.toLowerCase()) {
      case 'gospel':
        return isDark ? const Color(0xFFEF5350) : const Color(0xFFE53935);
      case 'responsorial psalm':
        return liturgicalColor ??
            (isDark ? const Color(0xFF42A5F5) : const Color(0xFF2196F3));
      case 'first reading':
        return isDark ? const Color(0xFFAB47BC) : const Color(0xFF9C27B0);
      case 'second reading':
        return isDark ? const Color(0xFF26A69A) : const Color(0xFF009688);
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }
}
