import 'package:catholic_daily/ui/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('onboarding introduction remains overflow-free in a short view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.binding.setSurfaceSize(const Size(320, 380));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: OnboardingScreen(onComplete: _onComplete)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

void _onComplete() {}
