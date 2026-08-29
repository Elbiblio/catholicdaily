import 'package:catholic_daily/data/models/daily_reading.dart';
import 'package:catholic_daily/ui/widgets/gospel_acclamation_widget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'display resolver preserves an already displayed acclamation verse',
    () async {
      const displayed =
          'I am the light of the world, says the Lord; whoever follows me will have the light of life.';
      final result = await resolveDisplayedGospelAcclamation(
        DailyReading(
          reading: 'Jn 8:12',
          position: 'Gospel',
          date: DateTime(2026, 8, 29),
          gospelAcclamation: displayed,
        ),
        DateTime(2026, 8, 29),
      );

      expect(result, displayed);
    },
  );
}
