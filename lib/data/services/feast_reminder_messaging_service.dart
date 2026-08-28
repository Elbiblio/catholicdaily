import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'feast_reminder_payload.dart';
import 'feast_reminder_background_service.dart';
import 'feast_reminder_service.dart';
import 'notification_installation_sync_service.dart';

class RemoteFeastMessage {
  const RemoteFeastMessage({required this.payload, required this.expiresAt});

  final FeastReminderPayload payload;
  final DateTime expiresAt;

  bool isDeliverableAt(DateTime now) => !now.isAfter(expiresAt);

  static RemoteFeastMessage? tryParse(Map<String, dynamic> data) {
    if (data['type'] != 'feast_reminder') return null;
    final normalized = Map<String, dynamic>.of(data);
    final schema = int.tryParse('${normalized['schema'] ?? normalized['v']}');
    if (schema != 2 && schema != FeastReminderPayload.schemaVersion) {
      return null;
    }
    normalized['schema'] = schema;
    normalized['v'] = schema;

    if (schema == FeastReminderPayload.schemaVersion &&
        normalized['local_notification_id'] is String) {
      final localNotificationId = int.tryParse(
        normalized['local_notification_id'] as String,
      );
      if (localNotificationId == null) return null;
      normalized['local_notification_id'] = localNotificationId;
    }

    final expiryField = schema == FeastReminderPayload.schemaVersion
        ? normalized['remote_expires_at']
        : normalized['expires_at'];
    final expiresAt = DateTime.tryParse('$expiryField');
    if (expiresAt == null) return null;
    final payload = FeastReminderPayload.fromMap(normalized);
    if (payload == null) return null;
    return RemoteFeastMessage(payload: payload, expiresAt: expiresAt);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!DefaultFirebaseOptions.isSupported) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Notification payloads are displayed by FCM while backgrounded or killed.
  // Parsing here rejects unrelated data and keeps the isolate forward-safe.
  RemoteFeastMessage.tryParse(message.data);
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

  Future<void> _syncToken(String token) async {
    final synchronized = await NotificationInstallationSyncService.instance
        .syncToken(token);
    if (!synchronized) {
      await FeastReminderBackgroundService.instance.enqueueRepair();
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final remote = RemoteFeastMessage.tryParse(message.data);
    if (remote == null || !remote.isDeliverableAt(DateTime.now())) return;
    await FeastReminderService.instance.showRemoteReminder(remote.payload);
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
