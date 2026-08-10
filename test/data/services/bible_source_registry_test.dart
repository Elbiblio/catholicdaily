import 'package:catholic_daily/data/services/bible_source_registry.dart';
import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/models/bible_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BibleSourceRegistry', () {
    test('exposes RSVCE and NABRE as bundled local SQLite sources', () {
      final registry = BibleSourceRegistry.instance;

      final rsvce = registry.requireById('rsvce');
      final nabre = registry.requireById('nabre');

      expect(rsvce.displayName, 'Revised Standard Version Catholic Edition');
      expect(rsvce.abbreviation, 'RSVCE');
      expect(rsvce.storage, BibleSourceStorage.bundledAsset);
      expect(rsvce.assetDbName, 'rsvce.db');
      expect(rsvce.redistribution, BibleSourceRedistribution.bundledAllowed);

      expect(nabre.displayName, 'New American Bible Revised Edition');
      expect(nabre.abbreviation, 'NABRE');
      expect(nabre.storage, BibleSourceStorage.bundledAsset);
      expect(nabre.assetDbName, 'nabre.db');
      expect(nabre.redistribution, BibleSourceRedistribution.bundledAllowed);
    });

    test('prepares ESVCE and Jerusalem Bible as non-bundled sources', () {
      final registry = BibleSourceRegistry.instance;

      final esvce = registry.requireById('esvce');
      final jerusalem = registry.requireById('jerusalem');

      expect(esvce.storage, BibleSourceStorage.externalOnly);
      expect(
        esvce.redistribution,
        isNot(BibleSourceRedistribution.bundledAllowed),
      );
      expect(esvce.regionAffinityCodes, contains('GB_EW'));

      expect(jerusalem.storage, BibleSourceStorage.externalOnly);
      expect(
        jerusalem.redistribution,
        isNot(BibleSourceRedistribution.bundledAllowed),
      );
      expect(jerusalem.regionAffinityCodes, contains('NG'));
    });

    test('registers Douay-Rheims as a downloadable local Catholic source', () {
      final source = BibleSourceRegistry.instance.requireById('douay_rheims');

      expect(source.displayName, 'Douay-Rheims Bible');
      expect(source.abbreviation, 'DR');
      expect(source.storage, BibleSourceStorage.userProvidedLocal);
      expect(source.redistribution, BibleSourceRedistribution.userProvidedOnly);
      expect(source.assetDbName, 'engdra.db');
      expect(source.catholicCanon, isTrue);
    });

    test(
      'selectableBundledSources only returns locally renderable sources',
      () {
        final ids = BibleSourceRegistry.instance.selectableBundledSources
            .map((source) => source.id)
            .toList();

        expect(ids, containsAll(<String>['rsvce', 'nabre']));
        expect(ids, isNot(contains('esvce')));
        expect(ids, isNot(contains('jerusalem')));
      },
    );

    test('BibleVersionType remains compatible with bundled registry ids', () {
      for (final version in BibleVersionType.values) {
        final source = BibleSourceRegistry.instance.requireById(version.dbName);
        expect(version.fullName, source.displayName);
        expect(version.abbreviation, source.abbreviation);
      }
    });
  });
}
