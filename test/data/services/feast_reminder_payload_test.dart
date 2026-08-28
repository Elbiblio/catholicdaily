import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
import 'package:catholic_daily/data/services/feast_reminder_notification_contract.dart';
import 'package:catholic_daily/data/services/feast_reminder_destination_resolver.dart';
import 'package:catholic_daily/data/services/feast_reminder_service.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeastReminderPayload', () {
    test('round-trips a versioned saint deep link', () {
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 11, 1),
        scheduledFor: DateTime.parse('2026-10-31T20:00:00+01:00'),
        occurrenceKey: 'feast:generalRoman:2026-11-01:eve:all_saints',
        timeZone: 'Africa/Lagos',
        liturgicalRegion: 'generalRoman',
        scheduleGeneration: 'feast-reminders-v5',
        title: 'All Saints',
        rank: 'Solemnity',
        saintProfileId: 'all_saints',
        dayBefore: true,
      );

      final decoded = FeastReminderPayload.tryParse(payload.encode());

      expect(decoded, isNotNull);
      expect(decoded!.celebrationDate, DateTime(2026, 11, 1));
      expect(decoded.title, 'All Saints');
      expect(decoded.rank, 'Solemnity');
      expect(decoded.saintProfileId, 'all_saints');
      expect(decoded.dayBefore, isTrue);
      expect(decoded.scheduledFor, isNotNull);
      expect(
        decoded.remoteExpiresAt,
        DateTime.parse('2026-10-31T20:02:00+01:00'),
      );
      expect(
        decoded.localSafetyAt,
        DateTime.parse('2026-10-31T20:03:00+01:00'),
      );
      expect(
        decoded.localNotificationId,
        FeastReminderNotificationContract.stableNotificationId(
          decoded.occurrenceKey!,
        ),
      );
      expect(
        decoded.occurrenceKey,
        'feast:generalRoman:2026-11-01:eve:all_saints',
      );
      expect(decoded.timeZone, 'Africa/Lagos');
      expect(decoded.liturgicalRegion, 'generalRoman');
      expect(decoded.scheduleGeneration, 'feast-reminders-v5');

      final celebration = decoded.toSaintCelebration();
      expect(celebration, isNotNull);
      expect(celebration!.id, 'all_saints');
      expect(celebration.month, 11);
      expect(celebration.day, 1);
    });

    test('accepts schema-v1 JSON while keeping its celebration date', () {
      final decoded = FeastReminderPayload.tryParse(
        '{"type":"feast","v":1,"date":"2026-08-15",'
        '"title":"The Assumption of the Blessed Virgin Mary",'
        '"rank":"Solemnity","saintId":"assumption","timing":"day"}',
      );

      expect(decoded, isNotNull);
      expect(decoded!.celebrationDate, DateTime(2026, 8, 15));
      expect(decoded.occurrenceKey, isNull);
      expect(decoded.scheduledFor, isNull);
      expect(decoded.dayBefore, isFalse);
    });

    test('accepts schema-v2 JSON with string version fields', () {
      final decoded = FeastReminderPayload.tryParse(
        '{"type":"feast_reminder","schema":"2","v":"2",'
        '"occurrence_key":"feast:nigeria:2026-08-15:on_day:assumption",'
        '"celebration_date":"2026-08-15",'
        '"scheduled_for":"2026-08-15T06:30:00+01:00",'
        '"expires_at":"2026-08-15T12:30:00+01:00",'
        '"title":"The Assumption", "rank":"Solemnity",'
        '"timing":"on_day"}',
      );

      expect(decoded, isNotNull);
      expect(decoded!.celebrationDate, DateTime(2026, 8, 15));
      expect(decoded.occurrenceKey, contains('2026-08-15'));
      expect(decoded.remoteExpiresAt, isNull);
      expect(decoded.localSafetyAt, isNull);
      expect(decoded.localNotificationId, isNull);
    });

    test('rejects v3 payloads with unsafe timing relationships', () {
      final base = <String, dynamic>{
        'type': 'feast_reminder',
        'schema': 3,
        'v': 3,
        'occurrence_key': 'feast:nigeria:2026-08-15:on_day:assumption',
        'local_notification_id':
            FeastReminderNotificationContract.stableNotificationId(
              'feast:nigeria:2026-08-15:on_day:assumption',
            ),
        'celebration_date': '2026-08-15',
        'scheduled_for': '2026-08-15T06:30:00+01:00',
        'remote_expires_at': '2026-08-15T06:32:00+01:00',
        'local_safety_at': '2026-08-15T06:31:00+01:00',
        'title': 'The Assumption',
        'rank': 'Solemnity',
        'timing': 'on_day',
      };

      expect(FeastReminderPayload.fromMap(base), isNull);

      final safetyBeforeScheduled = Map<String, dynamic>.from(base)
        ..['remote_expires_at'] = '2026-08-15T06:32:00+01:00'
        ..['local_safety_at'] = '2026-08-15T06:29:00+01:00';
      expect(FeastReminderPayload.fromMap(safetyBeforeScheduled), isNull);
    });

    test('rejects v3 payloads with mismatched identity or date', () {
      final key = 'feast:nigeria:2026-08-15:on_day:assumption';
      final validId = FeastReminderNotificationContract.stableNotificationId(
        key,
      );
      final base = <String, dynamic>{
        'type': 'feast_reminder',
        'schema': 3,
        'occurrence_key': key,
        'local_notification_id': validId,
        'celebration_date': '2026-08-15',
        'scheduled_for': '2026-08-15T06:30:00+01:00',
        'remote_expires_at': '2026-08-15T06:32:00+01:00',
        'local_safety_at': '2026-08-15T06:33:00+01:00',
        'title': 'The Assumption',
        'rank': 'Solemnity',
        'timing': 'on_day',
      };

      expect(FeastReminderPayload.fromMap(base), isNotNull);
      expect(
        FeastReminderPayload.fromMap(
          Map<String, dynamic>.from(base)
            ..['local_notification_id'] = validId + 1,
        ),
        isNull,
      );
      expect(
        FeastReminderPayload.fromMap(
          Map<String, dynamic>.from(base)..['celebration_date'] = '2026-08-16',
        ),
        isNull,
      );
    });

    test('accepts legacy feast payloads without inventing a saint id', () {
      final decoded = FeastReminderPayload.tryParse(
        'feast:2026-06-29T00:00:00.000:day',
      );

      expect(decoded, isNotNull);
      expect(decoded!.celebrationDate, DateTime(2026, 6, 29));
      expect(decoded.saintProfileId, isNull);
      expect(decoded.dayBefore, isFalse);
    });

    test(
      'resolves a pre-upgrade cold-start payload to its saint page',
      () async {
        final payload = FeastReminderPayload.tryParse(
          'feast:2026-11-01T00:00:00.000:day',
        );

        final celebration = await FeastReminderDestinationResolver.instance
            .resolve(payload!, region: LiturgicalRegion.generalRoman);

        expect(celebration, isNotNull);
        expect(celebration!.id, 'all_saints');
        expect(celebration.title, 'All Saints');
        expect(celebration.rank.name, 'solemnity');
      },
    );

    test('rejects malformed and unrelated payloads safely', () {
      expect(FeastReminderPayload.tryParse(null), isNull);
      expect(FeastReminderPayload.tryParse(''), isNull);
      expect(FeastReminderPayload.tryParse('reading:today'), isNull);
      expect(FeastReminderPayload.tryParse('{bad json'), isNull);
    });

    test('a cold-start tap is retained until navigation registers', () {
      final service = FeastReminderService.instance;
      final payload = FeastReminderPayload(
        celebrationDate: DateTime(2026, 11, 1),
        scheduledFor: DateTime(2026, 11, 1),
        occurrenceKey: 'feast:generalRoman:2026-11-01:on_day:all_saints',
        timeZone: 'UTC',
        liturgicalRegion: 'generalRoman',
        scheduleGeneration: 'feast-reminders-v5',
        title: 'All Saints',
        rank: 'Solemnity',
        saintProfileId: 'all_saints',
        dayBefore: false,
      );
      FeastReminderPayload? received;

      service.receiveNotificationTapForTesting(payload.encode());
      service.setNotificationTapHandler((value) => received = value);

      expect(received?.saintProfileId, 'all_saints');
      service.clearNotificationTapHandler();
    });
  });
}
