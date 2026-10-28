import 'package:catholic_daily/data/models/liturgical_region.dart';
import 'package:catholic_daily/data/services/liturgical_region_preference_service.dart';
import 'package:catholic_daily/data/services/robust_hymn_recommendation_service.dart';
import 'package:catholic_daily/ui/screens/hymn_list_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  final cleanup = mockMethodChannels();
  tearDownAll(cleanup);
  test('Advent readings surface Advent processional hymns', () async {
    await (await LiturgicalRegionPreferenceService.getInstance()).setRegion(
      LiturgicalRegion.nigeria,
    );
    final date = DateTime(2026, 11, 29);
    final context = await resolveDailyHymnContext(date);
    final results = await RobustHymnRecommendationService.instance
        .getMassPartRecommendations(
          date,
          context.readings,
          liturgicalDay: context.liturgicalDay,
          maxResultsPerPart: 3,
        );
    expect(results['entrance']!.any((h) => h.category == 'advent'), isTrue);
    expect(
      results['entrance']!.map((h) => h.title),
      contains('When He Comes Back'),
    );
  });
  test(
    'Lent uses suitable seasonal hymns without Good Friday chants',
    () async {
      await (await LiturgicalRegionPreferenceService.getInstance()).setRegion(
        LiturgicalRegion.nigeria,
      );
      final date = DateTime(2027, 2, 14);
      final context = await resolveDailyHymnContext(date);
      final results = await RobustHymnRecommendationService.instance
          .getMassPartRecommendations(
            date,
            context.readings,
            liturgicalDay: context.liturgicalDay,
            maxResultsPerPart: 3,
          );
      expect(
        results['entrance']!.map((h) => h.title),
        contains('Lord! Who Throughout These Forty Days'),
      );
      expect(
        results.values.expand((hymns) => hymns).map((h) => h.title),
        isNot(contains('The Reproaches')),
      );
    },
  );
  test('Epiphany carols are not proposed as Advent processionals', () async {
    await (await LiturgicalRegionPreferenceService.getInstance()).setRegion(
      LiturgicalRegion.nigeria,
    );
    final date = DateTime(2026, 11, 29);
    final context = await resolveDailyHymnContext(date);
    final results = await RobustHymnRecommendationService.instance
        .getMassPartRecommendations(
          date,
          context.readings,
          liturgicalDay: context.liturgicalDay,
          maxResultsPerPart: 5,
        );
    expect(
      results.values.expand((hymns) => hymns).map((h) => h.title),
      isNot(contains('What Star is This That Beams So Bright')),
    );
  });
  test('Epiphany carol remains eligible on the Epiphany', () async {
    await (await LiturgicalRegionPreferenceService.getInstance()).setRegion(
      LiturgicalRegion.nigeria,
    );
    final date = DateTime(2027, 1, 3);
    final context = await resolveDailyHymnContext(date);
    expect(context.liturgicalDay.title.toLowerCase(), contains('epiphany'));
    final hymns = await RobustHymnRecommendationService.instance
        .getRobustRecommendations(
          date,
          context.readings,
          liturgicalDay: context.liturgicalDay,
          massPart: 'entrance',
          maxResults: 200,
        );
    expect(
      hymns.map((h) => h.title),
      contains('What Star is This That Beams So Bright'),
    );
  });
}
