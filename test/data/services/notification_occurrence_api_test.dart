import 'dart:convert';

import 'package:catholic_daily/data/services/notification_installation.dart';
import 'package:catholic_daily/data/services/notification_occurrence.dart';
import 'package:catholic_daily/data/services/notification_occurrence_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const credentials = NotificationInstallationCredentials(
    installationId: '123e4567-e89b-42d3-a456-426614174000',
    registrationSecret: 'secret-that-must-never-be-logged',
  );

  NotificationOccurrence occurrence(int index) => NotificationOccurrence(
    occurrenceKey:
        'feast:nigeria:2026-09-${(index + 1).toString().padLeft(2, '0')}:on_day:saint-$index',
    localNotificationId: 1000 + index,
    scheduledFor: DateTime.utc(2026, 9, index + 1, 6),
    remoteExpiresAt: DateTime.utc(2026, 9, index + 1, 6, 2),
    localSafetyAt: DateTime.utc(2026, 9, index + 1, 6, 3),
    platform: 'android',
    scheduleGeneration: 'feast-reminders-v5',
    timezone: 'Africa/Lagos',
    configurationFingerprint: 'v1|nigeria|feasts|6|0|false',
    localArmed: true,
    payload: '{"schema":3,"occurrence_key":"$index"}',
  );

  test(
    'authenticates occurrence PUT and keeps the secret out of the body',
    () async {
      late http.Request captured;
      final api = NotificationOccurrenceApi(
        client: MockClient((request) async {
          captured = request;
          return http.Response('', 204);
        }),
      );

      final result = await api.putAll(credentials, [occurrence(0)]);

      expect(result, NotificationOccurrenceApiResult.success);
      expect(captured.method, 'PUT');
      expect(
        captured.url.toString(),
        'https://api.elbiblio.com/api/mobile/notification-installations/'
        '${credentials.installationId}/occurrences',
      );
      expect(captured.headers['authorization'], credentials.authorization);
      expect(captured.body, isNot(contains(credentials.registrationSecret)));
      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['occurrences'], hasLength(1));
      expect(body['events'], isEmpty);
      expect(
        (body['occurrences'] as List).single,
        containsPair('local_armed', true),
      );
    },
  );

  test('batches at most 100 rows per request', () async {
    final requestSizes = <int>[];
    final api = NotificationOccurrenceApi(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requestSizes.add((body['occurrences'] as List).length);
        return http.Response('', 200);
      }),
    );

    final result = await api.putAll(
      credentials,
      List.generate(205, occurrence),
    );

    expect(result, NotificationOccurrenceApiResult.success);
    expect(requestSizes, [100, 100, 5]);
  });

  test(
    'maps installation loss, invalid rows, throttling, and failures',
    () async {
      Future<NotificationOccurrenceApiResult> putWith(int status) =>
          NotificationOccurrenceApi(
            client: MockClient((_) async => http.Response('', status)),
          ).putAll(credentials, [occurrence(0)]);

      expect(await putWith(401), NotificationOccurrenceApiResult.reRegister);
      expect(await putWith(404), NotificationOccurrenceApiResult.reRegister);
      expect(await putWith(422), NotificationOccurrenceApiResult.invalid);
      expect(await putWith(408), NotificationOccurrenceApiResult.retry);
      expect(await putWith(429), NotificationOccurrenceApiResult.retry);
      expect(await putWith(500), NotificationOccurrenceApiResult.retry);
    },
  );

  test('reports only attempted batches for durable acknowledgement', () async {
    var requests = 0;
    final completed = <({int size, NotificationOccurrenceApiResult result})>[];
    final api = NotificationOccurrenceApi(
      client: MockClient((_) async {
        requests++;
        return http.Response('', requests == 1 ? 200 : 422);
      }),
    );

    final result = await api.putAll(
      credentials,
      List.generate(205, occurrence),
      onBatchResult: (occurrences, events, result) async {
        completed.add((
          size: occurrences.length + events.length,
          result: result,
        ));
      },
    );

    expect(result, NotificationOccurrenceApiResult.invalid);
    expect(completed, [
      (size: 100, result: NotificationOccurrenceApiResult.success),
      (size: 100, result: NotificationOccurrenceApiResult.invalid),
    ]);
  });

  test('network exceptions are retryable', () async {
    final api = NotificationOccurrenceApi(
      client: MockClient((_) async => throw Exception('offline')),
    );

    expect(
      await api.putAll(credentials, [occurrence(0)]),
      NotificationOccurrenceApiResult.retry,
    );
  });
}
