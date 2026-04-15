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

import 'dart:math';

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
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
    
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
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
    
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

// ==================== RICH TEXT THEME EXTRACTOR ====================

/// Extracts theological themes from actual text fields on DailyReading:
/// incipit, psalmResponse, gospelAcclamation, and feast name.
/// Uses synonym clusters so hymn lyrics can be matched meaningfully.
class RichTextThemeExtractor {
  // Each theme maps to synonyms checked against DailyReading text fields
  // AND against hymn title + first_line + lyrics.
  static const Map<String, List<String>> _themeSynonyms = {
    'shepherd': ['shepherd', 'sheep', 'flock', 'pasture', 'lead', 'stray', 'lost', 'found', 'lambs', 'herd', 'goat'],
    'eucharist': ['bread', 'wine', 'body', 'blood', 'table', 'feed', 'eat', 'drink', 'hunger', 'thirst', 'nourish', 'feast', 'supper', 'manna', 'loaves'],
    'mercy': ['mercy', 'forgive', 'pardon', 'compassion', 'tender', 'kindness', 'gentle', 'reconcil', 'guilt', 'sin', 'contrite', 'penitent', 'sorrow', 'repent'],
    'light': ['light', 'darkness', 'lamp', 'shine', 'blind', 'sight', 'see', 'dawn', 'radiance', 'glory', 'illuminate', 'beacon', 'star', 'sun'],
    'mission': ['send', 'go forth', 'proclaim', 'witness', 'apostle', 'nations', 'world', 'spread', 'preach', 'announce', 'herald', 'mission', 'disciple', 'fishers'],
    'resurrection': ['risen', 'resurrection', 'alive', 'victory', 'tomb', 'death', 'life', 'raised', 'conquer', 'glorified', 'alleluia', 'hallelujah', 'living'],
    'holySpirit': ['spirit', 'holy spirit', 'pentecost', 'fire', 'wind', 'breath', 'advocate', 'comforter', 'paraclete', 'anointed', 'filled', 'gifts', 'fruits'],
    'faith': ['faith', 'believe', 'trust', 'hope', 'confident', 'assurance', 'anchor', 'doubt', 'certainty', 'commit', 'reliance', 'firm', 'foundation'],
    'healing': ['heal', 'cure', 'sick', 'leper', 'blind', 'lame', 'deaf', 'raise', 'restore', 'wholeness', 'cleanse', 'well', 'infirm', 'suffering'],
    'praise': ['praise', 'glory', 'honor', 'worship', 'magnify', 'bless', 'exalt', 'acclaim', 'jubilee', 'sing', 'hymn', 'rejoice', 'thanksgiving', 'grateful'],
    'kingdom': ['kingdom', 'reign', 'king', 'throne', 'crown', 'lord', 'rule', 'dominion', 'power', 'majesty', 'sovereign', 'authority', 'christ the king'],
    'covenant': ['covenant', 'promise', 'faithful', 'chosen', 'people', 'inheritance', 'law', 'commandment', 'testament', 'seal', 'bond', 'pledge'],
    'sacrifice': ['sacrifice', 'offer', 'oblation', 'gift', 'altar', 'priest', 'atonement', 'lamb', 'immolate', 'victim', 'incense', 'consecrate'],
    'water': ['water', 'river', 'stream', 'spring', 'living water', 'thirst', 'fountain', 'well', 'rain', 'flood', 'baptism', 'cleanse', 'wash'],
    'word': ['word', 'scripture', 'gospel', 'teach', 'wisdom', 'truth', 'law', 'prophet', 'voice', 'logos', 'proclaim', 'listen', 'hear'],
    'marian': ['mary', 'virgin', 'mother', 'immaculate', 'assumption', 'rosary', 'queen', 'ave', 'magnificat', 'handmaid', 'lady', 'annunciation'],
    'advent': ['come', 'coming', 'wait', 'prepare', 'maranatha', 'advent', 'expectation', 'hope', 'watchful', 'ready', 'awaken', 'dawn', 'Emmanuel'],
    'passion': ['cross', 'crucif', 'suffer', 'calvary', 'wound', 'thorn', 'nail', 'gethsemane', 'agony', 'betrayal', 'passion', 'lament', 'sorrow'],
    'peace': ['peace', 'shalom', 'reconcil', 'unity', 'harmony', 'still', 'quiet', 'rest', 'comfort', 'solace', 'tranquil', 'serene'],
    'love': ['love', 'charity', 'agape', 'beloved', 'heart', 'tenderness', 'devoted', 'care', 'embrace', 'friend', 'neighbor', 'commandment'],
    'eternal': ['eternal', 'everlasting', 'immortal', 'heaven', 'paradise', 'last day', 'judgment', 'new creation', 'new earth', 'life eternal', 'resurrection'],
    'creation': ['creation', 'creator', 'made', 'formed', 'earth', 'nature', 'sky', 'sea', 'creature', 'universe', 'genesis', 'sustain'],
    'trinity': ['trinity', 'father', 'son', 'holy spirit', 'three', 'triune', 'doxology', 'persons', 'godhead'],
    'call': ['call', 'vocation', 'chosen', 'follow', 'leave', 'nets', 'come after', 'disciple', 'invite', 'welcome', 'gather', 'seek'],
    'justice': ['justice', 'poor', 'oppressed', 'widow', 'orphan', 'hungry', 'stranger', 'righteous', 'equity', 'liberation', 'freedom', 'captive'],
  };

  // Direct feast-name → theme mappings (highest priority signal)
  static const Map<String, List<String>> _feastThemes = {
    'holy thursday': ['eucharist', 'love', 'sacrifice'],
    'good friday': ['passion', 'sacrifice', 'love'],
    'easter': ['resurrection', 'praise', 'eternal'],
    'easter vigil': ['resurrection', 'water', 'light'],
    'pentecost': ['holySpirit', 'mission', 'praise'],
    'ascension': ['kingdom', 'mission', 'eternal'],
    'trinity': ['trinity', 'praise', 'faith'],
    'corpus christi': ['eucharist', 'praise', 'sacrifice'],
    'body and blood': ['eucharist', 'sacrifice', 'praise'],
    'sacred heart': ['love', 'mercy', 'passion'],
    'christ the king': ['kingdom', 'praise', 'eternal'],
    'all saints': ['eternal', 'praise', 'faith'],
    'immaculate conception': ['marian', 'mercy', 'advent'],
    'assumption': ['marian', 'eternal', 'praise'],
    'annunciation': ['marian', 'advent', 'word'],
    'baptism of the lord': ['water', 'holySpirit', 'call'],
    'epiphany': ['light', 'mission', 'kingdom'],
    'presentation': ['light', 'sacrifice', 'marian'],
    'palm sunday': ['passion', 'kingdom', 'sacrifice'],
    'ash wednesday': ['mercy', 'passion', 'covenant'],
  };

  /// Extract weighted themes from all rich text fields in today's readings.
  /// Returns map of theme → weight (higher = stronger signal).
  Map<String, double> extractFromReadings(List<DailyReading> readings) {
    final weights = <String, double>{};

    // Apply feast-name themes first (strong direct signal)
    for (final reading in readings) {
      final feast = reading.feast?.toLowerCase() ?? '';
      if (feast.isEmpty) continue;
      for (final entry in _feastThemes.entries) {
        if (feast.contains(entry.key)) {
          for (final theme in entry.value) {
            weights[theme] = (weights[theme] ?? 0.0) + 2.0;
          }
        }
      }
    }

    for (final reading in readings) {
      final position = (reading.position ?? '').toLowerCase();
      final isGospel = position.contains('gospel');
      final isPsalm = position.contains('psalm');

      // Build weighted text segments from rich fields
      final segments = <_TextSegment>[
        if ((reading.gospelAcclamation ?? '').isNotEmpty)
          _TextSegment(reading.gospelAcclamation!.toLowerCase(), isGospel ? 2.0 : 1.5),
        if ((reading.incipit ?? '').isNotEmpty)
          _TextSegment(reading.incipit!.toLowerCase(), isGospel ? 2.0 : 1.0),
        if ((reading.psalmResponse ?? '').isNotEmpty)
          _TextSegment(reading.psalmResponse!.toLowerCase(), isPsalm ? 1.5 : 1.0),
      ];

      for (final segment in segments) {
        for (final entry in _themeSynonyms.entries) {
          final theme = entry.key;
          final synonyms = entry.value;
          int hits = 0;
          for (final syn in synonyms) {
            if (segment.text.contains(syn)) hits++;
          }
          if (hits > 0) {
            weights[theme] = (weights[theme] ?? 0.0) + (hits * segment.weight);
          }
        }
      }
    }

    return weights;
  }

  /// Score a hymn against a set of active reading themes.
  /// Scans title (3x), firstLine (2x), and full lyrics (1x).
  double scoreHymnAgainstThemes(Hymn hymn, Map<String, double> readingThemes) {
    if (readingThemes.isEmpty) return 0.0;

    final titleText = hymn.title.toLowerCase();
    final firstLineText = (hymn.firstLine ?? '').toLowerCase();
    final lyricsText = hymn.displayLyrics.join(' ').toLowerCase();

    double score = 0.0;
    double totalWeight = 0.0;

    for (final entry in readingThemes.entries) {
      final theme = entry.key;
      final themeWeight = entry.value;
      totalWeight += themeWeight;

      final synonyms = _themeSynonyms[theme] ?? [];
      double hymnHits = 0.0;
      for (final syn in synonyms) {
        if (titleText.contains(syn)) hymnHits += 3.0;
        if (firstLineText.contains(syn) && firstLineText != titleText) hymnHits += 2.0;
        if (lyricsText.contains(syn)) hymnHits += 1.0;
      }
      if (hymnHits > 0 && synonyms.isNotEmpty) {
        score += (hymnHits / (synonyms.length * 3.0)) * themeWeight;
      }
    }

    return totalWeight > 0 ? (score / totalWeight) * 100.0 : 0.0;
  }

  /// Return the top N theme keys by weight.
  List<String> topThemes(Map<String, double> weights, {int n = 3}) {
    final sorted = weights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Build a focused theme map for a specific mass part.
  /// Each part is steered toward a different aspect of the day's readings.
  Map<String, double> themeMapForPart(
    String massPart,
    Map<String, double> allThemes,
  ) {
    final partThemes = Map<String, double>.from(allThemes);

    switch (massPart.toLowerCase()) {
      case 'entrance':
        // Amplify call/kingdom/praise — sets the gathering tone
        _boost(partThemes, ['call', 'kingdom', 'praise', 'advent', 'light'], 1.5);
        break;
      case 'offertory':
        // Amplify sacrifice/covenant/word — the offering moment
        _boost(partThemes, ['sacrifice', 'covenant', 'word', 'creation', 'love'], 1.5);
        break;
      case 'communion':
        // Always strongly amplify eucharist cluster
        _boost(partThemes, ['eucharist', 'shepherd', 'water', 'peace', 'love'], 2.0);
        partThemes['eucharist'] = (partThemes['eucharist'] ?? 0.0) + 4.0; // baseline boost
        break;
      case 'dismissal':
        // Amplify mission/praise/eternal — sending the assembly
        _boost(partThemes, ['mission', 'praise', 'eternal', 'justice', 'holySpirit'], 1.5);
        break;
    }
    return partThemes;
  }

  void _boost(Map<String, double> map, List<String> keys, double multiplier) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        map[key] = map[key]! * multiplier;
      } else {
        map[key] = multiplier; // introduce even if not detected in readings
      }
    }
  }
}

class _TextSegment {
  final String text;
  final double weight;
  const _TextSegment(this.text, this.weight);
}

// ==================== THREE JUDGMENTS INTEGRATION ENGINE ====================

/// Unified evaluation combining all Three Judgments
class ThreeJudgmentsIntegrationEngine {
  final LiturgicalJudgmentEngine _liturgicalEngine = LiturgicalJudgmentEngine();
  final PastoralJudgmentEngine _pastoralEngine = PastoralJudgmentEngine();
  final MusicalJudgmentEngine _musicalEngine = MusicalJudgmentEngine();
  final RichTextThemeExtractor themeExtractor = RichTextThemeExtractor();

  ThreeJudgmentsScore evaluateHymn(
    Hymn hymn,
    EnhancedLiturgicalContext context,
    Map<String, double> readingThemes, {
    String? massPart,
  }) {
    final liturgicalScore = _liturgicalEngine.calculateLiturgicalScore(hymn, context, massPart);
    final pastoralScore = _pastoralEngine.calculatePastoralScore(hymn, context);
    final musicalScore = _musicalEngine.calculateMusicalScore(hymn, context);

    // General hymns are eligible for any part but get a small category-match penalty
    final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
    final isGeneralHymn = categories.contains('general') && massPart != null && !categories.contains(massPart);
    final generalPenalty = isGeneralHymn ? -5.0 : 0.0;

    final themeScore = themeExtractor.scoreHymnAgainstThemes(hymn, readingThemes);

    // Combined: liturgical primacy 35%, pastoral 25%, musical 20%, theme 20%
    final combinedScore = (liturgicalScore * 0.35) +
        (pastoralScore * 0.25) +
        (musicalScore * 0.20) +
        (themeScore * 0.20) +
        generalPenalty;

    final evaluationDetails = <String, dynamic>{
      'liturgicalScore': liturgicalScore,
      'pastoralScore': pastoralScore,
      'musicalScore': musicalScore,
      'themeScore': themeScore,
      'combinedScore': combinedScore,
      'passesLiturgicalJudgment': liturgicalScore >= 70,
      'passesPastoralJudgment': pastoralScore >= 60,
      'passesMusicalJudgment': musicalScore >= 65,
      'validation': _liturgicalEngine.validateHymn(hymn, context),
    };

    return ThreeJudgmentsScore(
      liturgicalScore: liturgicalScore,
      pastoralScore: pastoralScore,
      musicalScore: musicalScore,
      combinedScore: combinedScore,
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
  
  /// Get comprehensive recommendations using Three Judgments framework.
  /// [partThemes] is a pre-computed theme map for this specific mass part.
  /// [dateSeed] drives the deterministic daily rotation within the top-N pool.
  Future<List<Hymn>> getRobustRecommendations(
    DateTime date,
    List<DailyReading> readings, {
    String? massPart,
    Map<String, double>? partThemes,
    int maxResults = 5,
    int candidatePoolSize = 12,
  }) async {
    final liturgicalDay = _calendar.getLiturgicalDay(date);
    final context = _integrationEngine._liturgicalEngine.buildContext({
      'season': liturgicalDay.season.name,
      'feast': liturgicalDay.title,
      'feastType': liturgicalDay.rank ?? 'feria',
    });

    // Use pre-computed part-specific themes if provided, else extract fresh
    final readingThemes = partThemes ??
        _integrationEngine.themeExtractor.extractFromReadings(readings);

    final allHymns = await _hymnService.getHymnsFromAssets();
    final evaluatedHymns = <Hymn, ThreeJudgmentsScore>{};

    for (final hymn in allHymns) {
      if (massPart != null) {
        final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
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

      if (score.passesLiturgicalJudgment) {
        evaluatedHymns[hymn] = score;
      }
    }

    // Sort by combined score to get quality candidates
    final sortedHymns = evaluatedHymns.entries.toList()
      ..sort((a, b) => b.value.combinedScore.compareTo(a.value.combinedScore));

    // Take a candidate pool larger than maxResults
    final pool = sortedHymns
        .take(candidatePoolSize)
        .map((e) => e.key)
        .toList();

    // Apply deterministic date-seeded shuffle within the pool for daily variety
    // Same date always yields same order; different dates rotate through the pool
    final dateSeed = date.year * 1000 + _dayOfYear(date);
    final partOffset = massPart != null ? massPart.hashCode.abs() % 97 : 0;
    final rng = Random(dateSeed + partOffset);
    for (int i = pool.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }

    return pool.take(maxResults).toList();
  }

  int _dayOfYear(DateTime date) {
    return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
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

    final readingThemes = _integrationEngine.themeExtractor.extractFromReadings(readings);

    return _integrationEngine.evaluateHymn(
      hymn,
      context,
      readingThemes,
      massPart: massPart,
    );
  }
  
  /// Get recommendations for all mass parts with per-part theme targeting
  /// and date-seeded rotation for daily variety.
  Future<Map<String, List<Hymn>>> getMassPartRecommendations(
    DateTime date,
    List<DailyReading> readings, {
    int maxResultsPerPart = 5,
    int minResultsPerPart = 2,
  }) async {
    // Extract themes once from all readings (expensive — do not repeat per part)
    final allThemes = _integrationEngine.themeExtractor.extractFromReadings(readings);

    const massParts = ['entrance', 'offertory', 'communion', 'dismissal'];
    final results = <String, List<Hymn>>{};

    for (final part in massParts) {
      // Build a part-specific theme map (steers scoring toward the right aspect)
      final partThemes = _integrationEngine.themeExtractor.themeMapForPart(part, allThemes);

      var recommendations = await getRobustRecommendations(
        date,
        readings,
        massPart: part,
        partThemes: partThemes,
        maxResults: maxResultsPerPart,
      );

      // Fallback: guarantee minimum results using category matches
      if (recommendations.length < minResultsPerPart) {
        final allHymns = await _hymnService.getHymnsFromAssets();
        final categoryMatches = allHymns.where((hymn) {
          final categories = hymn.category.toLowerCase().split(',').map((s) => s.trim()).toList();
          return categories.contains(part) && !recommendations.contains(hymn);
        }).toList();

        for (final hymn in categoryMatches) {
          recommendations.add(hymn);
          if (recommendations.length >= minResultsPerPart) break;
        }
      }

      results[part] = recommendations;
    }

    return results;
  }
}
