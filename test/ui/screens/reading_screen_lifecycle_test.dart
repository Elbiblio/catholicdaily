import 'package:catholic_daily/core/latest_request_guard.dart';
import 'package:catholic_daily/ui/screens/reading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('popping a reading invalidates work started by that route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final guard = LatestRequestGuard();
    final generation = guard.begin();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ReadingScreen(
                      reference: 'Jn 1:1',
                      content: 'In the beginning',
                      onRouteDisposed: guard.begin,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(guard.isCurrent(generation), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(guard.isCurrent(generation), isFalse);
  });
}
