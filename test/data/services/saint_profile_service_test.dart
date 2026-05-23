import 'package:flutter_test/flutter_test.dart';

import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/saint_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads curated profile for a celebration id', () async {
    const celebration = OptionalCelebration(
      id: 'bede_the_venerable',
      title: 'Saint Bede the Venerable, Priest and Doctor of the Church',
      rank: CelebrationRank.optionalMemorial,
      color: LiturgicalColor.white,
      month: 5,
      day: 25,
      commonType: 'DoctorsOfTheChurch',
    );

    final profile = await SaintProfileService.instance.findForCelebration(
      celebration,
    );

    expect(profile, isNotNull);
    expect(profile!.name, 'Saint Bede the Venerable');
    expect(profile.lifeLength, 'about 62 years');
    expect(profile.wikipediaUrl, contains('wikipedia.org'));
    expect(profile.patronage, contains('scholars'));
  });

  test('normalizes celebration titles for fallback matching', () {
    expect(
      SaintProfileService.normalizeTitle(
        'Saint Bede the Venerable, Priest and Doctor of the Church',
      ),
      SaintProfileService.normalizeTitle('Bede the Venerable'),
    );
  });
}
