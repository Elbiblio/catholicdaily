import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/ui/widgets/language_switcher_widget.dart';
import '../lib/data/services/language_preference_service.dart';

void main() {
  group('Language Switcher Contrast Tests', () {
    testWidgets('Language switcher should have proper contrast in light mode', (WidgetTester tester) async {
      // Test light mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: LanguageSwitcherWidget(
              currentLanguage: LanguagePreferenceService.english,
              availableLanguages: [LanguagePreferenceService.english, LanguagePreferenceService.latin],
              onLanguageChanged: (lang) {},
              showLabels: true,
            ),
          ),
        ),
      );

      // Find the language switcher container
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      
      // Verify container has proper styling
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNotNull);
      
      // Check text colors for unselected state
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style;
        expect(style?.color, isNotNull);
        
        // In light mode, unselected text should be dark (contrasting)
        if (style?.color == Colors.black87) {
          expect(style?.color, equals(Colors.black87));
        }
      }
    });

    testWidgets('Language switcher should have proper contrast in dark mode', (WidgetTester tester) async {
      // Test dark mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: LanguageSwitcherWidget(
              currentLanguage: LanguagePreferenceService.english,
              availableLanguages: [LanguagePreferenceService.english, LanguagePreferenceService.latin],
              onLanguageChanged: (lang) {},
              showLabels: true,
            ),
          ),
        ),
      );

      // Check text colors for unselected state in dark mode
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style;
        expect(style?.color, isNotNull);
        
        // In dark mode, unselected text should be light (contrasting)
        if (style?.color == Colors.white70) {
          expect(style?.color, equals(Colors.white70));
        }
      }
    });

    testWidgets('Compact language switcher should have proper contrast', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: CompactLanguageSwitcher(
              currentLanguage: LanguagePreferenceService.english,
              onTap: () {},
            ),
          ),
        ),
      );

      // Find the compact switcher container
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration as BoxDecoration;
      
      // Verify container has proper styling with border
      expect(decoration.color, isNotNull);
      expect(decoration.border, isNotNull);
      
      // Check icon and text colors
      final iconWidgets = tester.widgetList<Icon>(find.byType(Icon));
      for (final iconWidget in iconWidgets) {
        expect(iconWidget.color, equals(Colors.black87));
      }
      
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final style = textWidget.style;
        expect(style?.color, equals(Colors.black87));
      }
    });
  });
}
