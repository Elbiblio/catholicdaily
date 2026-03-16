import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/services/ordo_resolver_service.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  late Directory tempDocsDir;
  late void Function() cleanupMocks;

  setUpAll(() async {
    tempDocsDir = await createTempTestDir('catholic_daily_major_celebrations_');
    cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);
  });

  tearDownAll(() {
    cleanupMocks();
    cleanupTempDir(tempDocsDir);
  });

  test('export major celebration refs', () async {
    OrdoResolverService.instance.setPreferOffline(true);
    final backend = ReadingsBackendIo();
    final ordo = OrdoResolverService.instance;
    final outFile = File(
      r'c:\dev\catholicdaily-flutter\scripts\major_celebration_refs.json',
    );

    final targets = <String>{
      'Mary, the Holy Mother of God',
      'The Epiphany of the Lord',
      'The Baptism of the Lord',
      'Saint Joseph, Spouse of the Blessed Virgin Mary',
      'The Annunciation of the Lord',
      'Palm Sunday of the Passion of the Lord',
      'Holy Thursday - Evening Mass of the Lord\'s Supper',
      'Friday of the Passion of the Lord',
      'Holy Saturday',
      'Easter Sunday of the Resurrection of the Lord',
      'Second Sunday of Easter (Divine Mercy)',
      'Pentecost Sunday',
      'The Most Holy Trinity',
      'The Most Holy Body and Blood of Christ',
      'The Most Sacred Heart of Jesus',
      'The Immaculate Heart of the Blessed Virgin Mary',
      'The Nativity of Saint John the Baptist',
      'Saints Peter and Paul, Apostles',
      'The Assumption of the Blessed Virgin Mary',
      'All Saints',
      'The Commemoration of All the Faithful Departed',
      'The Immaculate Conception of the Blessed Virgin Mary',
      'Our Lord Jesus Christ, King of the Universe',
      'The Nativity of the Lord',
    };

    final resolved = <String, Map<String, dynamic>>{};

    for (
      var date = DateTime(2024, 1, 1);
      !date.isAfter(DateTime(2027, 12, 31));
      date = date.add(const Duration(days: 1))
    ) {
      final day = await ordo.resolveDay(date);
      if (!targets.contains(day.title)) {
        continue;
      }

      final readings = await backend.getReadingsForDate(date);
      if (readings.isEmpty) {
        continue;
      }

      final recordKey = '${date.year}-${date.month}-${date.day}-${day.title}';
      resolved[recordKey] = {
        'date': date.toIso8601String(),
        'title': day.title,
        'rank': day.rank,
        'season': day.season.toString().split('.').last,
        'week_number': day.weekNumber,
        'readings': readings
            .map(
              (reading) => {
                'position': reading.position,
                'reading': reading.reading,
                'psalm_response': reading.psalmResponse,
                'gospel_acclamation': reading.gospelAcclamation,
              },
            )
            .toList(),
      };
    }

    final sorted = resolved.values.toList()
      ..sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );
    await outFile.writeAsString(const JsonEncoder.withIndent('  ').convert(sorted));

    print('Resolved major celebrations: ${sorted.length}');
    print('Wrote: ${outFile.path}');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
