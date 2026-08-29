import 'package:flutter/material.dart';

import '../../data/services/reading_narration_controller.dart';

class NarrationMiniPlayer extends StatelessWidget {
  static const playerKey = ValueKey<String>('narration-mini-player');
  static const rates = <double>[0.4, 0.5, 0.75, 1.0];

  final bool visible;
  final ReadingNarrationState state;
  final bool canGoPrevious;
  final bool canGoNext;
  final double rate;
  final VoidCallback? onPrevious;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onStop;
  final VoidCallback? onDismiss;
  final ValueChanged<double>? onRateChanged;

  const NarrationMiniPlayer({
    super.key,
    required this.visible,
    required this.state,
    this.canGoPrevious = false,
    this.canGoNext = false,
    this.rate = 0.5,
    this.onPrevious,
    this.onPlayPause,
    this.onNext,
    this.onStop,
    this.onDismiss,
    this.onRateChanged,
  });

  bool get _isPlaying =>
      state.status == NarrationStatus.playing ||
      state.status == NarrationStatus.loading;

  String get _playbackTooltip {
    if (_isPlaying) {
      return state.supportsNativePause
          ? 'Pause reading'
          : 'Stop and keep position';
    }
    return state.supportsNativePause
        ? 'Resume reading'
        : 'Restart from position';
  }

  IconData get _playbackIcon {
    if (_isPlaying) {
      return state.supportsNativePause
          ? Icons.pause_rounded
          : Icons.stop_rounded;
    }
    return state.supportsNativePause
        ? Icons.play_arrow_rounded
        : Icons.replay_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final title = state.currentItem?.reading.position?.trim();

    return Material(
      key: playerKey,
      color: theme.colorScheme.surfaceContainer,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LinearProgressIndicator(
              minHeight: 2,
              value: state.progress.clamp(0, 1),
            ),
            SizedBox(
              height: 54,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title == null || title.isEmpty ? 'Reading aloud' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous reading',
                    onPressed: canGoPrevious ? onPrevious : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  IconButton(
                    tooltip: _playbackTooltip,
                    onPressed: onPlayPause,
                    icon: Icon(_playbackIcon),
                  ),
                  IconButton(
                    tooltip: 'Next reading',
                    onPressed: canGoNext ? onNext : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  IconButton(
                    tooltip: 'Stop reading',
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_rounded),
                  ),
                  Tooltip(
                    message: 'Speech speed',
                    child: InkWell(
                      onTap: onRateChanged == null
                          ? null
                          : () => onRateChanged!(_nextRate(rate)),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        child: Center(child: Text(_rateLabel(rate))),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss player',
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rateLabel(double rate) => '${rate.toStringAsFixed(2)}×'
      .replaceFirst(RegExp(r'0+×$'), '×')
      .replaceFirst('.×', '×');

  static double _nextRate(double rate) {
    final index = rates.indexWhere((candidate) => candidate > rate);
    return index == -1 ? rates.first : rates[index];
  }
}
