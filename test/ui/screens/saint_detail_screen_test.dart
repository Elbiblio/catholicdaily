import 'package:catholic_daily/data/models/saint_profile.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';
import 'package:catholic_daily/data/services/optional_memorial_service.dart';
import 'package:catholic_daily/data/services/saint_profile_service.dart';
import 'package:catholic_daily/ui/screens/saint_detail_screen.dart';
import 'package:catholic_daily/ui/widgets/saint_profile/saint_life_guide_view.dart';
import 'package:catholic_daily/ui/widgets/saint_profile/saint_sources_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route renders the complete guide for a published profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SaintDetailScreen(
          celebration: _celebration,
          profileLoader: (_) async => _profile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SaintLifeGuideView), findsOneWidget);
    expect(find.text('Why this saint matters today'), findsOneWidget);
  });

  testWidgets('route keeps legacy biography with an honest research notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SaintDetailScreen(
          celebration: _celebration,
          profileLoader: (_) async => _legacyProfile(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brief Bio'), findsOneWidget);
    expect(
      find.text('Existing source-backed offline biography.'),
      findsOneWidget,
    );
    expect(find.text('Research in progress'), findsOneWidget);
    expect(find.text('Open reference article'), findsOneWidget);
  });

  testWidgets('route shows an honest unavailable state for a missing profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SaintDetailScreen(
          celebration: _celebration,
          profileLoader: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile unavailable'), findsOneWidget);
    expect(find.textContaining('curated biography'), findsNothing);
  });

  testWidgets('retry requests a fresh future after a loading error', (
    tester,
  ) async {
    var calls = 0;
    Future<SaintProfile?> loader(OptionalCelebration _) {
      calls++;
      if (calls == 1) throw StateError('asset unavailable');
      return Future.value(_legacyProfile());
    }

    await tester.pumpWidget(
      MaterialApp(
        home: SaintDetailScreen(
          celebration: _celebration,
          profileLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load this profile'), findsOneWidget);
    expect(calls, 1);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(
      find.text('Existing source-backed offline biography.'),
      findsOneWidget,
    );
  });

  testWidgets('renders the complete guide in the approved spiritual order', (
    tester,
  ) async {
    var sourcesRequested = false;
    await tester.pumpWidget(
      _host(
        SaintLifeGuideView(
          profile: _profile(),
          onShowSources: () => sourcesRequested = true,
        ),
      ),
    );

    const headings = [
      'Why this saint matters today',
      'In one minute',
      'Their life and journey',
      'The Gospel visible in their life',
      'The struggle and response',
      'Virtues to imitate',
      'Live it today',
      'Reflect',
      'Scripture companion',
      'Prayer',
    ];
    var previousY = -1.0;
    for (final heading in headings) {
      final finder = find.text(heading);
      expect(finder, findsOneWidget);
      final y = tester.getTopLeft(finder).dy;
      expect(y, greaterThan(previousY), reason: '$heading is out of order');
      previousY = y;
      expect(
        tester.getSemantics(finder).flagsCollection.isHeader,
        isTrue,
        reason: '$heading must be announced as a heading',
      );
    }

    expect(find.text('Verified words from the saint.'), findsOneWidget);
    expect(find.text('A prayer from Catholic Daily'), findsOneWidget);
    expect(find.text('Sources and review'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Sources and review'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Sources and review'));
    expect(sourcesRequested, isTrue);
  });

  testWidgets('real curated profiles expose their sourced symbols', (
    tester,
  ) async {
    const cases = {'peter_damian': 'Cross', 'chair_of_saint_peter': 'Keys'};

    for (final entry in cases.entries) {
      final profile = await tester.runAsync(
        () => SaintProfileService.instance.findById(entry.key),
      );
      expect(profile, isNotNull, reason: '${entry.key} must be curated');

      await tester.pumpWidget(
        _host(SaintLifeGuideView(profile: profile!, onShowSources: () {})),
      );

      expect(
        find.text('Patronage and symbols'),
        findsOneWidget,
        reason: '${entry.key} has source-supported symbols',
      );
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('omits non-applicable lifespan and optional quotation', (
    tester,
  ) async {
    for (final kind in ['angelic', 'marian']) {
      final json = _profileJson();
      json['profileKind'] = kind;
      json['lifeSpan'] = '';
      json['lifeLength'] = '';
      json.remove('quote');
      await tester.pumpWidget(
        _host(
          SaintLifeGuideView(
            profile: SaintProfile.fromJson(json),
            onShowSources: () {},
          ),
        ),
      );

      expect(find.text('Lived'), findsNothing);
      expect(find.text('Length'), findsNothing);
      expect(find.text('Verified words from the saint.'), findsNothing);
      expect(find.text('The Gospel visible in their life'), findsOneWidget);
      expect(find.text('Reflect'), findsOneWidget);
      expect(find.text('Scripture companion'), findsOneWidget);
      expect(find.text('Prayer'), findsOneWidget);
    }
  });

  testWidgets('supports narrow screens and 200 percent text scaling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        SaintLifeGuideView(profile: _profile(), onShowSources: () {}),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Sources and review'),
      500,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Sources and review'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sources sheet exposes provenance and credited links', (
    tester,
  ) async {
    Uri? openedUri;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => SaintSourcesSheet.show(
                context,
                _profile(),
                onOpenUrl: (uri) => openedUri = uri,
              ),
              child: const Text('Show sources'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show sources'));
    await tester.pumpAndSettle();

    expect(find.text('Official Biography'), findsOneWidget);
    expect(find.text('Primary or official source'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open source'));
    expect(openedUri, Uri.parse('https://example.org/saint'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Image credit'), findsOneWidget);
  });
}

const _celebration = OptionalCelebration(
  id: 'sample_saint',
  title: 'Saint Sample, Religious',
  rank: CelebrationRank.optionalMemorial,
  color: LiturgicalColor.white,
  month: 1,
  day: 2,
  commonType: 'Religious',
);

Widget _host(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
  return MaterialApp(
    theme: ThemeData(colorSchemeSeed: const Color(0xFF6B3FA0)),
    home: MediaQuery(
      data: MediaQueryData(textScaler: textScaler),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

SaintProfile _profile() => SaintProfile.fromJson(_profileJson());

SaintProfile _legacyProfile() => SaintProfile.fromJson({
  'id': 'sample_saint',
  'celebrationIds': ['sample_saint'],
  'name': 'Saint Sample',
  'lifeSpan': '1900-1970',
  'lifeLength': '70 years',
  'briefBio': 'Existing source-backed offline biography.',
  'patronage': ['reconciliation'],
  'feastDates': ['January 2'],
  'wikipediaUrl': 'https://example.org/reference',
  'sources': ['Legacy discovery source'],
});

Map<String, dynamic> _profileJson() => {
  'schemaVersion': 2,
  'id': 'sample_saint',
  'profileKind': 'individual',
  'celebrationIds': ['sample_saint'],
  'name': 'Saint Sample',
  'ecclesialTitle': 'Religious',
  'lifeSpan': '1900-1970',
  'lifeLength': '70 years',
  'vocation': 'Service to people in need',
  'places': ['Rome'],
  'patronage': ['reconciliation'],
  'symbols': ['lamp'],
  'briefBio': 'A concise account of a life shaped by mercy and service.',
  'feastDates': ['January 2'],
  'historicalCertainty': 'documented',
  'sources': [
    {
      'id': 'official-biography',
      'title': 'Official Biography',
      'authorOrInstitution': 'Example Diocese',
      'publisher': 'Example Diocese',
      'url': 'https://example.org/saint',
      'accessedDate': '2026-08-10',
      'tier': 1,
      'reuseBasis': 'Facts only; original synthesis',
      'supports': ['identity', 'life.turning_point'],
    },
  ],
  'image': {
    'assetPath': 'assets/images/saints/sample_saint.jpg',
    'creator': 'Example Artist',
    'sourceUrl': 'https://example.org/image',
    'license': 'CC BY-SA 4.0',
    'creditLine': 'Example Artist / CC BY-SA 4.0',
    'isDerivative': false,
  },
  'editorial': {
    'state': 'published',
    'researcher': 'Catholic Daily editorial',
    'reviewer': 'Catholic Daily reviewer',
    'reviewedAt': '2026-08-10',
    'revision': 1,
    'warnings': <String>[],
  },
  'whyItMatters': 'Saint Sample chose mercy when retaliation was easier.',
  'oneMinuteSummary':
      'A concise, source-grounded summary of the saint and mission.',
  'life': {
    'sections': [
      {
        'heading': 'A decisive choice',
        'body':
            'A documented turning point written in original prose. The account remains readable when the user chooses a much larger system text size.',
        'sourceIds': ['official-biography'],
      },
    ],
    'gospelTheme': 'Mercy received becomes mercy offered.',
    'struggle': 'The saint faced a costly conflict.',
    'response': 'The saint responded through prayer and concrete charity.',
  },
  'virtues': [
    {
      'name': 'Mercy',
      'evidence': 'The documented turning point.',
      'imitation': 'Refuse one cycle of retaliation today.',
      'sourceIds': ['official-biography'],
    },
  ],
  'practice': {
    'spiritual': 'Spend five minutes praying for someone difficult.',
    'action': 'Make one concrete act of reconciliation.',
  },
  'reflectionQuestions': [
    'Where am I tempted to retaliate?',
    'What would mercy require today?',
  ],
  'scripture': {
    'reference': 'Luke 6:36',
    'connection': 'Jesus places mercy at the centre of discipleship.',
  },
  'prayer':
      'God of mercy, teach us to receive and offer your forgiveness through Christ our Lord. Amen.',
  'quote': {
    'text': 'Verified words from the saint.',
    'attribution': 'Saint Sample',
    'sourceId': 'official-biography',
  },
};
