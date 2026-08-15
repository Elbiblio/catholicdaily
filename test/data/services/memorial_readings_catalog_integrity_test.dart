import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/reading_reference_parser.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();

  test(
    'every populated memorial reading field contains the correct data type',
    () async {
      final rows = await ReadingCatalogService.instance.loadMemorialEntries();
      final problems = <String>[];

      for (final row in rows) {
        _expectReference(row.id, 'firstReading', row.firstReading, problems);
        _expectReference(
          row.id,
          'alternativeFirstReading',
          row.alternativeFirstReading,
          problems,
        );
        _expectReference(
          row.id,
          'psalmReference',
          row.psalmReference,
          problems,
        );
        _expectReference(row.id, 'secondReading', row.secondReading, problems);
        _expectGospel(row.id, 'gospel', row.gospel, problems);
        _expectGospel(
          row.id,
          'alternativeGospel',
          row.alternativeGospel,
          problems,
        );

        if (row.alternativeFirstReading.isNotEmpty &&
            row.alternativeFirstReading == row.firstReading) {
          problems.add('${row.id}.alternativeFirstReading duplicates primary');
        }
        if (row.alternativeGospel.isNotEmpty &&
            row.alternativeGospel == row.gospel) {
          problems.add('${row.id}.alternativeGospel duplicates primary');
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    },
  );
}

void _expectReference(
  String id,
  String field,
  String value,
  List<String> problems,
) {
  if (value.isEmpty) return;
  if (ReadingReferenceParser.parse(value).isEmpty) {
    problems.add('$id.$field is not a Scripture reference: "$value"');
  }
}

void _expectGospel(
  String id,
  String field,
  String value,
  List<String> problems,
) {
  if (value.isEmpty) return;
  final ranges = ReadingReferenceParser.parse(value);
  if (ranges.isEmpty ||
      ranges.any(
        (range) => !const <String>{
          'matt',
          'mark',
          'luke',
          'john',
        }.contains(ReadingReferenceParser.normalizeBookKey(range.book)),
      )) {
    problems.add('$id.$field is not a Gospel reference: "$value"');
  }
}
