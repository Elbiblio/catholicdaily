import 'dart:convert';

import 'improved_liturgical_calendar_service.dart';
import 'optional_memorial_service.dart';

class FeastReminderPayload {
  const FeastReminderPayload({
    required this.celebrationDate,
    this.scheduledFor,
    this.occurrenceKey,
    this.timeZone,
    this.liturgicalRegion,
    this.scheduleGeneration,
    required this.title,
    required this.rank,
    required this.saintProfileId,
    required this.dayBefore,
  });

  static const int schemaVersion = 2;

  final DateTime celebrationDate;
  final DateTime? scheduledFor;
  final String? occurrenceKey;
  final String? timeZone;
  final String? liturgicalRegion;
  final String? scheduleGeneration;
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

  Map<String, dynamic> toMap() {
    final key = occurrenceKey;
    if (key == null || key.trim().isEmpty) {
      return {
        'type': 'feast',
        'v': 1,
        'date': _dateOnly(celebrationDate),
        'title': title,
        'rank': rank,
        if (saintProfileId != null) 'saintId': saintProfileId,
        'timing': dayBefore ? 'eve' : 'day',
      };
    }

    return {
      'type': 'feast_reminder',
      'schema': schemaVersion,
      'v': schemaVersion,
      'occurrence_key': key,
      'celebration_date': _dateOnly(celebrationDate),
      if (scheduledFor != null)
        'scheduled_for': scheduledFor!.toIso8601String(),
      if (timeZone != null) 'timezone': timeZone,
      if (liturgicalRegion != null) 'liturgical_region': liturgicalRegion,
      if (scheduleGeneration != null) 'schedule_generation': scheduleGeneration,
      'title': title,
      'rank': rank,
      if (saintProfileId != null) 'saint_id': saintProfileId,
      'timing': dayBefore ? 'eve' : 'on_day',
    };
  }

  String encode() => jsonEncode(toMap());

  static FeastReminderPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = raw.trim();

    if (value.startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is! Map<String, dynamic>) {
          return null;
        }
        return fromMap(decoded);
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

  static FeastReminderPayload? fromMap(Map<String, dynamic> decoded) {
    try {
      final type = decoded['type'] as String?;
      final version = decoded['schema'] ?? decoded['v'];
      if (version == 1 && type == 'feast') {
        final date = DateTime.tryParse(decoded['date'] as String? ?? '');
        final title = decoded['title'] as String? ?? '';
        final rank = decoded['rank'] as String? ?? '';
        final rawSaintId = decoded['saintId'] as String?;
        if (date == null) return null;
        return FeastReminderPayload(
          celebrationDate: DateTime(date.year, date.month, date.day),
          title: title,
          rank: rank,
          saintProfileId: rawSaintId == null || rawSaintId.trim().isEmpty
              ? null
              : rawSaintId,
          dayBefore: decoded['timing'] == 'eve',
        );
      }

      if (version != schemaVersion ||
          (type != 'feast_reminder' && type != 'feast')) {
        return null;
      }
      final date = DateTime.tryParse(
        decoded['celebration_date'] as String? ?? '',
      );
      final key = decoded['occurrence_key'] as String? ?? '';
      final title = decoded['title'] as String? ?? '';
      if (date == null || key.trim().isEmpty || title.trim().isEmpty) {
        return null;
      }
      final rawSaintId = decoded['saint_id'] as String?;
      return FeastReminderPayload(
        celebrationDate: DateTime(date.year, date.month, date.day),
        scheduledFor: DateTime.tryParse(
          decoded['scheduled_for'] as String? ?? '',
        ),
        occurrenceKey: key,
        timeZone: decoded['timezone'] as String?,
        liturgicalRegion: decoded['liturgical_region'] as String?,
        scheduleGeneration: decoded['schedule_generation'] as String?,
        title: title,
        rank: decoded['rank'] as String? ?? '',
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
