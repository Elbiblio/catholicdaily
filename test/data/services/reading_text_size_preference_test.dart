import 'package:catholic_daily/data/services/reading_text_size_preference.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    ReadingTextSizePreference.resetForTest();
  });

  test('defaults to Standard', () async {
    final preference = await ReadingTextSizePreference.getInstance();

    expect(preference.currentSize, ReadingTextSize.standard);
    expect(preference.scale, 1.0);
  });

  test('persists a selected size and notifies listeners', () async {
    final preference = await ReadingTextSizePreference.getInstance();
    var notifications = 0;
    preference.addListener(() => notifications++);

    await preference.setSize(ReadingTextSize.large);
    ReadingTextSizePreference.resetForTest();
    final restored = await ReadingTextSizePreference.getInstance();

    expect(notifications, 1);
    expect(restored.currentSize, ReadingTextSize.large);
    expect(restored.scale, 1.3);
  });

  test('recovers unsupported stored values to Standard', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ReadingTextSizePreference.storageKey: 'giant',
    });

    final preference = await ReadingTextSizePreference.getInstance();

    expect(preference.currentSize, ReadingTextSize.standard);
  });

  test('does not notify when the selected size is unchanged', () async {
    final preference = await ReadingTextSizePreference.getInstance();
    var notifications = 0;
    preference.addListener(() => notifications++);

    await preference.setSize(ReadingTextSize.standard);

    expect(notifications, 0);
  });

  test('coalesces concurrent initialization into one notifier', () async {
    final firstFuture = ReadingTextSizePreference.getInstance();
    final secondFuture = ReadingTextSizePreference.getInstance();

    final first = await firstFuture;
    final second = await secondFuture;

    expect(identical(first, second), isTrue);
  });
}
