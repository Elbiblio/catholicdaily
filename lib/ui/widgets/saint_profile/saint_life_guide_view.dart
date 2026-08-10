import 'package:flutter/material.dart';

import '../../../data/models/saint_profile.dart';
import '../../../data/models/saint_profile_content.dart';
import '../../../data/models/saint_profile_source.dart';
import 'saint_profile_section.dart';

class SaintLifeGuideView extends StatelessWidget {
  const SaintLifeGuideView({
    super.key,
    required this.profile,
    required this.onShowSources,
  });

  final SaintProfile profile;
  final VoidCallback onShowSources;

  @override
  Widget build(BuildContext context) {
    final guide = profile.guide;
    if (guide == null) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showsLifeInfo(profile)) ...[
              _LifeInfo(profile: profile),
              const SizedBox(height: 28),
            ],
            SaintProfileSection(
              title: 'Why this saint matters today',
              icon: Icons.lightbulb_outline_rounded,
              child: _EmphasisPanel(child: Text(guide.whyItMatters)),
            ),
            SaintProfileSection(
              title: 'In one minute',
              icon: Icons.schedule_rounded,
              child: Text(guide.oneMinuteSummary),
            ),
            SaintProfileSection(
              title: 'Their life and journey',
              icon: Icons.route_rounded,
              child: _LifeSections(sections: guide.lifeSections),
            ),
            SaintProfileSection(
              title: 'The Gospel visible in their life',
              icon: Icons.menu_book_rounded,
              child: Text(guide.gospelTheme),
            ),
            SaintProfileSection(
              title: 'The struggle and response',
              icon: Icons.change_circle_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabelledText(label: 'The struggle', text: guide.struggle),
                  const SizedBox(height: 16),
                  _LabelledText(label: 'Their response', text: guide.response),
                ],
              ),
            ),
            SaintProfileSection(
              title: 'Virtues to imitate',
              icon: Icons.volunteer_activism_outlined,
              child: _VirtueList(virtues: guide.virtues),
            ),
            SaintProfileSection(
              title: 'Live it today',
              icon: Icons.directions_walk_rounded,
              child: Column(
                children: [
                  _PracticeRow(
                    icon: Icons.self_improvement_rounded,
                    label: 'Pray',
                    text: guide.practice.spiritual,
                  ),
                  const SizedBox(height: 12),
                  _PracticeRow(
                    icon: Icons.done_rounded,
                    label: 'Act',
                    text: guide.practice.action,
                  ),
                ],
              ),
            ),
            SaintProfileSection(
              title: 'Reflect',
              icon: Icons.psychology_alt_outlined,
              child: Column(
                children: [
                  for (
                    var index = 0;
                    index < guide.reflectionQuestions.length;
                    index++
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == guide.reflectionQuestions.length - 1
                            ? 0
                            : 12,
                      ),
                      child: _NumberedText(
                        number: index + 1,
                        text: guide.reflectionQuestions[index],
                      ),
                    ),
                ],
              ),
            ),
            SaintProfileSection(
              title: 'Scripture companion',
              icon: Icons.auto_stories_rounded,
              child: _ScriptureBlock(scripture: guide.scripture),
            ),
            SaintProfileSection(
              title: 'Prayer',
              icon: Icons.church_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A prayer from Catholic Daily',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _EmphasisPanel(child: Text(guide.prayer)),
                ],
              ),
            ),
            if (guide.quote != null) ...[
              _VerifiedQuote(quote: guide.quote!),
              const SizedBox(height: 28),
            ],
            if (_hasSourcedDevotionalDetails(profile)) ...[
              _DevotionalDetails(profile: profile),
              const SizedBox(height: 28),
            ],
            _SourcesButton(profile: profile, onPressed: onShowSources),
          ],
        ),
      ),
    );
  }

  static bool _showsLifeInfo(SaintProfile profile) {
    if (profile.lifeSpan.trim().isEmpty && profile.lifeLength.trim().isEmpty) {
      return false;
    }
    return switch (profile.kind) {
      SaintProfileKind.angelic ||
      SaintProfileKind.marian ||
      SaintProfileKind.collective ||
      SaintProfileKind.observance => false,
      _ => true,
    };
  }

  static bool _hasSourcedDevotionalDetails(SaintProfile profile) {
    if (profile.patronage.isEmpty && profile.symbols.isEmpty) return false;
    return profile.sources.any(
      (source) => source.supports.any(
        (field) => field == 'patronage' || field == 'symbols',
      ),
    );
  }
}

class _LifeInfo extends StatelessWidget {
  const _LifeInfo({required this.profile});

  final SaintProfile profile;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (profile.lifeSpan.trim().isNotEmpty)
          _InfoTile(
            icon: Icons.calendar_month_outlined,
            label: 'Lived',
            value: profile.lifeSpan,
          ),
        if (profile.lifeLength.trim().isNotEmpty)
          _InfoTile(
            icon: Icons.timelapse_rounded,
            label: 'Length',
            value: profile.lifeLength,
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 144),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmphasisPanel extends StatelessWidget {
  const _EmphasisPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: child,
    );
  }
}

class _LifeSections extends StatelessWidget {
  const _LifeSections({required this.sections});

  final List<SaintLifeSection> sections;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          Text(
            sections[index].heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(sections[index].body),
          if (index != sections.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _LabelledText extends StatelessWidget {
  const _LabelledText({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(text),
      ],
    );
  }
}

class _VirtueList extends StatelessWidget {
  const _VirtueList({required this.virtues});

  final List<SaintVirtue> virtues;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < virtues.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == virtues.length - 1 ? 0 : 12,
            ),
            child: _VirtueCard(number: index + 1, virtue: virtues[index]),
          ),
      ],
    );
  }
}

class _VirtueCard extends StatelessWidget {
  const _VirtueCard({required this.number, required this.virtue});

  final int number;
  final SaintVirtue virtue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NumberBadge(number: number),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  virtue.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LabelledText(label: 'Seen in their life', text: virtue.evidence),
          const SizedBox(height: 12),
          _LabelledText(label: 'Imitate it', text: virtue.imitation),
        ],
      ),
    );
  }
}

class _PracticeRow extends StatelessWidget {
  const _PracticeRow({
    required this.icon,
    required this.label,
    required this.text,
  });

  final IconData icon;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: _LabelledText(label: label, text: text),
          ),
        ],
      ),
    );
  }
}

class _NumberedText extends StatelessWidget {
  const _NumberedText({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberBadge(number: number),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScriptureBlock extends StatelessWidget {
  const _ScriptureBlock({required this.scripture});

  final SaintScriptureCompanion scripture;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _EmphasisPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scripture.reference,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(scripture.connection),
        ],
      ),
    );
  }
}

class _VerifiedQuote extends StatelessWidget {
  const _VerifiedQuote({required this.quote});

  final SaintVerifiedQuote quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${quote.attribution}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevotionalDetails extends StatelessWidget {
  const _DevotionalDetails({required this.profile});

  final SaintProfile profile;

  @override
  Widget build(BuildContext context) {
    return SaintProfileSection(
      title: 'Patronage and symbols',
      icon: Icons.local_florist_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final value in profile.patronage)
            Chip(label: Text('Patron of $value')),
          for (final value in profile.symbols) Chip(label: Text(value)),
        ],
      ),
    );
  }
}

class _SourcesButton extends StatelessWidget {
  const _SourcesButton({required this.profile, required this.onPressed});

  final SaintProfile profile;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final reviewedAt = profile.editorial.reviewedAt;
    final date = reviewedAt == null
        ? 'Review pending'
        : '${reviewedAt.year.toString().padLeft(4, '0')}-'
              '${reviewedAt.month.toString().padLeft(2, '0')}-'
              '${reviewedAt.day.toString().padLeft(2, '0')}';
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.fact_check_outlined),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Sources and review'),
          const SizedBox(height: 2),
          Text(
            '${_certaintyLabel(profile)} · $date',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  static String _certaintyLabel(SaintProfile profile) =>
      switch (profile.historicalCertainty) {
        HistoricalCertainty.documented => 'Documented history',
        HistoricalCertainty.reliablyTraditional => 'Reliable tradition',
        HistoricalCertainty.legendary => 'Traditional account',
        HistoricalCertainty.disputed => 'Historically disputed',
        HistoricalCertainty.mixed => 'Mixed historical record',
      };
}
