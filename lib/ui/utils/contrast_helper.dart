import 'dart:math' as math;
import 'package:flutter/material.dart';

/// WCAG-compliant contrast helper for ensuring readable text colors
/// against any background color in both light and dark modes
class ContrastHelper {
  /// Calculate the relative luminance of a color according to WCAG 2.x spec
  /// Uses sRGB to linear conversion for accurate luminance calculation
  static double _calculateLuminance(Color color) {
    // Convert sRGB channel to linear light value per WCAG 2.x spec
    double lin(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

    final r = lin(color.r);
    final g = lin(color.g);
    final b = lin(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Calculate the contrast ratio between two colors
  /// Returns a value between 1:1 and 21:1
  static double _calculateContrastRatio(Color foreground, Color background) {
    final fgLuminance = _calculateLuminance(foreground);
    final bgLuminance = _calculateLuminance(background);
    
    final lighter = math.max(fgLuminance, bgLuminance);
    final darker = math.min(fgLuminance, bgLuminance);
    
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if two colors have sufficient contrast (minimum 4.5:1 for WCAG AA)
  static bool hasSufficientContrast(Color foreground, Color background) {
    return _calculateContrastRatio(foreground, background) >= 4.5;
  }

  /// Resolve the appropriate text color for a given background color
  /// Ensures WCAG AA compliance (minimum 4.5:1 contrast ratio)
  /// 
  /// Parameters:
  /// - background: The background color to calculate contrast against
  /// - theme: The current theme for fallback colors
  /// - alpha: Optional alpha value for the returned color (default 1.0)
  static Color getContrastColor(
    Color background,
    ThemeData theme, {
    double alpha = 1.0,
  }) {
    // If the background has transparency, resolve it against white so
    // luminance calculations are accurate (semi-transparent colors appear
    // lighter over a typical light surface than their raw value suggests).
    final resolved = background.a < 1.0
        ? Color.alphaBlend(background, Colors.white)
        : background;

    // Calculate luminance of background
    final bgLuminance = _calculateLuminance(resolved);
    
    // For very light backgrounds (luminance > 0.85), always use dark text
    if (bgLuminance > 0.85) {
      return Colors.black.withValues(alpha: alpha);
    }
    
    // For very dark backgrounds (luminance < 0.15), always use light text
    if (bgLuminance < 0.15) {
      return Colors.white.withValues(alpha: alpha);
    }
    
    // For mid-range backgrounds, test both black and white
    final blackContrast = _calculateContrastRatio(Colors.black, resolved);
    final whiteContrast = _calculateContrastRatio(Colors.white, resolved);
    
    // Choose the color with better contrast
    if (blackContrast >= whiteContrast) {
      return Colors.black.withValues(alpha: alpha);
    } else {
      return Colors.white.withValues(alpha: alpha);
    }
  }

  /// Get a contrast-aware color that blends with the theme's onSurface color
  /// Useful for secondary text that needs to be readable but not as prominent.
  /// Guarantees at least 3:1 contrast ratio against [background]; falls back
  /// to pure black/white when the softer blend would fail that threshold.
  static Color getSecondaryContrastColor(
    Color background,
    ThemeData theme, {
    double alpha = 1.0,
  }) {
    // Resolve semi-transparent backgrounds against white before contrast math
    final resolved = background.a < 1.0
        ? Color.alphaBlend(background, Colors.white)
        : background;

    final primaryContrast = getContrastColor(resolved, theme, alpha: 1.0);
    final useDark = primaryContrast == Colors.black;

    // Attempt a softer blend with onSurfaceVariant
    final blended = Color.alphaBlend(
      theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
      useDark ? Colors.black : Colors.white,
    );

    // Verify the blend still passes 3:1 against the opaque resolved background
    final ratio = _calculateContrastRatio(blended, resolved);
    if (ratio >= 3.0) {
      return blended.withValues(alpha: alpha);
    }

    // Blend failed — return safe base color
    return primaryContrast.withValues(alpha: alpha);
  }

  /// Calculate an appropriate alpha for a color overlay to ensure text readability
  /// Returns an alpha value between 0.0 and 1.0
  static double getOverlayAlpha(Color overlayColor, Color backgroundColor) {
    // Start with a reasonable minimum alpha
    double alpha = 0.15;
    
    // Increase alpha until we get sufficient contrast with black or white text
    while (alpha < 0.9) {
      final blended = Color.alphaBlend(overlayColor.withValues(alpha: alpha), backgroundColor);
      final blackContrast = _calculateContrastRatio(Colors.black, blended);
      final whiteContrast = _calculateContrastRatio(Colors.white, blended);
      
      if (blackContrast >= 4.5 || whiteContrast >= 4.5) {
        break;
      }
      
      alpha += 0.05;
    }
    
    return alpha;
  }
}
