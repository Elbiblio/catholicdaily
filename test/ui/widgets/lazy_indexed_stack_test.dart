import 'package:catholic_daily/ui/widgets/lazy_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('builds only the active tab until another tab is selected', (
    tester,
  ) async {
    var firstBuilds = 0;
    var secondBuilds = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          index: 0,
          builders: [
            () {
              firstBuilds++;
              return const Text('First');
            },
            () {
              secondBuilds++;
              return const Text('Second');
            },
          ],
        ),
      ),
    );

    expect(firstBuilds, 1);
    expect(secondBuilds, 0);
    expect(find.text('First'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: LazyIndexedStack(
          index: 1,
          builders: [
            () {
              firstBuilds++;
              return const Text('First');
            },
            () {
              secondBuilds++;
              return const Text('Second');
            },
          ],
        ),
      ),
    );

    expect(firstBuilds, 2);
    expect(secondBuilds, 1);
    expect(find.text('Second'), findsOneWidget);
  });
}
