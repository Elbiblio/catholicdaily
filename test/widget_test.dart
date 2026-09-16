import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:catholic_daily/app_startup_maintenance.dart';
import 'package:catholic_daily/demo_launch_config.dart';
import 'package:catholic_daily/main.dart';

void main() {
  testWidgets('renders before delayed maintenance completes', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final maintenanceGate = Completer<void>();

    await tester.pumpWidget(
      CatholicDailyApp(
        demoLaunchConfig: const DemoLaunchConfig(
          screen: DemoLaunchScreen.home,
          date: null,
          region: null,
          bibleVersion: null,
        ),
        maintenance: AppStartupMaintenance(() => maintenanceGate.future),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));

    maintenanceGate.complete();
  });
}
