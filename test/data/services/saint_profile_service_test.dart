import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_daily/data/models/saint_profile_source.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/saint_calendar_service.dart';
import 'package:catholic_daily/data/services/saint_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads curated profile for a celebration id', () async {
    const celebration = OptionalCelebration(
      id: 'bede_the_venerable',
      title: 'Saint Bede the Venerable, Priest and Doctor of the Church',
      rank: CelebrationRank.optionalMemorial,
      color: LiturgicalColor.white,
      month: 5,
      day: 25,
      commonType: 'DoctorsOfTheChurch',
    );

    final profile = await SaintProfileService.instance.findForCelebration(
      celebration,
    );

    expect(profile, isNotNull);
    expect(profile!.name, 'Saint Bede the Venerable');
    expect(profile.lifeLength, 'about 62 years');
    expect(profile.wikipediaUrl, contains('wikipedia.org'));
    expect(profile.patronage, contains('scholars'));
  });

  test('loads a curated profile by stable profile id', () async {
    final profile = await SaintProfileService.instance.findById(
      'bede_the_venerable',
    );

    expect(profile, isNotNull);
    expect(profile!.name, 'Saint Bede the Venerable');
  });

  test('preserves reviewed Batch 3 publication precision', () async {
    final frances = await SaintProfileService.instance.findById(
      'frances_of_rome',
    );

    final odebiyi = frances!.sources.singleWhere(
      (source) => source.id == 'frances-odebiyi-noncloistered',
    );

    expect(odebiyi.publicationDate, '2024-09');
  });

  test('preserves reviewed Batch 3 source genres', () async {
    final casimir = await SaintProfileService.instance.findById(
      'casimir_of_poland',
    );

    final museum = casimir!.sources.singleWhere(
      (source) => source.id == 'casimir-lithuanian-art-museum',
    );

    expect(museum.tier, SaintSourceTier.discovery);
  });

  test(
    'resolves a notification title to a stable curated profile id',
    () async {
      final profile = await SaintProfileService.instance.findCuratedByTitle(
        'All Saints',
      );

      expect(profile?.id, 'all_saints');
    },
  );

  test('normalizes celebration titles for fallback matching', () {
    expect(
      SaintProfileService.normalizeTitle(
        'Saint Bede the Venerable, Priest and Doctor of the Church',
      ),
      SaintProfileService.normalizeTitle('Bede the Venerable'),
    );
  });

  test(
    'all saint-like memorial, optional, and observed rows are curated',
    () async {
      final entries = await ReadingCatalogService.instance
          .loadMemorialEntries();
      final saintEntries = entries.where(
        (entry) => SaintProfileService.isSaintLikeTitle(entry.title),
      );

      expect(saintEntries.length, greaterThan(100));

      final missing = <String>[];
      for (final entry in saintEntries) {
        final profile = await SaintProfileService.instance
            .findCuratedForCelebration(
              OptionalCelebration(
                id: entry.id,
                title: entry.title,
                rank: CelebrationRank.optionalMemorial,
                color: LiturgicalColor.white,
                month: int.tryParse(entry.month) ?? 1,
                day: int.tryParse(entry.day) ?? 1,
                commonType: entry.commonType.isEmpty ? null : entry.commonType,
              ),
            );
        if (profile == null) {
          missing.add('${entry.id}: ${entry.title}');
        }
      }

      const extraCelebrations = [
        OptionalCelebration(
          id: 'vincent_of_saragossa',
          title: 'Saint Vincent, Deacon and Martyr',
          rank: CelebrationRank.optionalMemorial,
          color: LiturgicalColor.red,
          month: 1,
          day: 22,
          commonType: 'Martyrs',
        ),
        OptionalCelebration(
          id: 'mary_mother_of_god',
          title: 'Mary, Mother of God',
          rank: CelebrationRank.solemnity,
          color: LiturgicalColor.white,
          month: 1,
          day: 1,
          commonType: 'BlessedVirginMary',
        ),
        OptionalCelebration(
          id: 'mary_mother_of_the_church',
          title: 'Mary, Mother of the Church',
          rank: CelebrationRank.obligatoryMemorial,
          color: LiturgicalColor.white,
          month: 5,
          day: 25,
          commonType: 'BlessedVirginMary',
        ),
        OptionalCelebration(
          id: 'saint_barnabas_apostle',
          title: 'Saint Barnabas, Apostle',
          rank: CelebrationRank.feast,
          color: LiturgicalColor.red,
          month: 6,
          day: 11,
          commonType: 'Apostles',
        ),
        OptionalCelebration(
          id: 'the_assumption',
          title: 'The Assumption',
          rank: CelebrationRank.solemnity,
          color: LiturgicalColor.white,
          month: 8,
          day: 15,
          commonType: 'BlessedVirginMary',
        ),
        OptionalCelebration(
          id: 'the_immaculate_conception',
          title: 'The Immaculate Conception',
          rank: CelebrationRank.solemnity,
          color: LiturgicalColor.white,
          month: 12,
          day: 8,
          commonType: 'BlessedVirginMary',
        ),
      ];

      for (final celebration in extraCelebrations) {
        final profile = await SaintProfileService.instance
            .findCuratedForCelebration(celebration);
        if (profile == null) {
          missing.add('${celebration.id}: ${celebration.title}');
        }
      }

      expect(missing, isEmpty);
    },
  );

  test('curated profiles contain offline profile body data', () async {
    final profiles = await SaintProfileService.instance.loadProfiles();

    expect(profiles.length, greaterThanOrEqualTo(150));
    expect(
      profiles.where((profile) => profile.briefBio.trim().isEmpty),
      isEmpty,
    );
    expect(
      profiles
          .expand((profile) => profile.patronage)
          .where((patronage) => patronage.trim().isEmpty),
      isEmpty,
    );
    expect(
      profiles.where(
        (profile) => profile.briefBio.contains('fuller curated biography'),
      ),
      isEmpty,
    );
  });

  test(
    'saint calendar exposes fixed feast days as clickable celebrations',
    () async {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: DateTime(2026, 4, 25));

      expect(
        celebrations.map((celebration) => celebration.id),
        contains('mark_evangelist'),
      );
      expect(
        celebrations.map((celebration) => celebration.title),
        contains('Saint Mark, Evangelist'),
      );
    },
  );

  test('saint calendar exposes Nigeria observed saint days', () async {
    final maryMother = await SaintCalendarService.instance
        .getSaintCelebrationsForDate(date: DateTime(2026, 5, 25));
    expect(
      maryMother.map((celebration) => celebration.id),
      contains('mary_mother_of_the_church'),
    );

    final barnabas = await SaintCalendarService.instance
        .getSaintCelebrationsForDate(date: DateTime(2026, 6, 11));
    expect(
      barnabas.map((celebration) => celebration.id),
      contains('saint_barnabas_apostle'),
    );

    final immaculateHeart = await SaintCalendarService.instance
        .getSaintCelebrationsForDate(date: DateTime(2026, 6, 13));
    expect(
      immaculateHeart.map((celebration) => celebration.id),
      contains('immaculate_heart_of_mary'),
    );
  });
}
