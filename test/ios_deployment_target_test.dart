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
    expect(workflow, contains('ensure_ios_push_profile.py'));
    expect(workflow, contains('test_ensure_ios_push_profile.py'));
    expect(workflow, contains('python3 -m venv'));
    expect(workflow, isNot(contains('pip install --user')));
    expect(podfile, contains("platform :ios, '15.0'"));
    expect(podfile, contains('use_modular_headers!'));
    expect(
      podfile,
      contains("config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'"),
    );
  });

  test('CI creates and stores a missing notification extension profile', () {
    final workflow = File('.github/workflows/mobile.yml').readAsStringSync();

    expect(
      workflow,
      contains(
        '--bundle-identifier "\${{ env.IOS_EXTENSION_BUNDLE_IDENTIFIER }}"',
      ),
    );
    expect(
      workflow,
      contains(
        '"s3://\${{ env.R2_BUCKET_NAME }}/\${{ env.IOS_EXTENSION_PROVISION_PROFILE_OBJECT_KEY }}"',
      ),
    );
    expect(
      workflow,
      contains('Created the notification extension provisioning profile.'),
    );
    expect(workflow, contains('--create-bundle-id-if-missing'));
    expect(
      workflow,
      contains('--bundle-name "Catholic Daily Feast Reminder"'),
    );
  });
}
