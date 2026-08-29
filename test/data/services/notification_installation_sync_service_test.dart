import 'dart:async';
import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_schedule_lock.dart';
import 'package:catholic_daily/data/services/notification_installation.dart';
import 'package:catholic_daily/data/services/notification_installation_api.dart';
import 'package:catholic_daily/data/services/notification_installation_store.dart';
import 'package:catholic_daily/data/services/notification_installation_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('concurrent token syncs serialize registration creation', () async {
    final api = _BlockingApi();
    final lockFile = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'notification-installation-sync-${DateTime.now().microsecondsSinceEpoch}.lock',
    );
    final service = NotificationInstallationSyncService(
      api: api,
      store: _FakeStore(),
      buildState: _state,
      registrationLock: InterprocessFileLock(file: lockFile),
    );

    final first = service.syncToken('first-token');
    await api.firstCreateStarted.future;
    final second = service.syncToken('second-token');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(api.createCalls, 1);
    api.releaseFirst.complete();
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(api.createCalls, 1);
    expect(api.updateCalls, 1);
  });
}

Future<NotificationInstallationState> _state(String token) async =>
    NotificationInstallationState(
      fcmToken: token,
      platform: 'android',
      appVersion: '1+1',
      locale: 'en',
      timezone: 'UTC',
      liturgicalRegion: 'universal',
      notificationPermission: true,
      remindersEnabled: true,
      reminderRank: 'feasts',
      notifyDayBefore: false,
      reminderHour: 6,
      reminderMinute: 0,
      scheduleGeneration: 'test',
      coverageThrough: null,
    );

class _FakeStore extends NotificationInstallationStore {
  bool registered = false;

  @override
  Future<NotificationInstallationCredentials> credentials() async =>
      const NotificationInstallationCredentials(
        installationId: '123e4567-e89b-42d3-a456-426614174000',
        registrationSecret: 'secret',
      );

  @override
  Future<bool> get isRegistered async => registered;

  @override
  Future<void> markRegistered(bool value) async => registered = value;

  @override
  Future<void> markSynchronized(NotificationInstallationState state) async {}
}

class _BlockingApi extends NotificationInstallationApi {
  int createCalls = 0;
  int updateCalls = 0;
  final firstCreateStarted = Completer<void>();
  final releaseFirst = Completer<void>();

  @override
  Future<NotificationInstallationApiResult> create(
    NotificationInstallationCredentials credentials,
    NotificationInstallationState state,
  ) async {
    createCalls++;
    if (createCalls == 1) {
      firstCreateStarted.complete();
      await releaseFirst.future;
    }
    return NotificationInstallationApiResult.success;
  }

  @override
  Future<NotificationInstallationApiResult> update(
    NotificationInstallationCredentials credentials,
    NotificationInstallationState state,
  ) async {
    updateCalls++;
    return NotificationInstallationApiResult.success;
  }
}
