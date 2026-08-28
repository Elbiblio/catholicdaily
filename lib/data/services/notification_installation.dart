class NotificationInstallationCredentials {
  const NotificationInstallationCredentials({
    required this.installationId,
    required this.registrationSecret,
  });

  final String installationId;
  final String registrationSecret;

  Map<String, String> toCreateJson() => <String, String>{
    'installation_id': installationId,
    'registration_secret': registrationSecret,
  };

  String get authorization =>
      'Installation $installationId:$registrationSecret';

  @override
  String toString() =>
      'NotificationInstallationCredentials(installationId: '
      '$installationId, registrationSecret: <redacted>)';
}

class NotificationInstallationState {
  const NotificationInstallationState({
    required this.fcmToken,
    required this.platform,
    required this.appVersion,
    required this.locale,
    required this.timezone,
    required this.liturgicalRegion,
    required this.notificationPermission,
    required this.remindersEnabled,
    required this.reminderRank,
    required this.notifyDayBefore,
    required this.reminderHour,
    required this.reminderMinute,
    required this.scheduleGeneration,
    required this.coverageThrough,
  });

  final String fcmToken;
  final String platform;
  final String appVersion;
  final String locale;
  final String timezone;
  final String liturgicalRegion;
  final bool notificationPermission;
  final bool remindersEnabled;
  final String reminderRank;
  final bool notifyDayBefore;
  final int reminderHour;
  final int reminderMinute;
  final String scheduleGeneration;
  final DateTime? coverageThrough;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fcm_token': fcmToken,
    'platform': platform,
    'app_version': appVersion,
    'locale': locale,
    'timezone': timezone,
    'liturgical_region': liturgicalRegion,
    'notification_permission': notificationPermission,
    'reminders_enabled': remindersEnabled,
    'reminder_rank': reminderRank,
    'notify_day_before': notifyDayBefore,
    'reminder_hour': reminderHour,
    'reminder_minute': reminderMinute,
    'schedule_generation': scheduleGeneration,
    'coverage_through': coverageThrough == null
        ? null
        : _formatDate(coverageThrough!),
  };

  @override
  String toString() =>
      'NotificationInstallationState(platform: $platform, '
      'region: $liturgicalRegion, enabled: $remindersEnabled, '
      'coverageThrough: ${coverageThrough == null ? null : _formatDate(coverageThrough!)}, '
      'fcmToken: <redacted>)';
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
