import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/liturgical_region.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_payload.dart';
import 'feast_reminder_schedule_capacity.dart';
import 'feast_reminder_schedule_policy.dart';
import 'feast_reminder_timezone.dart';
import 'improved_liturgical_calendar_service.dart';
import 'liturgical_region_preference_service.dart';
import 'offline_ordo_lookup_service.dart';
import 'optional_memorial_service.dart';
import 'saint_calendar_service.dart';
import 'saint_profile_service.dart';

/// Represents a feast/solemnity event that can trigger a reminder.
class _FeastEvent {
  final DateTime date;
  final String title;
  final String rank;
  final String? saintProfileId;
  final Color? liturgicalColor;

  const _FeastEvent({
    required this.date,
    required this.title,
    required this.rank,
    required this.saintProfileId,
    this.liturgicalColor,
  });
}

class _ReminderSlot {
  final bool dayBefore;
  final int hour;
  final int minute;
  final bool isAdditionalReminder;

  const _ReminderSlot({
    required this.dayBefore,
    required this.hour,
    required this.minute,
    this.isAdditionalReminder = false,
  });
}

class _ReminderOccurrence {
  final _FeastEvent event;
  final DateTime scheduledTime;
  final bool dayBefore;
  final bool isAdditionalReminder;

  const _ReminderOccurrence({
    required this.event,
    required this.scheduledTime,
    required this.dayBefore,
    required this.isAdditionalReminder,
  });
}

class FeastReminderPreviewEvent {
  final DateTime date;
  final String title;
  final String rank;
  final String? saintProfileId;

  const FeastReminderPreviewEvent({
    required this.date,
    required this.title,
    required this.rank,
    required this.saintProfileId,
  });
}

@visibleForTesting
class FeastReminderScheduledPreviewEvent {
  final DateTime celebrationDate;
  final DateTime scheduledTime;
  final String title;
  final String rank;
  final bool dayBefore;
  final bool isAdditionalReminder;

  const FeastReminderScheduledPreviewEvent({
    required this.celebrationDate,
    required this.scheduledTime,
    required this.title,
    required this.rank,
    required this.dayBefore,
    required this.isAdditionalReminder,
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
  void Function(FeastReminderPayload payload)? _tapHandler;
  FeastReminderPayload? _pendingTap;

  static const _channelId = 'feast_reminders';
  static const _channelName = 'Feast & Solemnity Reminders';
  static const _channelDesc =
      'Daily reminders for Catholic feasts and solemnities';
  static const scheduleSchemaVersion = 5;
  static const _schedulePolicy = FeastReminderSchedulePolicy();
  static const _majorFeastTitleTokens = <String>[
    'lord',
    'holy family',
    'holy cross',
    'blessed virgin mary',
    'our lady',
    'lateran basilica',
  ];

  Future<void> initialize() async {
    if (_initialized) return;

    await FeastReminderTimezone.configure();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _receiveTap(response.payload);
      },
    );
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _receiveTap(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  void setNotificationTapHandler(
    void Function(FeastReminderPayload payload) handler,
  ) {
    _tapHandler = handler;
    final pending = _pendingTap;
    if (pending != null) {
      _pendingTap = null;
      handler(pending);
    }
  }

  void clearNotificationTapHandler() => _tapHandler = null;

  void _receiveTap(String? rawPayload) {
    final payload = FeastReminderPayload.tryParse(rawPayload);
    if (payload == null) return;
    final handler = _tapHandler;
    if (handler == null) {
      _pendingTap = payload;
    } else {
      handler(payload);
    }
  }

  @visibleForTesting
  void receiveNotificationTapForTesting(String? rawPayload) {
    _receiveTap(rawPayload);
  }

  /// Request notification permission and return whether it was granted.
  Future<bool> requestPermission() async {
    await initialize();
    if (Platform.isIOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final result = await androidPlugin?.requestNotificationsPermission();
      if (result == true) {
        try {
          await androidPlugin?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint(
            '[FeastReminder] Exact alarm permission request failed: $e',
          );
        }
      }
      return result ?? false;
    }
    return true;
  }

  /// Check if notification permission has been granted.
  Future<bool> hasPermission() async {
    await initialize();
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return (await androidPlugin?.areNotificationsEnabled()) ?? false;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final settings = await iosPlugin?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return true;
  }

  /// Cancel all scheduled feast reminders.
  Future<void> cancelAll() async {
    await initialize();
    final prefs = await FeastReminderPreferences.getInstance();
    await _cancelScheduledFeastReminders(prefs);
  }

  Future<void> _cancelScheduledFeastReminders(
    FeastReminderPreferences prefs,
  ) async {
    final references = prefs.scheduledNotificationReferences;
    if (references.isEmpty &&
        prefs.scheduleSchemaVersion > 0 &&
        prefs.scheduleSchemaVersion < scheduleSchemaVersion) {
      // Versions 1-4 used the reserved 1000-1063 range without tags.
      for (var id = 1000; id < 1064; id++) {
        await _plugin.cancel(id);
      }
      return;
    }

    for (final reference in references) {
      final separator = reference.indexOf('|');
      if (separator <= 0 || separator == reference.length - 1) continue;
      final id = int.tryParse(reference.substring(0, separator));
      if (id == null) continue;
      await _plugin.cancel(id, tag: reference.substring(separator + 1));
    }
  }

  Future<LiturgicalRegion> _currentRegion() async {
    try {
      final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
      return regionPrefs.currentRegion;
    } catch (_) {
      return LiturgicalRegion.generalRoman;
    }
  }

  /// DEPRECATED: kept as a thin wrapper around [scheduleAheadMonths] for
  /// callers that still pass a single year. Schedules a 15-month rolling
  /// window starting today regardless of [year].
  Future<FeastReminderScheduleResult> scheduleForYear(
    int year,
    FeastReminderPreferences prefs,
  ) => scheduleAheadMonths(15, prefs);

  NotificationDetails _buildNotificationDetails(
    _FeastEvent event, {
    required FeastReminderNotificationContent content,
    required FeastReminderNotificationIdentity identity,
  }) {
    final isSolemnity = event.rank == 'Solemnity';
    final isFeast = event.rank == 'Feast';
    final isMajor = isSolemnity || isFeast;

    // Liturgical accent color, falling back to the app's deep crimson.
    final accent = event.liturgicalColor ?? const Color(0xFF8C1D2F);

    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        // Solemnity = high priority + heads-up; Feast = default; Memorial = low.
        importance: isSolemnity
            ? Importance.high
            : (isFeast ? Importance.defaultImportance : Importance.low),
        priority: isSolemnity
            ? Priority.high
            : (isFeast ? Priority.defaultPriority : Priority.low),
        enableVibration: isSolemnity,
        playSound: isMajor,
        icon: '@mipmap/ic_launcher',
        color: accent,
        colorized: isMajor,
        category: AndroidNotificationCategory.event,
        // Expandable rich text — shows the full reflection when the user
        // pulls down the notification or sees it in the shade.
        styleInformation: BigTextStyleInformation(
          content.expandedBody,
          contentTitle: content.title,
          summaryText: content.dateLabel,
        ),
        tag: identity.occurrenceKey,
        groupKey: identity.groupKey,
        subText: content.subtitle,
        ticker: event.title,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: isMajor,
        // The subtitle line — Apple's mid-tier hierarchy slot.
        subtitle: content.subtitle,
        // iOS allows interruption-level customization for Focus modes.
        interruptionLevel: isSolemnity
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
        threadIdentifier: identity.groupKey,
        categoryIdentifier: 'feast_reminder',
      ),
    );
  }

  /// Build the list of feast events for [year] filtered by [rank].
  Future<List<_FeastEvent>> _buildFeastEvents(
    int year,
    FeastReminderRank rank, {
    LiturgicalRegion? regionOverride,
  }) async {
    final lookup = OfflineOrdoLookupService.instance;
    final memorials = OptionalMemorialService.instance;
    final saintCalendar = SaintCalendarService.instance;
    var region = regionOverride ?? LiturgicalRegion.generalRoman;
    if (regionOverride == null) {
      try {
        final regionPrefs =
            await LiturgicalRegionPreferenceService.getInstance();
        region = regionPrefs.currentRegion;
      } catch (_) {}
    }
    final events = <_FeastEvent>[];

    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31);

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      try {
        final day = lookup.resolve(d, region: region);
        final dedupeKeys = <String>{};
        if (_shouldInclude(day.rank, rank)) {
          String? saintProfileId;
          if (SaintProfileService.isSaintLikeTitle(day.title)) {
            try {
              saintProfileId =
                  (await SaintProfileService.instance.findCuratedByTitle(
                    day.title,
                  ))?.id;
            } catch (e) {
              debugPrint(
                '[FeastReminder] Unable to resolve saint profile for '
                '${day.title}: $e',
              );
            }
          }
          events.add(
            _FeastEvent(
              date: d,
              title: day.title,
              rank: day.rank ?? '',
              saintProfileId: saintProfileId,
              liturgicalColor: day.colorValue,
            ),
          );
          dedupeKeys.add(SaintProfileService.normalizeTitle(day.title));
          if (saintProfileId != null) dedupeKeys.add(saintProfileId);
        }

        if (rank != FeastReminderRank.all ||
            !_canObserveMemorialsOn(d, day.rank, memorials)) {
          continue;
        }

        final celebrations = await saintCalendar.getSaintCelebrationsForDate(
          date: d,
          optionalCelebrations: memorials.getOptionalCelebrations(d),
        );
        for (final celebration in celebrations) {
          final profile =
              await SaintProfileService.instance.findByCelebrationId(
                celebration.id,
              ) ??
              await SaintProfileService.instance.findCuratedByTitle(
                celebration.title,
              );
          final normalizedTitle = SaintProfileService.normalizeTitle(
            celebration.title,
          );
          if (dedupeKeys.contains(celebration.id) ||
              dedupeKeys.contains(normalizedTitle) ||
              (profile != null && dedupeKeys.contains(profile.id))) {
            continue;
          }
          dedupeKeys.add(celebration.id);
          dedupeKeys.add(normalizedTitle);
          if (profile != null) dedupeKeys.add(profile.id);
          events.add(
            _FeastEvent(
              date: d,
              title: celebration.title,
              rank: _rankLabel(celebration.rank),
              saintProfileId: profile?.id,
              liturgicalColor: _colorValue(celebration.color),
            ),
          );
        }
      } catch (e) {
        debugPrint('[FeastReminder] Error resolving $d: $e');
      }
    }

    return events;
  }

  bool _canObserveMemorialsOn(
    DateTime date,
    String? principalRank,
    OptionalMemorialService memorials,
  ) {
    if (date.weekday == DateTime.sunday || memorials.isSuppressedDate(date)) {
      return false;
    }
    return principalRank != 'Solemnity' && principalRank != 'Feast';
  }

  String _rankLabel(CelebrationRank rank) => switch (rank) {
    CelebrationRank.solemnity => 'Solemnity',
    CelebrationRank.feast => 'Feast',
    CelebrationRank.obligatoryMemorial => 'Memorial',
    CelebrationRank.optionalMemorial => 'Optional Memorial',
  };

  Color _colorValue(LiturgicalColor color) => switch (color) {
    LiturgicalColor.green => const Color(0xFF228B22),
    LiturgicalColor.purple => const Color(0xFF6B3FA0),
    LiturgicalColor.red => const Color(0xFFB22222),
    LiturgicalColor.pink => const Color(0xFFFF69B4),
    LiturgicalColor.white => const Color(0xFFF5F5F5),
    LiturgicalColor.gold => const Color(0xFFFFD700),
  };

  @visibleForTesting
  Future<List<FeastReminderPreviewEvent>> buildPreviewEventsForTesting(
    int year,
    FeastReminderRank rank, {
    LiturgicalRegion? region,
  }) => buildCatalogEventsForYear(year, rank, region: region);

  /// Resolves the same celebration set used by local scheduling for export.
  Future<List<FeastReminderPreviewEvent>> buildCatalogEventsForYear(
    int year,
    FeastReminderRank rank, {
    LiturgicalRegion? region,
  }) async {
    final events = await _buildFeastEvents(year, rank, regionOverride: region);
    return events
        .map(
          (event) => FeastReminderPreviewEvent(
            date: event.date,
            title: event.title,
            rank: event.rank,
            saintProfileId: event.saintProfileId,
          ),
        )
        .toList();
  }

  @visibleForTesting
  Future<List<FeastReminderScheduledPreviewEvent>>
  buildScheduledRemindersForTesting({
    required DateTime now,
    required int monthsAhead,
    required FeastReminderRank rank,
    required int hour,
    required int minute,
    required bool notifyDayBefore,
    LiturgicalRegion? region,
  }) async {
    final endDate = DateTime(now.year, now.month + monthsAhead, now.day);
    final allEvents = <_FeastEvent>[];
    for (var y = now.year; y <= endDate.year; y++) {
      allEvents.addAll(
        await _buildFeastEvents(y, rank, regionOverride: region),
      );
    }
    allEvents.sort((a, b) => a.date.compareTo(b.date));

    return _buildReminderOccurrences(
          allEvents,
          now: now,
          endDate: endDate,
          hour: hour,
          minute: minute,
          notifyDayBefore: notifyDayBefore,
        )
        .map(
          (occurrence) => FeastReminderScheduledPreviewEvent(
            celebrationDate: occurrence.event.date,
            scheduledTime: occurrence.scheduledTime,
            title: occurrence.event.title,
            rank: occurrence.event.rank,
            dayBefore: occurrence.dayBefore,
            isAdditionalReminder: occurrence.isAdditionalReminder,
          ),
        )
        .toList();
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

  bool _shouldAddSecondReminder(_FeastEvent event) {
    if (event.rank == 'Solemnity') return true;
    if (event.rank != 'Feast') return false;

    final title = event.title.toLowerCase();
    return _majorFeastTitleTokens.any(title.contains);
  }

  List<_ReminderSlot> _reminderSlotsForEvent(
    _FeastEvent event, {
    required int hour,
    required int minute,
    required bool notifyDayBefore,
  }) {
    final slots = <_ReminderSlot>[
      _ReminderSlot(dayBefore: notifyDayBefore, hour: hour, minute: minute),
    ];

    if (_shouldAddSecondReminder(event)) {
      slots.add(
        notifyDayBefore
            ? const _ReminderSlot(
                dayBefore: false,
                hour: 6,
                minute: 0,
                isAdditionalReminder: true,
              )
            : const _ReminderSlot(
                dayBefore: true,
                hour: 20,
                minute: 0,
                isAdditionalReminder: true,
              ),
      );
    }

    return slots;
  }

  List<_ReminderOccurrence> _buildReminderOccurrences(
    List<_FeastEvent> events, {
    required DateTime now,
    required DateTime endDate,
    required int hour,
    required int minute,
    required bool notifyDayBefore,
  }) {
    final occurrences = <_ReminderOccurrence>[];
    final today = DateTime(now.year, now.month, now.day);

    for (final event in events) {
      if (event.date.isBefore(today)) continue;
      if (event.date.isAfter(endDate)) break;

      final slots = _reminderSlotsForEvent(
        event,
        hour: hour,
        minute: minute,
        notifyDayBefore: notifyDayBefore,
      );

      for (final slot in slots) {
        final deliveryDate = slot.dayBefore
            ? event.date.subtract(const Duration(days: 1))
            : event.date;
        final scheduledTime = DateTime(
          deliveryDate.year,
          deliveryDate.month,
          deliveryDate.day,
          slot.hour,
          slot.minute,
        );
        if (scheduledTime.isBefore(now)) continue;

        occurrences.add(
          _ReminderOccurrence(
            event: event,
            scheduledTime: scheduledTime,
            dayBefore: slot.dayBefore,
            isAdditionalReminder: slot.isAdditionalReminder,
          ),
        );
      }
    }

    occurrences.sort((a, b) {
      final byTime = a.scheduledTime.compareTo(b.scheduledTime);
      if (byTime != 0) return byTime;
      final byCelebration = a.event.date.compareTo(b.event.date);
      if (byCelebration != 0) return byCelebration;
      return a.isAdditionalReminder == b.isAdditionalReminder
          ? 0
          : (a.isAdditionalReminder ? 1 : -1);
    });

    return occurrences;
  }

  /// Call on app start to reschedule if needed (new year or prefs changed).
  Future<void> rescheduleIfNeeded(FeastReminderPreferences prefs) async {
    if (!prefs.isEnabled) return;
    final now = DateTime.now();
    if (_schedulePolicy.needsReschedule(
      now: now,
      scheduledThrough: prefs.scheduledThrough,
      schemaMatches: prefs.scheduleSchemaVersion == scheduleSchemaVersion,
    )) {
      await scheduleAheadMonths(15, prefs);
    }
  }

  /// First-launch auto-setup: enables feast reminders by default and
  /// schedules the upcoming 15 months of feasts/solemnities so the user
  /// gets midnight notifications without needing to open the app.
  ///
  /// Idempotent — runs only the first time after install. If the user later
  /// disables reminders, this method is a no-op.
  ///
  /// Permission prompt: best-effort. iOS shows the system prompt; Android 13+
  /// shows the POST_NOTIFICATIONS prompt. If the user denies, scheduling
  /// silently fails and we leave isEnabled=true so they can flip it on later
  /// in Settings without re-prompting.
  Future<void> autoSetupOnFirstRun(FeastReminderPreferences prefs) async {
    if (prefs.autoSetupCompleted) return;

    // If onboarding hasn't completed yet, defer entirely — the onboarding
    // notifications step will collect the user's preferred time and call
    // the appropriate setters/scheduler. Running auto-setup here would
    // overwrite the user's choice with midnight defaults.
    final sp = await SharedPreferences.getInstance();
    final onboardingComplete = sp.getBool('onboarding_complete') ?? false;
    if (!onboardingComplete) return;

    await initialize();

    // Defaults: every Feast & Solemnity, midnight (00:00) of the day itself.
    await prefs.setEnabled(true);
    await prefs.setRank(FeastReminderRank.feastsDays);
    await prefs.setTime(0, 0);

    // Best-effort permission request. Failure is non-fatal — user can grant
    // later via the OS settings or our Settings screen.
    try {
      await requestPermission();
    } catch (e) {
      debugPrint('[FeastReminder] Permission request failed: $e');
    }

    try {
      await scheduleAheadMonths(15, prefs);
    } catch (e, st) {
      debugPrint('[FeastReminder] First-run schedule failed: $e\n$st');
    }

    await prefs.markAutoSetupCompleted();
  }

  /// Schedule reminders for every qualifying feast in the next [monthsAhead]
  /// months. Crosses year boundaries cleanly so users don't need to open the
  /// app on Jan 1 to keep getting reminders.
  ///
  /// Cancels existing notifications first and reschedules in one pass — safer
  /// than scheduling two years separately (which would have wiped year 1 on
  /// the year 2 call).
  Future<FeastReminderScheduleResult> scheduleAheadMonths(
    int monthsAhead,
    FeastReminderPreferences prefs,
  ) async {
    await initialize();
    await _cancelScheduledFeastReminders(prefs);
    await prefs.invalidateSchedule();

    if (!prefs.isEnabled) {
      return const FeastReminderScheduleResult(
        eligibleCount: 0,
        scheduledCount: 0,
        failureCount: 0,
        scheduledThrough: null,
        usedExactDelivery: false,
      );
    }

    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month + monthsAhead, now.day);
    final region = await _currentRegion();

    // Walk every year touched by the window and pull qualifying events.
    final allEvents = <_FeastEvent>[];
    for (var y = now.year; y <= endDate.year; y++) {
      allEvents.addAll(
        await _buildFeastEvents(y, prefs.rank, regionOverride: region),
      );
    }
    allEvents.sort((a, b) => a.date.compareTo(b.date));

    final occurrences = _buildReminderOccurrences(
      allEvents,
      now: now,
      endDate: endDate,
      hour: prefs.hour,
      minute: prefs.minute,
      notifyDayBefore: prefs.notifyDayBefore,
    );
    final capacity = Platform.isIOS
        ? FeastReminderScheduleCapacity.forIos()
        : FeastReminderScheduleCapacity.forAndroid();
    final selection = capacity.select(
      occurrences,
      celebrationDate: (occurrence) => occurrence.event.date,
    );

    int failures = 0;
    final scheduledReferences =
        <({int id, String tag, DateTime celebrationDate})>[];
    var exactAllowed = false;
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      try {
        exactAllowed =
            (await androidPlugin?.canScheduleExactNotifications()) ?? false;
      } catch (e) {
        debugPrint('[FeastReminder] Exact alarm capability check failed: $e');
      }
    }
    final androidScheduleMode = _schedulePolicy.androidMode(
      exactAllowed: exactAllowed,
    );

    for (final occurrence in selection.selected) {
      final event = occurrence.event;
      final tzScheduled = tz.TZDateTime.from(
        occurrence.scheduledTime,
        tz.local,
      );
      final identity = FeastReminderNotificationContract.identity(
        region: region.name,
        celebrationDate: event.date,
        dayBefore: occurrence.dayBefore,
        celebrationId: event.saintProfileId ?? event.title,
      );
      final content = FeastReminderNotificationContract.content(
        celebrationDate: event.date,
        title: event.title,
        rank: event.rank,
        dayBefore: occurrence.dayBefore,
        locale: 'en',
      );

      try {
        await _plugin.zonedSchedule(
          identity.notificationId,
          content.title,
          content.body,
          tzScheduled,
          _buildNotificationDetails(
            event,
            content: content,
            identity: identity,
          ),
          androidScheduleMode: androidScheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: FeastReminderPayload(
            celebrationDate: event.date,
            scheduledFor: tzScheduled,
            occurrenceKey: identity.occurrenceKey,
            timeZone: tz.local.name,
            liturgicalRegion: region.name,
            scheduleGeneration:
                FeastReminderNotificationContract.scheduleGeneration,
            title: event.title,
            rank: event.rank,
            saintProfileId: event.saintProfileId,
            dayBefore: occurrence.dayBefore,
          ).encode(),
        );
        scheduledReferences.add((
          id: identity.notificationId,
          tag: identity.occurrenceKey,
          celebrationDate: DateTime(
            event.date.year,
            event.date.month,
            event.date.day,
          ),
        ));
      } catch (e) {
        failures++;
        debugPrint('[FeastReminder] Failed to schedule ${event.title}: $e');
        final failedDate = DateTime(
          event.date.year,
          event.date.month,
          event.date.day,
        );
        final partialDateReferences = scheduledReferences
            .where((reference) => reference.celebrationDate == failedDate)
            .toList(growable: false);
        for (final reference in partialDateReferences) {
          await _plugin.cancel(reference.id, tag: reference.tag);
        }
        scheduledReferences.removeWhere(
          (reference) => reference.celebrationDate == failedDate,
        );
        break;
      }
    }

    final scheduledThrough = occurrences.isEmpty
        ? endDate
        : (failures == 0
              ? selection.coverageThrough
              : (scheduledReferences.isEmpty
                    ? null
                    : scheduledReferences.last.celebrationDate));

    final result = FeastReminderScheduleResult(
      eligibleCount: occurrences.length,
      scheduledCount: scheduledReferences.length,
      failureCount: failures,
      scheduledThrough: occurrences.isEmpty ? endDate : scheduledThrough,
      usedExactDelivery: exactAllowed,
    );
    if (!result.shouldPersistHorizon) {
      for (final reference in scheduledReferences) {
        await _plugin.cancel(reference.id, tag: reference.tag);
      }
    } else {
      await prefs.setLastScheduledYear(
        result.scheduledThrough?.year ?? endDate.year,
      );
      await prefs.setScheduledThrough(result.scheduledThrough!);
      await prefs.setScheduleSchemaVersion(scheduleSchemaVersion);
      await prefs.setScheduleGeneration(
        FeastReminderNotificationContract.scheduleGeneration,
      );
      await prefs.setScheduleTimezone(tz.local.name);
      await prefs.setLastAuditAt(now);
      await prefs.setScheduledNotificationReferences(
        scheduledReferences
            .map((reference) => '${reference.id}|${reference.tag}')
            .toList(growable: false),
      );
    }
    debugPrint(
      '[FeastReminder] Scheduled ${scheduledReferences.length} reminders across '
      '${now.year}-${endDate.year} '
      '(${occurrences.length} occurrences, ${allEvents.length} candidates, '
      '${exactAllowed ? 'exact' : 'inexact'}, $failures failures)',
    );
    return result;
  }
}
