import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/ui/widgets/premium_browse/daily_mass_at_a_glance_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offers the Mass and reading actions on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reading = DailyReading(
      reading: 'John 1:1-5',
      date: DateTime(2026, 10, 28),
    );
    var beganMass = false;
    DailyReading? selectedReading;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: DailyMassAtAGlanceCard(
              liturgicalDay: null,
              readingGroups: [(baseType: 'Gospel', mainReading: reading)],
              onBeginMass: () => beganMass = true,
              onReadingRowTap: (_, selected) => selectedReading = selected,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Daily Mass'), findsOneWidget);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Begin Mass')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Begin Mass'));
    await tester.tap(find.text('John 1:1-5'));
    expect(beganMass, isTrue);
    expect(selectedReading, same(reading));
  });
}
