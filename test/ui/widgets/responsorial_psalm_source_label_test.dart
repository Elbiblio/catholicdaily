import 'package:catholic_daily/data/models/resolved_responsorial_psalm.dart';
import 'package:catholic_daily/ui/widgets/responsorial_psalm_source_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reading labels the actual fallback edition', (tester) async {
    const resolution = ResolvedResponsorialPsalm(
      text: 'Psalm text',
      responseText: 'Response',
      requestedEditionId: 'modern_psalter_us',
      actualEditionId: 'local_nabre',
      actualEditionName: 'NABRE',
      referenceNormalized: 'ps45:10,11,12,16',
      fallbackReason: PsalmFallbackReason.selectedEditionMissing,
      sourceUrl: 'repo://assets/nabre.db',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsorialPsalmSourceLabel(resolution: resolution),
        ),
      ),
    );
    expect(
      find.text('NABRE fallback — selected edition unavailable for this psalm'),
      findsOneWidget,
    );
  });
}
