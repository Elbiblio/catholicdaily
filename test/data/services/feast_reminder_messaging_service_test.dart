import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/android_feast_reminder_occurrence_store.dart';
import 'package:catholic_daily/data/services/feast_reminder_messaging_service.dart';
import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
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
      message.isDeliverableAt(DateTime.parse('2026-08-15T08:00:00+01:00')),
      isFalse,
    );
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

  group('remote processing', () {
    late List<String> operations;
    late RemoteFeastMessageProcessor processor;

    setUp(() {
      operations = <String>[];
      processor = RemoteFeastMessageProcessor(
        now: () => DateTime.parse('2026-08-15T06:01:00+01:00'),
        cancelOccurrence: (payload) async {
          operations.add('cancel:${payload.occurrenceKey}');
        },
        claimOccurrence: (payload) async {
          operations.add('claim:${payload.occurrenceKey}');
          return true;
        },
        removeDeliveredOccurrence: (payload) async {
          operations.add('remove:${payload.occurrenceKey}');
        },
        showReminder: (payload) async {
          operations.add('show:${payload.celebrationDate.toIso8601String()}');
        },
        recordReceived: (key, occurredAt) async {
          operations.add('received:$key');
        },
        recordExpired: (key, occurredAt) async {
          operations.add('expired:$key');
        },
        enqueueReconciliation: () async {
          operations.add('enqueue');
        },
      );
    });

    test(
      'validates then cancels, claims, shows, and queues reconciliation',
      () async {
        final outcome = await processor.process(_validV3Data(validData));

        expect(outcome, RemoteFeastMessageOutcome.shown);
        expect(operations, <String>[
          'cancel:feast:nigeria:2026-08-15:on_day:assumption',
          'claim:feast:nigeria:2026-08-15:on_day:assumption',
          'cancel:feast:nigeria:2026-08-15:on_day:assumption',
          'remove:feast:nigeria:2026-08-15:on_day:assumption',
          'show:2026-08-15T00:00:00.000',
          'received:feast:nigeria:2026-08-15:on_day:assumption',
          'enqueue',
        ]);
      },
    );

    test('invalid identity has no notification side effects', () async {
      final invalid = _validV3Data(validData)..['local_notification_id'] = '42';

      final outcome = await processor.process(invalid);

      expect(outcome, RemoteFeastMessageOutcome.ignored);
      expect(operations, isEmpty);
    });

    test(
      'expired payload cancels safety copy and records expiry only',
      () async {
        processor = RemoteFeastMessageProcessor(
          now: () => DateTime.parse('2026-08-15T06:02:00+01:00'),
          cancelOccurrence: (payload) async => operations.add('cancel'),
          claimOccurrence: (payload) async {
            operations.add('claim');
            return true;
          },
          removeDeliveredOccurrence: (payload) async =>
              operations.add('remove'),
          showReminder: (payload) async => operations.add('show'),
          recordReceived: (key, occurredAt) async => operations.add('received'),
          recordExpired: (key, occurredAt) async => operations.add('expired'),
          enqueueReconciliation: () async => operations.add('enqueue'),
        );

        final outcome = await processor.process(_validV3Data(validData));

        expect(outcome, RemoteFeastMessageOutcome.expired);
        expect(operations, <String>['cancel', 'expired', 'enqueue']);
      },
    );

    test('an already claimed occurrence never re-shows', () async {
      processor = RemoteFeastMessageProcessor(
        now: () => DateTime.parse('2026-08-15T06:01:00+01:00'),
        cancelOccurrence: (payload) async => operations.add('cancel'),
        claimOccurrence: (payload) async {
          operations.add('claim');
          return false;
        },
        removeDeliveredOccurrence: (payload) async => operations.add('remove'),
        showReminder: (payload) async => operations.add('show'),
        recordReceived: (key, occurredAt) async => operations.add('received'),
        recordExpired: (key, occurredAt) async => operations.add('expired'),
        enqueueReconciliation: () async => operations.add('enqueue'),
      );

      final outcome = await processor.process(_validV3Data(validData));

      expect(outcome, RemoteFeastMessageOutcome.duplicate);
      expect(operations, <String>['cancel', 'claim']);
    });

    test(
      'an unavailable native claim fails closed and requests repair',
      () async {
        processor = RemoteFeastMessageProcessor(
          now: () => DateTime.parse('2026-08-15T06:01:00+01:00'),
          cancelOccurrence: (payload) async => operations.add('cancel'),
          claimOccurrence: (payload) async {
            operations.add('claim');
            throw const FeastReminderOccurrenceStoreUnavailable('offline');
          },
          removeDeliveredOccurrence: (payload) async =>
              operations.add('remove'),
          showReminder: (payload) async => operations.add('show'),
          recordReceived: (key, occurredAt) async => operations.add('received'),
          recordExpired: (key, occurredAt) async => operations.add('expired'),
          enqueueReconciliation: () async => operations.add('enqueue'),
          handleClaimUnavailable: () async => operations.add('durable-repair'),
        );

        final outcome = await processor.process(_validV3Data(validData));

        expect(outcome, RemoteFeastMessageOutcome.unavailable);
        expect(operations, <String>['cancel', 'claim', 'durable-repair']);
      },
    );

    test('concurrent duplicate deliveries show exactly once', () async {
      var claimed = false;
      var shows = 0;
      processor = RemoteFeastMessageProcessor(
        now: () => DateTime.parse('2026-08-15T06:01:00+01:00'),
        cancelOccurrence: (payload) async {},
        claimOccurrence: (payload) async {
          await Future<void>.delayed(Duration.zero);
          if (claimed) return false;
          claimed = true;
          return true;
        },
        removeDeliveredOccurrence: (payload) async {},
        showReminder: (payload) async => shows++,
        recordReceived: (key, occurredAt) async {},
        recordExpired: (key, occurredAt) async {},
        enqueueReconciliation: () async {},
      );
      final data = _validV3Data(validData);

      final outcomes = await Future.wait([
        processor.process(data),
        processor.process(data),
      ]);

      expect(shows, 1);
      expect(
        outcomes,
        containsAll(<RemoteFeastMessageOutcome>[
          RemoteFeastMessageOutcome.shown,
          RemoteFeastMessageOutcome.duplicate,
        ]),
      );
    });

    test(
      'legacy v2 data follows the same cancellation and claim path',
      () async {
        final outcome = await processor.process(validData);

        expect(outcome, RemoteFeastMessageOutcome.shown);
        expect(operations.take(2), <String>[
          'cancel:feast:nigeria:2026-08-15:on_day:assumption',
          'claim:feast:nigeria:2026-08-15:on_day:assumption',
        ]);
      },
    );

    test('remote presentation uses a distinct deterministic Android tag', () {
      const key = 'feast:nigeria:2026-08-15:on_day:assumption';

      expect(FeastReminderService.remotePresentationTag(key), isNot(key));
      expect(
        FeastReminderService.remotePresentationTag(key),
        FeastReminderService.remotePresentationTag(key),
      );
    });
  });
}

Map<String, String> _validV3Data(Map<String, String> validData) {
  const key = 'feast:nigeria:2026-08-15:on_day:assumption';
  return <String, String>{
    ...validData,
    'schema': '3',
    'v': '3',
    'local_notification_id':
        '${FeastReminderNotificationContract.stableNotificationId(key)}',
    'remote_expires_at': '2026-08-15T06:02:00+01:00',
    'local_safety_at': '2026-08-15T06:03:00+01:00',
    'scheduled_for': '2026-08-15T06:00:00+01:00',
    'occurrence_key': key,
  };
}
