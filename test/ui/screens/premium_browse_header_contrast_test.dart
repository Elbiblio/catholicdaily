import 'package:catholic_daily/ui/screens/premium_browse_screen.dart';
import 'package:catholic_daily/ui/utils/contrast_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);

  testWidgets('liturgical header contrasts with its gradient in both themes', (
    tester,
  ) async {
    Widget app(Brightness brightness) => MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff8c1d2f),
          brightness: brightness,
        ),
        useMaterial3: true,
      ),
      home: PremiumBrowseScreen(
        initialDate: DateTime(2026, 8, 17),
        onReadingSelected: (_, __, ___, [____, _____, ______]) {},
      ),
    );
    await tester.pumpWidget(app(Brightness.light));
    final title = find.text('20th Week of Ordinary Time');
    for (var i = 0; i < 50 && title.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(title, findsOneWidget);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(app(brightness));
      await tester.pump();
      final text = tester.widget<Text>(title);
      final gradient = tester
          .widgetList<Container>(
            find.ancestor(of: title, matching: find.byType(Container)),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.gradient)
          .whereType<LinearGradient>()
          .first;
      for (final color in gradient.colors) {
        expect(
          ContrastHelper.hasSufficientContrast(text.style!.color!, color),
          isTrue,
          reason:
              'Header title must remain legible over the painted gradient in $brightness',
        );
      }
    }
  });
}
