import 'package:catholic_daily/data/services/android_feast_reminder_occurrence_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(
    'com.elbiblio.catholicdaily/feast_reminder_occurrence_store',
  );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('Android platform failure is explicitly unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'store-offline'),
        );

    expect(
      AndroidFeastReminderOccurrenceStore.instance.claimedOccurrenceKeys(),
      throwsA(isA<FeastReminderOccurrenceStoreUnavailable>()),
    );
  });

  test('malformed native claimed-key response is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, Object>{});

    expect(
      AndroidFeastReminderOccurrenceStore.instance.claimedOccurrenceKeys(),
      throwsA(isA<FeastReminderOccurrenceStoreUnavailable>()),
    );
  });

  test('missing Android plugin is explicitly unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);

    expect(
      AndroidFeastReminderOccurrenceStore.instance.claimedOccurrenceKeys(),
      throwsA(isA<FeastReminderOccurrenceStoreUnavailable>()),
    );
  });

  test('non-Android legitimately has no native claims', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(
      await AndroidFeastReminderOccurrenceStore.instance
          .claimedOccurrenceKeys(),
      isEmpty,
    );
  });
}
