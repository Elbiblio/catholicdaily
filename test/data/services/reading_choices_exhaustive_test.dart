import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/offline_ordo_lookup_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
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
}

bool _listEquals(List<String>? left, List<String> right) {
  if (left == null || left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}
