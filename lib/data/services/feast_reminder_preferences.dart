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

  static FeastReminderPreferences? _instance;
  final SharedPreferences _prefs;

  FeastReminderPreferences._(this._prefs);

  static Future<FeastReminderPreferences> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = FeastReminderPreferences._(prefs);
    }
    return _instance!;
  }

  bool get isEnabled => _prefs.getBool(_enabledKey) ?? false;
  int get hour => _prefs.getInt(_hourKey) ?? 7;
  int get minute => _prefs.getInt(_minuteKey) ?? 0;
  FeastReminderRank get rank =>
      FeastReminderRank.fromKey(_prefs.getString(_rankKey) ?? '');
  int get lastScheduledYear => _prefs.getInt(_lastScheduledYearKey) ?? 0;

  Future<void> setEnabled(bool value) =>
      _prefs.setBool(_enabledKey, value);

  Future<void> setTime(int hour, int minute) async {
    await _prefs.setInt(_hourKey, hour);
    await _prefs.setInt(_minuteKey, minute);
  }

  Future<void> setRank(FeastReminderRank rank) =>
      _prefs.setString(_rankKey, rank.key);

  Future<void> setLastScheduledYear(int year) =>
      _prefs.setInt(_lastScheduledYearKey, year);

  String get timeLabel {
    final h = hour;
    final m = minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$displayHour:$m $period';
  }
}
