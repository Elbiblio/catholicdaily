import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import '../../firebase_options.dart';
import 'android_feast_reminder_occurrence_store.dart';
import 'feast_reminder_notification_contract.dart';
import 'feast_reminder_payload.dart';
import 'feast_reminder_background_service.dart';
import 'feast_reminder_service.dart';
import 'notification_installation_sync_service.dart';
import 'notification_occurrence_sync_service.dart';

class RemoteFeastMessage {
  const RemoteFeastMessage({required this.payload, required this.expiresAt});

  final FeastReminderPayload payload;
  final DateTime expiresAt;

  bool isDeliverableAt(DateTime now) => now.isBefore(expiresAt);

  static RemoteFeastMessage? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'feast_reminder') return null;
    final normalized = Map<String, dynamic>.of(data);
    final schema = int.tryParse('${normalized['schema']}');
    final versionAlias = int.tryParse('${normalized['v']}');
    if (normalized.containsKey('schema') &&
        normalized.containsKey('v') &&
        schema != versionAlias) {
      return null;
    }
    final version = schema ?? versionAlias;
    if (version != 2 && version != FeastReminderPayload.schemaVersion) {
      return null;
    }
    normalized['schema'] = version;
    normalized['v'] = version;

    if (version == FeastReminderPayload.schemaVersion &&
        normalized['local_notification_id'] is String) {
      final localNotificationId = int.tryParse(
        normalized['local_notification_id'] as String,
      );
      if (localNotificationId == null) return null;
      normalized['local_notification_id'] = localNotificationId;
    }

    final expiryField = version == FeastReminderPayload.schemaVersion
        ? normalized['remote_expires_at']
        : normalized['expires_at'];
    final expiresAt = DateTime.tryParse('$expiryField');
    if (expiresAt == null) return null;
    final payload = FeastReminderPayload.fromMap(normalized);
    if (payload == null) return null;
    if (version == FeastReminderPayload.schemaVersion &&
        payload.scheduleGeneration !=
            FeastReminderNotificationContract.scheduleGeneration) {
      return null;
    }
    return RemoteFeastMessage(payload: payload, expiresAt: expiresAt);
  }
}

enum RemoteFeastMessageOutcome { ignored, expired, duplicate, shown }

class RemoteFeastMessageProcessor {
  const RemoteFeastMessageProcessor({
    required DateTime Function() now,
    required Future<void> Function(FeastReminderPayload payload)
    cancelOccurrence,
    required Future<bool> Function(FeastReminderPayload payload)
    claimOccurrence,
    required Future<void> Function(FeastReminderPayload payload)
    removeDeliveredOccurrence,
    required Future<void> Function(FeastReminderPayload payload) showReminder,
    required Future<void> Function(String occurrenceKey, DateTime occurredAt)
    recordReceived,
    required Future<void> Function(String occurrenceKey, DateTime occurredAt)
    recordExpired,
    required Future<void> Function() enqueueReconciliation,
  }) : _now = now,
       _cancelOccurrence = cancelOccurrence,
       _claimOccurrence = claimOccurrence,
       _removeDeliveredOccurrence = removeDeliveredOccurrence,
       _showReminder = showReminder,
       _recordReceived = recordReceived,
       _recordExpired = recordExpired,
       _enqueueReconciliation = enqueueReconciliation;

  final DateTime Function() _now;
  final Future<void> Function(FeastReminderPayload payload) _cancelOccurrence;
  final Future<bool> Function(FeastReminderPayload payload) _claimOccurrence;
  final Future<void> Function(FeastReminderPayload payload)
  _removeDeliveredOccurrence;
  final Future<void> Function(FeastReminderPayload payload) _showReminder;
  final Future<void> Function(String occurrenceKey, DateTime occurredAt)
  _recordReceived;
  final Future<void> Function(String occurrenceKey, DateTime occurredAt)
  _recordExpired;
  final Future<void> Function() _enqueueReconciliation;

  Future<RemoteFeastMessageOutcome> process(Map<String, dynamic> data) async {
    // Parsing validates schema/type/identity before any cancellation or claim.
    final remote = RemoteFeastMessage.tryParse(data);
    if (remote == null) return RemoteFeastMessageOutcome.ignored;
    final occurredAt = _now();
    final payload = remote.payload;
    final occurrenceKey = payload.occurrenceKey!;

    if (!remote.isDeliverableAt(occurredAt)) {
      // An expired remote still owns cancellation of its pending safety copy,
      // but can never claim or present the occurrence.
      await _cancelOccurrence(payload);
      await _recordExpired(occurrenceKey, occurredAt);
      await _enqueueReconciliation();
      return RemoteFeastMessageOutcome.expired;
    }

    // flutter_local_notifications cancellation removes both the pending alarm
    // and a matching delivered copy on Android before any remote presentation.
    await _cancelOccurrence(payload);
    if (!await _claimOccurrence(payload)) {
      return RemoteFeastMessageOutcome.duplicate;
    }
    // Close the scheduler race: a forced repair can create the same local
    // alarm after the first cancellation but before the durable claim.
    await _cancelOccurrence(payload);
    await _removeDeliveredOccurrence(payload);
    await _showReminder(payload);
    await _recordReceived(occurrenceKey, occurredAt);
    await _enqueueReconciliation();
    return RemoteFeastMessageOutcome.shown;
  }
}

RemoteFeastMessageProcessor _remoteProcessor() => RemoteFeastMessageProcessor(
  now: DateTime.now,
  cancelOccurrence: (payload) =>
      FeastReminderService.instance.cancelOccurrence(payload.occurrenceKey!),
  claimOccurrence: AndroidFeastReminderOccurrenceStore.instance.claim,
  removeDeliveredOccurrence: (payload) => FeastReminderService.instance
      .removeDeliveredRemoteOccurrence(payload.occurrenceKey!),
  showReminder: FeastReminderService.instance.showRemoteReminder,
  recordReceived: NotificationOccurrenceSyncService.instance.recordReceived,
  recordExpired: NotificationOccurrenceSyncService.instance.recordExpired,
  enqueueReconciliation: () => FeastReminderBackgroundService.instance
      .enqueueRepair(reason: FeastReminderRepairReason.occurrenceSync),
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isSupported) return;
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await FeastReminderService.instance.initialize();
  await _remoteProcessor().process(message.data);
}

class FeastReminderMessagingService {
  FeastReminderMessagingService._();

  static final FeastReminderMessagingService instance =
      FeastReminderMessagingService._();

  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized ||
        !DefaultFirebaseOptions.isSupported ||
        Firebase.apps.isEmpty) {
      return;
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: false,
          badge: false,
          sound: false,
        );
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage),
    );
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen(_syncToken),
    );
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedMessage(initialMessage);
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null && token.isNotEmpty) {
      await _syncToken(token);
    }
    _initialized = true;
  }

  Future<void> _syncToken(String token) => NotificationScheduleSyncCoordinator(
    syncInstallation: () =>
        NotificationInstallationSyncService.instance.syncToken(token),
    syncOccurrences: () async => NotificationOccurrenceSyncResult.success,
    enqueueRepair: FeastReminderBackgroundService.instance.enqueueRepair,
  ).dispatch();

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    await _remoteProcessor().process(message.data);
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final remote = RemoteFeastMessage.tryParse(message.data);
    if (remote == null) return;
    FeastReminderService.instance.receiveRemoteTap(remote.payload);
  }

  @visibleForTesting
  Future<void> disposeForTesting() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _initialized = false;
  }
}
