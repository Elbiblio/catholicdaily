import 'package:flutter/material.dart';

import '../../data/services/reading_narration_controller.dart';

class ReadAloudIcon extends StatelessWidget {
  static const double targetSize = 48;

  final NarrationStatus status;
  final bool supportsNativePause;
  final VoidCallback? onPressed;
  final Color? color;

  const ReadAloudIcon({
    super.key,
    required this.status,
    this.supportsNativePause = true,
    this.onPressed,
    this.color,
  });

  IconData get _icon => switch (status) {
    NarrationStatus.playing =>
      supportsNativePause ? Icons.pause_rounded : Icons.stop_rounded,
    NarrationStatus.paused =>
      supportsNativePause ? Icons.play_arrow_rounded : Icons.replay_rounded,
    _ => Icons.volume_up_outlined,
  };

  String get _label => switch (status) {
    NarrationStatus.playing =>
      supportsNativePause ? 'Pause reading' : 'Stop reading',
    NarrationStatus.paused =>
      supportsNativePause ? 'Resume reading' : 'Restart reading',
    _ => 'Read aloud',
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: targetSize,
      child: Tooltip(
        message: _label,
        child: Semantics(
          label: _label,
          button: true,
          enabled: onPressed != null,
          excludeSemantics: true,
          child: IconButton(
            constraints: const BoxConstraints.tightFor(
              width: targetSize,
              height: targetSize,
            ),
            padding: const EdgeInsets.all(12),
            iconSize: 22,
            color: color,
            onPressed: onPressed,
            icon: Icon(_icon, size: 22),
          ),
        ),
      ),
    );
  }
}
