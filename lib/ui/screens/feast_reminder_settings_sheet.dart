import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../data/services/feast_reminder_preferences.dart';
import '../../data/services/feast_reminder_service.dart';

/// Beautiful bottom-sheet UI for configuring feast/solemnity reminders.
class FeastReminderSettingsSheet extends StatefulWidget {
  const FeastReminderSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const FeastReminderSettingsSheet(),
    );
  }

  @override
  State<FeastReminderSettingsSheet> createState() =>
      _FeastReminderSettingsSheetState();
}

class _FeastReminderSettingsSheetState
    extends State<FeastReminderSettingsSheet> {
  FeastReminderPreferences? _prefs;
  bool _loading = true;
  bool _saving = false;
  bool _permissionDenied = false;

  bool _enabled = false;
  int _hour = 7;
  int _minute = 0;
  FeastReminderRank _rank = FeastReminderRank.solemnities;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await FeastReminderPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _enabled = prefs.isEnabled;
      _hour = prefs.hour;
      _minute = prefs.minute;
      _rank = prefs.rank;
      _loading = false;
    });
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final granted = await FeastReminderService.instance.requestPermission();
      if (!granted) {
        if (mounted) {
          setState(() => _permissionDenied = true);
        }
        return;
      }
    }

    setState(() {
      _enabled = value;
      _permissionDenied = false;
    });
    await _save();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
      helpText: 'Set reminder time',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await _save();
  }

  Future<void> _save() async {
    final prefs = _prefs;
    if (prefs == null) return;
    setState(() => _saving = true);
    try {
      await prefs.setEnabled(_enabled);
      await prefs.setTime(_hour, _minute);
      await prefs.setRank(_rank);

      final service = FeastReminderService.instance;
      if (_enabled) {
        await service.scheduleForYear(DateTime.now().year, prefs);
      } else {
        await service.cancelAll();
        await prefs.setLastScheduledYear(0);
      }
    } catch (e) {
      debugPrint('[FeastReminder] _save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update reminders. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Feast Day Reminders',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Be notified on feasts & solemnities',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const Divider(height: 24, indent: 24, endIndent: 24),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _enableToggleCard(theme, colorScheme, isLight),
                    if (_permissionDenied) _permissionBanner(colorScheme),
                    if (_enabled) ...[
                      const SizedBox(height: 12),
                      _timePickerCard(theme, colorScheme, isLight),
                      const SizedBox(height: 12),
                      _rankSelectorCard(theme, colorScheme, isLight),
                      const SizedBox(height: 12),
                      _upcomingPreview(theme, colorScheme),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _enableToggleCard(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isLight,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        value: _enabled,
        onChanged: _saving ? null : _toggleEnabled,
        title: Text(
          'Enable Reminders',
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          _enabled
              ? 'You\'ll receive notifications on feast days'
              : 'Off — tap to enable',
          style: theme.textTheme.bodySmall,
        ),
        secondary: _saving
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              )
            : Icon(
                _enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                color: _enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
        activeThumbColor: colorScheme.primary,
      ),
    );
  }

  Widget _permissionBanner(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: colorScheme.onErrorContainer, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                Platform.isIOS
                    ? 'Notification permission denied. Please enable in Settings > Catholic Daily.'
                    : 'Notification permission denied. Please enable in App Settings.',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timePickerCard(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isLight,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.access_time, color: colorScheme.primary),
        title: Text('Reminder Time', style: theme.textTheme.titleSmall),
        subtitle: Text(
          'Daily notification at this time',
          style: theme.textTheme.bodySmall,
        ),
        trailing: GestureDetector(
          onTap: _saving ? null : _pickTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _timeLabel,
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rankSelectorCard(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isLight,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_list, color: colorScheme.primary, size: 20),
                const SizedBox(width: 10),
                Text('Which days to remind', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...FeastReminderRank.values.map((rank) {
              final selected = _rank == rank;
              return _RankOption(
                rank: rank,
                selected: selected,
                colorScheme: colorScheme,
                theme: theme,
                onTap: _saving
                    ? null
                    : () async {
                        setState(() => _rank = rank);
                        await _save();
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _upcomingPreview(ThemeData theme, ColorScheme colorScheme) {
    final upcoming = _computeUpcoming();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: colorScheme.primary, size: 18),
                const SizedBox(width: 10),
                Text('Upcoming Reminders', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            ...upcoming.map((e) => _UpcomingTile(
                  event: e,
                  colorScheme: colorScheme,
                  theme: theme,
                )),
          ],
        ),
      ),
    );
  }

  List<_PreviewEvent> _computeUpcoming() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final events = <_PreviewEvent>[];

    for (final e in _buildUpcomingFeastDates()) {
      if (e.date.isBefore(todayDate) || events.length >= 4) continue;
      events.add(e);
    }
    return events;
  }

  List<_PreviewEvent> _buildUpcomingFeastDates() {
    final now = DateTime.now();
    final results = <_PreviewEvent>[];
    final lookup = _StaticFeastPreview();

    for (var d = now; d.year == now.year; d = d.add(const Duration(days: 1))) {
      final info = lookup.check(d);
      if (info != null && _shouldIncludeRank(info.rank)) {
        results.add(info);
      }
    }
    return results;
  }

  bool _shouldIncludeRank(String rank) {
    switch (_rank) {
      case FeastReminderRank.solemnities:
        return rank == 'Solemnity';
      case FeastReminderRank.feastsDays:
        return rank == 'Solemnity' || rank == 'Feast';
      case FeastReminderRank.all:
        return true;
    }
  }

  String get _timeLabel {
    final h = _hour;
    final m = _minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:$m $period';
  }
}

class _RankOption extends StatelessWidget {
  final FeastReminderRank rank;
  final bool selected;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _RankOption({
    required this.rank,
    required this.selected,
    required this.colorScheme,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = theme.brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withValues(alpha: isLight ? 0.10 : 0.18)
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outline.withValues(alpha: isLight ? 0.2 : 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rank.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    _rankDescription(rank),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _rankDescription(FeastReminderRank rank) {
    switch (rank) {
      case FeastReminderRank.solemnities:
        return 'Christmas, Easter, Assumption, and other highest-rank days';
      case FeastReminderRank.feastsDays:
        return 'Solemnities plus saints\' feast days';
      case FeastReminderRank.all:
        return 'All liturgical celebrations including optional memorials';
    }
  }
}

class _UpcomingTile extends StatelessWidget {
  final _PreviewEvent event;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _UpcomingTile({
    required this.event,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysAway = event.date.difference(DateTime(now.year, now.month, now.day)).inDays;
    final daysLabel = daysAway == 0
        ? 'Today'
        : daysAway == 1
            ? 'Tomorrow'
            : 'In $daysAway days';

    final isSolemnity = event.rank == 'Solemnity';
    final dotColor = isSolemnity ? colorScheme.primary : colorScheme.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      _formatDate(event.date),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: dotColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        daysLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lightweight static feast preview (no DB hit) for the upcoming list preview
// ---------------------------------------------------------------------------

class _PreviewEvent {
  final DateTime date;
  final String title;
  final String rank;
  const _PreviewEvent(this.date, this.title, this.rank);
}

class _StaticFeastPreview {
  _PreviewEvent? check(DateTime d) {
    final m = d.month;
    final day = d.day;
    final easter = _easter(d.year);

    // Movable
    final diffE = d.difference(easter).inDays;
    if (diffE == -46) return _PreviewEvent(d, 'Ash Wednesday', 'Day');
    if (diffE == -7) return _PreviewEvent(d, 'Palm Sunday', 'Solemnity');
    if (diffE == -3) return _PreviewEvent(d, 'Holy Thursday', 'Solemnity');
    if (diffE == -2) return _PreviewEvent(d, 'Good Friday', 'Day');
    if (diffE == 0) return _PreviewEvent(d, 'Easter Sunday', 'Solemnity');
    if (diffE == 39) return _PreviewEvent(d, 'Ascension Thursday', 'Solemnity');
    if (diffE == 49) return _PreviewEvent(d, 'Pentecost Sunday', 'Solemnity');
    if (diffE == 56) return _PreviewEvent(d, 'The Most Holy Trinity', 'Solemnity');
    if (diffE == 63) return _PreviewEvent(d, 'The Most Holy Body and Blood of Christ', 'Solemnity');

    // Fixed solemnities
    if (m == 1 && day == 1) return _PreviewEvent(d, 'Mary, the Holy Mother of God', 'Solemnity');
    if (m == 3 && day == 19) return _PreviewEvent(d, 'Saint Joseph', 'Solemnity');
    if (m == 3 && day == 25) return _PreviewEvent(d, 'The Annunciation of the Lord', 'Solemnity');
    if (m == 6 && day == 24) return _PreviewEvent(d, 'The Nativity of Saint John the Baptist', 'Solemnity');
    if (m == 6 && day == 29) return _PreviewEvent(d, 'Saints Peter and Paul', 'Solemnity');
    if (m == 8 && day == 15) return _PreviewEvent(d, 'The Assumption of the Blessed Virgin Mary', 'Solemnity');
    if (m == 11 && day == 1) return _PreviewEvent(d, 'All Saints', 'Solemnity');
    if (m == 12 && day == 8) return _PreviewEvent(d, 'The Immaculate Conception', 'Solemnity');
    if (m == 12 && day == 25) return _PreviewEvent(d, 'The Nativity of the Lord', 'Solemnity');

    // Feasts
    if (m == 1 && day == 6) return _PreviewEvent(d, 'The Epiphany of the Lord', 'Feast');
    if (m == 2 && day == 2) return _PreviewEvent(d, 'The Presentation of the Lord', 'Feast');
    if (m == 7 && day == 22) return _PreviewEvent(d, 'Saint Mary Magdalene', 'Feast');
    if (m == 8 && day == 6) return _PreviewEvent(d, 'The Transfiguration of the Lord', 'Feast');
    if (m == 9 && day == 14) return _PreviewEvent(d, 'The Exaltation of the Holy Cross', 'Feast');
    if (m == 9 && day == 29) return _PreviewEvent(d, 'Saints Michael, Gabriel, and Raphael', 'Feast');

    return null;
  }

  DateTime _easter(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }
}
