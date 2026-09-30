import 'package:catholic_daily/data/services/reading_text_size_preference.dart';
import 'package:catholic_daily/ui/widgets/reading_text_size_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ReadingTextSizePreference.resetForTest();
  });

  testWidgets('offers five sizes with live preview and reset', (tester) async {
    final preference = await ReadingTextSizePreference.getInstance();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ReadingTextSizeSheet(preference: preference)),
      ),
    );

    for (final size in ReadingTextSize.values) {
      expect(find.text(size.label), findsOneWidget);
      expect(find.text(size.percentageLabel), findsOneWidget);
    }
    expect(find.text('Reset to Standard'), findsNothing);

    final initialPreview = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reading-text-size-preview')),
    );
    await tester.tap(find.text('Extra large'));
    await tester.pumpAndSettle();

    final enlargedPreview = tester.widget<Text>(
      find.byKey(const ValueKey<String>('reading-text-size-preview')),
    );
    expect(preference.currentSize, ReadingTextSize.extraLarge);
    expect(
      enlargedPreview.style!.fontSize,
      greaterThan(initialPreview.style!.fontSize!),
    );
    expect(find.text('Reset to Standard'), findsOneWidget);

    await tester.tap(find.text('Reset to Standard'));
    await tester.pumpAndSettle();

    expect(preference.currentSize, ReadingTextSize.standard);
    expect(find.text('Reset to Standard'), findsNothing);
  });

  testWidgets('remains usable with large system text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preference = await ReadingTextSizePreference.getInstance();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(body: ReadingTextSizeSheet(preference: preference)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reading Text Size'), findsOneWidget);
    expect(
      tester.getSize(find.byType(RadioListTile<ReadingTextSize>).first).height,
      greaterThanOrEqualTo(48),
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Extra large'), findsOneWidget);
  });
}
