import 'dart:convert';

class FeastReminderNotificationContent {
  const FeastReminderNotificationContent({
    required this.title,
    required this.body,
    required this.expandedBody,
    required this.subtitle,
    required this.dateLabel,
  });

  final String title;
  final String body;
  final String expandedBody;
  final String subtitle;
  final String dateLabel;
}

class FeastReminderNotificationIdentity {
  const FeastReminderNotificationIdentity({
    required this.occurrenceKey,
    required this.notificationId,
    required this.groupKey,
    required this.sortKey,
  });

  final String occurrenceKey;
  final int notificationId;
  final String groupKey;
  final String sortKey;
}

class FeastReminderNotificationContract {
  static const scheduleGeneration = 'feast-reminders-v5';

  const FeastReminderNotificationContract._();

  static FeastReminderNotificationContent content({
    required DateTime celebrationDate,
    required String title,
    required String rank,
    required bool dayBefore,
    String locale = 'en',
  }) {
    final date = DateTime(
      celebrationDate.year,
      celebrationDate.month,
      celebrationDate.day,
    );
    final dateLabel = _dateLabel(date, locale);
    final rankLabel = _rankLabel(rank);
    final expandedLead = dayBefore
        ? 'The Church celebrates tomorrow, $dateLabel:'
        : 'On $dateLabel, the Church celebrates:';

    return FeastReminderNotificationContent(
      title: rankLabel == null
          ? '$dateLabel — Celebration'
          : '$dateLabel — A $rankLabel',
      body: title,
      expandedBody: '$expandedLead\n$title.',
      subtitle: dayBefore
          ? 'Tomorrow\'s celebration · $dateLabel'
          : '$dateLabel in the Sacred Liturgy',
      dateLabel: dateLabel,
    );
  }

  static FeastReminderNotificationIdentity identity({
    required String region,
    required DateTime celebrationDate,
    required bool dayBefore,
    required String celebrationId,
  }) {
    final date = _dateOnly(celebrationDate);
    final timing = dayBefore ? 'eve' : 'on_day';
    final normalizedRegion = _slug(region);
    final normalizedCelebration = _slug(celebrationId);
    final occurrenceKey =
        'feast:$normalizedRegion:$date:$timing:$normalizedCelebration';

    return FeastReminderNotificationIdentity(
      occurrenceKey: occurrenceKey,
      notificationId: stableNotificationId(occurrenceKey),
      groupKey: 'feast_reminders:$date',
      sortKey: '$date:$timing:$normalizedCelebration',
    );
  }

  static int stableNotificationId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    final positive = hash & 0x7fffffff;
    return positive == 0 ? 1 : positive;
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'celebration' : slug;
  }

  static String? _rankLabel(String rank) {
    final normalized = rank.trim().toLowerCase();
    if (normalized == 'solemnity') return 'Solemnity';
    if (normalized == 'feast') return 'Feast';
    if (normalized.contains('memorial')) return 'Memorial';
    return null;
  }

  static String _dateLabel(DateTime date, String locale) {
    // Catholic Daily currently ships English notification copy. Keeping the
    // date formatter self-contained makes it safe in background isolates,
    // where intl locale initialization is not guaranteed to have run.
    if (locale.trim().isEmpty) {
      throw ArgumentError.value(locale, 'locale', 'must not be empty');
    }
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
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
    return '${weekdays[date.weekday - 1]}, ${date.day} '
        '${months[date.month - 1]}';
  }
}
