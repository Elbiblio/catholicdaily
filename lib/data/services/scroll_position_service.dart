import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ScrollPositionService {
  static const String _scrollPositionsKey = 'scroll_positions';
  static const int _expirationDays = 30;
  
  static final ScrollPositionService _instance = ScrollPositionService._internal();
  factory ScrollPositionService() => _instance;
  ScrollPositionService._internal();

  Map<String, Map<String, dynamic>> _scrollPositions = {};

  Future<void> initialize() async {
    await _loadData();
    await _clearExpiredPositions();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final positionsJson = prefs.getString(_scrollPositionsKey);
    if (positionsJson != null) {
      final positionsMap = jsonDecode(positionsJson) as Map<String, dynamic>;
      _scrollPositions = positionsMap.map((key, value) => 
          MapEntry(key, value as Map<String, dynamic>));
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scrollPositionsKey, jsonEncode(_scrollPositions));
  }

  Future<void> _clearExpiredPositions() async {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _expirationDays));
    
    final expiredKeys = _scrollPositions.entries
        .where((entry) {
          final timestamp = entry.value['timestamp'] as int?;
          if (timestamp == null) return true;
          final positionDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return positionDate.isBefore(cutoffDate);
        })
        .map((entry) => entry.key)
        .toList();
    
    for (final key in expiredKeys) {
      _scrollPositions.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      await _saveData();
    }
  }

  Future<void> saveScrollPosition(String reference, double position) async {
    _scrollPositions[reference] = {
      'position': position,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    await _saveData();
  }

  double? getScrollPosition(String reference) {
    final entry = _scrollPositions[reference];
    if (entry == null) return null;
    
    final timestamp = entry['timestamp'] as int?;
    if (timestamp == null) return null;
    
    final now = DateTime.now();
    final positionDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final cutoffDate = now.subtract(Duration(days: _expirationDays));
    
    if (positionDate.isBefore(cutoffDate)) {
      // Expired, remove it
      _scrollPositions.remove(reference);
      _saveData();
      return null;
    }
    
    return entry['position'] as double?;
  }

  Future<void> clearPosition(String reference) async {
    _scrollPositions.remove(reference);
    await _saveData();
  }

  Future<void> clearAllPositions() async {
    _scrollPositions.clear();
    await _saveData();
  }
}
