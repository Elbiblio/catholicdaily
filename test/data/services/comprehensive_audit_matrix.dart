import 'package:catholic_daily/data/models/liturgical_region.dart';

const comprehensiveAuditRegions = <LiturgicalRegion>[
  LiturgicalRegion.generalRoman,
  LiturgicalRegion.unitedStates,
  LiturgicalRegion.unitedStatesAscensionThursday,
  LiturgicalRegion.englandWales,
  LiturgicalRegion.nigeria,
];

final _comprehensiveAuditSeedDates = List<DateTime>.unmodifiable(<DateTime>[
  DateTime(2026, 7, 15),
  DateTime(2026, 8, 15),
  DateTime(2026, 10, 1),
  DateTime(2026, 11, 1),
  DateTime(2026, 12, 8),
]);

final comprehensiveAuditDates = List<DateTime>.unmodifiable(<DateTime>[
  ..._comprehensiveAuditSeedDates,
  DateTime(2027, 1, 6),
  DateTime(2027, 2, 2),
  DateTime(2027, 2, 17),
  DateTime(2027, 3, 19),
  DateTime(2027, 3, 25),
  DateTime(2027, 4, 4),
  DateTime(2027, 5, 13),
  DateTime(2027, 5, 16),
  DateTime(2027, 6, 6),
  DateTime(2027, 6, 24),
  DateTime(2027, 7, 22),
  DateTime(2027, 8, 15),
  DateTime(2027, 9, 14),
  DateTime(2027, 11, 1),
  DateTime(2027, 12, 8),
  DateTime(2027, 12, 25),
  DateTime(2028, 1, 1),
  DateTime(2028, 2, 14),
  DateTime(2028, 3, 19),
  DateTime(2028, 4, 16),
  DateTime(2028, 5, 25),
  DateTime(2028, 6, 24),
  DateTime(2028, 6, 29),
  DateTime(2028, 7, 3),
  DateTime(2028, 8, 6),
  DateTime(2028, 9, 8),
  DateTime(2028, 10, 18),
  DateTime(2028, 11, 2),
  DateTime(2028, 12, 12),
  DateTime(2029, 1, 13),
  DateTime(2029, 2, 14),
  DateTime(2029, 3, 19),
  DateTime(2029, 3, 25),
  DateTime(2029, 4, 1),
  DateTime(2029, 5, 10),
  DateTime(2029, 6, 8),
  DateTime(2029, 7, 3),
  DateTime(2029, 8, 15),
  DateTime(2029, 9, 29),
  DateTime(2029, 11, 9),
  DateTime(2029, 12, 25),
  DateTime(2030, 1, 6),
  DateTime(2030, 2, 22),
  DateTime(2030, 3, 6),
  DateTime(2030, 3, 25),
  DateTime(2030, 4, 21),
  DateTime(2030, 5, 30),
  DateTime(2030, 6, 9),
  DateTime(2030, 6, 29),
  DateTime(2030, 8, 15),
  DateTime(2030, 9, 14),
  DateTime(2030, 10, 1),
  DateTime(2030, 11, 30),
  DateTime(2030, 12, 8),
  DateTime(2030, 12, 25),
  DateTime(2031, 1, 1),
  DateTime(2031, 2, 17),
  DateTime(2031, 3, 19),
  DateTime(2031, 4, 13),
  DateTime(2031, 5, 22),
  DateTime(2031, 6, 1),
  DateTime(2031, 8, 15),
  DateTime(2031, 10, 4),
  DateTime(2031, 11, 1),
  DateTime(2031, 12, 25),
  DateTime(2032, 1, 6),
  DateTime(2032, 2, 11),
  DateTime(2032, 3, 25),
  DateTime(2032, 5, 9),
  DateTime(2032, 12, 8),
]);

String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

enum AuditFailureKind {
  calendar,
  reference,
  priority,
  cycle,
  region,
  textMissing,
  textVersion,
  incipit,
  psalmResponse,
  ui,
}

class ResolverAuditFailure {
  final DateTime date;
  final LiturgicalRegion region;
  final AuditFailureKind kind;
  final String message;

  const ResolverAuditFailure({
    required this.date,
    required this.region,
    required this.kind,
    required this.message,
  });

  @override
  String toString() => '${isoDate(date)} ${region.code} ${kind.name}: $message';
}
