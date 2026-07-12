import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(() => cleanup());

  test(
    'switching RSVCE to NABRE changes rendered verse text without changing reference',
    () async {
      final pref = await BibleVersionPreference.getInstance();
      final service = ReadingsService.instance;

      await pref.setVersion(BibleVersionType.rsvce);
      final rsvceText = await service.getReadingText('John 3:16');

      await pref.setVersion(BibleVersionType.nabre);
      await service.reloadForVersionChange();
      final nabreText = await service.getReadingText('John 3:16');

      expect(rsvceText, isNot(contains('Reading text unavailable')));
      expect(nabreText, isNot(contains('Reading text unavailable')));
      expect(rsvceText, isNot(equals(nabreText)));
    },
  );
}
