import 'dart:math';

import 'package:catholic_daily/data/models/liturgical_region.dart';

const comprehensiveAuditRegions = <LiturgicalRegion>[
  LiturgicalRegion.generalRoman,
  LiturgicalRegion.unitedStates,
  LiturgicalRegion.unitedStatesAscensionThursday,
  LiturgicalRegion.englandWales,
  LiturgicalRegion.nigeria,
];

final comprehensiveAuditSeedDates = <DateTime>[
  DateTime(2026, 7, 15),
  DateTime(2026, 8, 15),
  DateTime(2026, 10, 1),
  DateTime(2026, 11, 1),
  DateTime(2026, 12, 8),
  DateTime(2027, 2, 17),
  DateTime(2027, 3, 19),
  DateTime(2027, 3, 25),
  DateTime(2027, 5, 13),
  DateTime(2027, 5, 16),
  DateTime(2027, 6, 6),
  DateTime(2028, 4, 16),
  DateTime(2028, 6, 24),
  DateTime(2029, 7, 3),
  DateTime(2030, 12, 25),
];

final comprehensiveAuditDates = _buildAuditDates();

List<DateTime> _buildAuditDates() {
  final dates = <DateTime>{...comprehensiveAuditSeedDates};
  final random = Random(20260712);

  while (dates.length < 75) {
    final year = 2027 + random.nextInt(6);
    final month = 1 + random.nextInt(12);
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = 1 + random.nextInt(maxDay);
    dates.add(DateTime(year, month, day));
  }

  final sorted = dates.toList()..sort((a, b) => a.compareTo(b));
  return List.unmodifiable(sorted);
}

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
