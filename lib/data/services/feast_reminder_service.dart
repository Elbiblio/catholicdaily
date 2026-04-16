import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'feast_reminder_preferences.dart';
import 'offline_ordo_lookup_service.dart';

/// Represents a feast/solemnity event that can trigger a reminder.
class _FeastEvent {
  final DateTime date;
  final String title;
  final String rank;

  const _FeastEvent({
    required this.date,
    required this.title,
    required this.rank,
  });
}

class FeastReminderService {
  static FeastReminderService? _instance;
  static FeastReminderService get instance =>
      _instance ??= FeastReminderService._();

  FeastReminderService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'feast_reminders';
  static const _channelName = 'Feast & Solemnity Reminders';
  static const _channelDesc =
      'Daily reminders for Catholic feasts and solemnities';

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Request notification permission and return whether it was granted.
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final result = await androidPlugin?.requestNotificationsPermission();
      return result ?? false;
    }
    return true;
  }

  /// Check if notification permission has been granted.
  Future<bool> hasPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return (await androidPlugin?.areNotificationsEnabled()) ?? false;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await iosPlugin?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return true;
  }

  /// Cancel all scheduled feast reminders.
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  /// Schedule reminders for feasts in [year] based on current preferences.
  Future<void> scheduleForYear(
    int year,
    FeastReminderPreferences prefs,
  ) async {
    await initialize();
    await _plugin.cancelAll();

    if (!prefs.isEnabled) return;

    final events = _buildFeastEvents(year, prefs.rank);
    final now = DateTime.now();
    int notifId = 1000;
    int scheduled = 0;
    const maxNotifications = 64;

    for (final event in events) {
      if (scheduled >= maxNotifications) break;
      final scheduledTime = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
        prefs.hour,
        prefs.minute,
      );
      if (scheduledTime.isBefore(now)) continue;

      final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

      try {
        await _plugin.zonedSchedule(
          notifId++,
          _notificationTitle(event),
          _notificationBody(event),
          tzScheduled,
          _buildNotificationDetails(event),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'feast:${event.date.toIso8601String()}',
        );
        scheduled++;
      } catch (e) {
        debugPrint('[FeastReminder] Failed to schedule ${event.title}: $e');
      }
    }

    await prefs.setLastScheduledYear(year);
    debugPrint('[FeastReminder] Scheduled $scheduled reminders for $year (${events.length} total feasts found)');
  }

  String _notificationTitle(_FeastEvent event) {
    if (event.rank == 'Solemnity') return 'Today is a Solemnity';
    if (event.rank == 'Feast') return 'Today is a Feast Day';
    return 'Today\'s Celebration';
  }

  String _notificationBody(_FeastEvent event) => event.title;

  NotificationDetails _buildNotificationDetails(_FeastEvent event) {
    final isSolemnity = event.rank == 'Solemnity';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: isSolemnity ? Importance.high : Importance.defaultImportance,
        priority: isSolemnity ? Priority.high : Priority.defaultPriority,
        enableVibration: isSolemnity,
        icon: '@mipmap/ic_launcher',
        color: const Color(0xFF8C1D2F),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        categoryIdentifier: 'feast_reminder',
      ),
    );
  }

  /// Build the list of feast events for [year] filtered by [rank].
  List<_FeastEvent> _buildFeastEvents(int year, FeastReminderRank rank) {
    final lookup = OfflineOrdoLookupService.instance;
    final events = <_FeastEvent>[];

    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);

    for (var d = start;
        !d.isAfter(end);
        d = d.add(const Duration(days: 1))) {
      try {
        final day = lookup.resolve(d);
        if (_shouldInclude(day.rank, rank)) {
          events.add(
            _FeastEvent(
              date: d,
              title: day.title,
              rank: day.rank ?? '',
            ),
          );
        }
      } catch (e) {
        debugPrint('[FeastReminder] Error resolving $d: $e');
      }
    }

    return events;
  }

  bool _shouldInclude(String? dayRank, FeastReminderRank filter) {
    if (dayRank == null || dayRank.isEmpty) return false;
    switch (filter) {
      case FeastReminderRank.solemnities:
        return dayRank == 'Solemnity';
      case FeastReminderRank.feastsDays:
        return dayRank == 'Solemnity' || dayRank == 'Feast';
      case FeastReminderRank.all:
        return dayRank == 'Solemnity' ||
            dayRank == 'Feast' ||
            dayRank == 'Memorial' ||
            dayRank == 'Optional Memorial';
    }
  }

  /// Call on app start to reschedule if needed (new year or prefs changed).
  Future<void> rescheduleIfNeeded(FeastReminderPreferences prefs) async {
    if (!prefs.isEnabled) return;
    final now = DateTime.now();
    if (prefs.lastScheduledYear != now.year) {
      await scheduleForYear(now.year, prefs);
    }
  }
}
