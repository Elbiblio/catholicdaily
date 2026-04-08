// hymn_recommendation_service.dart
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │                    HymnRecommendationService                            │
// │                                                                         │
// │  DEPRECATED: Use RobustHymnRecommendationService instead               │
// │                                                                         │
// │  This service has been replaced by the USCCB Three Judgments framework │
// │  implementation (RobustHymnRecommendationService) which provides:        │
// │  • Proper liturgical compliance validation                              │
// │  • USCCB Three Judgments framework (Liturgical, Pastoral, Musical)     │
// │  • Advanced theological theme extraction                                 │
// │  • Hierarchical filtering with quality thresholds                      │
// │                                                                         │
// │  Migration: Replace HymnRecommendationService.instance with             │
// │  RobustHymnRecommendationService.instance in your code.                 │
// │                                                                         │
// │  A four-layer pipeline for reliable, liturgically-correct hymn          │
// │  recommendations.                                                       │
// │                                                                         │
// │  Layer 0 — Season Gate      Hard-excludes liturgically incompatible     │
// │                             hymns before any scoring begins.            │
// │                             (No Christmas hymns in Lent, ever.)         │
// │                                                                         │
// │  Layer 1 — Theme Extraction Analyses readings by source weight          │
// │                             (Gospel 1.5× > 1st Reading 1× > …) and     │
// │                             maps content to named LiturgicalThemes.     │
// │                                                                         │
// │  Layer 2 — Multi-factor     Scores each eligible hymn across:           │
// │            Scoring          • Season/feast category match               │
// │                             • Reading theme match                       │
// │                             • Mass-part character match                 │
// │                             • Explicit liturgicalSeason metadata        │
// │                                                                         │
// │  Layer 3 — Mass-part        Re-weights scores per the liturgical        │
// │            Ranking          character of each mass part (offertory,     │
// │                             communion etc.) and guarantees a minimum    │
// │                             of two results.                             │
// └─────────────────────────────────────────────────────────────────────────┘

import '../models/hymn.dart';
import '../models/daily_reading.dart';
import 'hymn_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'base_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Supporting types
// ═════════════════════════════════════════════════════════════════════════════

/// High-level liturgical/theological themes that can be detected in readings
/// and matched against hymn metadata.
enum LiturgicalTheme {
  // Christological
  incarnation,
  passion,
  resurrection,
  ascension,
  kingship,
  // Sacramental
  eucharist,
  baptism,
  reconciliation,
  // Pneumatological
  holySpirit,
  // Marian
  marian,
  // Theological virtues and dispositions
  faith,
  hope,
  love,
  trust,
  mercy,
  forgiveness,
  repentance,
  humility,
  holiness,
  // Nature / scriptural imagery
  light,
  shepherd,
  water,
  // Community and mission
  gathering,
  praise,
  thanksgiving,
  mission,
  // Eschatological
  eternal,
  kingdom,
  // Pastoral / emotional
  comfort,
  healing,
  strength,
  peace,
  joy,
  // Sacrifice / offering
  sacrifice,
  offering,
}

/// Defines how to detect a theme in readings and how to recognise it in hymns.
///
/// [readingTriggers] are substrings looked for in reading text.
/// [hymnIndicators] are substrings looked for in hymn title/tags/themes/lyrics.
class _ThemeProfile {
  final LiturgicalTheme theme;
  final List<String> readingTriggers;
  final List<String> hymnIndicators;

  const _ThemeProfile({
    required this.theme,
    required this.readingTriggers,
    required this.hymnIndicators,
  });
}

/// A weighted reading source used during theme extraction.
class _WeightedReading {
  final String text;
  final double weight;
  const _WeightedReading(this.text, this.weight);
}

/// Describes the liturgical character of a single mass part.
class _MassPartProfile {
  final String primaryCategory;

  /// Themes that are thematically appropriate at this part of Mass.
  final List<LiturgicalTheme> preferredThemes;

  /// Hymn categories that are suitable for this part.
  final List<String> suitableCategories;

  const _MassPartProfile({
    required this.primaryCategory,
    required this.preferredThemes,
    required this.suitableCategories,
  });
}

/// Wraps a scored hymn; the breakdown map enables debugging and logging.
class ScoredHymn {
  final Hymn hymn;
  final int totalScore;
  final Map<String, int> breakdown;

  const ScoredHymn({
    required this.hymn,
    required this.totalScore,
    required this.breakdown,
  });
}

/// Encapsulates everything the scoring engine needs to know about the day.
class _LiturgicalContext {
  final String seasonKey;
  final String feastTitle;

  /// Ordered list of hymn categories associated with today's feast/solemnity.
  /// First entries carry more weight.
  final List<String> feastCategories;

  /// 0 = feria, 1 = optional/memorial, 2 = feast, 3 = solemnity.
  final int feastRank;

  /// Primary hymn categories for the current season.
  final List<String> seasonCategories;

  const _LiturgicalContext({
    required this.seasonKey,
    required this.feastTitle,
    required this.feastCategories,
    required this.feastRank,
    required this.seasonCategories,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// Main service
// ═════════════════════════════════════════════════════════════════════════════

class HymnRecommendationService
    extends BaseService<HymnRecommendationService> {
  static HymnRecommendationService get instance =>
      BaseService.init(() => HymnRecommendationService._());

  HymnRecommendationService._();

  final HymnService _hymnService = HymnService.instance;
  final ImprovedLiturgicalCalendarService _calendar =
      ImprovedLiturgicalCalendarService.instance;

  // ──────────────────────────────────────────────────────────────────────────
  // Layer 0 — Season eligibility gate
  // ──────────────────────────────────────────────────────────────────────────

  /// Hymn season tags that are forbidden for each liturgical season key.
  ///
  /// A hymn is excluded entirely if its [Hymn.liturgicalSeason] contains any
  /// value from the blocked set.  Hymns with no season tag are always allowed.
  static const Map<String, Set<String>> _seasonExclusions = {
    'advent': {'christmas', 'easter', 'lenten', 'penitential'},
    'christmas': {'advent', 'lenten', 'penitential', 'easter'},
    'lent': {'christmas', 'easter', 'advent'},
    'holyWeek': {'christmas', 'easter', 'advent'},
    'easterTriduum': {'christmas', 'advent', 'lenten'},
    'easter': {'christmas', 'lenten', 'penitential', 'advent'},
    'pentecost': {'christmas', 'lenten', 'penitential', 'advent'},
    'ordinaryTime': {'advent', 'christmas', 'lenten', 'easter'},
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Layer 1 — Semantic theme profiles
  // ──────────────────────────────────────────────────────────────────────────

  static const List<_ThemeProfile> _themeProfiles = [
    _ThemeProfile(
      theme: LiturgicalTheme.incarnation,
      readingTriggers: [
        'born', 'birth', 'child', 'infant', 'manger', 'bethlehem',
        'immanuel', 'emmanuel', 'word became', 'flesh', 'nativity',
        'virgin', 'joseph', 'swaddling', 'shepherds', 'magi', 'wise men',
      ],
      hymnIndicators: [
        'born', 'bethlehem', 'manger', 'infant', 'nativity', 'incarnat',
        'advent', 'christmas', 'emmanuel', 'word made flesh',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.passion,
      readingTriggers: [
        'cross', 'crucif', 'suffer', 'passion', 'betray', 'arrest',
        'trial', 'pilate', 'crown of thorns', 'gethsemane', 'golgotha',
        'calvary', 'tomb', 'burial', 'lament', 'death',
      ],
      hymnIndicators: [
        'cross', 'crucif', 'suffer', 'calvary', 'passion', 'atone',
        'lenten', 'penitential', 'golgotha', 'sacrifice',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.resurrection,
      readingTriggers: [
        'risen', 'resurrection', 'alive', 'empty tomb', 'he is not here',
        'alleluia', 'hallelujah', 'raised', 'new life', 'victory over death',
      ],
      hymnIndicators: [
        'risen', 'alleluia', 'hallelujah', 'resurrection', 'easter',
        'alive', 'victory', 'new life', 'conquer', 'death has no',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.ascension,
      readingTriggers: [
        'ascended', 'ascension', 'taken up', 'right hand of the father',
        'glorified', 'cloud', 'disciples watched', 'coming again',
      ],
      hymnIndicators: [
        'ascension', 'ascended', 'glory', 'throne', 'reign',
        'exalted', 'on high', 'right hand',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.kingship,
      readingTriggers: [
        'king', 'kingdom', 'reign', 'throne', 'dominion',
        'lord of lords', 'sovereign', 'majesty', 'crown',
        'all authority', 'power and glory', 'christ the king',
      ],
      hymnIndicators: [
        'king', 'kingdom', 'reign', 'throne', 'crown',
        'lord of lords', 'majesty', 'sovereign', 'christ the king',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.eucharist,
      readingTriggers: [
        'bread', 'wine', 'body', 'blood', 'cup', 'table', 'supper',
        'eat', 'drink', 'last supper', 'breaking of bread',
        'manna', 'bread of life', 'living bread', 'do this in memory',
        'new covenant',
      ],
      hymnIndicators: [
        'bread', 'wine', 'body and blood', 'communion', 'eucharist',
        'table', 'supper', 'manna', 'bread of life', 'cup',
        'host', 'adoration', 'corpus christi',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.baptism,
      readingTriggers: [
        'bapti', 'washed', 'born again', 'new birth', 'spirit descended',
        'beloved son', 'jordan', 'cleansed', 'purified', 'dove', 'font',
      ],
      hymnIndicators: [
        'bapti', 'washed', 'cleansed', 'born again', 'purified', 'font', 'renew',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.holySpirit,
      readingTriggers: [
        'spirit', 'pentecost', 'wind', 'fire', 'dove', 'advocate',
        'comforter', 'helper', 'tongues of fire', 'breath of god',
        'filled with the spirit', 'gifts of the spirit',
      ],
      hymnIndicators: [
        'spirit', 'pentecost', 'holy ghost', 'advocate', 'comforter',
        'wind', 'fire', 'breath', 'dove', 'veni sancte',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.marian,
      readingTriggers: [
        'mary', 'virgin', 'mother of god', 'theotokos', 'magnificat',
        'elizabeth', 'annunciation', 'immaculate', 'assumption',
        'woman clothed with the sun', 'our lady', 'blessed among women',
      ],
      hymnIndicators: [
        'mary', 'virgin', 'our lady', 'ave ', 'madonna', 'marian',
        'magnificat', 'immaculate', 'assumption', 'mother of god',
        'queen of heaven', 'salve regina', 'hail holy queen',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.trust,
      readingTriggers: [
        'trust', 'rely', 'lean not on your own', 'do not be afraid',
        'fear not', 'be not anxious', 'cast your cares', 'i am with you',
        'he will provide', 'do not worry', 'take heart', 'be still',
      ],
      hymnIndicators: [
        'trust', 'obey', 'rely', 'fear not', 'do not be afraid',
        'guide me', 'in his hands', 'safe', 'trusting', 'trust and obey',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.mercy,
      readingTriggers: [
        'mercy', 'compassion', 'forgive', 'pardon', 'prodigal',
        'lost sheep', 'seventy times seven', 'kyrie', 'have mercy',
        'steadfast love', 'hesed', 'tender', 'do not condemn',
        'go and sin no more',
      ],
      hymnIndicators: [
        'mercy', 'compassion', 'forgive', 'grace', 'pardon',
        'kyrie', 'have mercy', 'tender', 'prodigal',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.light,
      readingTriggers: [
        'light', 'darkness', 'shine', 'dawn', 'sun', 'star', 'lamp',
        'candle', 'i am the light', 'bright', 'radiant',
        'glory of god', 'transfigur', 'epiphany',
      ],
      hymnIndicators: [
        'light', 'shine', 'dawn', 'star', 'radiant', 'brightness',
        'illuminate', 'lamp', 'epiphany', 'transfigur',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.shepherd,
      readingTriggers: [
        'shepherd', 'sheep', 'flock', 'pasture', 'green pastures',
        'still waters', 'good shepherd', 'lost sheep', 'ninety-nine',
        'rod and staff', 'psalm 23',
      ],
      hymnIndicators: [
        'shepherd', 'sheep', 'flock', 'pasture', 'green pastures',
        'still waters', 'rod and staff',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.praise,
      readingTriggers: [
        'praise', 'glory', 'hallelujah', 'alleluia', 'sing', 'worship',
        'bless the lord', 'glorify', 'magnify', 'exalt', 'adore',
        'give thanks', 'joyful noise',
      ],
      hymnIndicators: [
        'praise', 'glory', 'alleluia', 'hallelujah', 'worship',
        'exalt', 'magnify', 'sing', 'adore', 'glorify',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.mission,
      readingTriggers: [
        'go and tell', 'proclaim', 'sent', 'mission', 'go into all',
        'witness', 'testify', 'herald', 'announce', 'make disciples',
        'preach', 'great commission', 'sent out',
      ],
      hymnIndicators: [
        'send', 'mission', 'go forth', 'herald', 'proclaim',
        'witness', 'commissioned', 'sent', 'go and tell',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.repentance,
      readingTriggers: [
        'repent', 'turn back', 'return to the lord', 'confess',
        'sinner', 'contrite', 'humbled myself', 'forgive me',
        'fast', 'ashes', 'lent',
      ],
      hymnIndicators: [
        'repent', 'confess', 'contrite', 'penitent', 'lenten',
        'ashes', 'forgive me', 'turn back', 'sinner',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.peace,
      readingTriggers: [
        'peace', 'shalom', 'reconcil', 'do not be troubled',
        'be still', 'calm', 'quietness', 'cease striving',
        'prince of peace', 'peace be with you',
      ],
      hymnIndicators: [
        'peace', 'shalom', 'still', 'calm', 'quietness',
        'tranquil', 'prince of peace', 'reconcil',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.joy,
      readingTriggers: [
        'rejoice', 'joy', 'glad', 'celebrate', 'feast', 'jubilee',
        'delight', 'good news', 'joyful noise', 'shout for joy',
      ],
      hymnIndicators: [
        'joy', 'rejoice', 'celebrate', 'glad', 'jubilate',
        'delight', 'joyful noise',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.healing,
      readingTriggers: [
        'heal', 'cure', 'blind', 'lame', 'deaf', 'leper',
        'made whole', 'rise and walk', 'sight restored',
        'touched him', 'cleansed', 'physician', 'power went out',
      ],
      hymnIndicators: [
        'heal', 'wholeness', 'restore', 'cure', 'balm',
        'physician', 'made whole',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.sacrifice,
      readingTriggers: [
        'sacrifice', 'offering', 'altar', 'lamb of god', 'atonement',
        'gave himself', 'ransomed', 'redeemed', 'blood of the covenant',
        'passover', 'redemption',
      ],
      hymnIndicators: [
        'sacrifice', 'offering', 'altar', 'atone', 'redeem',
        'ransom', 'lamb of god', 'agnus dei',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.eternal,
      readingTriggers: [
        'eternal life', 'everlasting', 'forever', 'heaven', 'paradise',
        'new creation', 'resurrection of the dead', 'last day',
        'new jerusalem',
      ],
      hymnIndicators: [
        'eternal', 'everlasting', 'forever', 'heaven', 'paradise',
        'immortal', 'new jerusalem', 'life eternal',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.comfort,
      readingTriggers: [
        'comfort', 'console', 'mourn', 'weep', 'sorrow',
        'brokenhearted', 'widow', 'affliction', 'burden',
        'come to me all', 'heavy laden',
      ],
      hymnIndicators: [
        'comfort', 'console', 'sorrow', 'mourn', 'afflict',
        'refuge', 'shelter', 'burden', 'balm',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.thanksgiving,
      readingTriggers: [
        'thanks', 'grateful', 'gratitude', 'give thanks', 'abundance',
        'harvest', 'provision', 'counted blessings',
      ],
      hymnIndicators: [
        'thank', 'grateful', 'gratitude', 'thanksgiving',
        'count your blessings', 'harvest',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.gathering,
      readingTriggers: [
        'gather', 'assembly', 'congregation', 'together', 'community',
        'one body', 'unity', 'family of god', 'people of god',
      ],
      hymnIndicators: [
        'gather', 'together', 'community', 'assembly', 'one body',
        'family', 'gathered here', 'we come', 'let us come',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.love,
      readingTriggers: [
        'love', 'beloved', 'charity', 'agape', 'love one another',
        'greater love', 'love the lord', 'love your neighbour',
        'abide in love',
      ],
      hymnIndicators: [
        'love', 'beloved', 'charity', 'love one another',
        'abide in love', 'love divine',
      ],
    ),
    _ThemeProfile(
      theme: LiturgicalTheme.strength,
      readingTriggers: [
        'strength', 'strong', 'mighty', 'power', 'armour of god',
        'shield of faith', 'battle', 'stand firm', 'endure',
        'persevere', 'courage', 'be strong',
      ],
      hymnIndicators: [
        'strength', 'strong', 'mighty', 'power', 'armour',
        'stand firm', 'endure', 'courage',
      ],
    ),
  ];

  // ──────────────────────────────────────────────────────────────────────────
  // Layer 2 — Mass part profiles
  // ──────────────────────────────────────────────────────────────────────────

  /// The liturgical character of each mass part.
  ///
  /// Based on GIRM §§ 47, 74, 87-88 and the principles of "Sing to the Lord"
  /// (USCCB, 2007):
  ///  • Entrance  – majestic, unifying, introduces the mystery of the day
  ///  • Offertory – theological depth, offering/sacrifice, gravitas
  ///  • Communion – intimate, joy of reception, communal union
  ///  • Dismissal – joyful sending-forth, mission, praise
  static const Map<String, _MassPartProfile> _massPartProfiles = {
    'entrance': _MassPartProfile(
      primaryCategory: 'entrance',
      preferredThemes: [
        LiturgicalTheme.gathering,
        LiturgicalTheme.praise,
        LiturgicalTheme.kingship,
        LiturgicalTheme.joy,
        LiturgicalTheme.light,
      ],
      suitableCategories: [
        'entrance', 'processional', 'gathering', 'general', 'praise',
      ],
    ),
    'offertory': _MassPartProfile(
      primaryCategory: 'offertory',
      preferredThemes: [
        LiturgicalTheme.sacrifice,
        LiturgicalTheme.offering,
        LiturgicalTheme.eucharist,
        LiturgicalTheme.trust,
        LiturgicalTheme.thanksgiving,
        LiturgicalTheme.love,
      ],
      suitableCategories: [
        'offertory', 'eucharist', 'thanksgiving', 'sacrifice', 'general',
      ],
    ),
    'communion': _MassPartProfile(
      primaryCategory: 'communion',
      preferredThemes: [
        LiturgicalTheme.eucharist,
        LiturgicalTheme.peace,
        LiturgicalTheme.love,
        LiturgicalTheme.healing,
        LiturgicalTheme.shepherd,
        LiturgicalTheme.comfort,
      ],
      suitableCategories: [
        'communion', 'eucharist', 'contemplative', 'intimate', 'general',
      ],
    ),
    'dismissal': _MassPartProfile(
      primaryCategory: 'dismissal',
      preferredThemes: [
        LiturgicalTheme.mission,
        LiturgicalTheme.joy,
        LiturgicalTheme.praise,
        LiturgicalTheme.eternal,
        LiturgicalTheme.thanksgiving,
        LiturgicalTheme.strength,
      ],
      suitableCategories: [
        'dismissal', 'recessional', 'mission', 'praise', 'general',
      ],
    ),
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Feast & solemnity → hymn category map
  // ──────────────────────────────────────────────────────────────────────────

  /// Maps canonical feast titles (all lowercase) to ordered hymn categories.
  ///
  /// Match is done via [String.contains] so partial matches work.
  /// List order matters: earlier entries receive a higher score bonus.
  static const Map<String, List<String>> _feastCategories = {
    // ── Advent / Christmas cycle ──
    'the nativity of the lord': ['christmas', 'incarnation', 'marian'],
    'the epiphany of the lord': ['christmas', 'light', 'general'],
    'the baptism of the lord': ['baptism', 'holy spirit', 'general'],
    'the presentation of the lord': ['marian', 'light', 'general'],
    'the annunciation of the lord': ['marian', 'incarnation', 'general'],
    // ── Lent / Holy Week ──
    'ash wednesday': ['penitential', 'lenten', 'repentance'],
    'palm sunday': ['passion', 'entrance', 'penitential'],
    'holy thursday': ['eucharist', 'communion', 'love'],
    'good friday': ['passion', 'lenten', 'penitential'],
    'holy saturday': ['easter vigil', 'baptism', 'light'],
    // ── Easter cycle ──
    'easter sunday': ['easter', 'resurrection', 'alleluia'],
    'divine mercy sunday': ['mercy', 'resurrection', 'trust'],
    'the ascension of the lord': ['ascension', 'kingdom', 'general'],
    'pentecost sunday': ['pentecost', 'holy spirit', 'mission'],
    // ── Trinity / Corpus Christi ──
    'the most holy trinity': ['trinity', 'holy spirit', 'general'],
    'the most holy body and blood of christ': ['eucharist', 'communion', 'adoration'],
    'the most sacred heart of jesus': ['sacred heart', 'love', 'mercy'],
    // ── Marian feasts ──
    'mary, mother of god': ['marian', 'incarnation', 'general'],
    'the immaculate conception': ['marian', 'general'],
    'the assumption of the blessed virgin mary': ['marian', 'eternal', 'general'],
    'our lady of the rosary': ['marian', 'general'],
    'our lady of sorrows': ['marian', 'passion', 'lenten'],
    'our lady of guadalupe': ['marian', 'general'],
    // ── Saints / other solemnities ──
    'all saints': ['saints', 'eternal', 'memorial'],
    'all souls': ['memorial', 'eternal', 'comfort'],
    'the birth of saint john the baptist': ['mission', 'light', 'general'],
    'saints peter and paul': ['mission', 'general'],
    'saint joseph': ['marian', 'trust', 'general'],
    'the transfiguration of the lord': ['light', 'glory', 'general'],
    // ── End-of-year ──
    'our lord jesus christ, king of the universe':
        ['christ the king', 'kingdom', 'praise'],
  };

  /// Numerical rank of each feast type. Higher = stronger scoring bonus.
  static const Map<String, int> _feastRank = {
    'solemnity': 3,
    'feast': 2,
    'memorial': 1,
    'optional memorial': 1,
    'feria': 0,
    'sunday': 1, // Ordinary Sundays treated like a memorial
  };

  // ──────────────────────────────────────────────────────────────────────────
  // Season → primary hymn categories
  // ──────────────────────────────────────────────────────────────────────────

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

  // ═════════════════════════════════════════════════════════════════════════
  // Public API
  // ═════════════════════════════════════════════════════════════════════════

  /// Returns up to [maxResults] hymns recommended for [date] based on the
  /// liturgical day alone (no readings required).
  Future<List<Hymn>> getRecommendedHymnsForDate(
    DateTime date, {
    int maxResults = 10,
  }) async {
    final ctx = _buildContext(_calendar.getLiturgicalDay(date));
    final eligible =
        _filterBySeasonEligibility(await _hymnService.getHymnsFromAssets(), ctx.seasonKey);

    return _sortByScore(
      eligible.map((h) => _scoreHymn(h, ctx, massPart: null)).toList(),
      maxResults,
    );
  }

  /// Returns up to [maxResults] hymns matched to the dominant themes found
  /// in [readings].
  Future<List<Hymn>> getRecommendedHymnsForReadings(
    List<DailyReading> readings, {
    int maxResults = 10,
  }) async {
    if (readings.isEmpty) return [];
    final themes = _extractThemesFromReadings(readings);
    final all = await _hymnService.getHymnsFromAssets();
    return _sortByScore(
      all.map((h) => _scoreHymnByThemes(h, themes)).toList(),
      maxResults,
    );
  }

  /// Returns up to [maxResults] hymns using both date context and reading
  /// themes.  This is the recommended method for weekly planning.
  Future<List<Hymn>> getCombinedRecommendations(
    DateTime date,
    List<DailyReading> readings, {
    int maxResults = 10,
  }) async {
    final ctx = _buildContext(_calendar.getLiturgicalDay(date));
    final themes = _extractThemesFromReadings(readings);
    final eligible =
        _filterBySeasonEligibility(await _hymnService.getHymnsFromAssets(), ctx.seasonKey);

    final scored = eligible.map((h) {
      final s1 = _scoreHymn(h, ctx, massPart: null);
      final s2 = _scoreHymnByThemes(h, themes);
      return ScoredHymn(
        hymn: h,
        totalScore: s1.totalScore + s2.totalScore,
        breakdown: {...s1.breakdown, ...s2.breakdown},
      );
    }).toList();

    return _sortByScore(scored, maxResults);
  }

  /// Returns tailored recommendations for all four mass parts at once.
  Future<Map<String, List<Hymn>>> getRecommendedHymnsForMassParts(
    DateTime date,
    List<DailyReading> readings,
  ) async {
    final ctx = _buildContext(_calendar.getLiturgicalDay(date));
    final themes = _extractThemesFromReadings(readings);
    final eligible =
        _filterBySeasonEligibility(await _hymnService.getHymnsFromAssets(), ctx.seasonKey);

    return {
      for (final part in _massPartProfiles.keys)
        part: _recommendForPart(eligible, ctx, themes, part),
    };
  }

  /// Returns hymns for a single [massPart].
  Future<List<Hymn>> getHymnsForMassPart(
    DateTime date,
    List<DailyReading> readings,
    String massPart, {
    int maxResults = 5,
  }) async {
    final ctx = _buildContext(_calendar.getLiturgicalDay(date));
    final themes = _extractThemesFromReadings(readings);
    final eligible =
        _filterBySeasonEligibility(await _hymnService.getHymnsFromAssets(), ctx.seasonKey);
    return _recommendForPart(eligible, ctx, themes, massPart, maxResults: maxResults);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 0 implementation — season gate
  // ═════════════════════════════════════════════════════════════════════════

  List<Hymn> _filterBySeasonEligibility(List<Hymn> hymns, String season) {
    final blocked = _seasonExclusions[season] ?? const {};
    if (blocked.isEmpty) return List.of(hymns);
    return hymns.where((h) {
      final tag = h.liturgicalSeason?.toLowerCase() ?? '';
      return tag.isEmpty || !blocked.any(tag.contains);
    }).toList();
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 1 implementation — theme extraction
  // ═════════════════════════════════════════════════════════════════════════

  /// Extracts themes from readings, weighting each source by its position
  /// and type in the liturgy.
  ///
  /// Source weights (derived from liturgical tradition):
  ///   Gospel          1.5 ×  (primary proclamation of the day)
  ///   First Reading   1.0 ×  (types and prophecies the Gospel)
  ///   Second Reading  0.7 ×  (apostolic letter, usually semi-continuous)
  ///   Psalm / Response 0.5 × (already a musical response; avoid double-counting)
  Map<LiturgicalTheme, double> _extractThemesFromReadings(
      List<DailyReading> readings) {
    final weighted = <_WeightedReading>[];

    for (var i = 0; i < readings.length; i++) {
      final r = readings[i];
      final src = (r.source ?? '').toLowerCase();

      // Determine weight by source label, then by position as fallback
      double w;
      if (_isGospel(src)) {
        w = 1.5;
      } else if (_isPsalm(src)) {
        w = 0.5;
      } else if (i == 0) {
        w = 1.0; // first listed → First Reading
      } else {
        w = 0.7; // additional readings → Second Reading
      }

      final text = [
        r.reading ?? '',
        r.incipit ?? '',
        r.psalmResponse ?? '',
        r.feast ?? '',
      ].join(' ').toLowerCase();

      if (text.trim().isNotEmpty) weighted.add(_WeightedReading(text, w));
    }

    if (weighted.isEmpty) return {};

    final scores = <LiturgicalTheme, double>{};

    for (final profile in _themeProfiles) {
      double score = 0.0;
      for (final wt in weighted) {
        var hits = 0;
        for (final trigger in profile.readingTriggers) {
          if (wt.text.contains(trigger)) hits++;
        }
        if (hits > 0) {
          // Diminishing returns: each additional hit adds less to avoid
          // a single theme dominating because of one verbose reading.
          score += wt.weight * (1.0 + (hits - 1) * 0.25);
        }
      }
      if (score > 0) scores[profile.theme] = score;
    }

    return scores;
  }

  bool _isGospel(String src) =>
      src.contains('gospel') ||
      src.contains('matthew') ||
      src.contains('mark') ||
      src.contains('luke') ||
      src.contains('john');

  bool _isPsalm(String src) =>
      src.contains('psalm') || src.startsWith('ps ') || src.contains('responsorial');

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 2 implementation — multi-factor scoring
  // ═════════════════════════════════════════════════════════════════════════

  /// Scores a hymn against the liturgical context (season + feast).
  ScoredHymn _scoreHymn(
    Hymn hymn,
    _LiturgicalContext ctx, {
    required String? massPart,
  }) {
    final breakdown = <String, int>{};
    var total = 0;

    // ── A. Liturgical season category match ─────────────────────────────
    // Award points for the first season category the hymn matches.
    for (final cat in ctx.seasonCategories) {
      if (_hymnMatchesCategory(hymn, cat)) {
        const pts = 10;
        breakdown['season:$cat'] = pts;
        total += pts;
        break;
      }
    }

    // ── B. Feast / solemnity match ──────────────────────────────────────
    // Points scale with feast rank: memorial = 8, feast = 16, solemnity = 24.
    if (ctx.feastRank > 0 && ctx.feastCategories.isNotEmpty) {
      final baseBonus = ctx.feastRank * 8;
      for (var i = 0; i < ctx.feastCategories.length; i++) {
        final cat = ctx.feastCategories[i];
        if (_hymnMatchesCategory(hymn, cat)) {
          final pts = (baseBonus - i * 2).clamp(1, 30);
          breakdown['feast:$cat'] = pts;
          total += pts;
        }
      }
    }

    // ── C. Mass part character ──────────────────────────────────────────
    if (massPart != null) {
      final profile = _massPartProfiles[massPart];
      if (profile != null) {
        if (_hymnMatchesCategory(hymn, profile.primaryCategory)) {
          const pts = 15;
          breakdown['massPart:primary'] = pts;
          total += pts;
        }
        for (final cat in profile.suitableCategories) {
          if (cat != profile.primaryCategory && _hymnMatchesCategory(hymn, cat)) {
            const pts = 5;
            breakdown['massPart:$cat'] = (breakdown['massPart:$cat'] ?? 0) + pts;
            total += pts;
          }
        }
      }
    }

    // ── D. Explicit liturgicalSeason metadata ───────────────────────────
    if (hymn.liturgicalSeason?.toLowerCase() == ctx.seasonKey) {
      const pts = 8;
      breakdown['seasonMetadata'] = pts;
      total += pts;
    }

    return ScoredHymn(hymn: hymn, totalScore: total, breakdown: breakdown);
  }

  /// Scores a hymn against a set of reading themes.
  ScoredHymn _scoreHymnByThemes(
    Hymn hymn,
    Map<LiturgicalTheme, double> themeWeights,
  ) {
    if (themeWeights.isEmpty) {
      return ScoredHymn(hymn: hymn, totalScore: 0, breakdown: {});
    }

    final breakdown = <String, int>{};
    var total = 0;

    // Pre-collect hymn text fields for efficient matching
    final titleLower = hymn.title.toLowerCase();
    final firstLineLower = hymn.firstLine?.toLowerCase() ?? '';
    final themesLower = hymn.themes?.toLowerCase() ?? '';
    final tagsLower = hymn.tags.map((t) => t.toLowerCase()).toList();
    final lyricsLower = hymn.displayLyrics.join(' ').toLowerCase();

    for (final profile in _themeProfiles) {
      final themeWeight = themeWeights[profile.theme] ?? 0.0;
      if (themeWeight == 0.0) continue;

      var hymnHits = 0;
      for (final indicator in profile.hymnIndicators) {
        // Title match is strongest signal
        if (titleLower.contains(indicator)) hymnHits += 3;
        // First line and declared themes are strong
        if (firstLineLower.contains(indicator)) hymnHits += 2;
        if (themesLower.contains(indicator)) hymnHits += 2;
        // Tags
        if (tagsLower.any((t) => t.contains(indicator))) hymnHits += 2;
        // Lyrics are a weaker signal (any word can appear once)
        if (lyricsLower.contains(indicator)) hymnHits += 1;
      }

      if (hymnHits > 0) {
        // Scale by reading theme weight; cap per-theme contribution at 20 pts
        final pts = (themeWeight * hymnHits).clamp(0, 20.0).toInt();
        breakdown['theme:${profile.theme.name}'] = pts;
        total += pts;
      }
    }

    return ScoredHymn(hymn: hymn, totalScore: total, breakdown: breakdown);
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Layer 3 implementation — mass part ranking
  // ═════════════════════════════════════════════════════════════════════════

  List<Hymn> _recommendForPart(
    List<Hymn> eligible,
    _LiturgicalContext ctx,
    Map<LiturgicalTheme, double> themes,
    String massPart, {
    int maxResults = 5,
  }) {
    // Reading-theme match is more important for Offertory and Communion
    // (the intimate, reflective mass parts) than for Entrance/Dismissal.
    final themeMultiplier =
        (massPart == 'offertory' || massPart == 'communion') ? 2 : 1;

    final scored = eligible.map((h) {
      final s1 = _scoreHymn(h, ctx, massPart: massPart);
      final s2 = _scoreHymnByThemes(h, themes);
      return ScoredHymn(
        hymn: h,
        totalScore: s1.totalScore + s2.totalScore * themeMultiplier,
        breakdown: {...s1.breakdown, ...s2.breakdown},
      );
    }).where((s) => s.totalScore > 0).toList()
      ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

    final results = scored.take(maxResults).map((s) => s.hymn).toList();

    // Guarantee at least 2 results by falling back to eligible hymns that
    // match the part's suitable categories, even if their score is zero.
    if (results.length < 2) {
      final profile = _massPartProfiles[massPart];
      final fallback = eligible.where((h) {
        if (results.any((r) => r.id == h.id)) return false;
        if (profile == null) return true;
        return _hymnMatchesCategory(h, profile.primaryCategory) ||
            profile.suitableCategories.any((c) => _hymnMatchesCategory(h, c));
      }).take(2 - results.length);
      results.addAll(fallback);
    }

    return results;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // Utility helpers
  // ═════════════════════════════════════════════════════════════════════════

  _LiturgicalContext _buildContext(dynamic liturgicalDay) {
    final seasonKey = _normaliseSeasonKey(liturgicalDay.seasonName as String? ?? '');
    final feastTitle = (liturgicalDay.title as String? ?? '').toLowerCase();
    final rankStr = (liturgicalDay.rank as String? ?? 'feria').toLowerCase();
    final rank = _feastRank[rankStr] ?? 0;

    List<String> feastCats = [];
    for (final entry in _feastCategories.entries) {
      if (feastTitle.contains(entry.key)) {
        feastCats = entry.value;
        break;
      }
    }

    return _LiturgicalContext(
      seasonKey: seasonKey,
      feastTitle: feastTitle,
      feastCategories: feastCats,
      feastRank: rank,
      seasonCategories: _seasonPrimaryCategories[seasonKey] ?? const ['general'],
    );
  }

  /// Normalises the raw season name from the liturgical calendar service into
  /// one of the keys used in [_seasonExclusions] and [_seasonPrimaryCategories].
  String _normaliseSeasonKey(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('advent')) return 'advent';
    if (s.contains('christmas')) return 'christmas';
    if (s.contains('triduum')) return 'easterTriduum';
    if (s.contains('holy week') || s.contains('holyweek')) return 'holyWeek';
    if (s.contains('easter')) return 'easter';
    if (s.contains('pentecost')) return 'pentecost';
    if (s.contains('lent')) return 'lent';
    return 'ordinaryTime';
  }

  /// Returns true when the hymn's category, tags, or themes field contains
  /// [category] (case-insensitive equality or containment).
  bool _hymnMatchesCategory(Hymn hymn, String category) {
    final lower = category.toLowerCase();
    if (hymn.category.toLowerCase() == lower) return true;
    if (hymn.tags.any((t) => t.toLowerCase() == lower)) return true;
    if (hymn.themes?.toLowerCase().contains(lower) ?? false) return true;
    return false;
  }

  List<Hymn> _sortByScore(List<ScoredHymn> scored, int max) {
    return (scored..sort((a, b) => b.totalScore.compareTo(a.totalScore)))
        .where((s) => s.totalScore > 0)
        .take(max)
        .map((s) => s.hymn)
        .toList();
  }
}