import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS and CI consistently require the FlutterFire minimum of iOS 15', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final frameworkInfo = File('ios/Flutter/AppFrameworkInfo.plist').readAsStringSync();
    final workflow = File('.github/workflows/mobile.yml').readAsStringSync();
    final podfile = File('ios/Podfile').readAsStringSync();

    expect(
      RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = 15\.0;').allMatches(project).length,
      greaterThanOrEqualTo(3),
    );
    expect(project, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 14.0;')));
    expect(
      frameworkInfo,
      matches(
        RegExp(
          r'<key>MinimumOSVersion</key>\s*<string>15\.0</string>',
        ),
      ),
    );
    expect(workflow, contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0'));
    expect(workflow, isNot(contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0')));
    expect(podfile, contains("platform :ios, '15.0'"));
    expect(podfile, contains('use_modular_headers!'));
    expect(
      podfile,
      contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'"),
    );
  });
}
