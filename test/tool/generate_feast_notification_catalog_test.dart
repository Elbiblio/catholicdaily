import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/feast_notification_catalog_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('committed feast catalog is canonical and complete', () async {
    final file = File('assets/data/feast_notification_catalog.json');
    expect(file.existsSync(), isTrue, reason: 'Generate the shared catalog.');

    final text = await file.readAsString();
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final catalog = FeastNotificationCatalog.fromJson(decoded);

    expect(catalog.schema, 1);
    expect(catalog.scheduleGeneration, 'feast-reminders-v5');
    expect(catalog.startDate, DateTime(2024, 1, 1));
    expect(catalog.endDate, DateTime(2035, 12, 31));
    expect(catalog.hasValidDigest, isTrue);
    expect(catalog.canonicalJson(), text);

    expect(
      catalog.events.map((event) => event.region).toSet(),
      LiturgicalRegion.selectable.map((region) => region.name).toSet(),
    );
    expect(catalog.events.length, greaterThan(10000));

    final orderingKeys = catalog.events
        .map(
          (event) => <Object>[
            event.region,
            event.date.millisecondsSinceEpoch,
            event.rank,
            event.celebrationId,
            event.title,
          ],
        )
        .toList(growable: false);
    final sortedOrderingKeys = List<List<Object>>.of(orderingKeys)
      ..sort((left, right) {
        for (var index = 0; index < left.length; index++) {
          final comparison = switch ((left[index], right[index])) {
            (final int a, final int b) => a.compareTo(b),
            (final String a, final String b) => a.compareTo(b),
            _ => throw StateError('Unexpected catalog ordering field'),
          };
          if (comparison != 0) return comparison;
        }
        return 0;
      });
    expect(orderingKeys, sortedOrderingKeys);

    final occurrenceKeys = <String>{};
    for (final event in catalog.events) {
      expect(event.onDay.notificationId, isPositive);
      expect(event.eve.notificationId, isPositive);
      expect(occurrenceKeys.add(event.onDay.occurrenceKey), isTrue);
      expect(occurrenceKeys.add(event.eve.occurrenceKey), isTrue);
    }

    expect(
      catalog.events,
      contains(
        isA<FeastNotificationCatalogEvent>()
            .having((event) => event.region, 'region', 'nigeria')
            .having((event) => event.date, 'date', DateTime(2026, 8, 15))
            .having(
              (event) => event.title,
              'title',
              'The Assumption of the Blessed Virgin Mary',
            ),
      ),
    );
  });
}
