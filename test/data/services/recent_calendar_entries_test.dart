import 'package:catholic_daily/data/services/alternate_readings_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/reading_catalog_service.dart';
import 'package:catholic_daily/data/services/saint_profile_service.dart';
import 'package:catholic_daily/data/services/saint_profile_validator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);

  test('Newman is available on October 9 as an optional memorial', () async {
    final choices = OptionalMemorialService.instance.getAllCelebrationsForDate(
      DateTime(2026, 10, 9),
    );
    final newman = choices.where((c) => c.id == 'john_henry_newman');
    expect(newman, hasLength(1));
    expect(newman.single.rank, CelebrationRank.optionalMemorial);
    expect(newman.single.title, contains('Doctor of the Church'));
    final rows = await ReadingCatalogService.instance
        .getMemorialEntriesForMonthDay(10, 9);
    expect(rows.any((r) => r.id == 'john_henry_newman'), isTrue);
    final sets = await AlternateReadingsService.instance
        .getAvailableReadingSets(DateTime(2026, 10, 9));
    expect(
      sets.any(
        (s) =>
            s.celebration?.id == 'john_henry_newman' && s.readings.isNotEmpty,
      ),
      isTrue,
    );
    expect(sets.first.label, isNot(contains('Newman')));
    final profile = await SaintProfileService.instance.findByCelebrationId(
      'john_henry_newman',
    );
    expect(profile, isNotNull);
    expect(profile!.hasFullGuide, isTrue);
    expect(
      SaintProfileValidator()
          .validateProfile(profile)
          .where((issue) => issue.isError),
      isEmpty,
    );
  });
}
