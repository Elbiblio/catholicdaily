import 'package:catholic_daily/data/services/feast_reminder_messaging_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
