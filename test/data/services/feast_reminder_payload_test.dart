import 'package:catholic_daily/data/services/feast_reminder_payload.dart';
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

      final celebration = decoded.toSaintCelebration();
      expect(celebration, isNotNull);
      expect(celebration!.id, 'all_saints');
      expect(celebration.month, 11);
      expect(celebration.day, 1);
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
