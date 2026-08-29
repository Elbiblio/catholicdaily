import 'package:flutter/material.dart';

import '../../data/services/reading_narration_controller.dart';

class ReadAloudIcon extends StatelessWidget {
  static const double targetSize = 48;

  final NarrationStatus status;
  final VoidCallback? onPressed;
  final Color? color;

  const ReadAloudIcon({
    super.key,
    required this.status,
    this.onPressed,
    this.color,
  });

  IconData get _icon => switch (status) {
    NarrationStatus.playing => Icons.pause_rounded,
    NarrationStatus.paused => Icons.play_arrow_rounded,
    _ => Icons.volume_up_outlined,
  };

  String get _label => switch (status) {
    NarrationStatus.playing => 'Pause reading',
    NarrationStatus.paused => 'Resume reading',
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
