import 'package:flutter_test/flutter_test.dart';

import '../lib/data/models/hymn.dart';
import '../lib/data/models/daily_reading.dart';
import '../lib/data/services/hymn_text_index.dart';
import '../lib/data/services/robust_hymn_recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final shepherd = Hymn(
    id: 1,
    title: 'The Lord Is My Shepherd',
    category: 'general',
    lyrics: ['He leads me beside still waters'],
  );
  final praise = Hymn(
    id: 2,
    title: 'Sing to the Lord',
    category: 'general',
    lyrics: ['Sing his praises'],
  );
  final mercy = Hymn(
    id: 3,
    title: 'Lord Have Mercy',
    category: 'general',
    lyrics: ['Forgive our sin'],
  );

  test(
    'distinctive reading terms rank a related hymn above generic overlap',
    () {
      final index = HymnTextIndex([shepherd, praise, mercy]);
      expect(
        index.score(shepherd, 'The Lord is my shepherd'),
        greaterThan(index.score(praise, 'The Lord is my shepherd')),
      );
    },
  );

  test('matching whole words avoids treating sing as sin', () {
    final index = HymnTextIndex([shepherd, praise, mercy]);
    expect(index.score(praise, 'sin'), 0);
    expect(index.score(mercy, 'sin'), greaterThan(0));
  });

  test('unindexed words in long passages do not dilute useful matches', () {
    final index = HymnTextIndex([shepherd, praise, mercy]);
    expect(
      index.score(shepherd, 'shepherd irrelevantword anotherunknownword'),
      index.score(shepherd, 'shepherd'),
    );
  });

  test('ordinary time rejects hymns assigned to Christmas', () {
    final engine = LiturgicalJudgmentEngine();
    final context = engine.buildContext({'season': 'ordinaryTime'});
    final hymn = Hymn(
      id: 4,
      title: 'Christmas',
      category: 'christmas',
      lyrics: ['Christ is born'],
    );
    expect(engine.validateHymn(hymn, context).isValid, isFalse);
  });

  test(
    'full passage text influences recommendations from the bundled hymnal',
    () async {
      final date = DateTime(2026, 1, 15);
      final readings = [
        DailyReading(date: date, reading: 'John 10:11-18', position: 'Gospel'),
      ];
      final results = await RobustHymnRecommendationService.instance
          .getRobustRecommendations(
            date,
            readings,
            massPart: 'communion',
            maxResults: 5,
            // John 10:11–18 from the bundled RSV-CE database.
            readingTexts: {
              'John 10:11-18':
                  '''I am the good shepherd. The good shepherd lays down his life for the sheep.
He who is a hireling and not a shepherd, whose own the sheep are not, sees the wolf coming and leaves the sheep and flees; and the wolf snatches them and scatters them.
He flees because he is a hireling and cares nothing for the sheep.
I am the good shepherd; I know my own and my own know me,
as the Father knows me and I know the Father; and I lay down my life for the sheep.
And I have other sheep, that are not of this fold; I must bring them also, and they will heed my voice. So there shall be one flock, one shepherd.
For this reason the Father loves me, because I lay down my life, that I may take it again.
No one takes it from me, but I lay it down of my own accord. I have power to lay it down, and I have power to take it again; this charge I have received from my Father.''',
            },
          );
      expect(results.first.title, 'Loving Shepherd Of Thy Sheep');
      expect(
        results.any((hymn) => hymn.title.toLowerCase().contains('shepherd')),
        isTrue,
        reason:
            'The full passage contains a distinctive theme absent from reading metadata.',
      );
    },
  );

  test(
    'one unavailable passage does not discard other reading texts',
    () async {
      final readings = [
        DailyReading(date: DateTime(2026), reading: 'John 10'),
        DailyReading(date: DateTime(2026), reading: 'Psalm 23'),
        DailyReading(date: DateTime(2026), reading: 'Isaiah 40'),
      ];
      final texts = await resolveHymnReadingTexts(readings, (reading) async {
        if (reading.reading == 'Psalm 23') throw StateError('missing');
        if (reading.reading == 'Isaiah 40')
          return 'Reading text unavailable for Isaiah 40.';
        return 'The good shepherd';
      });
      expect(texts, {'John 10': 'The good shepherd'});
    },
  );

  test('seasonal hymns can be matched on Easter', () async {
    final date = DateTime(2026, 4, 5);
    final readings = [
      DailyReading(date: date, reading: 'John 20', position: 'Gospel'),
    ];
    final hymns = await RobustHymnRecommendationService.instance
        .getRobustRecommendations(
          date,
          readings,
          massPart: 'entrance',
          maxResults: 5,
          readingTexts: {'John 20': 'Christ the Lord is risen today'},
        );
    expect(hymns.any((hymn) => hymn.category == 'easter'), isTrue);
  });

  test('mass part results respect limits and Lenten validation', () async {
    final date = DateTime(2026, 3, 15);
    final service = RobustHymnRecommendationService.instance;
    final results = await service.getMassPartRecommendations(
      date,
      [],
      maxResultsPerPart: 1,
      readingTexts: {},
    );
    for (final entry in results.entries) {
      expect(entry.value.length, lessThanOrEqualTo(1));
      for (final hymn in entry.value) {
        final score = await service.evaluateHymn(
          hymn,
          date,
          [],
          massPart: entry.key,
        );
        expect(score!.passesLiturgicalJudgment, isTrue);
      }
    }
  });

  test('theme extraction does not confuse sing with sin', () {
    final themes = RichTextThemeExtractor().extractFromReadings([
      DailyReading(
        date: DateTime(2026),
        reading: 'Psalm 96',
        psalmResponse: 'Sing a new song',
      ),
    ]);
    expect(themes['mercy'], isNull);
  });

  test(
    'communion and offertory suggestions use their indexed Mass parts',
    () async {
      final date = DateTime(2026, 4, 5);
      final readings = [
        DailyReading(date: date, reading: 'John 20', position: 'Gospel'),
      ];
      final results = await RobustHymnRecommendationService.instance
          .getMassPartRecommendations(
            date,
            readings,
            readingTexts: {'John 20': 'Christ the Lord is risen today'},
          );
      for (final part in ['communion', 'offertory']) {
        expect(results[part], isNotEmpty);
        expect(
          results[part]!.every(
            (h) => h.category
                .toLowerCase()
                .split(',')
                .map((c) => c.trim())
                .contains(part),
          ),
          isTrue,
          reason: '$part needs a specific Mass-part designation',
        );
      }
      final ids = results.values
          .expand((hymns) => hymns.map((h) => h.id))
          .toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'Suggestions should not repeat across Mass parts',
      );
    },
  );

  test(
    'ordinary-day processional suggestions exclude unclassified narrative hymns',
    () async {
      final date = DateTime(2026, 8, 17);
      final readings = [
        DailyReading(date: date, reading: 'Matt 19:16-22', position: 'Gospel'),
      ];
      final hymns = await RobustHymnRecommendationService.instance
          .getRobustRecommendations(
            date,
            readings,
            massPart: 'entrance',
            readingTexts: {
              'Matt 19:16-22':
                  'Jesus said if you would enter life keep the commandments',
            },
          );
      expect(
        hymns.every(
          (h) => h.category
              .toLowerCase()
              .split(',')
              .map((c) => c.trim())
              .contains('entrance'),
        ),
        isTrue,
      );
    },
  );

  test('Lenten processionals exclude rite-specific chants', () async {
    final date = DateTime(2026, 2, 22);
    final hymns = await RobustHymnRecommendationService.instance
        .getRobustRecommendations(
          date,
          [
            DailyReading(
              date: date,
              reading: 'Psalm 51',
              psalmResponse: 'Have mercy on me, O God',
            ),
          ],
          massPart: 'entrance',
          readingTexts: {
            'Psalm 51': 'My people what have I done to you have mercy on me',
          },
        );
    expect(hymns.map((h) => h.title), isNot(contains('The Reproaches')));
  });
}
