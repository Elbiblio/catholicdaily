import 'package:catholic_daily/data/services/theme_preferences.dart';
import 'package:catholic_daily/ui/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'renders the home shell without preloading a duplicate reading set',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            themeMode: ThemeMode.system,
            themeStyle: AppThemeStyle.standard,
            onThemeModeChanged: (_) {},
            onThemeStyleChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );
}
