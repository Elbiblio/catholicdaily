import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final themePreferences = await ThemePreferences.getInstance();

    await tester.pumpWidget(CatholicDailyApp(themePreferences: themePreferences));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
  });
}
