import 'package:flutter/material.dart';

import '../../data/models/resolved_responsorial_psalm.dart';

class ResponsorialPsalmSourceLabel extends StatelessWidget {
  final ResolvedResponsorialPsalm resolution;

  const ResponsorialPsalmSourceLabel({super.key, required this.resolution});

  String get _label {
    if (!resolution.didFallback) return resolution.actualEditionName;
    final reason = switch (resolution.fallbackReason) {
      PsalmFallbackReason.selectedEditionMissing =>
        'selected edition unavailable for this psalm',
      PsalmFallbackReason.selectedPackUnavailable =>
        'selected edition is not installed',
      PsalmFallbackReason.territoryEditionMissing =>
        'territory edition unavailable for this psalm',
      PsalmFallbackReason.bibleEditionMissing =>
        'selected Bible edition unavailable for this psalm',
      PsalmFallbackReason.corruptPack => 'source pack could not be verified',
      PsalmFallbackReason.none => '',
    };
    return '${resolution.actualEditionName} fallback — $reason';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Responsorial Psalm source: $_label',
      child: Row(
        children: <Widget>[
          Icon(
            resolution.didFallback
                ? Icons.info_outline
                : Icons.verified_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
