import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeastReminderRank {
  solemnities('solemnities', 'Solemnities only'),
  feastsDays('feasts', 'Feasts & Solemnities'),
  all('all', 'All memorials & feasts');

  final String key;
  final String label;
  const FeastReminderRank(this.key, this.label);

  static FeastReminderRank fromKey(String key) {
    return FeastReminderRank.values.firstWhere(
      (r) => r.key == key,
      orElse: () => FeastReminderRank.solemnities,
    );
  }
}

class FeastReminderPreferences {
  static const String _enabledKey = 'feast_reminders_enabled';
  static const String _hourKey = 'feast_reminder_hour';
  static const String _minuteKey = 'feast_reminder_minute';
  static const String _rankKey = 'feast_reminder_rank';
  static const String _lastScheduledYearKey = 'feast_reminder_last_year';
  static const String _scheduleSchemaVersionKey =
      'feast_reminder_schedule_schema_version';
  static const String _scheduledThroughKey = 'feast_reminder_scheduled_through';
  static const String _scheduleGenerationKey =
      'feast_reminder_schedule_generation';
  static const String _scheduleTimezoneKey = 'feast_reminder_schedule_timezone';
  static const String _lastAuditAtKey = 'feast_reminder_last_audit_at';
  static const String _scheduledNotificationReferencesKey =
      'feast_reminder_scheduled_notification_references';
  static const String _scheduledNotificationPayloadsKey =
      'feast_reminder_scheduled_notification_payloads';
  static const String _scheduleInProgressKey =
      'feast_reminder_schedule_in_progress';
  static const String _scheduleJournalReferencesKey =
      'feast_reminder_schedule_journal_references';
  static const String _scheduleJournalPayloadsKey =
      'feast_reminder_schedule_journal_payloads';
  static const String _scheduledConfigurationKey =
      'feast_reminder_scheduled_configuration';
  static const String _autoSetupCompletedKey = 'feast_reminder_auto_setup_done';
  static const String _dayBeforeKey = 'feast_reminder_day_before';

  static FeastReminderPreferences? _instance;
  static Future<bool> Function(String key, Future<bool> Function() write)?
  _writeInterceptor;
  final SharedPreferences _prefs;

  FeastReminderPreferences._(this._prefs);

  static Future<FeastReminderPreferences> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = FeastReminderPreferences._(prefs);
    }
    return _instance!;
  }

  static void resetInstanceForTesting() => _instance = null;

  @visibleForTesting
  static void setWriteInterceptorForTesting(
    Future<bool> Function(String key, Future<bool> Function() write) value,
  ) => _writeInterceptor = value;

  @visibleForTesting
  static void resetWriteInterceptorForTesting() => _writeInterceptor = null;

  Future<void> _write(String key, Future<bool> Function() operation) async {
    final succeeded =
        await (_writeInterceptor?.call(key, operation) ?? operation());
    if (!succeeded) throw StateError('Unable to persist $key');
  }

  Future<void> reload() => _prefs.reload();

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;
  int get hour => _prefs.getInt(_hourKey) ?? 0;
  int get minute => _prefs.getInt(_minuteKey) ?? 0;
  FeastReminderRank get rank =>
      FeastReminderRank.fromKey(_prefs.getString(_rankKey) ?? '');
  int get lastScheduledYear => _prefs.getInt(_lastScheduledYearKey) ?? 0;
  int get scheduleSchemaVersion =>
      _prefs.getInt(_scheduleSchemaVersionKey) ?? 0;
  DateTime? get scheduledThrough {
    final timestamp = _prefs.getInt(_scheduledThroughKey);
    return timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  String? get scheduleGeneration => _prefs.getString(_scheduleGenerationKey);
  String? get scheduleTimezone => _prefs.getString(_scheduleTimezoneKey);
  String? get scheduledConfigurationFingerprint =>
      _prefs.getString(_scheduledConfigurationKey);
  DateTime? get lastAuditAt {
    final timestamp = _prefs.getInt(_lastAuditAtKey);
    return timestamp == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  List<String> get scheduledNotificationReferences => List<String>.unmodifiable(
    _prefs.getStringList(_scheduledNotificationReferencesKey) ?? const [],
  );
  List<String> get scheduledNotificationPayloads => List<String>.unmodifiable(
    _prefs.getStringList(_scheduledNotificationPayloadsKey) ?? const [],
  );
  bool get scheduleInProgress =>
      _prefs.getBool(_scheduleInProgressKey) ?? false;
  List<String> get scheduleJournalReferences => List<String>.unmodifiable(
    _prefs.getStringList(_scheduleJournalReferencesKey) ?? const [],
  );
  List<String> get scheduleJournalPayloads => List<String>.unmodifiable(
    _prefs.getStringList(_scheduleJournalPayloadsKey) ?? const [],
  );
  List<String> get cancellationNotificationReferences =>
      List<String>.unmodifiable({
        ...scheduledNotificationReferences,
        ...scheduleJournalReferences,
      });
  bool get hasCancellationState =>
      scheduleInProgress ||
      scheduleSchemaVersion > 0 ||
      cancellationNotificationReferences.isNotEmpty;

  String configurationFingerprint({required String region}) =>
      'v1|$region|${rank.key}|$hour|$minute|$notifyDayBefore';

  /// When true, the notification fires the EVENING BEFORE the feast at
  /// [hour]:[minute] (e.g. 8pm/9pm/10pm/11pm). When false, fires on the
  /// DAY OF the feast at [hour]:[minute] (e.g. 6am/12pm/6pm).
  bool get notifyDayBefore => _prefs.getBool(_dayBeforeKey) ?? false;

  Future<void> setNotifyDayBefore(bool value) =>
      _prefs.setBool(_dayBeforeKey, value);

  /// True once the first-run auto-setup has run. After that, the user's
  /// explicit preference is authoritative — we never re-enable behind their
  /// back if they later turn reminders off.
  bool get autoSetupCompleted =>
      _prefs.getBool(_autoSetupCompletedKey) ?? false;

  Future<void> markAutoSetupCompleted() =>
      _prefs.setBool(_autoSetupCompletedKey, true);

  Future<void> setEnabled(bool value) => _prefs.setBool(_enabledKey, value);

  Future<void> setTime(int hour, int minute) async {
    await _prefs.setInt(_hourKey, hour);
    await _prefs.setInt(_minuteKey, minute);
  }

  Future<void> setRank(FeastReminderRank rank) =>
      _prefs.setString(_rankKey, rank.key);

  Future<void> setLastScheduledYear(int year) =>
      _prefs.setInt(_lastScheduledYearKey, year);

  Future<void> setScheduleSchemaVersion(int version) =>
      _prefs.setInt(_scheduleSchemaVersionKey, version);

  Future<void> setScheduledThrough(DateTime value) =>
      _prefs.setInt(_scheduledThroughKey, value.millisecondsSinceEpoch);

  Future<void> setScheduleGeneration(String value) =>
      _prefs.setString(_scheduleGenerationKey, value);

  Future<void> setScheduleTimezone(String value) =>
      _prefs.setString(_scheduleTimezoneKey, value);

  Future<void> setLastAuditAt(DateTime value) =>
      _prefs.setInt(_lastAuditAtKey, value.millisecondsSinceEpoch);

  Future<void> setScheduledNotificationReferences(List<String> values) =>
      _prefs.setStringList(_scheduledNotificationReferencesKey, values);

  Future<void> beginScheduleUpdate() async {
    final recovering = scheduleInProgress;
    await _write(
      _scheduleJournalReferencesKey,
      () => _prefs.setStringList(
        _scheduleJournalReferencesKey,
        recovering
            ? <String>{
                ...scheduleJournalReferences,
                ...scheduledNotificationReferences,
              }.toList(growable: false)
            : scheduledNotificationReferences,
      ),
    );
    await _write(
      _scheduleJournalPayloadsKey,
      () => _prefs.setStringList(
        _scheduleJournalPayloadsKey,
        recovering
            ? <String>{
                ...scheduleJournalPayloads,
                ...scheduledNotificationPayloads,
              }.toList(growable: false)
            : scheduledNotificationPayloads,
      ),
    );
    await _write(
      _scheduleInProgressKey,
      () => _prefs.setBool(_scheduleInProgressKey, true),
    );
  }

  Future<void> setScheduleJournalReferences(List<String> values) => _write(
    _scheduleJournalReferencesKey,
    () => _prefs.setStringList(_scheduleJournalReferencesKey, values),
  );

  Future<void> setScheduleJournalPayloads(List<String> values) => _write(
    _scheduleJournalPayloadsKey,
    () => _prefs.setStringList(_scheduleJournalPayloadsKey, values),
  );

  Future<void> clearScheduleFreshnessForUpdate() async {
    await _prefs.setInt(_lastScheduledYearKey, 0);
    await _prefs.setInt(_scheduleSchemaVersionKey, 0);
    await _prefs.remove(_scheduledThroughKey);
    await _prefs.remove(_scheduleGenerationKey);
    await _prefs.remove(_scheduleTimezoneKey);
    await _prefs.remove(_lastAuditAtKey);
    await _prefs.remove(_scheduledNotificationReferencesKey);
    await _prefs.remove(_scheduledNotificationPayloadsKey);
    await _prefs.remove(_scheduledConfigurationKey);
  }

  Future<void> completeScheduleUpdate({
    required int lastScheduledYear,
    required DateTime scheduledThrough,
    required int schemaVersion,
    required String scheduleGeneration,
    required String scheduleTimezone,
    required DateTime auditedAt,
    required String configurationFingerprint,
    required List<String> references,
    required List<String> payloads,
  }) async {
    // Keep the in-progress marker and journal intact until every freshness
    // field and cancellation reference has been durably written.
    await _write(
      _scheduleJournalReferencesKey,
      () => _prefs.setStringList(_scheduleJournalReferencesKey, references),
    );
    await _write(
      _scheduleJournalPayloadsKey,
      () => _prefs.setStringList(_scheduleJournalPayloadsKey, payloads),
    );
    await _write(
      _scheduledNotificationReferencesKey,
      () =>
          _prefs.setStringList(_scheduledNotificationReferencesKey, references),
    );
    await _write(
      _scheduledNotificationPayloadsKey,
      () => _prefs.setStringList(_scheduledNotificationPayloadsKey, payloads),
    );
    await _write(
      _lastScheduledYearKey,
      () => _prefs.setInt(_lastScheduledYearKey, lastScheduledYear),
    );
    await _write(
      _scheduledThroughKey,
      () => _prefs.setInt(
        _scheduledThroughKey,
        scheduledThrough.millisecondsSinceEpoch,
      ),
    );
    await _write(
      _scheduleSchemaVersionKey,
      () => _prefs.setInt(_scheduleSchemaVersionKey, schemaVersion),
    );
    await _write(
      _scheduleGenerationKey,
      () => _prefs.setString(_scheduleGenerationKey, scheduleGeneration),
    );
    await _write(
      _scheduleTimezoneKey,
      () => _prefs.setString(_scheduleTimezoneKey, scheduleTimezone),
    );
    await _write(
      _scheduledConfigurationKey,
      () => _prefs.setString(
        _scheduledConfigurationKey,
        configurationFingerprint,
      ),
    );
    await _write(
      _lastAuditAtKey,
      () => _prefs.setInt(_lastAuditAtKey, auditedAt.millisecondsSinceEpoch),
    );
    await _write(
      _scheduleJournalReferencesKey,
      () => _prefs.remove(_scheduleJournalReferencesKey),
    );
    await _write(
      _scheduleJournalPayloadsKey,
      () => _prefs.remove(_scheduleJournalPayloadsKey),
    );
    await _write(
      _scheduleInProgressKey,
      () => _prefs.setBool(_scheduleInProgressKey, false),
    );
  }

  Future<void> invalidateSchedule() async {
    await _write(
      _lastScheduledYearKey,
      () => _prefs.setInt(_lastScheduledYearKey, 0),
    );
    await _write(
      _scheduleSchemaVersionKey,
      () => _prefs.setInt(_scheduleSchemaVersionKey, 0),
    );
    await _write(
      _scheduledThroughKey,
      () => _prefs.remove(_scheduledThroughKey),
    );
    await _write(
      _scheduleGenerationKey,
      () => _prefs.remove(_scheduleGenerationKey),
    );
    await _write(
      _scheduleTimezoneKey,
      () => _prefs.remove(_scheduleTimezoneKey),
    );
    await _write(_lastAuditAtKey, () => _prefs.remove(_lastAuditAtKey));
    await _write(
      _scheduledNotificationReferencesKey,
      () => _prefs.remove(_scheduledNotificationReferencesKey),
    );
    await _write(
      _scheduledNotificationPayloadsKey,
      () => _prefs.remove(_scheduledNotificationPayloadsKey),
    );
    await _write(
      _scheduledConfigurationKey,
      () => _prefs.remove(_scheduledConfigurationKey),
    );
    await _write(
      _scheduleJournalReferencesKey,
      () => _prefs.remove(_scheduleJournalReferencesKey),
    );
    await _write(
      _scheduleJournalPayloadsKey,
      () => _prefs.remove(_scheduleJournalPayloadsKey),
    );
    await _write(
      _scheduleInProgressKey,
      () => _prefs.remove(_scheduleInProgressKey),
    );
  }

  String get timeLabel {
    final h = hour;
    final m = minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:$m $period';
  }

  /// Human-readable summary including the day-before suffix.
  /// E.g. "9:00 PM (day before)" or "6:00 AM".
  String get slotLabel {
    return notifyDayBefore ? '$timeLabel (day before)' : timeLabel;
  }
}
