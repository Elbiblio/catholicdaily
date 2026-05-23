import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/ui/widgets/premium_browse/todays_saint_card.dart';

void main() {
  testWidgets('tapping a saint row invokes the celebration callback', (
    tester,
  ) async {
    const celebration = OptionalCelebration(
      id: 'rita_of_cascia',
      title: 'Saint Rita of Cascia, Religious',
      rank: CelebrationRank.optionalMemorial,
      color: LiturgicalColor.white,
      month: 5,
      day: 22,
      commonType: 'Religious',
    );

    OptionalCelebration? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodaysSaintCard(
            celebrations: const [celebration],
            liturgicalDay: null,
            onCelebrationTap: (value) => tapped = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Saint Rita of Cascia, Religious'));
    await tester.pump();

    expect(tapped?.id, 'rita_of_cascia');
  });
}
