import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_service.dart';
import 'feast_reminder_timezone.dart';

enum FeastReminderAuditDecision { skip, current, repair }

class FeastReminderAuditSnapshot {
  const FeastReminderAuditSnapshot({
    required this.enabled,
    required this.permissionGranted,
    required this.schemaVersion,
    required this.scheduleGeneration,
    required this.scheduledTimezone,
    required this.currentTimezone,
    required this.scheduledThrough,
  });

  final bool enabled;
  final bool permissionGranted;
  final int schemaVersion;
  final String? scheduleGeneration;
  final String? scheduledTimezone;
  final String currentTimezone;
  final DateTime? scheduledThrough;

  FeastReminderAuditSnapshot copyWith({
    bool? enabled,
    bool? permissionGranted,
    int? schemaVersion,
    String? scheduleGeneration,
    String? scheduledTimezone,
    String? currentTimezone,
    DateTime? scheduledThrough,
  }) => FeastReminderAuditSnapshot(
    enabled: enabled ?? this.enabled,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    scheduleGeneration: scheduleGeneration ?? this.scheduleGeneration,
    scheduledTimezone: scheduledTimezone ?? this.scheduledTimezone,
    currentTimezone: currentTimezone ?? this.currentTimezone,
    scheduledThrough: scheduledThrough ?? this.scheduledThrough,
  );
}

class FeastReminderAuditPolicy {
  const FeastReminderAuditPolicy({
    required this.expectedSchemaVersion,
    required this.expectedScheduleGeneration,
    this.minimumCoverage = const Duration(days: 30),
  });

  final int expectedSchemaVersion;
  final String expectedScheduleGeneration;
  final Duration minimumCoverage;

  FeastReminderAuditDecision decide(
    FeastReminderAuditSnapshot snapshot, {
    required DateTime now,
  }) {
    if (!snapshot.enabled || !snapshot.permissionGranted) {
      return FeastReminderAuditDecision.skip;
    }
    final coverageThreshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(minimumCoverage);
    if (snapshot.schemaVersion != expectedSchemaVersion ||
        snapshot.scheduleGeneration != expectedScheduleGeneration ||
        snapshot.scheduledTimezone != snapshot.currentTimezone ||
        snapshot.scheduledThrough == null ||
        snapshot.scheduledThrough!.isBefore(coverageThreshold)) {
      return FeastReminderAuditDecision.repair;
    }
    return FeastReminderAuditDecision.current;
  }
}

@pragma('vm:entry-point')
void feastReminderWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return FeastReminderBackgroundService.instance.auditAndRepair();
  });
}

class FeastReminderBackgroundService {
  FeastReminderBackgroundService._();

  static final FeastReminderBackgroundService instance =
      FeastReminderBackgroundService._();

  static const periodicWorkName = 'feast-reminder-coverage-audit';
  static const repairWorkName = 'feast-reminder-coverage-repair';
  static const taskName = 'audit-feast-reminder-coverage';
  static const _scheduleMonths = 15;
  static const _policy = FeastReminderAuditPolicy(
    expectedSchemaVersion: FeastReminderService.scheduleSchemaVersion,
    expectedScheduleGeneration:
        FeastReminderNotificationContract.scheduleGeneration,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    await Workmanager().initialize(feastReminderWorkmanagerDispatcher);
    await Workmanager().registerPeriodicTask(
      periodicWorkName,
      taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    _initialized = true;
  }

  Future<void> enqueueRepair() async {
    if (!Platform.isAndroid) return;
    await initialize();
    await Workmanager().registerOneOffTask(
      repairWorkName,
      taskName,
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
  }

  Future<bool> auditAndRepair() async {
    try {
      final prefs = await FeastReminderPreferences.getInstance();
      if (!prefs.isEnabled) {
        await prefs.setLastAuditAt(DateTime.now());
        return true;
      }

      final timezone = await FeastReminderTimezone.configure();
      final reminders = FeastReminderService.instance;
      await reminders.initialize();
      final permissionGranted = await reminders.hasPermission();
      final now = DateTime.now();
      final decision = _policy.decide(
        FeastReminderAuditSnapshot(
          enabled: prefs.isEnabled,
          permissionGranted: permissionGranted,
          schemaVersion: prefs.scheduleSchemaVersion,
          scheduleGeneration: prefs.scheduleGeneration,
          scheduledTimezone: prefs.scheduleTimezone,
          currentTimezone: timezone,
          scheduledThrough: prefs.scheduledThrough,
        ),
        now: now,
      );

      if (decision == FeastReminderAuditDecision.repair) {
        final result = await reminders.scheduleAheadMonths(
          _scheduleMonths,
          prefs,
        );
        return result.shouldPersistHorizon;
      }

      await prefs.setLastAuditAt(now);
      return true;
    } catch (error, stackTrace) {
      debugPrint(
        '[FeastReminder] Background coverage audit failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }
}
