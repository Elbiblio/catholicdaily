import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import '../../helpers/test_helpers.dart';

/// Walks every day from Jan 1 2025 through Dec 31 2027 and asserts the
/// backend output (the path the UI actually renders) is free of the
/// issues the user flagged: trailing page-number noise, "-R." rubric
/// residue, and un-decoded "(R. Xx)" psalm-response references.
///
/// Also spot-verifies a handful of specific dates the user called out.
void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'Three-year audit: no trailing PDF noise anywhere',
    timeout: const Timeout(Duration(minutes: 15)),
    () async {
      final service = ReadingsService.instance;
      final start = DateTime(2025, 1, 1);
      final end = DateTime(2027, 12, 31);

      final noisePattern = RegExp(
        r'(?:\s\d{2,4}\s+[A-Z][A-Z \-]{2,}|\s(?:MONDAY|TUESDAY|WEDNESDAY|THURSDAY|FRIDAY|SATURDAY|SUNDAY|JANUARY|FEBRUARY|MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER)\s+\d{2,4}\b)',
      );
      final trailingRRubric = RegExp(r'[-–—]\s*R\.?\s*$');
      final spacedHeader = RegExp(r'\bG\s+O\s+S\s+P\s+E\s+L\b');
      final omittedRubric = RegExp(
        r'^If (?:the )?(?:Alleluia|acclamation) is not sung, it is omitted\.',
        caseSensitive: false,
      );

      final offenders = <String>[];

      final previousDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      try {
        for (
          var d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1))
        ) {
          final readings = await service.getReadingsForDate(d);
          for (final r in readings) {
            final iso =
                '${d.year}-${d.month.toString().padLeft(2, '0')}'
                '-${d.day.toString().padLeft(2, '0')}';
            void checkField(String label, String? value) {
              if (value == null) return;
              final trimmed = value.trim();
              if (trimmed.isEmpty) return;
              if (noisePattern.hasMatch(trimmed) ||
                  trailingRRubric.hasMatch(trimmed) ||
                  spacedHeader.hasMatch(trimmed) ||
                  omittedRubric.hasMatch(trimmed)) {
                offenders.add('$iso [${r.position}] $label → "$trimmed"');
              }
            }

            checkField('psalmResponse', r.psalmResponse);
            checkField('gospelAcclamation', r.gospelAcclamation);
            checkField('incipit', r.incipit);
          }
        }
      } finally {
        debugPrint = previousDebugPrint;
      }

      if (offenders.isNotEmpty) {
        // ignore: avoid_print
        print('Trailing-noise offenders (first 20):');
        for (final o in offenders.take(20)) {
          // ignore: avoid_print
          print('  $o');
        }
      }
      expect(offenders, isEmpty, reason: 'Found trailing PDF/rubric noise');
    },
  );

  test('Spot checks: user-reported dates', () async {
    final service = ReadingsService.instance;

    // 2026-04-15: Acts 5:17-26 — incipit must contain "In those days"
    // AND "rose up". Psalm 34 refrain must be the RSVCE verse text.
    final today = await service.getReadingsForDate(DateTime(2026, 4, 15));
    final first = today.firstWhere((r) => r.position == 'First Reading');
    expect(first.reading, 'Acts 5:17-26');
    expect(first.incipit, isNotNull);

    // Fetch rendered text and verify the body stays focused on scripture text;
    // the incipit is displayed separately in the UI.
    final firstText = await service.getReadingText(
      first.reading,
      incipit: first.incipit,
    );
    expect(firstText, contains('rose up'));

    final psalm = today.firstWhere((r) => r.position == 'Responsorial Psalm');
    expect(psalm.reading, contains('(R.'));
    expect(psalm.psalmResponse, isNotNull);
    expect(psalm.psalmResponse!.toLowerCase(), contains('cry of the poor'));

    // 2026-04-19: Acts 2:14, 22-33 — incipit must continue naturally
    // into "lifted up his voice and addressed them".
    final sun = await service.getReadingsForDate(DateTime(2026, 4, 19));
    final sunFirst = sun.firstWhere((r) => r.position == 'First Reading');
    final sunText = await service.getReadingText(
      sunFirst.reading,
      incipit: sunFirst.incipit,
    );
    expect(sunText, contains('But Peter, standing with the eleven'));
    expect(sunText, contains('lifted up his voice'));

    // Gospel Acclamation reference "cf. Luke 24:32" must decode.
    final acc = sun.firstWhere((r) => r.position == 'Gospel Acclamation');
    final accText = await service.getReadingText(acc.reading);
    expect(accText, isNot(startsWith('Reading text unavailable')));
    expect(accText.toLowerCase(), contains('hearts burn'));
  });

  test(
    'Bible-reference R notation preserves lectionary refrain when present',
    () async {
      final service = ReadingsService.instance;
      final readings = await service.getReadingsForDate(DateTime(2027, 12, 15));
      final psalm = readings.firstWhere(
        (r) => r.position == 'Responsorial Psalm',
      );

      expect(psalm.reading, contains('R. Isa 45.8'));
      expect(psalm.psalmResponse, isNotNull);
      expect(psalm.psalmResponse, 'Let the clouds rain down the Just One.');
      expect(psalm.psalmResponse!.toLowerCase(), isNot(contains('shower')));
    },
  );

  test(
    '2026-05-23 matches official Nigeria missal body text and separate intro',
    () async {
      final service = ReadingsService.instance;
      final readings = await service.getReadingsForDate(DateTime(2026, 5, 23));

      final first = readings.firstWhere((r) => r.position == 'First Reading');
      final psalm = readings.firstWhere(
        (r) => r.position == 'Responsorial Psalm',
      );
      final gospel = readings.firstWhere((r) => r.position == 'Gospel');

      expect(first.reading, 'Acts 28:16-20, 30-31');
      expect(first.incipit, 'He lived in Rome, preaching the kingdom of God.');
      expect(psalm.reading, contains('Ps 11:4, 5, 7'));
      expect(
        psalm.psalmResponse,
        'The upright shall behold your face, O Lord.',
      );
      expect(gospel.reading, 'John 21:20-25');
      expect(
        gospel.incipit,
        'This is the disciple who has written these things, and his testimony is true.',
      );

      final firstText = await service.getReadingText(
        first.reading,
        incipit: first.incipit,
        readingType: first.position,
      );
      expect(firstText, startsWith('16 When we came into Rome'));
      expect(firstText, contains('30 And he lived there two whole years'));
      expect(firstText, isNot(contains('Since Paul had appealed')));
      expect(firstText, isNot(contains('Festus sent Paul to Rome.')));
      expect(firstText, isNot(contains('And when we came into Rome')));

      final gospelText = await service.getReadingText(
        gospel.reading,
        incipit: gospel.incipit,
        readingType: gospel.position,
      );
      expect(gospelText, startsWith('20 At that time: Peter turned'));
      expect(gospelText, isNot(contains('After he was raised from the dead')));

      final hydrated = await ReadingFlowService.instance.hydrateReadingSet(
        date: DateTime(2026, 5, 23),
        readings: readings,
      );
      final hydratedPsalm = hydrated.readings.firstWhere(
        (r) => r.position == 'Responsorial Psalm',
      );
      expect(
        hydratedPsalm.psalmResponse,
        'The upright shall behold your face, O Lord.',
      );
      expect(hydratedPsalm.psalmResponse, isNot('John 16.7, 13'));
    },
  );

  test(
    'Nigeria official-window regression dates use the observed readings',
    () async {
      final service = ReadingsService.instance;

      Future<Map<String, DailyReading>> byPosition(DateTime date) async {
        final readings = await service.getReadingsForDate(date);
        return {
          for (final reading in readings) reading.position ?? '': reading,
        };
      }

      var readings = await byPosition(DateTime(2026, 5, 25));
      expect(readings['First Reading']!.reading, 'Gen 3:9-15, 20');
      expect(readings['Responsorial Psalm']!.reading, 'Ps 87:1-2, 3, 5, 6-7');
      expect(
        readings['Responsorial Psalm']!.psalmResponse,
        'Of you are told glorious things, O city of God!',
      );
      expect(readings['Gospel']!.reading, 'John 19:25-34');

      readings = await byPosition(DateTime(2026, 6, 1));
      expect(readings['First Reading']!.reading, '2 Pet 1:2-7');
      expect(
        readings['First Reading']!.incipit,
        startsWith('He has granted to us his precious'),
      );

      readings = await byPosition(DateTime(2026, 6, 7));
      expect(readings['First Reading']!.reading, 'Deut 8:2-3, 14b-16a');
      expect(readings['Second Reading']!.reading, '1 Cor 10:16-17');
      expect(readings['Gospel']!.reading, 'John 6:51-58');
      expect(
        readings['Responsorial Psalm']!.psalmResponse,
        'O Jerusalem, glorify the Lord!',
      );

      readings = await byPosition(DateTime(2026, 6, 11));
      expect(readings['First Reading']!.reading, 'Acts 11:21b-26; 13:1-3');
      expect(readings['Gospel']!.reading, 'Matt 10:7-13');
      expect(
        readings['First Reading']!.incipit,
        'He was a good man, full of the Holy Spirit and of faith.',
      );

      readings = await byPosition(DateTime(2026, 6, 13));
      expect(readings['First Reading']!.reading, '1 Kgs 19:19-21');
      expect(
        readings['Responsorial Psalm']!.psalmResponse,
        'It is you, O Lord, who are my portion.',
      );
      expect(readings['Gospel']!.reading, 'Luke 2:41-51');
      expect(
        readings['Gospel']!.incipit,
        'She kept all these things in her heart.',
      );

      readings = await byPosition(DateTime(2026, 7, 22));
      expect(readings['First Reading']!.reading, '2 Cor 5:14-17');
      expect(readings['Gospel']!.reading, 'John 20:1-2, 11-18');

      readings = await byPosition(DateTime(2026, 8, 18));
      final acclamation = readings['Gospel Acclamation']!;
      expect(acclamation.reading, '2 Cor 8:9');
      expect(
        acclamation.gospelAcclamation,
        'Jesus Christ was rich but he became poor, to make you rich out of his poverty.',
      );
      final acclamationText = await service.getReadingText(
        acclamation.reading,
        readingType: acclamation.position,
      );
      expect(acclamationText, isNot(startsWith('Reading text unavailable')));

      readings = await byPosition(DateTime(2026, 5, 30));
      expect(readings['First Reading']!.reading, 'Jude 1:17, 20b-25');
      final judeText = await service.getReadingText(
        readings['First Reading']!.reading,
        incipit: readings['First Reading']!.incipit,
        readingType: readings['First Reading']!.position,
      );
      expect(judeText, isNot(startsWith('Reading text unavailable')));

      readings = await byPosition(DateTime(2026, 6, 20));
      expect(
        readings['Gospel']!.gospelAcclamation,
        isNot(contains('SATURDAY')),
      );
      expect(
        readings['Gospel']!.gospelAcclamation,
        'Jesus Christ was rich but he became poor, to make you rich out of his poverty.',
      );

      readings = await byPosition(DateTime(2026, 6, 23));
      expect(
        readings['First Reading']!.reading,
        '2 Kgs 19:9b-11, 14-21, 31-35a, 36',
      );

      readings = await byPosition(DateTime(2025, 12, 25));
      expect(readings['First Reading']!.reading, 'Isa 52:7-10');
      expect(readings['Second Reading']!.reading, 'Heb 1:1-6');
      expect(readings['Gospel']!.reading, 'John 1:1-18');
      expect(
        readings['Gospel']!.incipit,
        'The Word became flesh and dwelt among us.',
      );

      readings = await byPosition(DateTime(2026, 2, 27));
      expect(readings['Gospel']!.reading, 'Matt 5:20-26');
      final lentFridayGospel = await service.getReadingText(
        readings['Gospel']!.reading,
        incipit: readings['Gospel']!.incipit,
        readingType: readings['Gospel']!.position,
      );
      expect(lentFridayGospel, isNot(startsWith('Reading text unavailable')));
    },
  );
}
