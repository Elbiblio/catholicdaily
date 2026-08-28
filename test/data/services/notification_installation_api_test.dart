import 'dart:convert';

import 'package:catholic_daily/data/services/notification_installation.dart';
import 'package:catholic_daily/data/services/notification_installation_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const credentials = NotificationInstallationCredentials(
    installationId: '123e4567-e89b-42d3-a456-426614174000',
    registrationSecret: 'secret-that-must-never-be-logged',
  );
  final state = NotificationInstallationState(
    fcmToken: 'fcm-token',
    platform: 'android',
    appVersion: '1.6.10+35',
    locale: 'en_NG',
    timezone: 'Africa/Lagos',
    liturgicalRegion: 'nigeria',
    notificationPermission: true,
    remindersEnabled: true,
    reminderRank: 'feasts',
    notifyDayBefore: false,
    reminderHour: 6,
    reminderMinute: 30,
    scheduleGeneration: 'feast-reminders-v5',
    coverageThrough: DateTime(2026, 12, 31),
  );

  test('create sends the exact anonymous installation wire format', () async {
    late http.Request captured;
    final api = NotificationInstallationApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 201);
      }),
    );

    final result = await api.create(credentials, state);

    expect(result, NotificationInstallationApiResult.success);
    expect(captured.method, 'POST');
    expect(
      captured.url.toString(),
      'https://api.elbiblio.com/api/mobile/notification-installations',
    );
    expect(jsonDecode(captured.body), <String, dynamic>{
      'installation_id': credentials.installationId,
      'registration_secret': credentials.registrationSecret,
      'fcm_token': 'fcm-token',
      'platform': 'android',
      'app_version': '1.6.10+35',
      'locale': 'en_NG',
      'timezone': 'Africa/Lagos',
      'liturgical_region': 'nigeria',
      'notification_permission': true,
      'reminders_enabled': true,
      'reminder_rank': 'feasts',
      'notify_day_before': false,
      'reminder_hour': 6,
      'reminder_minute': 30,
      'schedule_generation': 'feast-reminders-v5',
      'coverage_through': '2026-12-31',
    });
  });

  test('update authenticates without placing the secret in its body', () async {
    late http.Request captured;
    final api = NotificationInstallationApi(
      client: MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      }),
    );

    final result = await api.update(credentials, state);

    expect(result, NotificationInstallationApiResult.success);
    expect(captured.method, 'PUT');
    expect(
      captured.url.toString(),
      'https://api.elbiblio.com/api/mobile/notification-installations/'
      '${credentials.installationId}',
    );
    expect(
      captured.headers['authorization'],
      'Installation ${credentials.installationId}:'
      '${credentials.registrationSecret}',
    );
    expect(captured.body, isNot(contains(credentials.registrationSecret)));
  });

  test('maps auth loss, validation, throttling, and server failures', () async {
    Future<NotificationInstallationApiResult> updateWith(int status) =>
        NotificationInstallationApi(
          client: MockClient((_) async => http.Response('', status)),
        ).update(credentials, state);

    expect(await updateWith(401), NotificationInstallationApiResult.reRegister);
    expect(await updateWith(404), NotificationInstallationApiResult.reRegister);
    expect(await updateWith(422), NotificationInstallationApiResult.invalid);
    expect(await updateWith(429), NotificationInstallationApiResult.retry);
    expect(await updateWith(503), NotificationInstallationApiResult.retry);
  });

  test('credentials never reveal their registration secret', () {
    expect(credentials.toString(), isNot(contains('secret-that')));
    expect(state.toString(), isNot(contains('fcm-token')));
  });
}
