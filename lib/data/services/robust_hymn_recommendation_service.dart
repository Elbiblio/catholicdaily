// robust_hymn_recommendation_service.dart
//
// USCCB Three Judgments Framework for Hymn Recommendation
// Based on "Sing to the Lord: Music in Divine Worship"
//
// Implements:
// 1. Liturgical Judgment - Primary validation gate
// 2. Pastoral Judgment - Community needs and formation  
// 3. Musical Judgment - Quality and artistry assessment
// 4. Theological Theme Extraction - Advanced semantic analysis
// 5. Three Judgments Integration - Unified evaluation engine

import '../models/hymn.dart';
import '../models/daily_reading.dart';
import 'hymn_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'base_service.dart';

// ==================== CORE THREE JUDGMENTS TYPES ====================

/// Represents the Three Judgments evaluation scores
class ThreeJudgmentsScore {
  final double liturgicalScore;    // 0-100, minimum 70 required
  final double pastoralScore;      // 0-100, minimum 60 required  
  final double musicalScore;       // 0-100, minimum 65 required
  final double combinedScore;      // Weighted average with liturgical primacy
  final Map<String, dynamic> evaluationDetails;
  
  const ThreeJudgmentsScore({
    required this.liturgicalScore,
    required this.pastoralScore,
    required this.musicalScore,
    required this.combinedScore,
    required this.evaluationDetails,
  });
  
  bool get passesAllJudgments => 
    liturgicalScore >= 70 && 
    pastoralScore >= 60 && 
    musicalScore >= 65;
  
  bool get passesLiturgicalJudgment => liturgicalScore >= 70;
}

/// Liturgical validation result with specific failure reasons
class LiturgicalValidation {
  final bool isValid;
  final List<String> violations;
  final List<String> warnings;
  
  const LiturgicalValidation({
    required this.isValid,
    required this.violations,
    required this.warnings,
  });
}

/// Enhanced liturgical context with feast day detection
class EnhancedLiturgicalContext {
  final String seasonKey;
  final String feastTitle;
  final int feastRank; // 0=feria, 1=memorial, 2=feast, 3=solemnity
  final List<String> feastCategories;
  final List<String> seasonCategories;
  final bool isAlleluiaPermitted;
  final bool isGloriaPermitted;
  final Map<String, dynamic> specialRules;
  
  const EnhancedLiturgicalContext({
    required this.seasonKey,
    required this.feastTitle,
    required this.feastRank,
    required this.feastCategories,
    required this.seasonCategories,
    required this.isAlleluiaPermitted,
    required this.isGloriaPermitted,
    required this.specialRules,
  });
}

// ==================== LITURGICAL JUDGMENT ENGINE ====================

/// Primary validation gate ensuring liturgical appropriateness
class LiturgicalJudgmentEngine {
  static const Map<String, Set<String>> _seasonExclusions = {
    'advent': {'christmas', 'easter', 'lenten', 'penitential'},
    'christmas': {'advent', 'lenten', 'penitential', 'easter'},
    'lent': {'christmas', 'easter', 'advent', 'alleluia'},
    'holyWeek': {'christmas', 'easter', 'advent', 'alleluia'},
    'easterTriduum': {'christmas', 'advent', 'lenten'},
    'easter': {'christmas', 'lenten', 'penitential', 'advent'},
    'pentecost': {'christmas', 'lenten', 'penitential', 'advent'},
    'ordinaryTime': {'advent', 'christmas', 'lenten', 'easter'},
  };
  
  static const Map<String, List<String>> _seasonPrimaryCategories = {
    'advent': ['advent', 'light', 'hope', 'coming', 'general'],
    'christmas': ['christmas', 'incarnation', 'marian', 'general'],
    'lent': ['lenten', 'penitential', 'repentance', 'passion', 'general'],
    'holyWeek': ['passion', 'penitential', 'lenten', 'general'],
    'easterTriduum': ['easter vigil', 'passion', 'resurrection', 'general'],
    'easter': ['easter', 'resurrection', 'alleluia', 'general'],
    'pentecost': ['pentecost', 'holy spirit', 'mission', 'general'],
    'ordinaryTime': ['general', 'praise', 'mission', 'faith', 'entrance'],
  };
  
  static const Map<String, List<String>> _feastCategories = {
    'the nativity of the lord': ['christmas', 'incarnation', 'marian'],
    'the epiphany of the lord': ['christmas', 'light', 'general'],
    'the baptism of the lord': ['baptism', 'holy spirit', 'general'],
    'ash wednesday': ['penitential', 'lenten', 'repentance'],
    'palm sunday': ['passion', 'entrance', 'penitential'],
    'holy thursday': ['eucharist', 'communion', 'love'],
    'good friday': ['passion', 'lenten', 'penitential'],
    'easter sunday': ['easter', 'resurrection', 'alleluia'],
    'divine mercy sunday': ['mercy', 'resurrection', 'trust'],
    'the ascension of the lord': ['ascension', 'kingdom', 'general'],
    'pentecost sunday': ['pentecost', 'holy spirit', 'mission'],
    'the most holy trinity': ['trinity', 'holy spirit', 'general'],
    'the most holy body and blood of christ': ['eucharist', 'communion', 'adoration'],
    'the most sacred heart of jesus': ['sacred heart', 'love', 'mercy'],
    'mary, mother of god': ['marian', 'incarnation', 'general'],
    'the immaculate conception': ['marian', 'general'],
    'the assumption of the blessed virgin mary': ['marian', 'eternal', 'general'],
    'all saints': ['saints', 'eternal', 'memorial'],
    'our lord jesus christ, king of the universe': ['christ the king', 'kingdom', 'praise'],
  };
  
  static const Map<String, int> _feastRank = {
    'solemnity': 3,
    'feast': 2,
    'memorial': 1,
    'optional memorial': 1,
    'feria': 0,
    'sunday': 1,
  };
  
  EnhancedLiturgicalContext buildContext(Map<String, dynamic> liturgicalDay) {
    final seasonKey = liturgicalDay['season']?.toString().toLowerCase() ?? 'ordinaryTime';
    final feastTitle = liturgicalDay['feast']?.toString().toLowerCase() ?? '';
    final feastType = liturgicalDay['feastType']?.toString().toLowerCase() ?? 'feria';
    
    // Determine feast categories and rank
    final feastCategories = _feastCategories.entries
        .where((entry) => feastTitle.contains(entry.key))
        .expand((entry) => entry.value)
        .toList();
    
    final feastRank = _feastRank[feastType] ?? 0;
    final seasonCategories = _seasonPrimaryCategories[seasonKey] ?? ['general'];
    
    // Determine special rules
    final isAlleluiaPermitted = seasonKey != 'lent' && seasonKey != 'holyWeek';
    final isGloriaPermitted = seasonKey != 'lent' && seasonKey != 'holyWeek';
    
    final specialRules = <String, dynamic>{
      'isAlleluiaPermitted': isAlleluiaPermitted,
      'isGloriaPermitted': isGloriaPermitted,
      'requiresPenitentialCharacter': seasonKey == 'lent' || seasonKey == 'holyWeek',
      'preferJoyfulCharacter': seasonKey == 'easter' || seasonKey == 'christmas',
      'allowMarianEmphasis': feastCategories.contains('marian') || seasonKey == 'christmas',
    };
    
    return EnhancedLiturgicalContext(
      seasonKey: seasonKey,
      feastTitle: feastTitle,
      feastRank: feastRank,
      feastCategories: feastCategories,
      seasonCategories: seasonCategories,
      isAlleluiaPermitted: isAlleluiaPermitted,
      isGloriaPermitted: isGloriaPermitted,
      specialRules: specialRules,
    );
  }
  
  LiturgicalValidation validateHymn(Hymn hymn, EnhancedLiturgicalContext context) {
    final violations = <String>[];
    final warnings = <String>[];
    
    // Check seasonal exclusions (hard blocking)
    final blockedSeasons = _seasonExclusions[context.seasonKey] ?? const <String>{};
    final hymnSeasons = hymn.liturgicalSeason?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
    
    // Check both liturgicalSeason and category for blocking
    for (final season in hymnSeasons) {
      if (blockedSeasons.contains(season)) {
        violations.add('Hymn season "$season" is incompatible with ${context.seasonKey}');
      }
    }
    
    // Also check categories for seasonal incompatibility (stronger blocking)
    for (final category in categories) {
      if (blockedSeasons.contains(category)) {
        violations.add('Hymn category "$category" is incompatible with ${context.seasonKey}');
      }
    }
    
    // Check Alleluia restrictions during Lent
    if (!context.isAlleluiaPermitted) {
      final title = hymn.title.toLowerCase();
      final lyrics = hymn.lyrics.join(' ').toLowerCase();
      if (title.contains('alleluia') || title.contains('hallelujah') || 
          lyrics.contains('alleluia') || lyrics.contains('hallelujah')) {
        violations.add('Alleluia/Hallelujah content not permitted during ${context.seasonKey}');
      }
    }
    
    // Check thematic appropriateness warnings
    if (context.seasonKey == 'lent' && categories.contains('christmas')) {
      warnings.add('Christmas hymn during Lenten season - consider alternative');
    }
    if (context.seasonKey == 'advent' && categories.contains('easter')) {
      warnings.add('Easter hymn during Advent season - consider alternative');
    }
    
    return LiturgicalValidation(
      isValid: violations.isEmpty,
      violations: violations,
      warnings: warnings,
    );
  }
  
  double calculateLiturgicalScore(Hymn hymn, EnhancedLiturgicalContext context, String? massPart) {
    final validation = validateHymn(hymn, context);
    if (!validation.isValid) return 0.0; // Hard block
    
    double score = 70.0; // Base score for passing validation
    
    // Seasonal appropriateness bonus
    final hymnSeasons = hymn.liturgicalSeason != null 
        ? hymn.liturgicalSeason!.toLowerCase().split(',').map((s) => s.trim()).toList() 
        : <String>[];
    if (hymnSeasons.contains(context.seasonKey)) {
      score += 15.0;
    }
    
    // Feast day matching bonus
    if (context.feastRank > 0) {
      final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
      for (final feastCategory in context.feastCategories) {
        if (categories.contains(feastCategory)) {
          score += 10.0 * context.feastRank;
          break;
        }
      }
    }
    
    // Mass part appropriateness
    if (massPart != null) {
      score += _calculateMassPartScore(hymn, massPart, context);
    }
    
    return score.clamp(0.0, 100.0);
  }
  
  double _calculateMassPartScore(Hymn hymn, String massPart, EnhancedLiturgicalContext context) {
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
    
    switch (massPart.toLowerCase()) {
      case 'entrance':
        if (categories.contains('entrance') || categories.contains('processional')) return 10.0;
        if (categories.contains('gathering')) return 8.0;
        break;
      case 'offertory':
        if (categories.contains('offertory')) return 10.0;
        if (categories.contains('eucharist') || categories.contains('sacrifice')) return 8.0;
        break;
      case 'communion':
        if (categories.contains('communion')) return 10.0;
        if (categories.contains('eucharist') || categories.contains('contemplative')) return 8.0;
        break;
      case 'dismissal':
        if (categories.contains('dismissal') || categories.contains('recessional')) return 10.0;
        if (categories.contains('mission') || categories.contains('praise')) return 8.0;
        break;
    }
    return 0.0;
  }
}

// ==================== PASTORAL JUDGMENT ENGINE ====================

/// Assesses community needs, formation, and participation factors
class PastoralJudgmentEngine {
  // User preferences would be stored in a real implementation
  final Map<String, int> _communityUsageHistory = {};
  
  double calculatePastoralScore(Hymn hymn, EnhancedLiturgicalContext context) {
    double score = 60.0; // Base score
    
    // Familiarity bonus (based on usage history)
    final hymnId = hymn.id.toString();
    final usageCount = _communityUsageHistory[hymnId] ?? 0;
    if (usageCount > 0) {
      score += (usageCount / 10.0).clamp(0.0, 15.0); // Max 15 points for familiarity
    }
    
    // Singability assessment based on metadata
    score += _assessSingability(hymn);
    
    // Theological educational value
    score += _assessEducationalValue(hymn, context);
    
    // Community participation factors
    score += _assessParticipationFactors(hymn);
    
    return score.clamp(0.0, 100.0);
  }
  
  double _assessSingability(Hymn hymn) {
    double score = 0.0;
    
    // Check for singability indicators in metadata
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    if (themes.contains('simple') || themes.contains('easy')) score += 5.0;
    if (themes.contains('repetitive') || themes.contains('call and response')) score += 3.0;
    if (themes.contains('complex') || themes.contains('difficult')) score -= 5.0;
    
    return score.clamp(-5.0, 10.0);
  }
  
  double _assessEducationalValue(Hymn hymn, EnhancedLiturgicalContext context) {
    double score = 0.0;
    
    // Theological depth indicators
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    
    if (themes.contains('scripture') || themes.contains('biblical')) score += 5.0;
    if (themes.contains('catechetical') || themes.contains('teaching')) score += 5.0;
    if (categories.contains('doctrine') || categories.contains('theology')) score += 3.0;
    
    // Seasonal educational appropriateness
    if (context.seasonKey == 'lent' && themes.contains('penitential')) score += 3.0;
    if (context.seasonKey == 'advent' && themes.contains('anticipation')) score += 3.0;
    if (context.seasonKey == 'easter' && themes.contains('resurrection')) score += 3.0;
    
    return score.clamp(0.0, 10.0);
  }
  
  double _assessParticipationFactors(Hymn hymn) {
    double score = 0.0;
    
    // Assembly-friendly characteristics
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    if (themes.contains('community') || themes.contains('gathering')) score += 3.0;
    if (themes.contains('responsive') || themes.contains('call and response')) score += 4.0;
    if (themes.contains('meditative') || themes.contains('contemplative')) score += 2.0;
    
    return score.clamp(0.0, 5.0);
  }
}

// ==================== MUSICAL JUDGMENT ENGINE ====================

/// Evaluates musical quality, artistry, and sacred character
class MusicalJudgmentEngine {
  double calculateMusicalScore(Hymn hymn, EnhancedLiturgicalContext context) {
    double score = 65.0; // Base score for meeting minimum requirements
    
    // Musical quality indicators
    score += _assessMusicalQuality(hymn);
    
    // Textual faithfulness to Catholic teaching
    score += _assessTextualFaithfulness(hymn);
    
    // Sacred character assessment
    score += _assessSacredCharacter(hymn, context);
    
    // Technical quality factors
    score += _assessTechnicalQuality(hymn);
    
    return score.clamp(0.0, 100.0);
  }
  
  double _assessMusicalQuality(Hymn hymn) {
    double score = 0.0;
    
    // Quality indicators from metadata
    final themeList = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    if (themeList.contains('traditional') || themeList.contains('classic')) score += 8.0;
    if (themeList.contains('contemporary') && themeList.contains('quality')) score += 5.0;
    if (themeList.contains('artistic') || themeList.contains('excellent')) score += 7.0;
    
    return score.clamp(0.0, 15.0);
  }
  
  double _assessTextualFaithfulness(Hymn hymn) {
    double score = 0.0;
    
    // Check for orthodox theological indicators
    final title = hymn.title.toLowerCase();
    final lyrics = hymn.lyrics.join(' ').toLowerCase();
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    
    // Positive indicators
    if (themes.contains('orthodox') || themes.contains('catholic')) score += 10.0;
    if (title.contains('trinity') || title.contains('eucharist') || title.contains('incarnation')) score += 5.0;
    if (lyrics.contains('father') && lyrics.contains('son') && lyrics.contains('holy spirit')) score += 5.0;
    
    // Negative indicators (theological concerns)
    if (themes.contains('heretical') || themes.contains('unorthodox')) score -= 20.0;
    
    return score.clamp(-10.0, 15.0);
  }
  
  double _assessSacredCharacter(Hymn hymn, EnhancedLiturgicalContext context) {
    double score = 0.0;
    
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    
    // Sacred character indicators
    if (themes.contains('sacred') || themes.contains('worship')) score += 8.0;
    if (themes.contains('reverent') || themes.contains('solemn')) score += 6.0;
    if (categories.contains('praise') || categories.contains('adoration')) score += 5.0;
    
    // Contextual appropriateness
    if (context.seasonKey == 'lent' && themes.contains('solemn')) score += 3.0;
    if (context.seasonKey == 'easter' && themes.contains('joyful')) score += 3.0;
    
    return score.clamp(0.0, 10.0);
  }
  
  double _assessTechnicalQuality(Hymn hymn) {
    double score = 0.0;
    
    // Technical quality indicators
    final themes = hymn.themes?.toLowerCase().split(',').map((s) => s.trim()).toList() ?? [];
    if (themes.contains('well-crafted') || themes.contains('polished')) score += 5.0;
    if (themes.contains('professional') || themes.contains('excellent')) score += 3.0;
    
    return score.clamp(0.0, 5.0);
  }
}

// ==================== THEOLOGICAL THEME EXTRACTOR ====================

/// Advanced semantic analysis for theological theme detection
class TheologicalThemeExtractor {
  static const Map<String, List<String>> _theologicalThemes = {
    'creation': ['creation', 'creator', 'made', 'formed', 'beginning', 'genesis'],
    'fall': ['fall', 'sin', 'disobedience', 'forbidden', 'temptation', 'expulsion'],
    'redemption': ['redeem', 'save', 'salvation', 'rescue', 'deliver', 'ransom'],
    'sanctification': ['sanctify', 'holy', 'saint', 'purify', 'consecrate', 'make holy'],
    'incarnation': ['incarnat', 'word made flesh', 'emmanuel', 'born child', 'nativity'],
    'passion': ['passion', 'cross', 'crucif', 'suffer', 'death', 'calvary'],
    'resurrection': ['resurrection', 'risen', 'alive', 'victory', 'empty tomb'],
    'ascension': ['ascension', 'ascended', 'heaven', 'right hand', 'glorified'],
    'eucharist': ['bread', 'wine', 'body', 'blood', 'communion', 'eucharist', 'table'],
    'baptism': ['bapti', 'water', 'cleansed', 'born again', 'holy spirit'],
    'confirmation': ['confirm', 'spirit', 'seal', 'anoint', 'strengthen'],
    'reconciliation': ['reconcil', 'forgive', 'mercy', 'pardon', 'confess'],
    'anointing': ['anoint', 'heal', 'sick', 'suffering', 'oil'],
    'holyOrders': ['priest', 'deacon', 'bishop', 'ordain', 'ministry'],
    'marriage': ['marriage', 'union', 'covenant', 'love', 'faithful'],
    'trinity': ['trinity', 'father', 'son', 'holy spirit', 'three persons'],
    'mary': ['mary', 'virgin', 'mother', 'theotokos', 'marian'],
    'saints': ['saint', 'martyr', 'witness', 'holy ones', 'blessed'],
    'church': ['church', 'body of christ', 'community', 'assembly', 'people of god'],
    'eschatology': ['heaven', 'eternal', 'last day', 'judgment', 'new creation'],
  };
  
  Map<String, double> extractTheologicalThemes(List<DailyReading> readings) {
    final themeWeights = <String, double>{};
    
    for (final reading in readings) {
      final text = (reading.reading ?? '').toLowerCase();
      final source = reading.source?.toLowerCase() ?? '';
      
      // Weight by source importance
      double weight = 1.0;
      if (source.contains('gospel')) weight = 1.5;
      else if (source.contains('psalm')) weight = 0.5;
      else if (source.contains('reading')) weight = 1.0;
      
      // Extract themes
      for (final entry in _theologicalThemes.entries) {
        final theme = entry.key;
        final keywords = entry.value;
        
        int matches = 0;
        for (final keyword in keywords) {
          if (text.contains(keyword)) matches++;
        }
        
        if (matches > 0) {
          themeWeights[theme] = (themeWeights[theme] ?? 0.0) + (matches * weight);
        }
      }
    }
    
    return themeWeights;
  }
  
  double calculateThemeMatchScore(Hymn hymn, Map<String, double> readingThemes) {
    if (readingThemes.isEmpty) return 0.0;
    
    final hymnText = [
      hymn.title.toLowerCase(),
      hymn.lyrics.join(' ').toLowerCase(),
      (hymn.themes ?? '').toLowerCase(),
      hymn.category.toLowerCase(),
    ].join(' ');
    
    double score = 0.0;
    double totalWeight = 0.0;
    
    for (final entry in readingThemes.entries) {
      final theme = entry.key;
      final weight = entry.value;
      totalWeight += weight;
      
      final keywords = _theologicalThemes[theme] ?? [];
      int matches = 0;
      for (final keyword in keywords) {
        if (hymnText.contains(keyword)) matches++;
      }
      
      if (matches > 0) {
        score += (matches / keywords.length) * weight;
      }
    }
    
    return totalWeight > 0 ? (score / totalWeight) * 100.0 : 0.0;
  }
}

// ==================== THREE JUDGMENTS INTEGRATION ENGINE ====================

/// Unified evaluation combining all Three Judgments
class ThreeJudgmentsIntegrationEngine {
  final LiturgicalJudgmentEngine _liturgicalEngine = LiturgicalJudgmentEngine();
  final PastoralJudgmentEngine _pastoralEngine = PastoralJudgmentEngine();
  final MusicalJudgmentEngine _musicalEngine = MusicalJudgmentEngine();
  final TheologicalThemeExtractor _themeExtractor = TheologicalThemeExtractor();
  
  ThreeJudgmentsScore evaluateHymn(
    Hymn hymn,
    EnhancedLiturgicalContext context,
    Map<String, double> readingThemes, {
    String? massPart,
  }) {
    // Calculate individual judgment scores
    final liturgicalScore = _liturgicalEngine.calculateLiturgicalScore(hymn, context, massPart);
    final pastoralScore = _pastoralEngine.calculatePastoralScore(hymn, context);
    final musicalScore = _musicalEngine.calculateMusicalScore(hymn, context);
    
    // Theme matching bonus
    final themeScore = _themeExtractor.calculateThemeMatchScore(hymn, readingThemes);
    
    // Combined score with liturgical primacy (40% liturgical, 30% pastoral, 30% musical)
    final combinedScore = (liturgicalScore * 0.4) + (pastoralScore * 0.3) + (musicalScore * 0.3);
    
    // Add theme bonus as extra credit
    final finalScore = (combinedScore * 0.8) + (themeScore * 0.2);
    
    final evaluationDetails = <String, dynamic>{
      'liturgicalScore': liturgicalScore,
      'pastoralScore': pastoralScore,
      'musicalScore': musicalScore,
      'themeScore': themeScore,
      'combinedScore': combinedScore,
      'finalScore': finalScore,
      'passesLiturgicalJudgment': liturgicalScore >= 70,
      'passesPastoralJudgment': pastoralScore >= 60,
      'passesMusicalJudgment': musicalScore >= 65,
      'validation': _liturgicalEngine.validateHymn(hymn, context),
    };
    
    return ThreeJudgmentsScore(
      liturgicalScore: liturgicalScore,
      pastoralScore: pastoralScore,
      musicalScore: musicalScore,
      combinedScore: finalScore,
      evaluationDetails: evaluationDetails,
    );
  }
}

// ==================== MAIN ROBUST SERVICE ====================

class RobustHymnRecommendationService extends BaseService<RobustHymnRecommendationService> {
  static RobustHymnRecommendationService get instance =>
      BaseService.init(() => RobustHymnRecommendationService._());
  
  RobustHymnRecommendationService._();
  
  final HymnService _hymnService = HymnService.instance;
  final ImprovedLiturgicalCalendarService _calendar = ImprovedLiturgicalCalendarService.instance;
  final ThreeJudgmentsIntegrationEngine _integrationEngine = ThreeJudgmentsIntegrationEngine();
  
  /// Get comprehensive recommendations using Three Judgments framework
  Future<List<Hymn>> getRobustRecommendations(
    DateTime date,
    List<DailyReading> readings, {
    String? massPart,
    int maxResults = 10,
  }) async {
    // Build enhanced liturgical context
    final liturgicalDay = _calendar.getLiturgicalDay(date);
    final context = _integrationEngine._liturgicalEngine.buildContext({
      'season': liturgicalDay.season.name,
      'feast': liturgicalDay.title,
      'feastType': liturgicalDay.rank ?? 'feria',
    });
    
    // Extract theological themes from readings
    final readingThemes = _integrationEngine._themeExtractor.extractTheologicalThemes(readings);
    
    // Get all hymns and evaluate
    final allHymns = await _hymnService.getHymnsFromAssets();
    final evaluatedHymns = <Hymn, ThreeJudgmentsScore>{};
    
    for (final hymn in allHymns) {
      // Filter by mass part category if specified
      if (massPart != null) {
        final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
        // Only include hymns that match the mass part or are general
        if (!categories.contains(massPart) && !categories.contains('general')) {
          continue;
        }
      }
      
      final score = _integrationEngine.evaluateHymn(
        hymn,
        context,
        readingThemes,
        massPart: massPart,
      );
      
      // Only include hymns that pass liturgical judgment
      if (score.passesLiturgicalJudgment) {
        evaluatedHymns[hymn] = score;
      }
    }
    
    // Sort by combined score and return top results
    final sortedHymns = evaluatedHymns.entries.toList()
      ..sort((a, b) => b.value.combinedScore.compareTo(a.value.combinedScore));
    
    return sortedHymns
        .take(maxResults)
        .map((entry) => entry.key)
        .toList();
  }
  
  /// Get detailed evaluation for a specific hymn
  Future<ThreeJudgmentsScore?> evaluateHymn(
    Hymn hymn,
    DateTime date,
    List<DailyReading> readings, {
    String? massPart,
  }) async {
    final liturgicalDay = _calendar.getLiturgicalDay(date);
    final context = _integrationEngine._liturgicalEngine.buildContext({
      'season': liturgicalDay.season.name,
      'feast': liturgicalDay.title,
      'feastType': liturgicalDay.rank ?? 'feria',
    });
    
    final readingThemes = _integrationEngine._themeExtractor.extractTheologicalThemes(readings);
    
    return _integrationEngine.evaluateHymn(
      hymn,
      context,
      readingThemes,
      massPart: massPart,
    );
  }
  
  /// Get recommendations for all mass parts with minimum guarantee
  Future<Map<String, List<Hymn>>> getMassPartRecommendations(
    DateTime date,
    List<DailyReading> readings, {
    int maxResultsPerPart = 5,
    int minResultsPerPart = 2,
  }) async {
    // Only these 4 mass parts are used for recommendations
    final massParts = ['entrance', 'offertory', 'communion', 'dismissal'];
    final results = <String, List<Hymn>>{};
    
    for (final part in massParts) {
      var recommendations = await getRobustRecommendations(
        date,
        readings,
        massPart: part,
        maxResults: maxResultsPerPart,
      );
      
      // Fallback: If we don't have minimum hymns, get more with relaxed criteria
      if (recommendations.length < minResultsPerPart) {
        final allHymns = await _hymnService.getHymnsFromAssets();
        
        // Get hymns that match the specific mass part category (only the 4 allowed)
        final categoryMatches = allHymns.where((hymn) {
          final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
          // Only match if the category is exactly one of the 4 mass parts
          return categories.contains(part);
        }).toList();
        
        // Add category-matched hymns to reach minimum
        for (final hymn in categoryMatches) {
          if (!recommendations.contains(hymn)) {
            recommendations.add(hymn);
            if (recommendations.length >= minResultsPerPart) break;
          }
        }
      }
      
      results[part] = recommendations;
    }
    
    return results;
  }
}
