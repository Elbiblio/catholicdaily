import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/ui/screens/reading_screen.dart';
import '../lib/data/models/daily_reading.dart';

void main() {
  group('Reading UI Optimization Tests', () {
    testWidgets('should display pills with reduced height', (WidgetTester tester) async {
      final readings = [
        DailyReading(
          reading: 'Ez 37:12-14',
          position: 'First Reading',
          date: DateTime.now(),
        ),
        DailyReading(
          reading: 'Ps 130:1-2, 3-4, 5-6',
          position: 'Responsorial Psalm',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'Test content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false,
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Find the variant switcher container specifically
      final variantSwitcherFinder = find.byWidgetPredicate((widget) {
        if (widget is SizedBox) {
          // Look for the SizedBox with height 80 that contains the ListView
          return widget.height == 80.0;
        }
        return false;
      });
      
      // Verify the height is reduced to 80
      expect(variantSwitcherFinder, findsOneWidget);
    });

    testWidgets('should show navigation when multiple readings exist', (WidgetTester tester) async {
      final readings = [
        DailyReading(
          reading: 'Ez 37:12-14',
          position: 'First Reading',
          date: DateTime.now(),
        ),
        DailyReading(
          reading: 'Ps 130:1-2, 3-4, 5-6',
          position: 'Responsorial Psalm',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'Test content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false,
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify navigation buttons are present
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Reading 1 of 2'), findsOneWidget);
    });

    testWidgets('should show loading state during navigation', (WidgetTester tester) async {
      bool nextCalled = false;
      
      final readings = [
        DailyReading(
          reading: 'Ez 37:12-14',
          position: 'First Reading',
          date: DateTime.now(),
        ),
        DailyReading(
          reading: 'Ps 130:1-2, 3-4, 5-6',
          position: 'Responsorial Psalm',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'Test content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false,
              liturgicalDay: null,
              onNextReading: () {
                nextCalled = true;
              },
            ),
          ),
        ),
      );

      // Tap the Next button
      await tester.tap(find.text('Next'));
      await tester.pump();

      // Verify loading state appears (there might be multiple Loading texts)
      expect(find.text('Loading...'), findsAtLeastNWidgets(1));
      
      // Wait for the delay to complete
      await tester.pump(const Duration(milliseconds: 150));
      
      // Verify the callback was called
      expect(nextCalled, isTrue);
    });

    testWidgets('should not show navigation for single reading', (WidgetTester tester) async {
      final readings = [
        DailyReading(
          reading: 'Ez 37:12-14',
          position: 'First Reading',
          date: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'Test content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: false,
              hasPrev: false,
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify navigation buttons are not present
      expect(find.text('Next'), findsNothing);
      expect(find.text('Previous'), findsNothing);
    });
  });
}
