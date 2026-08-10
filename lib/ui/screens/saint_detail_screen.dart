import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/saint_profile.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/optional_memorial_service.dart';
import '../../data/services/saint_profile_service.dart';
import '../widgets/saint_profile/saint_life_guide_view.dart';
import '../widgets/saint_profile/saint_sources_sheet.dart';

typedef SaintProfileLoader =
    Future<SaintProfile?> Function(OptionalCelebration celebration);

class SaintDetailScreen extends StatefulWidget {
  final OptionalCelebration celebration;
  final SaintProfileLoader? profileLoader;

  const SaintDetailScreen({
    super.key,
    required this.celebration,
    this.profileLoader,
  });

  @override
  State<SaintDetailScreen> createState() => _SaintDetailScreenState();
}

class _SaintDetailScreenState extends State<SaintDetailScreen> {
  late Future<SaintProfile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _requestProfile();
  }

  @override
  void didUpdateWidget(covariant SaintDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.celebration != widget.celebration ||
        oldWidget.profileLoader != widget.profileLoader) {
      _profileFuture = _requestProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_shortTitle(widget.celebration.title))),
      body: FutureBuilder<SaintProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _PageList(
              children: [
                _Header(
                  title: widget.celebration.title,
                  subtitle: _celebrationSubtitle(widget.celebration),
                  color: _colorForLiturgicalColor(widget.celebration.color),
                ),
                const SizedBox(height: 18),
                _LoadError(onRetry: _retry),
              ],
            );
          }

          final profile = snapshot.data;
          return _PageList(
            children: [
              _Header(
                title: profile?.name ?? widget.celebration.title,
                subtitle: _celebrationSubtitle(widget.celebration),
                color: _colorForLiturgicalColor(widget.celebration.color),
              ),
              const SizedBox(height: 18),
              if (profile == null)
                _MissingProfile(celebration: widget.celebration)
              else if (profile.isPublished && profile.hasFullGuide)
                SaintLifeGuideView(
                  profile: profile,
                  onShowSources: () => SaintSourcesSheet.show(
                    context,
                    profile,
                    onOpenUrl: _openExternalUri,
                  ),
                )
              else
                _ProfileBody(
                  profile: profile,
                  onOpenWikipedia: profile.hasWikipediaLink
                      ? () => _openExternalUri(Uri.parse(profile.wikipediaUrl!))
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<SaintProfile?> _requestProfile() {
    final loader =
        widget.profileLoader ?? SaintProfileService.instance.findForCelebration;
    return Future<SaintProfile?>.sync(() => loader(widget.celebration));
  }

  void _retry() {
    setState(() {
      _profileFuture = _requestProfile();
    });
  }

  Future<void> _openExternalUri(Uri uri) async {
    HapticFeedback.selectionClick();
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  static String _shortTitle(String title) {
    return title
        .replaceFirst(RegExp(r'^Saint '), 'St. ')
        .replaceFirst(RegExp(r'^Saints '), 'Sts. ');
  }

  static String _celebrationSubtitle(OptionalCelebration celebration) {
    final date = '${_monthName(celebration.month)} ${celebration.day}';
    return '$date - ${_rankLabel(celebration.rank)}';
  }

  static String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > names.length) return '';
    return names[month - 1];
  }

  static String _rankLabel(CelebrationRank rank) {
    switch (rank) {
      case CelebrationRank.solemnity:
        return 'Solemnity';
      case CelebrationRank.feast:
        return 'Feast';
      case CelebrationRank.obligatoryMemorial:
        return 'Memorial';
      case CelebrationRank.optionalMemorial:
        return 'Optional memorial';
    }
  }

  static Color _colorForLiturgicalColor(LiturgicalColor color) {
    switch (color) {
      case LiturgicalColor.green:
        return const Color(0xFF228B22);
      case LiturgicalColor.purple:
        return const Color(0xFF6B3FA0);
      case LiturgicalColor.red:
        return const Color(0xFFB22222);
      case LiturgicalColor.pink:
        return const Color(0xFFD84C8A);
      case LiturgicalColor.white:
        return const Color(0xFFD4AF37);
      case LiturgicalColor.gold:
        return const Color(0xFFD4AF37);
    }
  }
}

class _PageList extends StatelessWidget {
  const _PageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: children,
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: isDark ? 0.18 : 0.10),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.24 : 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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

class _ProfileBody extends StatelessWidget {
  final SaintProfile profile;
  final VoidCallback? onOpenWikipedia;

  const _ProfileBody({required this.profile, required this.onOpenWikipedia});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.manage_search_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Research in progress',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This existing offline profile is being expanded and '
                      'reviewed for the full spiritual life guide.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (profile.hasLifeInfo)
          _InfoStrip(
            children: [
              _InfoCell(
                icon: Icons.calendar_month_rounded,
                label: 'Lived',
                value: profile.lifeSpan.isEmpty ? 'Unknown' : profile.lifeSpan,
              ),
              _InfoCell(
                icon: Icons.timelapse_rounded,
                label: 'Length',
                value: profile.lifeLength.isEmpty
                    ? 'Unknown'
                    : profile.lifeLength,
              ),
            ],
          ),
        if (profile.hasLifeInfo) const SizedBox(height: 18),
        Text(
          'Patronage',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (profile.patronage.isEmpty)
          Text(
            'No patronage has been curated for this profile yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.patronage
                .map((item) => _PatronageChip(label: item))
                .toList(growable: false),
          ),
        const SizedBox(height: 22),
        Text(
          'Brief Bio',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          profile.briefBio,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        if (profile.feastDates.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text(
            'Feast Day',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(profile.feastDates.join(', '), style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 24),
        if (onOpenWikipedia != null)
          FilledButton.icon(
            onPressed: onOpenWikipedia,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open reference article'),
          ),
        if (profile.sources.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Sources: ${profile.sources.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _MissingProfile extends StatelessWidget {
  final OptionalCelebration celebration;

  const _MissingProfile({required this.celebration});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profile unavailable',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'No verified offline profile is available for '
            '${celebration.title} yet.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            'Celebration type: ${_rankLabel(celebration.rank)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  static String _rankLabel(CelebrationRank rank) {
    switch (rank) {
      case CelebrationRank.solemnity:
        return 'Solemnity';
      case CelebrationRank.feast:
        return 'Feast';
      case CelebrationRank.obligatoryMemorial:
        return 'Memorial';
      case CelebrationRank.optionalMemorial:
        return 'Optional memorial';
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Could not load this profile',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The offline profile could not be read. Please try again.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final List<Widget> children;

  const _InfoStrip({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map(
              (child) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: child,
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _PatronageChip extends StatelessWidget {
  final String label;

  const _PatronageChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.36 : 0.55,
      ),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: theme.colorScheme.primary.withValues(alpha: 0.18),
      ),
    );
  }
}
