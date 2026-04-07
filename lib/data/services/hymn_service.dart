import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/hymn.dart';
import '../models/hymn_category.dart';
import 'base_service.dart';

class HymnService extends BaseService<HymnService> {
  static HymnService get instance => BaseService.init(() => HymnService._());

  HymnService._();

  static const String _hymnsAssetPath = 'assets/data/hymns.json';
  static const String _categoriesAssetPath = 'assets/data/hymn_categories.json';

  List<Hymn>? _cachedHymns;
  List<HymnCategory>? _cachedCategories;

  Future<List<Hymn>> getHymnsFromAssets() async {
    if (_cachedHymns != null) {
      return _cachedHymns!;
    }

    try {
      final String response = await rootBundle.loadString(_hymnsAssetPath);
      final List<dynamic> data = json.decode(response);
      _cachedHymns = data.map((json) => Hymn.fromMap(json)).toList();
      return _cachedHymns!;
    } catch (e) {
      print('Error loading hymns from assets: $e');
      return [];
    }
  }

  Future<List<HymnCategory>> getCategoriesFromAssets() async {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }

    try {
      final String response = await rootBundle.loadString(_categoriesAssetPath);
      final List<dynamic> data = json.decode(response);
      _cachedCategories = data.map((json) => HymnCategory.fromMap(json)).toList();
      return _cachedCategories!;
    } catch (e) {
      print('Error loading categories from assets: $e');
      return [];
    }
  }

  Future<List<Hymn>> getHymnsByCategory(String categoryId) async {
    final allHymns = await getHymnsFromAssets();
    return allHymns.where((hymn) => hymn.category == categoryId).toList();
  }

  Future<List<Hymn>> searchHymns(String query) async {
    final allHymns = await getHymnsFromAssets();
    final queryLower = query.toLowerCase();
    return allHymns.where((hymn) =>
      hymn.title.toLowerCase().contains(queryLower) ||
      (hymn.author?.toLowerCase().contains(queryLower) ?? false) ||
      hymn.displayLyrics.any((line) => line.toLowerCase().contains(queryLower)) ||
      hymn.tags.any((tag) => tag.toLowerCase().contains(queryLower))
    ).toList();
  }

  Future<Hymn?> getHymnById(int id) async {
    final allHymns = await getHymnsFromAssets();
    try {
      return allHymns.firstWhere((hymn) => hymn.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Hymn>> getHymnsByLiturgicalSeason(String season) async {
    final allHymns = await getHymnsFromAssets();
    return allHymns.where((hymn) =>
      hymn.liturgicalSeason?.toLowerCase() == season.toLowerCase()
    ).toList();
  }

  Future<List<Hymn>> getHymnsByTheme(String theme) async {
    final allHymns = await getHymnsFromAssets();
    final themeLower = theme.toLowerCase();
    return allHymns.where((hymn) =>
      hymn.themes?.toLowerCase().contains(themeLower) ?? false ||
      hymn.tags.any((tag) => tag.toLowerCase().contains(themeLower))
    ).toList();
  }

  void clearCache() {
    _cachedHymns = null;
    _cachedCategories = null;
  }
}
