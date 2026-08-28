import 'dart:io';

import 'package:catholic_daily/data/services/feast_notification_catalog_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'builds a deterministic canonical feast catalog',
    () async {
      final builder = FeastNotificationCatalogBuilder();
      final first = await builder.build(startYear: 2024, endYear: 2035);
      final second = await builder.build(startYear: 2024, endYear: 2035);

      expect(first.canonicalJson(), second.canonicalJson());
      expect(first.hasValidDigest, isTrue);

      if (const bool.fromEnvironment('WRITE_FEAST_CATALOG')) {
        final output = File('assets/data/feast_notification_catalog.json');
        await output.writeAsString(first.canonicalJson(), flush: true);
      }

      // Kept concise so CI logs expose the exact artifact identity.
      // ignore: avoid_print
      print('events=${first.events.length} sha256=${first.sha256Digest}');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
