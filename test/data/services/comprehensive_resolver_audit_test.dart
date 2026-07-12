import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:flutter_test/flutter_test.dart';

import 'comprehensive_audit_matrix.dart';

void main() {
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
  });
}
