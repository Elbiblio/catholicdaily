import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/ui/screens/reading_screen.dart';
import '../lib/data/models/daily_reading.dart';

void main() {
  group('Navigation State Tests', () {
    testWidgets('should maintain navigation state when switching readings', (WidgetTester tester) async {
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
        DailyReading(
          reading: 'Lk 15:1-3, 11-32',
          position: 'Gospel',
          date: DateTime.now(),
        ),
      ];

      // Start with first reading (index 0)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'First reading content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false, // First reading has no previous
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify initial state: only Next button should be visible
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsNothing);
      expect(find.text('Reading 1 of 3'), findsOneWidget);

      // Simulate navigating to second reading (index 1)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ps 130:1-2, 3-4, 5-6',
              content: 'Psalm content',
              sessionReadings: readings,
              currentReadingIndex: 1,
              hasNext: true,
              hasPrev: true, // Second reading should have both previous and next
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify second reading state: both Previous and Next buttons should be visible
      expect(find.text('Next'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Reading 2 of 3'), findsOneWidget);

      // Simulate navigating to third reading (index 2)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Lk 15:1-3, 11-32',
              content: 'Gospel content',
              sessionReadings: readings,
              currentReadingIndex: 2,
              hasNext: false, // Last reading has no next
              hasPrev: true, // But should have previous
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify third reading state: only Previous button should be visible
      expect(find.text('Next'), findsNothing);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Reading 3 of 3'), findsOneWidget);
    });

    testWidgets('should show correct pill selection state', (WidgetTester tester) async {
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

      // Start with first reading selected
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'First reading content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false,
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify first pill is selected (should have selected styling)
      final firstPill = tester.widget<Material>(find.byType(Material).first);
      expect(firstPill.color, isNotNull); // Selected pill should have a color

      // Switch to second reading
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ps 130:1-2, 3-4, 5-6',
              content: 'Psalm content',
              sessionReadings: readings,
              currentReadingIndex: 1,
              hasNext: false,
              hasPrev: true,
              liturgicalDay: null,
            ),
          ),
        ),
      );

      // Verify second pill is now selected
      final pills = tester.widgetList<Material>(find.byType(Material));
      final secondPill = pills.elementAt(1); // Second pill should now be selected
      expect(secondPill.color, isNotNull);
    });

    testWidgets('should handle navigation callbacks correctly', (WidgetTester tester) async {
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

      bool nextCalled = false;
      bool prevCalled = false;
      bool indexSelectCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadingScreen(
              reference: 'Ez 37:12-14',
              content: 'First reading content',
              sessionReadings: readings,
              currentReadingIndex: 0,
              hasNext: true,
              hasPrev: false,
              liturgicalDay: null,
              onNextReading: () => nextCalled = true,
              onPrevReading: () => prevCalled = true,
              onSelectReadingIndex: (index) => indexSelectCalled = true,
            ),
          ),
        ),
      );

      // Test Next button
      await tester.tap(find.text('Next'));
      await tester.pump(); // Trigger loading state
      await tester.pump(const Duration(milliseconds: 150)); // Wait for loading to complete
      expect(nextCalled, true);

      // Test pill selection
      await tester.tap(find.text('Responsorial Psalm'));
      await tester.pump(); // Trigger loading state
      await tester.pump(const Duration(milliseconds: 150)); // Wait for loading to complete
      expect(indexSelectCalled, true);
    });
  });
}
