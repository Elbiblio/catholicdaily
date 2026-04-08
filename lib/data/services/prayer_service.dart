import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer.dart';
import 'base_service.dart';
import 'prayer_content_parser.dart';

class PrayerService extends BaseService<PrayerService> {
  static PrayerService get instance => BaseService.init(() => PrayerService._());
  
  /// Factory constructor for backward compatibility
  factory PrayerService() => instance;
  
  PrayerService._();

  List<Prayer> _prayers = [];
  List<Prayer> _recentlyUsed = [];
  final String _prayersJsonPath = 'assets/data/prayers.json';
  bool _initialized = false;

  List<Prayer> get allPrayers => List.unmodifiable(_prayers);
  List<Prayer> get recentlyUsedPrayers => List.unmodifiable(_recentlyUsed);

  Future<void> initialize() async {
    if (_initialized) return;
    
    await _loadPrayers();
    await _loadRecentlyUsed();
    _initialized = true;
  }

  Future<void> _loadPrayers() async {
    try {
      final String jsonString = await rootBundle.loadString(_prayersJsonPath);
      final List<dynamic> jsonList = json.decode(jsonString);
      _prayers = await Future.wait(jsonList.map((json) async {
        final prayer = Prayer.fromMap(json);
        // Load English version by default for backward compatibility
        final htmlContent = await _loadHtmlContent(prayer.sourceFile, 'en');
        final prayerWithHtml = prayer.copyWith(htmlContent: htmlContent);
        // Parse content for language separation
        return PrayerContentParser.parsePrayerContent(prayerWithHtml);
      }));
    } catch (e) {
      debugPrint('Error loading prayers: $e');
      _prayers = [];
    }
  }

  Future<String?> _loadHtmlContent(String? sourceFile, [String language = 'en']) async {
    if (sourceFile == null) return null;
    try {
      // Try language-specific path first
      final languagePath = 'assets/prayers/$language/$sourceFile';
      try {
        return await rootBundle.loadString(languagePath);
      } catch (e) {
        // Fallback to old path if language-specific file doesn't exist
        if (language == 'en') {
          return await rootBundle.loadString('assets/prayers/$sourceFile');
        }
        // For other languages, return null if file doesn't exist
        return null;
      }
    } catch (e) {
      debugPrint('Error loading HTML content for $sourceFile ($language): $e');
      return null;
    }
  }

  Future<String?> loadHtmlContentForLanguage(String? sourceFile, String language) async {
    return _loadHtmlContent(sourceFile, language);
  }

  Future<void> _loadRecentlyUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentlyUsedSlugs = prefs.getStringList('recently_used_prayers') ?? [];
      
      _recentlyUsed = recentlyUsedSlugs
          .map((slug) => _prayers.where((p) => p.slug == slug).firstOrNull)
          .where((prayer) => prayer != null)
          .cast<Prayer>()
          .toList();
    } catch (e) {
      debugPrint('Error loading recently used prayers: $e');
      _recentlyUsed = [];
    }
  }

  Future<void> markPrayerAsUsed(Prayer prayer) async {
    try {
      // Remove from recent if already exists
      _recentlyUsed.removeWhere((p) => p.slug == prayer.slug);
      
      // Add to beginning of list
      _recentlyUsed.insert(0, prayer);
      
      // Keep only top 20
      if (_recentlyUsed.length > 20) {
        _recentlyUsed = _recentlyUsed.take(20).toList();
      }
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      final slugs = _recentlyUsed.map((p) => p.slug).toList();
      await prefs.setStringList('recently_used_prayers', slugs);
    } catch (e) {
      debugPrint('Error marking prayer as used: $e');
    }
  }

  Map<String, List<Prayer>> get prayersByCategory {
    final categorized = <String, List<Prayer>>{};
    
    for (final prayer in _prayers) {
      final category = _categorizePrayer(prayer);
      if (!categorized.containsKey(category)) {
        categorized[category] = [];
      }
      categorized[category]!.add(prayer);
    }
    
    // Sort categories and prayers within each category
    for (final category in categorized.keys) {
      categorized[category]!.sort((a, b) => a.title.compareTo(b.title));
    }
    
    return categorized;
  }

  String _categorizePrayer(Prayer prayer) {
    final title = prayer.title.toLowerCase();
    final slug = prayer.slug.toLowerCase();
    
    // Mass & Liturgical
    if (title.contains('creed') || title.contains('sanctus') || 
        title.contains('pater noster') || title.contains('our father') ||
        title.contains('sign of the cross') || title.contains('confiteor') ||
        title.contains('benediction') || title.contains('memorial acclamations') ||
        slug.contains('credo') || slug.contains('sanctus') ||
        slug.contains('pater_noster') || slug.contains('signum_crucis')) {
      return 'Mass & Liturgical';
    }
    
    // Marian
    if (title.contains('mary') || title.contains('marian') || 
        title.contains('hail mary') || title.contains('ave maria') ||
        title.contains('memorare') || title.contains('regina') ||
        title.contains('salve') || title.contains('immaculate') ||
        title.contains('our lady') || title.contains('blessed virgin') ||
        title.contains('litany of mary') || title.contains('invocation to mary') ||
        slug.contains('mary') || slug.contains('memorare') ||
        slug.contains('regina_caeli') || slug.contains('salve_regina') ||
        slug.contains('litany_of_mary')) {
      return 'Marian';
    }
    
    // Rosary Mysteries (check before Lenten to avoid misclassification)
    if (title.contains('mystery') && 
        (title.contains('sorrowful') || title.contains('joyful') || 
         title.contains('glorious') || title.contains('luminous')) ||
        slug.contains('sorrowful') || slug.contains('joyful') ||
        slug.contains('glorious') || slug.contains('luminous')) {
      return 'Rosary';
    }
    
    // Lenten
    if (title.contains('stations') || title.contains('contrition') ||
        title.contains('dying') ||
        slug.contains('stations') || slug.contains('act_of_contrition') ||
        slug.contains('prayer_before_crucifix') || slug.contains('prayer_for_the_dying')) {
      return 'Lenten';
    }
    
    // Commons & Devotional
    if (title.contains('angel') || title.contains('holy spirit') ||
        title.contains('glory be') || title.contains('glory to god') ||
        title.contains('peace prayer') || title.contains('morning offering') ||
        title.contains('grace') || title.contains('spiritual communion') ||
        slug.contains('angel_of_god') || slug.contains('angelus') ||
        slug.contains('anima_christi') || slug.contains('come_holy_spirit') ||
        slug.contains('glory_be') || slug.contains('peace_prayer') ||
        slug.contains('morning_offering') || slug.contains('grace_before_after_meal') ||
        slug.contains('spiritual_communion')) {
      return 'Commons & Devotional';
    }
    
    // Saints & Novenas
    if (title.contains('st.') || title.contains('saint') ||
        title.contains('divine mercy') || title.contains('novena') ||
        title.contains('michael') || title.contains('anthony') ||
        title.contains('augustine') || title.contains('john vianney') ||
        title.contains('joseph') || title.contains('thomas') ||
        title.contains('valentine') ||
        slug.contains('st_') || slug.contains('saint') ||
        slug.contains('divine_mercy') || slug.contains('novena') ||
        slug.contains('st_michael') || slug.contains('st_anthony') ||
        slug.contains('st_augustine') || slug.contains('st_john') ||
        slug.contains('st_joseph') || slug.contains('st_thomas') ||
        slug.contains('st_valentine')) {
      return 'Saints & Novenas';
    }
    
    // Life Events
    if (title.contains('engaged') || title.contains('married') ||
        title.contains('smoking') || title.contains('christlikeness') ||
        slug.contains('prayer_for_engaged') || slug.contains('prayer_for_married') ||
        slug.contains('prayer_stop_smoking') || slug.contains('prayer_for_christlikeness')) {
      return 'Life Events';
    }
    
    // Rosary (group the mysteries)
    if (title.contains('joyful') || title.contains('sorrowful') ||
        title.contains('glorious') || title.contains('luminous') ||
        title.contains('rosary') || title.contains('decade') ||
        slug.contains('joyful') || slug.contains('sorrowful') ||
        slug.contains('glorious') || slug.contains('light') ||
        slug.contains('rosary_for_the_dead')) {
      return 'Rosary';
    }
    
    // Acts of Faith
    if (title.contains('act of') || slug.contains('act_of')) {
      return 'Acts of Faith';
    }
    
    return prayer.category == 'prayer' ? 'Prayers' : prayer.category;
  }

  Prayer? findPrayerBySlug(String slug) {
    try {
      return _prayers.where((p) => p.slug == slug).firstOrNull;
    } catch (e) {
      return null;
    }
  }

  List<Prayer> searchPrayers(String query) {
    if (query.isEmpty) return [];
    
    final lowercaseQuery = query.toLowerCase();
    return _prayers.where((prayer) {
      return prayer.title.toLowerCase().contains(lowercaseQuery) ||
             prayer.firstLine.toLowerCase().contains(lowercaseQuery) ||
             prayer.slug.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  Future<void> toggleBookmark(Prayer prayer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList('bookmarked_prayers') ?? [];
      
      if (bookmarks.contains(prayer.slug)) {
        bookmarks.remove(prayer.slug);
      } else {
        bookmarks.add(prayer.slug);
      }
      
      await prefs.setStringList('bookmarked_prayers', bookmarks);
    } catch (e) {
      debugPrint('Error toggling bookmark: $e');
    }
  }

  Future<bool> isBookmarked(Prayer prayer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList('bookmarked_prayers') ?? [];
      return bookmarks.contains(prayer.slug);
    } catch (e) {
      return false;
    }
  }

  Future<List<Prayer>> getBookmarkedPrayers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarks = prefs.getStringList('bookmarked_prayers') ?? [];
      
      return bookmarks
          .map((slug) => findPrayerBySlug(slug))
          .where((prayer) => prayer != null)
          .cast<Prayer>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}
