import 'dart:convert';

import 'improved_liturgical_calendar_service.dart';
import 'optional_memorial_service.dart';

class FeastReminderPayload {
  const FeastReminderPayload({
    required this.celebrationDate,
    required this.title,
    required this.rank,
    required this.saintProfileId,
    required this.dayBefore,
  });

  static const int schemaVersion = 1;

  final DateTime celebrationDate;
  final String title;
  final String rank;
  final String? saintProfileId;
  final bool dayBefore;

  OptionalCelebration? toSaintCelebration() {
    final profileId = saintProfileId;
    if (profileId == null || profileId.isEmpty || title.trim().isEmpty) {
      return null;
    }
    return OptionalCelebration(
      id: profileId,
      title: title,
      rank: switch (rank) {
        'Solemnity' => CelebrationRank.solemnity,
        'Feast' => CelebrationRank.feast,
        'Memorial' => CelebrationRank.obligatoryMemorial,
        _ => CelebrationRank.optionalMemorial,
      },
      color: _colorFromTitle(title),
      month: celebrationDate.month,
      day: celebrationDate.day,
      commonType: null,
    );
  }

  String encode() => jsonEncode({
    'type': 'feast',
    'v': schemaVersion,
    'date': _dateOnly(celebrationDate),
    'title': title,
    'rank': rank,
    if (saintProfileId != null) 'saintId': saintProfileId,
    'timing': dayBefore ? 'eve' : 'day',
  });

  static FeastReminderPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map<String, dynamic> ||
            decoded['type'] != 'feast' ||
            decoded['v'] != schemaVersion) {
          return null;
        }
        final date = DateTime.tryParse(decoded['date'] as String? ?? '');
        final title = decoded['title'] as String? ?? '';
        final rank = decoded['rank'] as String? ?? '';
        final rawSaintId = decoded['saintId'] as String?;
        if (date == null || title.trim().isEmpty) return null;
        return FeastReminderPayload(
          celebrationDate: DateTime(date.year, date.month, date.day),
          title: title,
          rank: rank,
          saintProfileId: rawSaintId == null || rawSaintId.trim().isEmpty
              ? null
              : rawSaintId,
          dayBefore: decoded['timing'] == 'eve',
        );
      } on FormatException {
        return null;
      } on TypeError {
        return null;
      }
    }

    const legacyPrefix = 'feast:';
    if (!value.startsWith(legacyPrefix)) return null;
    final timingSeparator = value.lastIndexOf(':');
    if (timingSeparator <= legacyPrefix.length) return null;
    final date = DateTime.tryParse(
      value.substring(legacyPrefix.length, timingSeparator),
    );
    if (date == null) return null;
    return FeastReminderPayload(
      celebrationDate: DateTime(date.year, date.month, date.day),
      title: '',
      rank: '',
      saintProfileId: null,
      dayBefore: value.substring(timingSeparator + 1) == 'eve',
    );
  }

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static LiturgicalColor _colorFromTitle(String title) {
    final normalized = title.toLowerCase();
    if (normalized.contains('martyr') ||
        normalized.contains('apostle') ||
        normalized.contains('holy cross')) {
      return LiturgicalColor.red;
    }
    return LiturgicalColor.white;
  }
}
