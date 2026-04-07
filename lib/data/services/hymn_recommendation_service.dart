import '../models/hymn.dart';
import '../models/daily_reading.dart';
import 'hymn_service.dart';
import 'improved_liturgical_calendar_service.dart';
import 'base_service.dart';

class HymnRecommendationService extends BaseService<HymnRecommendationService> {
  static HymnRecommendationService get instance =>
      BaseService.init(() => HymnRecommendationService._());

  HymnRecommendationService._();

  final HymnService _hymnService = HymnService.instance;
  final ImprovedLiturgicalCalendarService _calendar =
      ImprovedLiturgicalCalendarService.instance;

  // Mapping of liturgical seasons to hymn categories
  static const Map<String, List<String>> _seasonToCategories = {
    'advent': ['advent', 'general', 'entrance'],
    'christmas': ['christmas', 'marian', 'general'],
    'lent': ['lenten', 'penitential', 'general'],
    'easter': ['easter', 'general', 'communion'],
    'ordinaryTime': ['general', 'communion', 'entrance', 'offertory'],
  };

  // Mapping of feast days to hymn categories
  static const Map<String, List<String>> _feastToCategories = {
    'Mary, Mother of God': ['marian', 'general'],
    'The Immaculate Conception': ['marian', 'general'],
    'The Nativity of the Lord': ['christmas', 'marian'],
    'The Epiphany of the Lord': ['christmas', 'general'],
    'The Baptism of the Lord': ['general', 'holy spirit'],
    'The Presentation of the Lord': ['marian', 'general'],
    'The Annunciation of the Lord': ['marian', 'general'],
    'The Ascension of the Lord': ['general', 'christ the king'],
    'Pentecost': ['pentecost', 'holy spirit', 'general'],
    'The Most Holy Trinity': ['general', 'holy spirit'],
    'The Most Holy Body and Blood of Christ': ['communion', 'general'],
    'The Assumption of the Blessed Virgin Mary': ['marian', 'general'],
    'All Saints': ['general', 'memorial'],
    'Christ the King': ['christ the king', 'general'],
  };

  // Theme keywords extracted from readings
  static const Map<String, List<String>> _themeKeywords = {
    'praise': ['praise', 'glory', 'worship', 'adoration'],
    'mercy': ['mercy', 'compassion', 'forgiveness'],
    'love': ['love', 'charity', 'beloved'],
    'hope': ['hope', 'trust', 'faith'],
    'peace': ['peace', 'comfort', 'consolation'],
    'joy': ['joy', 'rejoice', 'celebrate'],
    'light': ['light', 'shine', 'illuminate'],
    'shepherd': ['shepherd', 'sheep', 'fold'],
    'king': ['king', 'kingdom', 'reign'],
    'spirit': ['spirit', 'holy ghost', 'breath'],
    'cross': ['cross', 'crucifix', 'suffering'],
    'resurrection': ['resurrection', 'risen', 'alive'],
    'creation': ['creation', 'world', 'earth'],
    'salvation': ['salvation', 'save', 'redeem'],
  };

  /// Get recommended hymns for a given date based on liturgical context
  Future<List<Hymn>> getRecommendedHymnsForDate(DateTime date) async {
    final liturgicalDay = _calendar.getLiturgicalDay(date);
    final seasonName = liturgicalDay.seasonName.toLowerCase();
    final feastTitle = liturgicalDay.title.toLowerCase();

    final recommendations = <Hymn>[];

    // 1. Match by liturgical season category
    final seasonCategories = _seasonToCategories[seasonName] ?? ['general'];
    for (final category in seasonCategories) {
      final categoryHymns = await _hymnService.getHymnsByCategory(category);
      recommendations.addAll(categoryHymns);
    }

    // 2. Match by feast day if applicable
    for (final entry in _feastToCategories.entries) {
      if (feastTitle.contains(entry.key.toLowerCase())) {
        for (final category in entry.value) {
          final feastHymns = await _hymnService.getHymnsByCategory(category);
          recommendations.addAll(feastHymns);
        }
      }
    }

    // 3. Match by liturgical season in hymn metadata
    final seasonHymns = await _hymnService.getHymnsByLiturgicalSeason(seasonName);
    recommendations.addAll(seasonHymns);

    // Remove duplicates and limit to top recommendations
    final uniqueHymns = <int, Hymn>{};
    for (final hymn in recommendations) {
      uniqueHymns.putIfAbsent(hymn.id, () => hymn);
    }

    final hymnList = uniqueHymns.values.toList();

    // Sort by relevance (hymns with matching season metadata first)
    hymnList.sort((a, b) {
      final aHasSeason = a.liturgicalSeason?.toLowerCase() == seasonName;
      final bHasSeason = b.liturgicalSeason?.toLowerCase() == seasonName;
      if (aHasSeason && !bHasSeason) return -1;
      if (!aHasSeason && bHasSeason) return 1;
      return 0;
    });

    // Return top 10 recommendations
    return hymnList.take(10).toList();
  }

  /// Get recommended hymns based on reading content/themes
  Future<List<Hymn>> getRecommendedHymnsForReadings(
    List<DailyReading> readings,
  ) async {
    if (readings.isEmpty) {
      return [];
    }

    // Extract themes from reading content
    final detectedThemes = _extractThemesFromReadings(readings);

    final allHymns = await _hymnService.getHymnsFromAssets();
    final scoredHymns = <Hymn, int>{};

    for (final hymn in allHymns) {
      int score = 0;

      // Check hymn themes against detected themes
      if (hymn.themes != null) {
        for (final theme in detectedThemes) {
          if (hymn.themes!.toLowerCase().contains(theme)) {
            score += 3;
          }
        }
      }

      // Check hymn tags against detected themes
      for (final theme in detectedThemes) {
        for (final tag in hymn.tags) {
          if (tag.toLowerCase().contains(theme)) {
            score += 2;
          }
        }
      }

      // Check lyrics for theme keywords
      for (final line in hymn.displayLyrics) {
        for (final theme in detectedThemes) {
          if (line.toLowerCase().contains(theme)) {
            score += 1;
          }
        }
      }

      if (score > 0) {
        scoredHymns[hymn] = score;
      }
    }

    // Sort by score and return top matches
    final sortedHymns = scoredHymns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedHymns.take(10).map((e) => e.key).toList();
  }

  /// Get combined recommendations considering both date and readings
  Future<List<Hymn>> getCombinedRecommendations(
    DateTime date,
    List<DailyReading> readings,
  ) async {
    final dateRecommendations = await getRecommendedHymnsForDate(date);
    final readingRecommendations = await getRecommendedHymnsForReadings(readings);

    // Combine and weight recommendations
    final combinedScores = <Hymn, int>{};

    // Date-based recommendations get higher weight
    for (var i = 0; i < dateRecommendations.length; i++) {
      final hymn = dateRecommendations[i];
      final score = (dateRecommendations.length - i) * 2;
      combinedScores[hymn] = (combinedScores[hymn] ?? 0) + score;
    }

    // Reading-based recommendations
    for (var i = 0; i < readingRecommendations.length; i++) {
      final hymn = readingRecommendations[i];
      final score = readingRecommendations.length - i;
      combinedScores[hymn] = (combinedScores[hymn] ?? 0) + score;
    }

    // Sort by combined score
    final sorted = combinedScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(10).map((e) => e.key).toList();
  }

  /// Extract themes from reading content
  List<String> _extractThemesFromReadings(List<DailyReading> readings) {
    final detectedThemes = <String>{};
    final fullText = readings.map((r) => r.reading.toLowerCase()).join(' ');

    for (final entry in _themeKeywords.entries) {
      for (final keyword in entry.value) {
        if (fullText.contains(keyword)) {
          detectedThemes.add(entry.key);
          break;
        }
      }
    }

    return detectedThemes.toList();
  }

  /// Get recommended hymns for specific mass parts based on date and readings
  Future<Map<String, List<Hymn>>> getRecommendedHymnsForMassParts(
    DateTime date,
    List<DailyReading> readings,
  ) async {
    final massParts = ['entrance', 'offertory', 'communion', 'dismissal'];
    final recommendations = <String, List<Hymn>>{};

    for (final part in massParts) {
      recommendations[part] = await getHymnsForMassPart(date, readings, part);
    }

    return recommendations;
  }

  /// Get recommended hymns for a specific mass part
  Future<List<Hymn>> getHymnsForMassPart(
    DateTime date,
    List<DailyReading> readings,
    String massPart,
  ) async {
    final liturgicalDay = _calendar.getLiturgicalDay(date);
    final seasonName = liturgicalDay.seasonName.toLowerCase();
    final feastTitle = liturgicalDay.title.toLowerCase();

    // Get hymns for the specific mass part category
    final categoryHymns = await _hymnService.getHymnsByCategory(massPart);

    // Score hymns based on liturgical context and reading themes
    final scoredHymns = <Hymn, int>{};

    for (final hymn in categoryHymns) {
      int score = 0;

      // Bonus for matching liturgical season
      if (hymn.liturgicalSeason?.toLowerCase() == seasonName) {
        score += 5;
      }

      // Bonus for matching feast day
      for (final entry in _feastToCategories.entries) {
        if (feastTitle.contains(entry.key.toLowerCase()) &&
            entry.value.contains(massPart)) {
          score += 5;
        }
      }

      // Extract themes from readings and match against hymn
      final detectedThemes = _extractThemesFromReadings(readings);
      if (hymn.themes != null) {
        for (final theme in detectedThemes) {
          if (hymn.themes!.toLowerCase().contains(theme)) {
            score += 3;
          }
        }
      }

      // Check hymn tags
      for (final theme in detectedThemes) {
        for (final tag in hymn.tags) {
          if (tag.toLowerCase().contains(theme)) {
            score += 2;
          }
        }
      }

      // Check lyrics for theme keywords
      for (final line in hymn.displayLyrics) {
        for (final theme in detectedThemes) {
          if (line.toLowerCase().contains(theme)) {
            score += 1;
          }
        }
      }

      if (score > 0) {
        scoredHymns[hymn] = score;
      }
    }

    // Sort by score and return top matches
    final sortedHymns = scoredHymns.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedHymns.take(5).map((e) => e.key).toList();
  }
}
