import 'package:catholic_daily/data/services/csv_readings_resolver_service.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';
import 'comprehensive_audit_matrix.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  group('ComprehensiveAuditMatrix', () {
    test(
      'contains required regions and at least 75 deterministic future dates',
      () {
        expect(
          comprehensiveAuditRegions,
          containsAll(<LiturgicalRegion>[
            LiturgicalRegion.generalRoman,
            LiturgicalRegion.unitedStates,
            LiturgicalRegion.unitedStatesAscensionThursday,
            LiturgicalRegion.englandWales,
            LiturgicalRegion.nigeria,
          ]),
        );

        expect(comprehensiveAuditDates.length, greaterThanOrEqualTo(75));
        expect(comprehensiveAuditDates, contains(DateTime(2026, 10, 1)));
        expect(comprehensiveAuditDates, contains(DateTime(2027, 5, 13)));
        expect(comprehensiveAuditDates, contains(DateTime(2030, 12, 25)));
      },
    );

    test('dates are an exact stable sorted unique snapshot', () {
      final snapshot = comprehensiveAuditDates.map(isoDate).toList();
      final sortedSnapshot = snapshot.toList()..sort();

      expect(snapshot, hasLength(75));
      expect(snapshot, orderedEquals(sortedSnapshot));
      expect(snapshot.toSet(), hasLength(snapshot.length));
      expect(
        snapshot,
        orderedEquals(<String>[
          '2026-07-15',
          '2026-08-15',
          '2026-10-01',
          '2026-11-01',
          '2026-12-08',
          '2027-01-06',
          '2027-02-02',
          '2027-02-17',
          '2027-03-19',
          '2027-03-25',
          '2027-04-04',
          '2027-05-13',
          '2027-05-16',
          '2027-06-06',
          '2027-06-24',
          '2027-07-22',
          '2027-08-15',
          '2027-09-14',
          '2027-11-01',
          '2027-12-08',
          '2027-12-25',
          '2028-01-01',
          '2028-02-14',
          '2028-03-19',
          '2028-04-16',
          '2028-05-25',
          '2028-06-24',
          '2028-06-29',
          '2028-07-03',
          '2028-08-06',
          '2028-09-08',
          '2028-10-18',
          '2028-11-02',
          '2028-12-12',
          '2029-01-13',
          '2029-02-14',
          '2029-03-19',
          '2029-03-25',
          '2029-04-01',
          '2029-05-10',
          '2029-06-08',
          '2029-07-03',
          '2029-08-15',
          '2029-09-29',
          '2029-11-09',
          '2029-12-25',
          '2030-01-06',
          '2030-02-22',
          '2030-03-06',
          '2030-03-25',
          '2030-04-21',
          '2030-05-30',
          '2030-06-09',
          '2030-06-29',
          '2030-08-15',
          '2030-09-14',
          '2030-10-01',
          '2030-11-30',
          '2030-12-08',
          '2030-12-25',
          '2031-01-01',
          '2031-02-17',
          '2031-03-19',
          '2031-04-13',
          '2031-05-22',
          '2031-06-01',
          '2031-08-15',
          '2031-10-04',
          '2031-11-01',
          '2031-12-25',
          '2032-01-06',
          '2032-02-11',
          '2032-03-25',
          '2032-05-09',
          '2032-12-08',
        ]),
      );
    });

    test('date matrix cannot be mutated by callers', () {
      expect(
        () => comprehensiveAuditDates.add(DateTime(2033, 1, 1)),
        throwsUnsupportedError,
      );
    });

    test(
      'regional ordo sentinels prove selected region changes titles',
      () async {
        final prefs = await LiturgicalRegionPreferenceService.getInstance();
        final ordo = OrdoResolverService.instance;
        final failures = <ResolverAuditFailure>[];

        Future<void> expectTitleContains({
          required DateTime date,
          required LiturgicalRegion region,
          required String expected,
          required AuditFailureKind kind,
        }) async {
          await prefs.setRegion(region);
          final day = await ordo.resolveDay(date);
          if (!day.title.contains(expected)) {
            failures.add(
              ResolverAuditFailure(
                date: date,
                region: region,
                kind: kind,
                message:
                    'Expected title containing "$expected", got "${day.title}"',
              ),
            );
          }
        }

        Future<void> expectTitleDoesNotContain({
          required DateTime date,
          required LiturgicalRegion region,
          required String unexpected,
          required AuditFailureKind kind,
        }) async {
          await prefs.setRegion(region);
          final day = await ordo.resolveDay(date);
          if (day.title.contains(unexpected)) {
            failures.add(
              ResolverAuditFailure(
                date: date,
                region: region,
                kind: kind,
                message:
                    'Expected title not containing "$unexpected", got "${day.title}"',
              ),
            );
          }
        }

        await expectTitleContains(
          date: DateTime(2026, 10, 1),
          region: LiturgicalRegion.nigeria,
          expected: 'Our Lady, Queen of Nigeria',
          kind: AuditFailureKind.region,
        );
        await expectTitleDoesNotContain(
          date: DateTime(2026, 10, 1),
          region: LiturgicalRegion.generalRoman,
          unexpected: 'Our Lady, Queen of Nigeria',
          kind: AuditFailureKind.region,
        );

        await expectTitleContains(
          date: DateTime(2028, 5, 25),
          region: LiturgicalRegion.unitedStatesAscensionThursday,
          expected: 'Ascension',
          kind: AuditFailureKind.calendar,
        );
        await expectTitleDoesNotContain(
          date: DateTime(2028, 5, 25),
          region: LiturgicalRegion.unitedStates,
          unexpected: 'Ascension',
          kind: AuditFailureKind.calendar,
        );
        await expectTitleContains(
          date: DateTime(2028, 5, 28),
          region: LiturgicalRegion.unitedStates,
          expected: 'Ascension',
          kind: AuditFailureKind.calendar,
        );

        if (failures.isNotEmpty) {
          // ignore: avoid_print
          print('\nRegional resolver audit failures:');
          for (final failure in failures) {
            // ignore: avoid_print
            print('  $failure');
          }
        }

        expect(failures, isEmpty);
      },
    );

    test(
      'resolves non-empty well-formed readings for every matrix date and region',
      timeout: const Timeout(Duration(minutes: 8)),
      () async {
        final resolver = CsvReadingsResolverService.instance;
        final prefs = await LiturgicalRegionPreferenceService.getInstance();
        final failures = <ResolverAuditFailure>[];

        for (final region in comprehensiveAuditRegions) {
          await prefs.setRegion(region);
          for (final date in comprehensiveAuditDates) {
            final readings = await resolver.resolve(date);

            if (readings.isEmpty) {
              failures.add(
                ResolverAuditFailure(
                  date: date,
                  region: region,
                  kind: AuditFailureKind.reference,
                  message: 'No readings resolved',
                ),
              );
              continue;
            }

            final hasFirst = readings.any(
              (reading) => (reading.position ?? '').toLowerCase().contains(
                'first reading',
              ),
            );
            final hasPsalm = readings.any(
              (reading) =>
                  (reading.position ?? '').toLowerCase().contains('psalm'),
            );
            final hasGospel = readings.any((reading) {
              final position = (reading.position ?? '').toLowerCase();
              return position.contains('gospel') &&
                  !position.contains('acclamation');
            });

            if (!hasFirst) {
              failures.add(
                ResolverAuditFailure(
                  date: date,
                  region: region,
                  kind: AuditFailureKind.reference,
                  message:
                      'No first reading in ${readings.map((r) => r.position).join(', ')}',
                ),
              );
            }
            if (!hasPsalm) {
              failures.add(
                ResolverAuditFailure(
                  date: date,
                  region: region,
                  kind: AuditFailureKind.psalmResponse,
                  message:
                      'No responsorial psalm in ${readings.map((r) => r.position).join(', ')}',
                ),
              );
            }
            if (!hasGospel) {
              failures.add(
                ResolverAuditFailure(
                  date: date,
                  region: region,
                  kind: AuditFailureKind.reference,
                  message:
                      'No gospel in ${readings.map((r) => r.position).join(', ')}',
                ),
              );
            }

            for (final reading in readings) {
              if (reading.position == 'Sequence') continue;
              final reference = reading.reading.trim();
              final valid = RegExp(
                r'^[A-Za-z]|^\d+\s+[A-Za-z]',
              ).hasMatch(reference);
              if (!valid) {
                failures.add(
                  ResolverAuditFailure(
                    date: date,
                    region: region,
                    kind: AuditFailureKind.reference,
                    message:
                        '${reading.position}: malformed reference "$reference"',
                  ),
                );
              }
            }
          }
        }

        if (failures.isNotEmpty) {
          // ignore: avoid_print
          print('\nComprehensive resolver audit failures:');
          for (final failure in failures.take(80)) {
            // ignore: avoid_print
            print('  $failure');
          }
        }

        expect(failures, isEmpty);
      },
    );
  });
}
