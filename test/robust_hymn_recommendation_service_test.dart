// robust_hymn_recommendation_service_test.dart
//
// Comprehensive test suite for the USCCB Three Judgments Hymn Recommendation Engine
// Tests liturgical compliance, pastoral sensitivity, musical quality, and theological accuracy

import 'package:flutter_test/flutter_test.dart';
import '../lib/data/models/hymn.dart';
import '../lib/data/models/daily_reading.dart';
import '../lib/data/services/robust_hymn_recommendation_service.dart';

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();
  group('RobustHymnRecommendationService - USCCB Three Judgments Tests', () {
    late RobustHymnRecommendationService service;

    setUp(() {
      service = RobustHymnRecommendationService.instance;
    });

    // ==================== LITURGICAL JUDGMENT TESTS ====================
    
    group('Liturgical Judgment Tests', () {
      test('should block Christmas hymns during Lent', () async {
        // Lent 2026 - March 15, 2026
        final lentDate = DateTime(2026, 3, 15);
        final readings = _createSampleReadings();
        
        // Christmas hymn that should be blocked
        final christmasHymn = Hymn(
          id: 1,
          title: 'Joy to the World',
          category: 'christmas',
          lyrics: ['Joy to the world', 'the Lord has come'],
          liturgicalSeason: 'christmas',
        );
        
        final evaluation = await service.evaluateHymn(christmasHymn, lentDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesLiturgicalJudgment, isFalse,
            reason: 'Christmas hymns should not pass liturgical judgment during Lent');
        expect(evaluation.liturgicalScore, lessThan(70.0),
            reason: 'Liturgical score should be below minimum threshold');
      });

      test('should block Alleluia content during Lent', () async {
        // Lent 2026 - March 15, 2026 (Ash Wednesday 2026 is Feb 18, Easter is April 5)
        final lentDate = DateTime(2026, 3, 15);
        final readings = _createSampleReadings();
        
        final alleluiaHymn = Hymn(
          id: 2,
          title: 'Alleluia! Sing to Jesus',
          category: 'general',
          lyrics: ['Alleluia! Alleluia!', 'Sing to Jesus'],
        );
        
        final evaluation = await service.evaluateHymn(alleluiaHymn, lentDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesLiturgicalJudgment, isFalse,
            reason: 'Alleluia content should be blocked during Lent');
      });

      test('should allow appropriate Easter hymns during Easter season', () async {
        final easterDate = DateTime(2026, 4, 5); // Easter Sunday 2026
        final readings = _createEasterReadings();
        
        final easterHymn = Hymn(
          id: 3,
          title: 'Christ the Lord Is Risen Today',
          category: 'easter',
          lyrics: ['Christ the Lord is risen today', 'Alleluia!'],
          liturgicalSeason: 'easter',
        );
        
        final evaluation = await service.evaluateHymn(easterHymn, easterDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesLiturgicalJudgment, isTrue,
            reason: 'Easter hymns should pass liturgical judgment during Easter');
        expect(evaluation.liturgicalScore, greaterThanOrEqualTo(70.0));
      });

      test('should give preference boost for feast day matches', () async {
        final christmasDate = DateTime(2025, 12, 25); // Christmas
        final readings = _createChristmasReadings();
        
        final christmasHymn = Hymn(
          id: 4,
          title: 'O Come All Ye Faithful',
          category: 'christmas,incarnation',
          lyrics: ['O come all ye faithful', 'Joyful and triumphant'],
          liturgicalSeason: 'christmas',
        );
        
        final evaluation = await service.evaluateHymn(christmasHymn, christmasDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.liturgicalScore, greaterThan(80.0),
            reason: 'Feast day matches should receive significant boost');
      });

      test('should validate mass part appropriateness', () async {
        final ordinaryDate = DateTime(2026, 1, 15); // Ordinary Time
        final readings = _createSampleReadings();
        
        // Entrance hymn
        final entranceHymn = Hymn(
          id: 5,
          title: 'Gather Us In',
          category: 'entrance,gathering',
          lyrics: ['Gather us in', 'You are the living God'],
        );
        
        final entranceEvaluation = await service.evaluateHymn(
          entranceHymn, ordinaryDate, readings, massPart: 'entrance');
        
        expect(entranceEvaluation, isNotNull);
        expect(entranceEvaluation!.passesLiturgicalJudgment, isTrue,
            reason: 'Entrance hymns should pass for entrance mass part');
        
        // Same hymn should score lower for communion
        final communionEvaluation = await service.evaluateHymn(
          entranceHymn, ordinaryDate, readings, massPart: 'communion');
        
        expect(communionEvaluation, isNotNull);
        expect(communionEvaluation!.liturgicalScore, 
               lessThan(entranceEvaluation.liturgicalScore),
               reason: 'Non-communion hymns should score lower for communion');
      });
    });

    // ==================== PASTORAL JUDGMENT TESTS ====================
    
    group('Pastoral Judgment Tests', () {
      test('should assess singability factors', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Simple, singable hymn
        final simpleHymn = Hymn(
          id: 6,
          title: 'Simple Gifts',
          category: 'general',
          lyrics: ['Tis the gift to be simple', 'Tis the gift to be free'],
          themes: 'simple,easy,call and response',
        );
        
        final evaluation = await service.evaluateHymn(simpleHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.pastoralScore, greaterThanOrEqualTo(60.0),
            reason: 'Simple hymns should meet minimum pastoral judgment');
      });

      test('should evaluate educational value', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Theologically educational hymn
        final educationalHymn = Hymn(
          id: 7,
          title: 'I Bind Unto Myself Today',
          category: 'doctrine',
          lyrics: ['I bind unto myself today', 'The strong Name of the Trinity'],
          themes: 'scripture,catechetical,doctrine',
        );
        
        final evaluation = await service.evaluateHymn(educationalHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.pastoralScore, greaterThan(65.0),
            reason: 'Educational hymns should score higher on pastoral judgment');
      });

      test('should assess community participation factors', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Community-focused hymn
        final communityHymn = Hymn(
          id: 8,
          title: 'We Are One Body',
          category: 'community',
          lyrics: ['We are one body', 'One body in Christ'],
          themes: 'community,gathering,responsive',
        );
        
        final evaluation = await service.evaluateHymn(communityHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.pastoralScore, greaterThanOrEqualTo(60.0),
            reason: 'Community hymns should meet pastoral judgment standards');
      });
    });

    // ==================== MUSICAL JUDGMENT TESTS ====================
    
    group('Musical Judgment Tests', () {
      test('should assess musical quality indicators', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // High-quality traditional hymn
        final qualityHymn = Hymn(
          id: 9,
          title: 'Amazing Grace',
          category: 'general',
          lyrics: ['Amazing grace', 'How sweet the sound'],
          themes: 'traditional,classic,artistic',
        );
        
        final evaluation = await service.evaluateHymn(qualityHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.musicalScore, greaterThanOrEqualTo(65.0),
            reason: 'Quality hymns should meet minimum musical judgment');
      });

      test('should evaluate textual faithfulness', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Theologically sound hymn
        final orthodoxHymn = Hymn(
          id: 10,
          title: 'Holy Holy Holy',
          category: 'praise',
          lyrics: ['Holy, holy, holy', 'Lord God Almighty', 'Father, Son, and Holy Spirit'],
          themes: 'orthodox,catholic,trinity',
        );
        
        final evaluation = await service.evaluateHymn(orthodoxHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.musicalScore, greaterThan(70.0),
            reason: 'Theologically sound hymns should score well on musical judgment');
      });

      test('should assess sacred character', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Sacred worship hymn
        final sacredHymn = Hymn(
          id: 11,
          title: 'O Sacrum Convivium',
          category: 'eucharist,adoration',
          lyrics: ['O sacred banquet', 'In which Christ is received'],
          themes: 'sacred,worship,reverent',
        );
        
        final evaluation = await service.evaluateHymn(sacredHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.musicalScore, greaterThanOrEqualTo(65.0),
            reason: 'Sacred hymns should meet musical judgment standards');
      });
    });

    // ==================== THEOLOGICAL THEME TESTS ====================

    group('Theological Theme Extraction Tests', () {
      test('should extract creation themes from incipit/psalmResponse', () async {
        final readings = _createCreationReadings();
        final extractor = RichTextThemeExtractor();

        final themes = extractor.extractFromReadings(readings);

        expect(themes['creation'], greaterThan(0.0),
            reason: 'Creation readings should extract creation themes from rich text fields');
      });

      test('should extract faith/love themes from rich text', () async {
        final readings = _createRedemptionReadings();
        final extractor = RichTextThemeExtractor();

        final themes = extractor.extractFromReadings(readings);

        // The redemption readings use psalmResponse with 'love' and incipit with 'save'
        expect(themes.isNotEmpty, isTrue,
            reason: 'Rich text fields should yield at least one detected theme');
      });

      test('should extract eucharist themes from incipit', () async {
        final readings = _createEucharistReadings();
        final extractor = RichTextThemeExtractor();

        final themes = extractor.extractFromReadings(readings);

        expect(themes['eucharist'], greaterThan(0.0),
            reason: 'Eucharist readings should extract eucharist themes from rich text fields');
      });

      test('should boost communion part themes toward eucharist', () {
        final extractor = RichTextThemeExtractor();
        final baseThemes = <String, double>{'shepherd': 1.0, 'mercy': 0.5};

        final communionThemes = extractor.themeMapForPart('communion', baseThemes);

        expect(communionThemes['eucharist'], greaterThan(0.0),
            reason: 'Communion part should always have a eucharist boost');
        expect(communionThemes['shepherd'], greaterThan(baseThemes['shepherd']!),
            reason: 'Communion part should amplify shepherd theme');
      });

      test('should boost dismissal part themes toward mission', () {
        final extractor = RichTextThemeExtractor();
        final baseThemes = <String, double>{'praise': 1.0};

        final dismissalThemes = extractor.themeMapForPart('dismissal', baseThemes);

        expect(dismissalThemes['mission'], greaterThan(0.0),
            reason: 'Dismissal part should always introduce mission theme');
      });
    });

    // ==================== THREE JUDGMENTS INTEGRATION TESTS ====================
    
    group('Three Judgments Integration Tests', () {
      test('should pass all Three Judgments for appropriate hymns', () async {
        final easterDate = DateTime(2026, 4, 5); // Easter
        final readings = _createEasterReadings();
        
        final idealEasterHymn = Hymn(
          id: 12,
          title: 'Jesus Christ Is Risen Today',
          category: 'easter,resurrection',
          lyrics: ['Jesus Christ is risen today', 'Alleluia!', 'Our triumphant holy God'],
          liturgicalSeason: 'easter',
          themes: 'traditional,orthodox,sacred,worship',
        );
        
        final evaluation = await service.evaluateHymn(idealEasterHymn, easterDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesAllJudgments, isTrue,
            reason: 'Ideal hymns should pass all Three Judgments');
        expect(evaluation.liturgicalScore, greaterThanOrEqualTo(70.0));
        expect(evaluation.pastoralScore, greaterThanOrEqualTo(60.0));
        expect(evaluation.musicalScore, greaterThanOrEqualTo(65.0));
      });

      test('should fail liturgical judgment for inappropriate hymns', () async {
        final lentDate = DateTime(2026, 3, 15); // Lent
        final readings = _createSampleReadings();
        
        final inappropriateHymn = Hymn(
          id: 13,
          title: 'Jingle Bells',
          category: 'christmas,secular',
          lyrics: ['Jingle bells, jingle bells', 'Jingle all the way'],
          liturgicalSeason: 'christmas',
        );
        
        final evaluation = await service.evaluateHymn(inappropriateHymn, lentDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesAllJudgments, isFalse,
            reason: 'Inappropriate hymns should not pass all judgments');
        expect(evaluation.passesLiturgicalJudgment, isFalse,
            reason: 'Inappropriate hymns should fail liturgical judgment');
      });

      test('should provide comprehensive evaluation details', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        final hymn = Hymn(
          id: 14,
          title: 'Test Hymn',
          category: 'general',
          lyrics: ['This is a test hymn', 'For testing purposes'],
        );
        
        final evaluation = await service.evaluateHymn(hymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.evaluationDetails.containsKey('liturgicalScore'), isTrue);
        expect(evaluation.evaluationDetails.containsKey('pastoralScore'), isTrue);
        expect(evaluation.evaluationDetails.containsKey('musicalScore'), isTrue);
        expect(evaluation.evaluationDetails.containsKey('themeScore'), isTrue);
        expect(evaluation.evaluationDetails.containsKey('validation'), isTrue);
      });
    });

    // ==================== COMPREHENSIVE RECOMMENDATION TESTS ====================
    
    group('Comprehensive Recommendation Tests', () {
      test('should return appropriate recommendations for Easter', () async {
        final easterDate = DateTime(2026, 4, 5);
        final readings = _createEasterReadings();
        
        final recommendations = await service.getRobustRecommendations(
          easterDate, readings, maxResults: 5);
        
        expect(recommendations, isNotEmpty);
        expect(recommendations.length, lessThanOrEqualTo(5));
        
        // All recommendations should pass liturgical judgment
        for (final hymn in recommendations) {
          final evaluation = await service.evaluateHymn(hymn, easterDate, readings);
          expect(evaluation!.passesLiturgicalJudgment, isTrue,
              reason: 'All recommendations should pass liturgical judgment');
        }
      });

      test('should provide mass part specific recommendations', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        final massPartRecommendations = await service.getMassPartRecommendations(
          date, readings, maxResultsPerPart: 3);
        
        expect(massPartRecommendations.containsKey('entrance'), isTrue);
        expect(massPartRecommendations.containsKey('offertory'), isTrue);
        expect(massPartRecommendations.containsKey('communion'), isTrue);
        expect(massPartRecommendations.containsKey('dismissal'), isTrue);
        
        // Each mass part should have recommendations
        for (final part in ['entrance', 'offertory', 'communion', 'dismissal']) {
          expect(massPartRecommendations[part]!, isNotEmpty,
              reason: 'Each mass part should have recommendations');
          expect(massPartRecommendations[part]!.length, lessThanOrEqualTo(3),
              reason: 'Should respect max results per part');
        }
      });

      test('should handle edge cases gracefully', () async {
        final date = DateTime(2026, 1, 15);
        final emptyReadings = <DailyReading>[];
        
        // Should not crash with empty readings
        final recommendations = await service.getRobustRecommendations(
          date, emptyReadings, maxResults: 3);
        
        expect(recommendations, isA<List<Hymn>>());
        // Should still provide some recommendations based on date alone
        expect(recommendations, isNotEmpty);
      });
    });

    // ==================== USCCB COMPLIANCE TESTS ====================
    
    group('USCCB Compliance Tests', () {
      test('should enforce liturgical primacy', () async {
        final lentDate = DateTime(2026, 3, 15);
        final readings = _createSampleReadings();
        
        // Hymn with high pastoral/musical scores but liturgically inappropriate
        final problematicHymn = Hymn(
          id: 15,
          title: 'Beautiful Christmas Carol',
          category: 'christmas',
          lyrics: ['Beautiful Christmas lyrics', 'Amazing melody'],
          themes: 'beautiful,artistic,excellent,community',
        );
        
        final evaluation = await service.evaluateHymn(problematicHymn, lentDate, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesLiturgicalJudgment, isFalse,
            reason: 'Liturgical primacy should block inappropriate hymns regardless of other factors');
        expect(evaluation.passesAllJudgments, isFalse,
            reason: 'Should not pass all judgments due to liturgical failure');
      });

      test('should maintain minimum quality thresholds', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        // Hymn that meets liturgical requirements but has poor quality
        final poorQualityHymn = Hymn(
          id: 16,
          title: 'Basic Hymn',
          category: 'general',
          lyrics: ['Very basic', 'Poor quality'],
          themes: 'heretical,unorthodox', // Should trigger musical judgment failure
        );
        
        final evaluation = await service.evaluateHymn(poorQualityHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.musicalScore, lessThan(65.0),
            reason: 'Poor quality hymns should fail musical judgment minimum threshold');
      });

      test('should demonstrate Three Judgments balance', () async {
        final date = DateTime(2026, 1, 15);
        final readings = _createSampleReadings();
        
        final balancedHymn = Hymn(
          id: 17,
          title: 'Balanced Hymn',
          category: 'general',
          lyrics: ['Balanced lyrics', 'Good theological content'],
          themes: 'orthodox,community,simple',
        );
        
        final evaluation = await service.evaluateHymn(balancedHymn, date, readings);
        
        expect(evaluation, isNotNull);
        expect(evaluation!.passesAllJudgments, isTrue,
            reason: 'Balanced hymns should pass all Three Judgments');
        
        // Combined score should be reasonable given the 4-component formula
        // (35% liturgical + 25% pastoral + 20% musical + 20% theme)
        expect(evaluation.evaluationDetails['combinedScore'],
               greaterThanOrEqualTo(50.0),
               reason: 'Combined score should meet minimum threshold');
      });
    });
  });
}

// ==================== TEST DATA HELPERS ====================

List<DailyReading> _createSampleReadings() {
  return [
    DailyReading(
      reading: 'In the beginning was the Word, and the Word was with God...',
      position: 'First Reading',
      date: DateTime(2026, 1, 15),
      source: 'John 1:1-18',
    ),
    DailyReading(
      reading: 'The LORD is my shepherd, I shall not want...',
      position: 'Responsorial Psalm',
      date: DateTime(2026, 1, 15),
      source: 'Psalm 23',
    ),
    DailyReading(
      reading: 'For God so loved the world that he gave his only Son...',
      position: 'Gospel',
      date: DateTime(2026, 1, 15),
      source: 'John 3:16-21',
    ),
  ];
}

List<DailyReading> _createEasterReadings() {
  return [
    DailyReading(
      reading: 'Why do you look for the living among the dead? He is not here...',
      position: 'Gospel',
      date: DateTime(2026, 4, 5),
      source: 'Luke 24:1-12',
    ),
    DailyReading(
      reading: 'Christ, raised from the dead, dies no more...',
      position: 'Second Reading',
      date: DateTime(2026, 4, 5),
      source: 'Romans 6:3-11',
    ),
  ];
}

List<DailyReading> _createChristmasReadings() {
  return [
    DailyReading(
      reading: 'For today is born to you a Savior, who is Christ the Lord...',
      position: 'Gospel',
      date: DateTime(2025, 12, 25),
      source: 'Luke 2:1-14',
    ),
    DailyReading(
      reading: 'The people who walked in darkness have seen a great light...',
      position: 'First Reading',
      date: DateTime(2025, 12, 25),
      source: 'Isaiah 9:1-6',
    ),
  ];
}

List<DailyReading> _createCreationReadings() {
  return [
    DailyReading(
      reading: 'Gen 1:1-19',
      position: 'First Reading',
      date: DateTime(2026, 1, 15),
      source: 'Genesis 1:1-19',
      incipit: 'In the beginning God created the heavens and the earth',
      psalmResponse: 'The earth is full of the goodness of the Lord.',
    ),
  ];
}

List<DailyReading> _createRedemptionReadings() {
  return [
    DailyReading(
      reading: 'Jn 3:16-21',
      position: 'Gospel',
      date: DateTime(2026, 1, 15),
      source: 'John 3:16-21',
      incipit: 'God so loved the world that he gave his only Son to save us',
      psalmResponse: 'The Lord is kind and merciful; slow to anger and rich in love.',
      gospelAcclamation: 'God so loved the world that he gave his only Son.',
    ),
  ];
}

List<DailyReading> _createEucharistReadings() {
  return [
    DailyReading(
      reading: 'Luke 22:14-20',
      position: 'Gospel',
      date: DateTime(2026, 1, 15),
      source: 'Luke 22:14-20',
      incipit: 'This is my body, the bread given for you; do this in memory of me',
      psalmResponse: 'I will take the cup of salvation, and call on the name of the Lord.',
      gospelAcclamation: 'I am the living bread that came down from heaven, says the Lord.',
    ),
  ];
}
