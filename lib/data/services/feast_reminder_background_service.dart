import 'dart:io' show Platform;
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_preferences.dart';
import 'feast_reminder_service.dart';
import 'feast_reminder_timezone.dart';
import 'liturgical_region_preference_service.dart';
import 'notification_installation_sync_service.dart';

enum FeastReminderAuditDecision { skip, cleanup, current, repair }

class FeastReminderAuditSnapshot {
  const FeastReminderAuditSnapshot({
    required this.enabled,
    required this.permissionGranted,
    required this.schemaVersion,
    required this.scheduleGeneration,
    required this.scheduledTimezone,
    required this.currentTimezone,
    required this.scheduledThrough,
    required this.scheduleInProgress,
    required this.hasCancellationState,
    required this.scheduledConfigurationFingerprint,
    required this.currentConfigurationFingerprint,
  });

  final bool enabled;
  final bool permissionGranted;
  final int schemaVersion;
  final String? scheduleGeneration;
  final String? scheduledTimezone;
  final String currentTimezone;
  final DateTime? scheduledThrough;
  final bool scheduleInProgress;
  final bool hasCancellationState;
  final String? scheduledConfigurationFingerprint;
  final String currentConfigurationFingerprint;

  FeastReminderAuditSnapshot copyWith({
    bool? enabled,
    bool? permissionGranted,
    int? schemaVersion,
    String? scheduleGeneration,
    String? scheduledTimezone,
    String? currentTimezone,
    DateTime? scheduledThrough,
    bool? scheduleInProgress,
    bool? hasCancellationState,
    String? scheduledConfigurationFingerprint,
    String? currentConfigurationFingerprint,
  }) => FeastReminderAuditSnapshot(
    enabled: enabled ?? this.enabled,
    permissionGranted: permissionGranted ?? this.permissionGranted,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    scheduleGeneration: scheduleGeneration ?? this.scheduleGeneration,
    scheduledTimezone: scheduledTimezone ?? this.scheduledTimezone,
    currentTimezone: currentTimezone ?? this.currentTimezone,
    scheduledThrough: scheduledThrough ?? this.scheduledThrough,
    scheduleInProgress: scheduleInProgress ?? this.scheduleInProgress,
    hasCancellationState: hasCancellationState ?? this.hasCancellationState,
    scheduledConfigurationFingerprint:
        scheduledConfigurationFingerprint ??
        this.scheduledConfigurationFingerprint,
    currentConfigurationFingerprint:
        currentConfigurationFingerprint ?? this.currentConfigurationFingerprint,
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
      return snapshot.scheduleInProgress || snapshot.hasCancellationState
          ? FeastReminderAuditDecision.cleanup
          : FeastReminderAuditDecision.skip;
    }
    final coverageThreshold = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(minimumCoverage);
    if (snapshot.scheduleInProgress ||
        snapshot.schemaVersion != expectedSchemaVersion ||
        snapshot.scheduleGeneration != expectedScheduleGeneration ||
        snapshot.scheduledTimezone != snapshot.currentTimezone ||
        snapshot.scheduledConfigurationFingerprint !=
            snapshot.currentConfigurationFingerprint ||
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
      await prefs.reload();
      final now = DateTime.now();
      final reminders = FeastReminderService.instance;
      if (!prefs.isEnabled) {
        if (prefs.hasCancellationState) {
          await reminders.cancelAll();
        }
        await prefs.setLastAuditAt(now);
        return NotificationInstallationSyncService.instance.syncCurrentToken();
      }

      final timezone = await FeastReminderTimezone.configure();
      await reminders.initialize();
      final permissionGranted = await reminders.hasPermission();
      final regionPreferences =
          await LiturgicalRegionPreferenceService.getInstance();
      final currentConfiguration = prefs.configurationFingerprint(
        region: regionPreferences.currentRegion.name,
      );
      final decision = _policy.decide(
        FeastReminderAuditSnapshot(
          enabled: prefs.isEnabled,
          permissionGranted: permissionGranted,
          schemaVersion: prefs.scheduleSchemaVersion,
          scheduleGeneration: prefs.scheduleGeneration,
          scheduledTimezone: prefs.scheduleTimezone,
          currentTimezone: timezone,
          scheduledThrough: prefs.scheduledThrough,
          scheduleInProgress: prefs.scheduleInProgress,
          hasCancellationState: prefs.hasCancellationState,
          scheduledConfigurationFingerprint:
              prefs.scheduledConfigurationFingerprint,
          currentConfigurationFingerprint: currentConfiguration,
        ),
        now: now,
      );

      if (decision == FeastReminderAuditDecision.cleanup) {
        await reminders.cancelAll();
        await prefs.setLastAuditAt(now);
      } else if (decision == FeastReminderAuditDecision.repair) {
        final result = await reminders.scheduleAheadMonths(
          _scheduleMonths,
          prefs,
        );
        if (!result.shouldPersistHorizon) return false;
      } else {
        await prefs.setLastAuditAt(now);
      }

      return NotificationInstallationSyncService.instance.syncCurrentToken();
    } catch (error, stackTrace) {
      debugPrint(
        '[FeastReminder] Background coverage audit failed: '
        '$error\n$stackTrace',
      );
      return false;
    }
  }
}
