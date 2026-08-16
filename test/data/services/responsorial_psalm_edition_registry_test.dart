import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/responsorial_psalm_edition_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry separates installed and unavailable psalm editions', () {
    final fixture =
        jsonDecode(
              File(
                'assets/data/psalm_editions/manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final registry = ResponsorialPsalmEditionRegistry.fromJson(fixture);

    expect(registry.requireById('local_rsvce').isInstalled, isTrue);
    expect(registry.requireById('esvce').isInstalled, isFalse);
    expect(
      registry.selectable.map((edition) => edition.id),
      contains('local_rsvce'),
    );
    expect(
      registry.selectable.map((edition) => edition.id),
      isNot(contains('esvce')),
    );
  });
}
