import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppNavigationService {
  static const String _lastScreenKey = 'last_screen';
  static const String _lastBibleChapterKey = 'last_bible_chapter';
  static const String _lastNavigationTimeKey = 'last_navigation_time';
  
  static final AppNavigationService _instance = AppNavigationService._internal();
  factory AppNavigationService() => _instance;
  AppNavigationService._internal();

  static const String _screenHome = 'home';
  static const String _screenBible = 'bible';
  static const String _screenBibleChapter = 'bible_chapter';

  String? _lastScreen;
  Map<String, dynamic>? _lastBibleChapter;
  DateTime? _lastNavigationTime;

  Future<void> initialize() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    _lastScreen = prefs.getString(_lastScreenKey);
    
    final chapterJson = prefs.getString(_lastBibleChapterKey);
    if (chapterJson != null) {
      _lastBibleChapter = jsonDecode(chapterJson) as Map<String, dynamic>;
    }
    
    final timestamp = prefs.getInt(_lastNavigationTimeKey);
    if (timestamp != null) {
      _lastNavigationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (_lastScreen != null) {
      await prefs.setString(_lastScreenKey, _lastScreen!);
    }
    
    if (_lastBibleChapter != null) {
      await prefs.setString(_lastBibleChapterKey, jsonEncode(_lastBibleChapter!));
    }
    
    if (_lastNavigationTime != null) {
      await prefs.setInt(_lastNavigationTimeKey, _lastNavigationTime!.millisecondsSinceEpoch);
    }
  }

  Future<void> trackHomeScreen() async {
    _lastScreen = _screenHome;
    _lastNavigationTime = DateTime.now();
    await _saveData();
  }

  Future<void> trackBibleScreen() async {
    _lastScreen = _screenBible;
    _lastNavigationTime = DateTime.now();
    await _saveData();
  }

  Future<void> trackBibleChapter({
    required String reference,
    required String content,
    String? title,
  }) async {
    _lastScreen = _screenBibleChapter;
    _lastBibleChapter = {
      'reference': reference,
      'content': content,
      'title': title ?? reference,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    _lastNavigationTime = DateTime.now();
    await _saveData();
  }

  bool get shouldResumeToBibleChapter {
    // Only resume to Bible chapter if:
    // 1. Last screen was a Bible chapter
    // 2. It was accessed within the last 24 hours
    // 3. We have valid chapter data
    
    if (_lastScreen != _screenBibleChapter || _lastBibleChapter == null) {
      return false;
    }
    
    if (_lastNavigationTime == null) {
      return false;
    }
    
    final hoursSinceLastNavigation = DateTime.now().difference(_lastNavigationTime!).inHours;
    return hoursSinceLastNavigation < 24;
  }

  Map<String, dynamic>? get lastBibleChapter => _lastBibleChapter;

  String? get lastScreen => _lastScreen;

  DateTime? get lastNavigationTime => _lastNavigationTime;
}
