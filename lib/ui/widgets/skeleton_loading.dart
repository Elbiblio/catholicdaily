import 'package:flutter/material.dart';
import '../../core/constants.dart';

/// Skeleton loading widget for creating shimmer effects during content loading
/// 
/// Usage:
/// ```dart
/// SkeletonLoading(
///   child: Column(
///     children: [
///       SkeletonItem(height: 24, width: double.infinity),
///       SizedBox(height: 8),
///       SkeletonItem(height: 16, width: 200),
///     ],
///   ),
/// )
/// ```
class SkeletonLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;

    final theme = Theme.of(context);
    final base = baseColor ?? theme.colorScheme.surfaceContainerHighest;
    final highlight = highlightColor ?? theme.colorScheme.surface;

    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.0, 0.5, 1.0],
          begin: const Alignment(-1.0, -0.3),
          end: const Alignment(1.0, 0.3),
          tileMode: TileMode.clamp,
        ).createShader(bounds);
      },
      child: child,
    );
  }
}

/// Individual skeleton item that pulses during loading
class SkeletonItem extends StatelessWidget {
  final double? height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const SkeletonItem({
    super.key,
    this.height,
    this.width,
    this.borderRadius = LayoutConstants.radiusMd,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Pre-built skeleton for reading content
class ReadingSkeleton extends StatelessWidget {
  const ReadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: Padding(
        padding: const EdgeInsets.all(LayoutConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title skeleton
            SkeletonItem(
              height: 28,
              width: 200,
              margin: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
            ),
            const SizedBox(height: LayoutConstants.spacingMd),
            // Verse skeletons
            for (int i = 0; i < ReadingConstants.maxLoadingIndicatorLines; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonItem(
                    height: 32,
                    width: 32,
                    borderRadius: 16,
                    margin: const EdgeInsets.only(
                      right: LayoutConstants.spacingMd,
                      top: 2,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonItem(
                          height: 16,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: LayoutConstants.spacingSm),
                        ),
                        SkeletonItem(
                          height: 16,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: LayoutConstants.spacingSm),
                        ),
                        if (i < 2)
                          SkeletonItem(
                            height: 16,
                            width: 150,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LayoutConstants.spacingMd),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton for card items
class CardSkeleton extends StatelessWidget {
  final int lineCount;

  const CardSkeleton({
    super.key,
    this.lineCount = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonLoading(
      child: Card(
        margin: const EdgeInsets.all(LayoutConstants.spacingMd),
        child: Padding(
          padding: const EdgeInsets.all(LayoutConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonItem(
                height: 20,
                width: 150,
                margin: const EdgeInsets.only(bottom: LayoutConstants.spacingMd),
              ),
              for (int i = 0; i < lineCount; i++)
                SkeletonItem(
                  height: 14,
                  width: i == lineCount - 1 ? 200 : double.infinity,
                  margin: const EdgeInsets.only(bottom: LayoutConstants.spacingSm),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
