import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'bible_version_preference.dart';

class BibleCacheService {
  static const String _recentlyOpenedKey = 'recently_opened_passages';
  static const String _bookmarkedKey = 'bookmarked_passages';
  static const String _insightsKey = 'cached_insights';
  
  static final BibleCacheService _instance = BibleCacheService._internal();
  factory BibleCacheService() => _instance;
  BibleCacheService._internal();

  List<Map<String, dynamic>> _recentlyOpened = [];
  List<Map<String, dynamic>> _bookmarked = [];
  Map<String, Map<String, dynamic>> _insights = {};

  Future<void> initialize() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final recentlyOpenedJson = prefs.getStringList(_recentlyOpenedKey) ?? [];
    _recentlyOpened = recentlyOpenedJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
    
    final bookmarkedJson = prefs.getStringList(_bookmarkedKey) ?? [];
    _bookmarked = bookmarkedJson
        .map((json) => jsonDecode(json) as Map<String, dynamic>)
        .toList();
    
    final insightsJson = prefs.getString(_insightsKey);
    if (insightsJson != null) {
      final insightsMap = jsonDecode(insightsJson) as Map<String, dynamic>;
      _insights = insightsMap.map((key, value) => 
          MapEntry(key, value as Map<String, dynamic>));
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final recentlyOpenedJson = _recentlyOpened
        .map((item) => jsonEncode(item))
        .toList();
    await prefs.setStringList(_recentlyOpenedKey, recentlyOpenedJson);
    
    final bookmarkedJson = _bookmarked
        .map((item) => jsonEncode(item))
        .toList();
    await prefs.setStringList(_bookmarkedKey, bookmarkedJson);
    
    await prefs.setString(_insightsKey, jsonEncode(_insights));
  }

  List<Map<String, dynamic>> get recentlyOpened => List.unmodifiable(_recentlyOpened.take(10));

  List<Map<String, dynamic>> get bookmarked => List.unmodifiable(_bookmarked);

  List<Map<String, dynamic>> get recentInsights {
    final now = DateTime.now();
    final recentInsights = _insights.entries
        .where((entry) {
          final timestamp = entry.value['timestamp'] as int?;
          if (timestamp == null) return false;
          final insightDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return now.difference(insightDate).inDays <= 7; // Last 7 days
        })
        .map((entry) => {
          'reference': entry.key,
          'title': entry.value['title'] as String?,
          'content': entry.value['content'] as String?,
          'timestamp': entry.value['timestamp'] as int?,
        })
        .toList()
        ..sort((a, b) => (b['timestamp'] as int? ?? 0).compareTo(a['timestamp'] as int? ?? 0));
    
    return recentInsights.take(10).toList();
  }

  Future<void> addRecentlyOpened({
    required String reference,
    required String title,
    required String content,
    String? version,
  }) async {
    // Remove if already exists
    _recentlyOpened.removeWhere((item) => item['reference'] == reference);
    
    // Add to beginning
    _recentlyOpened.insert(0, {
      'reference': reference,
      'title': title,
      'content': content,
      'version': version,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    
    // Keep only last 20
    if (_recentlyOpened.length > 20) {
      _recentlyOpened = _recentlyOpened.take(20).toList();
    }
    
    await _saveData();
  }

  Future<void> toggleBookmark({
    required String reference,
    required String title,
    required String content,
    String? version,
  }) async {
    final existingIndex = _bookmarked.indexWhere((item) => item['reference'] == reference);
    
    if (existingIndex >= 0) {
      _bookmarked.removeAt(existingIndex);
    } else {
      _bookmarked.add({
        'reference': reference,
        'title': title,
        'content': content,
        'version': version,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    await _saveData();
  }

  bool isBookmarked(String reference) {
    return _bookmarked.any((item) => item['reference'] == reference);
  }

  Future<void> cacheInsight({
    required String reference,
    required String title,
    required String content,
  }) async {
    _insights[reference] = {
      'title': title,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Keep only last 50 insights
    if (_insights.length > 50) {
      final sortedEntries = _insights.entries.toList()
        ..sort((a, b) => (a.value['timestamp'] as int? ?? 0).compareTo(b.value['timestamp'] as int? ?? 0));
      
      final toRemove = sortedEntries.take(_insights.length - 50);
      for (final entry in toRemove) {
        _insights.remove(entry.key);
      }
    }
    
    await _saveData();
  }

  Map<String, dynamic>? getCachedInsight(String reference) {
    return _insights[reference];
  }

  /// Refresh cached content for all items when Bible version changes
  Future<void> refreshContentForVersionChange(String newVersion) async {
    final preference = await BibleVersionPreference.getInstance();
    final currentVersion = preference.currentVersion.dbName;
    
    if (currentVersion == newVersion) return;
    
    // Clear content cache but preserve metadata
    _recentlyOpened = _recentlyOpened.map((item) => {
      ...item,
      'content': '', // Clear cached content
      'version': currentVersion,
    }).toList();
    
    _bookmarked = _bookmarked.map((item) => {
      ...item,
      'content': '', // Clear cached content
      'version': currentVersion,
    }).toList();
    
    await _saveData();
  }

  /// Get content for a specific reference, loading fresh content if version mismatch
  Future<String?> getContentForReference(String reference, String currentVersion) async {
    // Check recently opened first
    final recentItem = _recentlyOpened.where((item) => item['reference'] == reference).firstOrNull;
    if (recentItem != null && recentItem['version'] == currentVersion && recentItem['content']?.isNotEmpty == true) {
      return recentItem['content'] as String?;
    }
    
    // Check bookmarks
    final bookmarkedItem = _bookmarked.where((item) => item['reference'] == reference).firstOrNull;
    if (bookmarkedItem != null && bookmarkedItem['version'] == currentVersion && bookmarkedItem['content']?.isNotEmpty == true) {
      return bookmarkedItem['content'] as String?;
    }
    
    return null; // Content not cached or version mismatch
  }
}
