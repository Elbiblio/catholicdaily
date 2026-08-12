import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_daily/data/models/saint_profile_source.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
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
    // The researched overlay removes unsupported legacy patronage tokens.
    expect(profile.patronage, isEmpty);
  });

  test('loads a curated profile by stable profile id', () async {
    final profile = await SaintProfileService.instance.findById(
      'bede_the_venerable',
    );

    expect(profile, isNotNull);
    expect(profile!.name, 'Saint Bede the Venerable');
  });

  test('preserves Anthony Zaccaria legacy celebration routing', () async {
    final profile = await SaintProfileService.instance.findByCelebrationId(
      'saint_anthony_zaccaria_priest',
    );

    expect(profile, isNotNull);
    expect(profile!.id, 'anthony_zaccaria');
    expect(profile.name, 'Saint Anthony Mary Zaccaria, Priest');
  });

  test('preserves reviewed Batch 5 identity mappings', () async {
    final gregory = await SaintProfileService.instance.findById(
      'gregory_vii_pope',
    );
    final pazzi = await SaintProfileService.instance.findById(
      'mary_magdalene_de_pazzi',
    );

    expect(gregory!.wikidataId, 'Q133063');
    expect(pazzi!.wikidataId, 'Q242040');
  });

  test('preserves reviewed Batch 6 observance and group identities', () async {
    final nativity = await SaintProfileService.instance.findById(
      'the_nativity_of_saint_john_the_baptist',
    );
    final fisherAndMore = await SaintProfileService.instance.findById(
      'john_fisher_and_thomas_more',
    );

    expect(nativity!.wikidataId, 'Q3870479');
    expect(nativity.kind.name, 'observance');
    expect(nativity.lifeSpan, isEmpty);
    expect(nativity.lifeLength, isEmpty);

    expect(fisherAndMore!.wikidataId, isNull);
    expect(fisherAndMore.kind.name, 'group');
    expect(fisherAndMore.lifeSpan, isEmpty);
    expect(fisherAndMore.lifeLength, isEmpty);
  });

  test('preserves reviewed Batch 7 identities and profile kinds', () async {
    const expected = {
      'first_martyrs_of_rome': ('Q640666', 'group'),
      'thomas_apostle': ('Q43669', 'biblical'),
      'elizabeth_of_portugal': ('Q235857', 'individual'),
      'anthony_zaccaria': ('Q380099', 'individual'),
      'maria_goretti': ('Q234697', 'individual'),
      'henry_ii_emperor': ('Q103556', 'individual'),
      'camillus_de_lellis': ('Q332656', 'individual'),
      'our_lady_of_mount_carmel': ('Q1065053', 'observance'),
      'apollinaris_of_ravenna': ('Q320199', 'individual'),
      'lawrence_of_brindisi': ('Q313803', 'individual'),
      'mary_magdalene': ('Q63070', 'individual'),
      'bridget_of_sweden': ('Q204996', 'individual'),
    };

    for (final entry in expected.entries) {
      final profile = await SaintProfileService.instance.findById(entry.key);

      expect(profile, isNotNull, reason: entry.key);
      expect(profile!.wikidataId, entry.value.$1, reason: entry.key);
      expect(profile.kind.name, entry.value.$2, reason: entry.key);
    }

    final mountCarmel = await SaintProfileService.instance.findById(
      'our_lady_of_mount_carmel',
    );
    expect(mountCarmel!.lifeSpan, isEmpty);
    expect(mountCarmel.lifeLength, isEmpty);
  });

  test('preserves reviewed Batch 8 identities and profile kinds', () async {
    const expected = {
      'sharbel_makhluf': ('Q331876', 'individual'),
      'james_apostle': ('Q43999', 'biblical'),
      'peter_chrysologus': ('Q328742', 'individual'),
      'eusebius_of_vercelli': ('Q181489', 'individual'),
      'peter_julian_eymard': ('Q560994', 'individual'),
      'dedication_of_basilica_of_saint_mary_major': ('Q186282', 'observance'),
      'cajetan_of_thiene': ('Q379914', 'individual'),
      'sixtus_ii_pope': (null, 'group'),
      'teresa_benedicta_of_the_cross': ('Q76749', 'individual'),
      'lawrence_of_rome_deacon': ('Q17590', 'individual'),
      'jane_frances_de_chantal': ('Q234521', 'individual'),
      'pontian_and_hippolytus': (null, 'group'),
    };

    for (final entry in expected.entries) {
      final profile = await SaintProfileService.instance.findById(entry.key);

      expect(profile, isNotNull, reason: entry.key);
      expect(profile!.wikidataId, entry.value.$1, reason: entry.key);
      expect(profile.kind.name, entry.value.$2, reason: entry.key);
    }

    for (final id in const [
      'dedication_of_basilica_of_saint_mary_major',
      'sixtus_ii_pope',
      'pontian_and_hippolytus',
    ]) {
      final profile = await SaintProfileService.instance.findById(id);
      expect(profile!.lifeSpan, isEmpty, reason: id);
      expect(profile.lifeLength, isEmpty, reason: id);
    }
  });

  test('preserves reviewed Batch 9 identities and profile kinds', () async {
    const expected = {
      'the_assumption_of_the_blessed_virgin_mary': ('Q162691', 'observance'),
      'stephen_of_hungary': ('Q177903', 'individual'),
      'john_eudes': ('Q441714', 'individual'),
      'queenship_of_blessed_virgin_mary': ('Q1358870', 'observance'),
      'rose_of_lima': ('Q244383', 'individual'),
      'bartholomew_apostle': ('Q43982', 'individual'),
      'joseph_of_calasanz': ('Q360589', 'individual'),
      'louis_ix_of_france': ('Q346', 'individual'),
      'passion_of_john_the_baptist': ('Q2511873', 'observance'),
      'nativity_of_blessed_virgin_mary': ('Q501107', 'observance'),
      'peter_claver': ('Q167458', 'individual'),
      'most_holy_name_of_mary': ('Q1537037', 'observance'),
    };

    for (final entry in expected.entries) {
      final profile = await SaintProfileService.instance.findById(entry.key);

      expect(profile, isNotNull, reason: entry.key);
      expect(profile!.wikidataId, entry.value.$1, reason: entry.key);
      expect(profile.kind.name, entry.value.$2, reason: entry.key);
    }

    for (final id in const [
      'the_assumption_of_the_blessed_virgin_mary',
      'queenship_of_blessed_virgin_mary',
      'passion_of_john_the_baptist',
      'nativity_of_blessed_virgin_mary',
      'most_holy_name_of_mary',
    ]) {
      final profile = await SaintProfileService.instance.findById(id);
      expect(profile!.lifeSpan, isEmpty, reason: id);
      expect(profile.lifeLength, isEmpty, reason: id);
    }
  });

  test('preserves reviewed Batch 10 identities and profile kinds', () async {
    const expected = <String, (String?, String)>{
      'our_lady_of_sorrows': ('Q20170562', 'observance'),
      'robert_bellarmine': ('Q298664', 'individual'),
      'januarius_of_benevento': ('Q315312', 'individual'),
      'matthew_apostle': ('Q43600', 'biblical'),
      'cosmas_and_damian': ('Q76486', 'group'),
      'lawrence_ruiz': ('Q669138', 'group'),
      'wenceslaus_of_bohemia': ('Q196527', 'individual'),
      'faustina_kowalska': ('Q18978', 'individual'),
      'bruno_of_cologne': ('Q312314', 'individual'),
      'our_lady_of_the_rosary': (null, 'observance'),
      'denis_of_paris': (null, 'group'),
      'john_leonardi': ('Q1355472', 'individual'),
    };

    for (final entry in expected.entries) {
      final profile = await SaintProfileService.instance.findById(entry.key);

      expect(profile, isNotNull, reason: entry.key);
      expect(profile!.wikidataId, entry.value.$1, reason: entry.key);
      expect(profile.kind.name, entry.value.$2, reason: entry.key);
    }

    for (final id in const [
      'our_lady_of_sorrows',
      'our_lady_of_the_rosary',
      'cosmas_and_damian',
      'lawrence_ruiz',
      'denis_of_paris',
    ]) {
      final profile = await SaintProfileService.instance.findById(id);
      expect(profile!.lifeSpan, isEmpty, reason: id);
      expect(profile.lifeLength, isEmpty, reason: id);
    }
  });

  test('preserves reviewed Batch 11 identities and profile kinds', () async {
    const expected = <String, (String?, String)>{
      'john_xxiii_pope': ('Q23873', 'individual'),
      'our_lady_of_aparecida': (null, 'observance'),
      'callistus_i_pope': ('Q122376', 'individual'),
      'hedwig_of_silesia': ('Q57520', 'individual'),
      'margaret_mary_alacoque': ('Q235853', 'individual'),
      'luke_evangelist': ('Q128538', 'biblical'),
      'john_de_brebeuf_and_isaac_jogues': ('Q2653872', 'group'),
      'paul_of_the_cross': ('Q370261', 'individual'),
      'john_paul_ii_pope': ('Q989', 'individual'),
      'john_of_capistrano': ('Q310359', 'individual'),
      'anthony_mary_claret': ('Q162973', 'individual'),
      'simon_and_jude_apostles': ('Q10400498', 'group'),
    };

    for (final entry in expected.entries) {
      final profile = await SaintProfileService.instance.findById(entry.key);

      expect(profile, isNotNull, reason: entry.key);
      expect(profile!.wikidataId, entry.value.$1, reason: entry.key);
      expect(profile.kind.name, entry.value.$2, reason: entry.key);
    }

    for (final id in const [
      'our_lady_of_aparecida',
      'luke_evangelist',
      'john_de_brebeuf_and_isaac_jogues',
      'simon_and_jude_apostles',
    ]) {
      final profile = await SaintProfileService.instance.findById(id);
      expect(profile!.lifeSpan, isEmpty, reason: id);
      expect(profile.lifeLength, isEmpty, reason: id);
    }
  });

  test('preserves reviewed Batch 3 publication precision', () async {
    final frances = await SaintProfileService.instance.findById(
      'frances_of_rome',
    );

    final odebiyi = frances!.sources.singleWhere(
      (source) => source.id == 'frances-odebiyi-noncloistered',
    );

    expect(odebiyi.publicationDate, '2025-03-03');
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

  test('Batch 4 one-minute summaries contain 100 to 150 words', () async {
    const batch4Ids = [
      'vincent_ferrer',
      'martin_i_pope',
      'anselm_of_canterbury',
      'adalbert_of_prague',
      'george_of_lydda',
      'fidelis_of_sigmaringen',
      'mark_evangelist',
      'louis_grignion_de_montfort',
      'peter_chanel',
      'our_lady_mother_of_africa',
      'pius_v_pope',
      'philip_and_james_apostles',
    ];
    final failures = <String>[];

    for (final id in batch4Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 5 one-minute summaries contain 100 to 150 words', () async {
    const batch5Ids = [
      'john_of_avila',
      'nereus_and_achilleus',
      'pancras_of_rome',
      'our_lady_of_fatima',
      'matthias_apostle',
      'john_i_pope',
      'bernardine_of_siena',
      'christopher_magallanes',
      'rita_of_cascia',
      'bede_the_venerable',
      'gregory_vii_pope',
      'mary_magdalene_de_pazzi',
    ];
    final failures = <String>[];

    for (final id in batch5Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 6 one-minute summaries contain 100 to 150 words', () async {
    const batch6Ids = [
      'augustine_of_canterbury',
      'paul_vi_pope',
      'visitation_of_mary',
      'marcellinus_and_peter',
      'norbert_of_xanten',
      'ephrem_the_syrian',
      'saint_barnabas_apostle',
      'romuald_of_ravenna',
      'john_fisher_and_thomas_more',
      'paulinus_of_nola',
      'the_nativity_of_saint_john_the_baptist',
      'cyril_of_alexandria',
    ];
    final failures = <String>[];

    for (final id in batch6Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 7 one-minute summaries contain 100 to 150 words', () async {
    const batch7Ids = [
      'first_martyrs_of_rome',
      'thomas_apostle',
      'elizabeth_of_portugal',
      'anthony_zaccaria',
      'maria_goretti',
      'henry_ii_emperor',
      'camillus_de_lellis',
      'our_lady_of_mount_carmel',
      'apollinaris_of_ravenna',
      'lawrence_of_brindisi',
      'mary_magdalene',
      'bridget_of_sweden',
    ];
    final failures = <String>[];

    for (final id in batch7Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 8 one-minute summaries contain 100 to 150 words', () async {
    const batch8Ids = [
      'sharbel_makhluf',
      'james_apostle',
      'peter_chrysologus',
      'eusebius_of_vercelli',
      'peter_julian_eymard',
      'dedication_of_basilica_of_saint_mary_major',
      'cajetan_of_thiene',
      'sixtus_ii_pope',
      'teresa_benedicta_of_the_cross',
      'lawrence_of_rome_deacon',
      'jane_frances_de_chantal',
      'pontian_and_hippolytus',
    ];
    final failures = <String>[];

    for (final id in batch8Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 9 one-minute summaries contain 100 to 150 words', () async {
    const batch9Ids = [
      'the_assumption_of_the_blessed_virgin_mary',
      'stephen_of_hungary',
      'john_eudes',
      'queenship_of_blessed_virgin_mary',
      'rose_of_lima',
      'bartholomew_apostle',
      'joseph_of_calasanz',
      'louis_ix_of_france',
      'passion_of_john_the_baptist',
      'nativity_of_blessed_virgin_mary',
      'peter_claver',
      'most_holy_name_of_mary',
    ];
    final failures = <String>[];

    for (final id in batch9Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 10 one-minute summaries contain 100 to 150 words', () async {
    const batch10Ids = [
      'our_lady_of_sorrows',
      'robert_bellarmine',
      'januarius_of_benevento',
      'matthew_apostle',
      'cosmas_and_damian',
      'lawrence_ruiz',
      'wenceslaus_of_bohemia',
      'faustina_kowalska',
      'bruno_of_cologne',
      'our_lady_of_the_rosary',
      'denis_of_paris',
      'john_leonardi',
    ];
    final failures = <String>[];

    for (final id in batch10Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('Batch 11 one-minute summaries contain 100 to 150 words', () async {
    const batch11Ids = [
      'john_xxiii_pope',
      'our_lady_of_aparecida',
      'callistus_i_pope',
      'hedwig_of_silesia',
      'margaret_mary_alacoque',
      'luke_evangelist',
      'john_de_brebeuf_and_isaac_jogues',
      'paul_of_the_cross',
      'john_paul_ii_pope',
      'john_of_capistrano',
      'anthony_mary_claret',
      'simon_and_jude_apostles',
    ];
    final failures = <String>[];

    for (final id in batch11Ids) {
      final profile = await SaintProfileService.instance.findById(id);
      final summary = profile!.guide!.oneMinuteSummary.trim();
      final wordCount = summary
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .length;
      if (wordCount < 100 || wordCount > 150) {
        failures.add('$id: $wordCount words');
      }
    }

    expect(failures, isEmpty);
  });

  test('preserves reviewed Batch 7 calendar ranks and colors', () async {
    final cases = [
      (
        DateTime(2026, 6, 30),
        'first_martyrs_of_rome',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 7, 3),
        'thomas_apostle',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 7, 4),
        'elizabeth_of_portugal',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 5),
        'anthony_zaccaria',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 6),
        'maria_goretti',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 7, 13),
        'henry_ii_emperor',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 14),
        'camillus_de_lellis',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 16),
        'our_lady_of_mount_carmel',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 20),
        'apollinaris_of_ravenna',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 7, 21),
        'lawrence_of_brindisi',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 22),
        'mary_magdalene',
        CelebrationRank.feast,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 23),
        'bridget_of_sweden',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
    ];

    for (final entry in cases) {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: entry.$1);
      final celebration = celebrations.singleWhere(
        (candidate) => candidate.id == entry.$2,
      );

      expect(celebration.rank, entry.$3, reason: entry.$2);
      expect(celebration.color, entry.$4, reason: entry.$2);
    }
  });

  test('preserves reviewed Batch 8 calendar ranks and colors', () async {
    final cases = [
      (
        DateTime(2026, 7, 24),
        'sharbel_makhluf',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 7, 25),
        'james_apostle',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 7, 30),
        'peter_chrysologus',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 2),
        'eusebius_of_vercelli',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 2),
        'peter_julian_eymard',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 5),
        'dedication_of_basilica_of_saint_mary_major',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 7),
        'cajetan_of_thiene',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 7),
        'sixtus_ii_pope',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 8, 9),
        'teresa_benedicta_of_the_cross',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 8, 10),
        'lawrence_of_rome_deacon',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 8, 12),
        'jane_frances_de_chantal',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 13),
        'pontian_and_hippolytus',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
    ];

    for (final entry in cases) {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: entry.$1);
      final celebration = celebrations.singleWhere(
        (candidate) => candidate.id == entry.$2,
      );

      expect(celebration.rank, entry.$3, reason: entry.$2);
      expect(celebration.color, entry.$4, reason: entry.$2);
    }
  });

  test('preserves reviewed Batch 9 calendar ranks and colors', () async {
    final assumption = ImprovedLiturgicalCalendarService.instance
        .getLiturgicalDay(DateTime(2026, 8, 15));
    expect(assumption.title, 'The Assumption');
    expect(assumption.rank, 'Solemnity');
    expect(assumption.color, LiturgicalColor.white);

    final cases = [
      (
        DateTime(2026, 8, 16),
        'stephen_of_hungary',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 19),
        'john_eudes',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 22),
        'queenship_of_blessed_virgin_mary',
        CelebrationRank.obligatoryMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 23),
        'rose_of_lima',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 24),
        'bartholomew_apostle',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 8, 25),
        'joseph_of_calasanz',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 25),
        'louis_ix_of_france',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 8, 29),
        'passion_of_john_the_baptist',
        CelebrationRank.obligatoryMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 9, 8),
        'nativity_of_blessed_virgin_mary',
        CelebrationRank.feast,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 9, 9),
        'peter_claver',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 9, 12),
        'most_holy_name_of_mary',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
    ];

    for (final entry in cases) {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: entry.$1);
      final matching = celebrations
          .where((candidate) => candidate.id == entry.$2)
          .toList(growable: false);
      expect(
        matching,
        hasLength(1),
        reason:
            '${entry.$1.toIso8601String()}: '
            '${celebrations.map((candidate) => candidate.id).join(', ')}',
      );
      final celebration = matching.single;

      expect(celebration.rank, entry.$3, reason: entry.$2);
      expect(celebration.color, entry.$4, reason: entry.$2);
    }
  });

  test('preserves reviewed Batch 10 calendar ranks and colors', () async {
    final cases = [
      (
        DateTime(2026, 9, 15),
        'our_lady_of_sorrows',
        CelebrationRank.obligatoryMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 9, 17),
        'robert_bellarmine',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 9, 19),
        'januarius_of_benevento',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 9, 21),
        'matthew_apostle',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 9, 26),
        'cosmas_and_damian',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 9, 28),
        'lawrence_ruiz',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 9, 28),
        'wenceslaus_of_bohemia',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 10, 5),
        'faustina_kowalska',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 6),
        'bruno_of_cologne',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 7),
        'our_lady_of_the_rosary',
        CelebrationRank.obligatoryMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 9),
        'denis_of_paris',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 10, 9),
        'john_leonardi',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
    ];

    for (final entry in cases) {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: entry.$1);
      final matching = celebrations
          .where((candidate) => candidate.id == entry.$2)
          .toList();
      expect(matching, hasLength(1), reason: entry.$2);
      expect(matching.single.rank, entry.$3, reason: entry.$2);
      expect(matching.single.color, entry.$4, reason: entry.$2);
    }
  });

  test('preserves reviewed Batch 11 calendar ranks and colors', () async {
    final cases = [
      (
        DateTime(2026, 10, 11),
        'john_xxiii_pope',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 14),
        'callistus_i_pope',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 10, 16),
        'hedwig_of_silesia',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 16),
        'margaret_mary_alacoque',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 18),
        'luke_evangelist',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 10, 19),
        'john_de_brebeuf_and_isaac_jogues',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.red,
      ),
      (
        DateTime(2026, 10, 19),
        'paul_of_the_cross',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 22),
        'john_paul_ii_pope',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 23),
        'john_of_capistrano',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 24),
        'anthony_mary_claret',
        CelebrationRank.optionalMemorial,
        LiturgicalColor.white,
      ),
      (
        DateTime(2026, 10, 28),
        'simon_and_jude_apostles',
        CelebrationRank.feast,
        LiturgicalColor.red,
      ),
    ];

    for (final entry in cases) {
      final celebrations = await SaintCalendarService.instance
          .getSaintCelebrationsForDate(date: entry.$1);
      final matching = celebrations
          .where((candidate) => candidate.id == entry.$2)
          .toList();
      expect(matching, hasLength(1), reason: entry.$2);
      expect(matching.single.rank, entry.$3, reason: entry.$2);
      expect(matching.single.color, entry.$4, reason: entry.$2);
    }

    final aparecida = OfflineOrdoLookupService.instance.resolve(
      DateTime(2026, 10, 12),
      region: LiturgicalRegion.brazil,
    );
    expect(aparecida.title, 'Our Lady of Aparecida');
    expect(aparecida.rank, 'Solemnity');
    expect(aparecida.color, LiturgicalColor.white);
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
          rank: CelebrationRank.obligatoryMemorial,
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
    expect(
      barnabas
          .firstWhere(
            (celebration) => celebration.id == 'saint_barnabas_apostle',
          )
          .rank,
      CelebrationRank.obligatoryMemorial,
    );

    final immaculateHeart = await SaintCalendarService.instance
        .getSaintCelebrationsForDate(date: DateTime(2026, 6, 13));
    expect(
      immaculateHeart.map((celebration) => celebration.id),
      contains('immaculate_heart_of_mary'),
    );
  });
}
