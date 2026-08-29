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
          final title = celebration.title;
          if (!sets.any((set) => set.label.contains(title))) {
            problems.add('$entry does not expose $title');
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
    'every regional celebration identity resolves and every local source surfaces',
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
      final titleEvents = <String, Map<String, dynamic>>{};
      for (final event in events) {
        final identityKey = '${event['region']}|${event['celebration_id']}';
        identityEvents.putIfAbsent(identityKey, () => event);
        titleEvents.putIfAbsent(event['celebration_id'] as String, () => event);
      }

      final catalog = ReadingCatalogService.instance;
      final resolver = CsvReadingsResolverService.instance;
      final prefs = await LiturgicalRegionPreferenceService.getInstance();
      final allRows = await catalog.loadMemorialEntries();
      final resolutionById = <String, List<String>>{};
      final rowById = <String, MemorialFeastEntry?>{};
      final invalidReadings = <String>[];
      final unresolvedAliases = <String>[];

      for (final event in titleEvents.values) {
        final id = event['celebration_id'] as String;
        final title = event['title'] as String;
        final region = LiturgicalRegion.values.byName(
          event['region'] as String,
        );
        await prefs.setRegion(region);
        final date = DateTime.parse(event['date'] as String);
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
          unresolvedAliases.add('$id — $title');
        }
        final readings = await resolver.resolveCelebrationChoice(
          date: date,
          celebrationId: id,
          celebrationTitle: title,
        );
        rowById[id] = row;
        resolutionById[id] = readings
            .map((reading) => reading.reading)
            .toList();
        for (final reading in readings) {
          if ((reading.position ?? '').contains('Sequence')) continue;
          if (ReadingReferenceParser.parse(reading.reading).isEmpty) {
            invalidReadings.add('$id has invalid ${reading.reading}');
          }
        }
      }

      final unsurfacedSources = <String>[];
      final sourceGaps = <String>{};
      for (final event in titleEvents.values) {
        final id = event['celebration_id'] as String;
        final row = rowById[id];
        if (row == null) continue;
        final hasLocalSource =
            row.firstReading.isNotEmpty || row.gospel.isNotEmpty;
        if (hasLocalSource && (resolutionById[id]?.isEmpty ?? true)) {
          unsurfacedSources.add(id);
        } else if (!hasLocalSource) {
          sourceGaps.add(id);
        }
      }
      for (final event in titleEvents.values) {
        final id = event['celebration_id'] as String;
        if (rowById[id] == null && (resolutionById[id]?.isEmpty ?? true)) {
          sourceGaps.add(id);
        }
      }

      final sourcedCatalogRows = rowById.values
          .whereType<MemorialFeastEntry>()
          .where((row) => row.firstReading.isNotEmpty || row.gospel.isNotEmpty)
          .map((row) => row.id)
          .toSet();

      final canonicalIdentityTitles = <String, String>{};
      final identityCollisions = <String>[];
      for (final event in titleEvents.values) {
        final id = (event['celebration_id'] as String).toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '_',
        );
        final title = event['title'] as String;
        final existing = canonicalIdentityTitles[id];
        if (existing != null && existing != title) {
          identityCollisions.add('$id: $existing <> $title');
        }
        canonicalIdentityTitles[id] = title;
      }

      // Kept concise so CI reports the exhaustiveness and honest source gaps.
      // ignore: avoid_print
      print(
        'celebration identities=${identityEvents.length} '
        'catalog titles=${titleEvents.length} '
        'local sources surfaced=${sourcedCatalogRows.length} '
        'source gaps=${sourceGaps.length}',
      );
      expect(identityEvents.length, greaterThan(1100));
      expect(
        identityCollisions,
        isEmpty,
        reason: identityCollisions.join('\n'),
      );
      expect(unsurfacedSources, isEmpty, reason: unsurfacedSources.join('\n'));
      expect(unresolvedAliases, isEmpty, reason: unresolvedAliases.join('\n'));
      expect(invalidReadings, isEmpty, reason: invalidReadings.join('\n'));
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
