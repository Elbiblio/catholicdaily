import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../firebase_options.dart';
import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_service.dart';
import 'feast_reminder_timezone.dart';
import 'liturgical_region_preference_service.dart';
import 'notification_installation.dart';
import 'notification_installation_api.dart';
import 'notification_installation_store.dart';
import 'feast_reminder_schedule_lock.dart';

typedef NotificationInstallationStateBuilder =
    Future<NotificationInstallationState> Function(String token);

class NotificationInstallationSyncService {
  NotificationInstallationSyncService({
    NotificationInstallationApi? api,
    NotificationInstallationStore? store,
    NotificationInstallationStateBuilder? buildState,
    InterprocessFileLock? registrationLock,
  }) : _api = api ?? NotificationInstallationApi(),
       _store = store ?? NotificationInstallationStore(),
       _buildStateOverride = buildState,
       _registrationLock =
           registrationLock ??
           InterprocessFileLock(
             file: File(
               '${Directory.systemTemp.path}${Platform.pathSeparator}'
               'catholic-daily-notification-installation-sync.lock',
             ),
           );

  static final NotificationInstallationSyncService instance =
      NotificationInstallationSyncService();

  final NotificationInstallationApi _api;
  final NotificationInstallationStore _store;
  final NotificationInstallationStateBuilder? _buildStateOverride;
  final InterprocessFileLock _registrationLock;

  Future<bool> syncCurrentToken() async {
    if (!DefaultFirebaseOptions.isSupported) return true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      return _registrationLock.synchronized(_syncCurrentTokenLocked);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _syncCurrentTokenLocked() async {
    final prefs = await FeastReminderPreferences.getInstance();
    final credentials = await _store.credentials();
    final registered = await _store.isRegistered;
    if (!prefs.isEnabled) {
      if (!registered) return true;
      final result = await _api.disable(credentials);
      if (result == NotificationInstallationApiResult.success ||
          result == NotificationInstallationApiResult.reRegister) {
        await _store.markRegistered(false);
      }
      return result != NotificationInstallationApiResult.retry;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return false;
    return _syncTokenLocked(token);
  }

  Future<bool> syncToken(String fcmToken) async {
    if (fcmToken.trim().isEmpty) return false;
    try {
      return _registrationLock.synchronized(() => _syncTokenLocked(fcmToken));
    } catch (_) {
      return false;
    }
  }

  Future<bool> _syncTokenLocked(String fcmToken) async {
    final credentials = await _store.credentials();
    final state =
        await (_buildStateOverride?.call(fcmToken) ?? _buildState(fcmToken));
    var registered = await _store.isRegistered;
    var result = registered
        ? await _api.update(credentials, state)
        : await _api.create(credentials, state);

    if (result == NotificationInstallationApiResult.reRegister) {
      result = registered
          ? await _api.create(credentials, state)
          : await _api.update(credentials, state);
      registered = result == NotificationInstallationApiResult.success;
    }

    if (result == NotificationInstallationApiResult.success) {
      await _store.markRegistered(true);
      await _store.markSynchronized(state);
      return true;
    }
    if (result == NotificationInstallationApiResult.invalid) {
      return true;
    }
    if (!registered) await _store.markRegistered(false);
    return false;
  }

  Future<NotificationInstallationState> _buildState(String token) async {
    final prefs = await FeastReminderPreferences.getInstance();
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    final package = await PackageInfo.fromPlatform();
    final timezone = await FeastReminderTimezone.configure();
    final permission = await FeastReminderService.instance.hasPermission();
    return NotificationInstallationState(
      fcmToken: token,
      platform: Platform.operatingSystem,
      appVersion: '${package.version}+${package.buildNumber}',
      locale: Platform.localeName,
      timezone: timezone,
      liturgicalRegion: regionPrefs.currentRegion.name,
      notificationPermission: permission,
      remindersEnabled: prefs.isEnabled,
      reminderRank: prefs.rank.key,
      notifyDayBefore: prefs.notifyDayBefore,
      reminderHour: prefs.hour,
      reminderMinute: prefs.minute,
      scheduleGeneration: FeastReminderNotificationContract.scheduleGeneration,
      coverageThrough: prefs.scheduledThrough,
    );
  }
}
