import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/feast_reminder_messaging_service.dart';
import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the server-owned fallback contract fixture', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/feast_fallback_contract_v2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    final message = RemoteFeastMessage.tryParse(fixture);

    expect(message, isNotNull);
    expect(message!.payload.celebrationDate, DateTime(2026, 8, 15));
    expect(message.expiresAt, DateTime.parse('2026-08-15T12:30:00+01:00'));
    expect(message.payload.occurrenceKey, fixture['occurrence_key']);
  });

  final validData = <String, String>{
    'type': 'feast_reminder',
    'schema': '2',
    'occurrence_key': 'feast:nigeria:2026-08-15:on_day:assumption',
    'celebration_date': '2026-08-15',
    'scheduled_for': '2026-08-15T06:00:00+01:00',
    'expires_at': '2026-08-15T08:00:00+01:00',
    'timezone': 'Africa/Lagos',
    'liturgical_region': 'nigeria',
    'schedule_generation': 'feast-reminders-v5',
    'title': 'The Assumption of the Blessed Virgin Mary',
    'rank': 'Solemnity',
    'saint_id': 'assumption',
    'timing': 'on_day',
  };

  test('parses FCM string data through payload v2', () {
    final message = RemoteFeastMessage.tryParse(validData);

    expect(message, isNotNull);
    expect(message!.payload.celebrationDate, DateTime(2026, 8, 15));
    expect(message.payload.saintProfileId, 'assumption');
    expect(message.payload.liturgicalRegion, 'nigeria');
  });

  test('accepts schema-v3 FCM data with a string local notification ID', () {
    final key = 'feast:nigeria:2026-08-15:on_day:assumption';
    final v3Data = <String, String>{
      ...validData,
      'schema': '3',
      'v': '3',
      'local_notification_id':
          '${FeastReminderNotificationContract.stableNotificationId(key)}',
      'remote_expires_at': '2026-08-15T06:02:00+01:00',
      'local_safety_at': '2026-08-15T06:03:00+01:00',
      'scheduled_for': '2026-08-15T06:00:00+01:00',
      'occurrence_key': key,
      'expires_at': '2026-08-15T08:00:00+01:00',
    };

    final message = RemoteFeastMessage.tryParse(v3Data);

    expect(message, isNotNull);
    expect(
      message!.payload.localNotificationId,
      FeastReminderNotificationContract.stableNotificationId(key),
    );
    expect(message.expiresAt, DateTime.parse('2026-08-15T06:02:00+01:00'));
  });

  test('ignores unrelated and malformed messages', () {
    expect(
      RemoteFeastMessage.tryParse({...validData, 'type': 'daily_verse'}),
      isNull,
    );
    expect(RemoteFeastMessage.tryParse({...validData, 'schema': '1'}), isNull);
    expect(
      RemoteFeastMessage.tryParse({...validData}..remove('expires_at')),
      isNull,
    );
    expect(RemoteFeastMessage.tryParse({...validData, 'v': '3'}), isNull);
  });

  test('rejects an expired foreground delivery', () {
    final message = RemoteFeastMessage.tryParse(validData)!;

    expect(
      message.isDeliverableAt(DateTime.parse('2026-08-15T08:00:01+01:00')),
      isFalse,
    );
    expect(
      message.isDeliverableAt(DateTime.parse('2026-08-15T07:59:59+01:00')),
      isTrue,
    );
  });

  test('tap payload retains the absolute celebration date', () {
    final message = RemoteFeastMessage.tryParse(validData)!;

    expect(message.payload.celebrationDate, DateTime(2026, 8, 15));
    expect(message.payload.dayBefore, isFalse);
  });
}
