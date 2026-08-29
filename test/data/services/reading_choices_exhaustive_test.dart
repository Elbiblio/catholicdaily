import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'every fixed feast and memorial remains reachable with valid readings',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.nigeria);
      final celebrations = OptionalMemorialService.instance.allCelebrations;
      final lookup = OfflineOrdoLookupService.instance;
      final catalog = ReadingCatalogService.instance;
      final resolver = CsvReadingsResolverService.instance;
      final byDate = <String, List<OptionalCelebration>>{};
      for (final celebration in celebrations) {
        byDate
            .putIfAbsent('${celebration.month}-${celebration.day}', () => [])
            .add(celebration);
      }
      final problems = <String>[];

      for (final entry in byDate.entries) {
        final parts = entry.key.split('-');
        final date = DateTime(2026, int.parse(parts[0]), int.parse(parts[1]));
        final sets = await AlternateReadingsService.instance
            .getAvailableReadingSets(date);
        if (sets.isEmpty || sets.first.readings.isEmpty) {
          problems.add('$entry has no primary reading set');
          continue;
        }

        final resolvedDay = lookup.resolve(
          date,
          region: LiturgicalRegion.nigeria,
        );
        final resolvedRank = (resolvedDay.rank ?? '').toLowerCase();
        if ((resolvedRank.contains('feast') ||
                resolvedRank.contains('solemnity')) &&
            sets.first.label != resolvedDay.title) {
          problems.add(
            '${entry.key} ${resolvedDay.rank} ${resolvedDay.title} is not first; '
            'found ${sets.first.label}',
          );
        }

        for (final celebration in entry.value) {
          final row = await catalog.findMemorialEntry(
            celebrationId: celebration.id,
            celebrationTitle: celebration.title,
          );
          final hasProper =
              row != null &&
              (row.firstReading.isNotEmpty || row.gospel.isNotEmpty);
          final commonChoices = celebration.commonType?.trim().isEmpty == false
              ? await resolver.resolveCommonChoices(
                  date: date,
                  commonType: celebration.commonType!,
                )
              : const <NamedReadingChoice>[];
          if (hasProper &&
              !sets.any((set) => set.label.contains(celebration.title))) {
            problems.add('$entry does not expose ${celebration.title} proper');
          }
          for (final common in commonChoices) {
            if (!sets.any((set) => set.label.contains(common.label))) {
              problems.add(
                '$entry does not expose ${celebration.title} ${common.label}',
              );
            }
          }
        }

        for (final set in sets) {
          if (set.readings.isEmpty) {
            problems.add('${entry.key} ${set.label} is empty');
          }
          for (final reading in set.readings) {
            if (ReadingReferenceParser.parse(reading.reading).isEmpty) {
              problems.add(
                '${entry.key} ${set.label} has invalid ${reading.position}: ${reading.reading}',
              );
            }
          }
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'Assumption proper readings follow every supported regional transfer',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final lookup = OfflineOrdoLookupService.instance;
      final problems = <String>[];

      for (final region in LiturgicalRegion.selectable) {
        await prefs.setRegion(region);
        for (var year = 2025; year <= 2032; year++) {
          DateTime? observedDate;
          for (var offset = 0; offset <= 7; offset++) {
            final candidate = DateTime(year, 8, 15 + offset);
            final day = lookup.resolve(candidate, region: region);
            if (day.title == 'The Assumption of the Blessed Virgin Mary') {
              observedDate = candidate;
              break;
            }
          }
          if (observedDate == null) {
            problems.add('${region.code} $year has no Assumption observance');
            continue;
          }

          final sets = await AlternateReadingsService.instance
              .getAvailableReadingSets(observedDate);
          final primary = sets.isEmpty ? null : sets.first;
          final references = primary?.readings
              .map((reading) => reading.reading)
              .toList();
          const expected = <String>[
            'Rev 11:19a; 12:1-6a, 10ab',
            'Ps 45:10, 11, 12, 16',
            '1 Cor 15:20-27',
            'Luke 1:39-56',
          ];
          if (primary?.label != 'The Assumption of the Blessed Virgin Mary' ||
              !_listEquals(references, expected)) {
            problems.add(
              '${region.code} $observedDate resolved ${primary?.label}: $references',
            );
          }
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'all supported regional event paths resolve or match the gap snapshot',
    () async {
      final decoded =
          jsonDecode(
                await File(
                  'assets/data/feast_notification_catalog.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final events = (decoded['events'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final identityEvents = <String, Map<String, dynamic>>{};
      for (final event in events) {
        final identityKey = '${event['region']}|${event['celebration_id']}';
        identityEvents.putIfAbsent(identityKey, () => event);
      }

      final catalog = ReadingCatalogService.instance;
      final resolver = CsvReadingsResolverService.instance;
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final allRows = await catalog.loadMemorialEntries();
      final invalidReadings = <String>[];
      final unresolvedAliases = <String>[];
      final identityTitles = <String, String>{};
      final titleCollisions = <String>[];
      final sourceGaps = <String>{};
      final sourceGapIds = <String>{};
      final surfacedLocalSources = <String>{};
      final surfacedCommonSources = <String>{};
      LiturgicalRegion? currentRegion;

      for (final event in events) {
        final id = event['celebration_id'] as String;
        final title = event['title'] as String;
        final region = LiturgicalRegion.values.byName(
          event['region'] as String,
        );
        if (region != currentRegion) {
          await prefs.setRegion(region);
          currentRegion = region;
        }
        final date = DateTime.parse(event['date'] as String);
        final identityKey = '${event['region']}|$id';
        final previousTitle = identityTitles[identityKey];
        if (previousTitle != null && previousTitle != title) {
          titleCollisions.add('$identityKey: $previousTitle <> $title');
        }
        identityTitles[identityKey] = title;

        final row = await catalog.findMemorialEntry(
          celebrationId: id,
          celebrationTitle: title,
        );
        final requestedIdentities = <String>{
          _auditIdentity(id),
          _auditIdentity(title),
        };
        final hasDirectCatalogIdentity = allRows.any(
          (candidate) => <String>{
            _auditIdentity(candidate.id),
            _auditIdentity(candidate.title),
          }.any(requestedIdentities.contains),
        );
        if (hasDirectCatalogIdentity && row == null) {
          unresolvedAliases.add('$identityKey — $title');
        }
        final readings = await resolver.resolveCelebrationChoice(
          date: date,
          celebrationId: id,
          celebrationTitle: title,
        );
        if (readings.isNotEmpty) {
          surfacedLocalSources.add(identityKey);
        } else {
          final registryMatches = OptionalMemorialService.instance
              .getAllCelebrationsForDate(date)
              .where(
                (celebration) =>
                    _auditIdentity(celebration.id) == _auditIdentity(id) ||
                    _auditIdentity(celebration.title) == _auditIdentity(title),
              );
          final commonType = row?.commonType.trim().isNotEmpty == true
              ? row!.commonType
              : registryMatches.isEmpty
              ? ''
              : registryMatches.first.commonType ?? '';
          final commonChoices = commonType.isEmpty
              ? const <NamedReadingChoice>[]
              : await resolver.resolveCommonChoices(
                  date: date,
                  commonType: commonType,
                );
          if (commonChoices.isNotEmpty) {
            surfacedCommonSources.add(identityKey);
          } else {
            sourceGaps.add(identityKey);
            sourceGapIds.add(id);
          }
        }
        for (final reading in readings) {
          if ((reading.position ?? '').contains('Sequence')) continue;
          if (ReadingReferenceParser.parse(reading.reading).isEmpty) {
            invalidReadings.add('$identityKey has invalid ${reading.reading}');
          }
        }
      }

      // ignore: avoid_print
      print(
        'event paths=${events.length} identities=${identityEvents.length} '
        'local=${surfacedLocalSources.length} '
        'common=${surfacedCommonSources.length} '
        'source gap paths=${sourceGaps.length} '
        'source gap ids=${sourceGapIds.length}',
      );
      expect(events, hasLength(11510));
      expect(identityEvents, hasLength(1143));
      expect(titleCollisions, isEmpty, reason: titleCollisions.join('\n'));
      expect(unresolvedAliases, isEmpty, reason: unresolvedAliases.join('\n'));
      expect(invalidReadings, isEmpty, reason: invalidReadings.join('\n'));
      expect(
        sourceGapIds,
        equals(_expectedRegionalSourceGaps),
        reason:
            'Update the reviewed source-gap snapshot only when a local proper/common source is added or catalog scope changes:\n${(sourceGapIds.toList()..sort()).join('\n')}',
      );
      expect(sourceGaps, hasLength(_expectedRegionalSourceGapPathCount));
    },
    timeout: const Timeout(Duration(minutes: 12)),
  );

  test(
    'all populated memorial rows surface or have an explicit temporal class',
    () async {
      final catalog = ReadingCatalogService.instance;
      final rows = (await catalog.loadMemorialEntries())
          .where((row) => row.firstReading.isNotEmpty || row.gospel.isNotEmpty)
          .toList();
      final resolver = CsvReadingsResolverService.instance;
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.nigeria);
      final problems = <String>[];
      final classifications = <String, int>{};

      for (final row in rows) {
        DateTime? date;
        String classification;
        final month = int.tryParse(row.month);
        final day = int.tryParse(row.day);
        if (month != null && day != null) {
          classification = 'fixed-local';
          for (var year = 2024; year <= 2035; year++) {
            final candidate = DateTime(year, month, day);
            if (candidate.weekday != DateTime.sunday) {
              date = candidate;
              break;
            }
          }
        } else {
          classification = _temporalClassification(row.id);
          date = _representativeTemporalDate(row.dateRule);
        }
        classifications.update(
          classification,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        if (date == null) {
          problems.add('${row.id}: no representative date for ${row.dateRule}');
          continue;
        }

        final readings = await resolver.resolveCelebrationChoice(
          date: date,
          celebrationId: row.id,
          celebrationTitle: row.title,
        );
        if (readings.isEmpty) {
          problems.add('${row.id}: $classification did not surface on $date');
        }
      }

      // ignore: avoid_print
      print('populated rows=${rows.length} classifications=$classifications');
      expect(rows, hasLength(62));
      expect(classifications['fixed-local'], 53);
      expect(classifications['triduum'], 4);
      expect(classifications['temporal-solemnity-or-feast'], 5);
      expect(problems, isEmpty, reason: problems.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );

  test(
    'every fixed obligatory memorial is primary when the calendar appoints it',
    () async {
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      await prefs.setRegion(LiturgicalRegion.nigeria);
      final rows = await ReadingCatalogService.instance.loadMemorialEntries();
      final obligatory = rows.where(
        (row) =>
            row.rank.toLowerCase() == 'obligatory memorial' &&
            int.tryParse(row.month) != null &&
            int.tryParse(row.day) != null,
      );
      final problems = <String>[];
      var appointed = 0;

      for (final row in obligatory) {
        for (final year in <int>[2024, 2025, 2026, 2027]) {
          final date = DateTime(year, int.parse(row.month), int.parse(row.day));
          if (date.weekday == DateTime.sunday ||
              OptionalMemorialService.instance.isSuppressedDate(date)) {
            continue;
          }
          final higherRanked = OfflineOrdoLookupService.instance.resolve(
            date,
            region: LiturgicalRegion.nigeria,
          );
          if (higherRanked.title.isNotEmpty) continue;

          appointed += 1;
          final sets = await AlternateReadingsService.instance
              .getAvailableReadingSets(date);
          if (sets.isEmpty || !sets.first.label.startsWith(row.title)) {
            problems.add(
              '$date ${row.id}: ${sets.isEmpty ? '<empty>' : sets.first.label}',
            );
          }
          if ((row.firstReading.isNotEmpty || row.gospel.isNotEmpty) &&
              (sets.isEmpty || sets.first.readings.isEmpty)) {
            problems.add('$date ${row.id}: local proper was not surfaced');
          }
        }
      }

      // ignore: avoid_print
      print(
        'obligatory memorial rows=${obligatory.length} '
        'appointed year-dates=$appointed',
      );
      expect(obligatory, isNotEmpty);
      expect(appointed, greaterThanOrEqualTo(20));
      expect(problems, isEmpty, reason: problems.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

bool _listEquals(List<String>? left, List<String> right) {
  if (left == null || left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

String _auditIdentity(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return const <String, String>{
        'the_passion_of_saint_john_the_baptist': 'passion_of_john_the_baptist',
        'the_martyrdom_of_saint_john_the_baptist':
            'passion_of_john_the_baptist',
        'the_beheading_of_saint_john_the_baptist':
            'passion_of_john_the_baptist',
      }[normalized] ??
      normalized;
}

String _temporalClassification(String id) {
  if (const <String>{
    'friday_of_the_passion_of_the_lord',
    'good_friday_of_the_lords_passion',
    'holy_saturday',
    'holy_thursday_evening_mass_of_the_lords_supper',
  }.contains(id)) {
    return 'triduum';
  }
  return 'temporal-solemnity-or-feast';
}

DateTime? _representativeTemporalDate(String dateRule) {
  return switch (dateRule) {
    'Easter Sunday' => DateTime(2026, 4, 5),
    'Friday before Easter' || 'Good Friday' => DateTime(2026, 4, 3),
    'Saturday before Easter' => DateTime(2026, 4, 4),
    "Thursday before Easter" => DateTime(2026, 4, 2),
    'Last Sunday of the liturgical year' => DateTime(2026, 11, 22),
    'Sunday before Easter' => DateTime(2026, 3, 29),
    'Sunday within the Octave of Christmas, or December 30 if no Sunday occurs' =>
      DateTime(2026, 12, 27),
    'Saturday after the Solemnity of the Most Sacred Heart of Jesus' =>
      DateTime(2026, 6, 13),
    _ => null,
  };
}

const Set<String> _expectedRegionalSourceGaps = <String>{
  'albert-the-great',
  'angela-merici',
  'anselm-of-canterbury',
  'ansgar-of-hamburg',
  'anthony-mary-claret',
  'anthony-zaccaria',
  'augustine-of-canterbury',
  'bede-the-venerable',
  'bernardine-of-siena',
  'bridget-of-sweden',
  'bruno-of-cologne',
  'cajetan-of-thiene',
  'camillus-de-lellis',
  'casimir-of-poland',
  'columban-of-luxeuil',
  'cyril-of-alexandria',
  'damasus-i-pope',
  'dedication-of-basilicas-of-peter-and-paul',
  'elizabeth-of-portugal',
  'ephrem-the-syrian',
  'eusebius-of-vercelli',
  'gertrude-the-great',
  'gregory-of-narek',
  'gregory-vii-pope',
  'hedwig-of-silesia',
  'henry-ii-emperor',
  'hilary-of-poitiers',
  'isidore-of-seville',
  'jane-frances-de-chantal',
  'jerome-emiliani',
  'john-damascene',
  'john-eudes',
  'john-leonardi',
  'john-of-avila',
  'john-of-capistrano',
  'joseph-of-calasanz',
  'josephine-bakhita',
  'juan-diego',
  'lawrence-of-brindisi',
  'louis-grignion-de-montfort',
  'louis-ix-of-france',
  'margaret-mary-alacoque',
  'margaret-of-scotland',
  'mary-magdalene-de-pazzi',
  'mary-mother-of-the-church',
  'nicholas-of-myra',
  'norbert-of-xanten',
  'paul-of-the-cross',
  'paul-vi-pope',
  'paulinus-of-nola',
  'peter-chrysologus',
  'peter-claver',
  'peter-damian',
  'peter-julian-eymard',
  'pius-v-pope',
  'raymond-of-penyafort',
  'rita-of-cascia',
  'robert-bellarmine',
  'romuald-of-ravenna',
  'saint-barnabas-apostle',
  'seven-holy-founders-of-servites',
  'sharbel-makhluf',
  'stephen-of-hungary',
  'turibius-of-mogrovejo',
  'vincent-ferrer',
};
const int _expectedRegionalSourceGapPathCount = 454;
