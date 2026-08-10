import 'package:flutter/material.dart';

import '../../../data/models/saint_profile.dart';
import '../../../data/models/saint_profile_source.dart';

class SaintSourcesSheet extends StatelessWidget {
  const SaintSourcesSheet({
    super.key,
    required this.profile,
    required this.onOpenUrl,
  });

  final SaintProfile profile;
  final ValueChanged<Uri> onOpenUrl;

  static Future<void> show(
    BuildContext context,
    SaintProfile profile, {
    required ValueChanged<Uri> onOpenUrl,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) =>
          SaintSourcesSheet(profile: profile, onOpenUrl: onOpenUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Sources and review',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'See the evidence, historical certainty, and editorial review '
            'behind this guide.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _ReviewSummary(profile: profile),
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(
              'References',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < profile.sources.length; index++) ...[
            _SourceCard(source: profile.sources[index], onOpenUrl: onOpenUrl),
            if (index != profile.sources.length - 1) const SizedBox(height: 12),
          ],
          if (profile.image != null) ...[
            const SizedBox(height: 28),
            _ImageCredit(image: profile.image!, onOpenUrl: onOpenUrl),
          ],
          if (profile.editorial.warnings.isNotEmpty) ...[
            const SizedBox(height: 28),
            _Warnings(warnings: profile.editorial.warnings),
          ],
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.profile});

  final SaintProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewedAt = profile.editorial.reviewedAt;
    final reviewedDate = reviewedAt == null
        ? 'Not yet reviewed'
        : '${reviewedAt.year.toString().padLeft(4, '0')}-'
              '${reviewedAt.month.toString().padLeft(2, '0')}-'
              '${reviewedAt.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          _Metadata(label: 'Historical record', value: _certainty(profile)),
          _Metadata(label: 'Reviewed', value: reviewedDate),
          _Metadata(
            label: 'Editorial revision',
            value: '${profile.editorial.revision}',
          ),
        ],
      ),
    );
  }

  static String _certainty(SaintProfile profile) =>
      switch (profile.historicalCertainty) {
        HistoricalCertainty.documented => 'Documented',
        HistoricalCertainty.reliablyTraditional => 'Reliable tradition',
        HistoricalCertainty.legendary => 'Traditional or legendary',
        HistoricalCertainty.disputed => 'Disputed',
        HistoricalCertainty.mixed => 'Mixed',
      };
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onOpenUrl});

  final SaintSource source;
  final ValueChanged<Uri> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              source.authorOrInstitution,
              source.publisher,
            ].where((value) => value.trim().isNotEmpty).toSet().join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(_tierLabel(source.tier))),
              if (source.accessedDate != null)
                Chip(label: Text('Accessed ${_date(source.accessedDate!)}')),
            ],
          ),
          if (source.url != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => onOpenUrl(source.url!),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open source'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _tierLabel(SaintSourceTier tier) => switch (tier) {
    SaintSourceTier.primary => 'Primary or official source',
    SaintSourceTier.scholarly => 'Scholarly reference',
    SaintSourceTier.discovery => 'Discovery source',
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _ImageCredit extends StatelessWidget {
  const _ImageCredit({required this.image, required this.onOpenUrl});

  final SaintImageAttribution image;
  final ValueChanged<Uri> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Image credit',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(image.creditLine, style: theme.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Text(
          '${image.creator} · ${image.license}'
          '${image.isDerivative ? ' · Adapted' : ''}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (image.sourceUrl != null)
          TextButton.icon(
            onPressed: () => onOpenUrl(image.sourceUrl!),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open image source'),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          ),
      ],
    );
  }
}

class _Warnings extends StatelessWidget {
  const _Warnings({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Editorial notes',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final warning in warnings)
            Text(
              '• $warning',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
        ],
      ),
    );
  }
}
