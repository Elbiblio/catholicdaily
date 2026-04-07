import 'package:shared_preferences/shared_preferences.dart';
import '../models/hymn.dart';

class HymnFavoritesService {
  static const String _keyFavorites = 'hymn_favorites';
  static HymnFavoritesService? _instance;
  
  HymnFavoritesService._();
  
  static HymnFavoritesService get instance {
    _instance ??= HymnFavoritesService._();
    return _instance!;
  }
  
  Future<Set<int>> _getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList(_keyFavorites) ?? [];
    return favoriteIds.map((id) => int.tryParse(id) ?? 0).toSet();
  }
  
  Future<bool> isFavorite(int hymnId) async {
    final favoriteIds = await _getFavoriteIds();
    return favoriteIds.contains(hymnId);
  }
  
  Future<void> toggleFavorite(int hymnId) async {
    final favoriteIds = await _getFavoriteIds();
    final prefs = await SharedPreferences.getInstance();
    
    if (favoriteIds.contains(hymnId)) {
      favoriteIds.remove(hymnId);
    } else {
      favoriteIds.add(hymnId);
    }
    
    await prefs.setStringList(_keyFavorites, favoriteIds.map((id) => id.toString()).toList());
  }
  
  Future<void> setFavorite(int hymnId, bool isFavorite) async {
    final favoriteIds = await _getFavoriteIds();
    final prefs = await SharedPreferences.getInstance();
    
    if (isFavorite) {
      favoriteIds.add(hymnId);
    } else {
      favoriteIds.remove(hymnId);
    }
    
    await prefs.setStringList(_keyFavorites, favoriteIds.map((id) => id.toString()).toList());
  }
  
  Future<List<Hymn>> getFavoriteHymns(List<Hymn> allHymns) async {
    final favoriteIds = await _getFavoriteIds();
    return allHymns.where((hymn) => favoriteIds.contains(hymn.id)).toList();
  }
}
