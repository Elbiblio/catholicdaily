import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import '../models/hymn.dart';
import 'base_service.dart';

class HymnDatabaseService extends BaseService<HymnDatabaseService> {
  static HymnDatabaseService get instance =>
      BaseService.init(() => HymnDatabaseService._());

  HymnDatabaseService._();

  Database? _database;
  List<Hymn>? _cachedHymns;

  Future<Database> get _db async {
    if (_database != null) {
      return _database!;
    }

    // Load the database from assets
    final dbBytes = await rootBundle.load('assets/nch.db');
    final dbPath = await getDatabasesPath();
    final dbFile = File('$dbPath/nch.db');

    // Write the database to a file if it doesn't exist
    if (!dbFile.existsSync()) {
      await dbFile.writeAsBytes(dbBytes.buffer.asUint8List(dbBytes.offsetInBytes, dbBytes.lengthInBytes));
    }

    // Open the database
    _database = await openDatabase(
      dbFile.path,
      readOnly: true,
    );

    return _database!;
  }

  Future<List<Hymn>> getHymnsFromDatabase() async {
    if (_cachedHymns != null) {
      return _cachedHymns!;
    }

    try {
      final db = await _db;
      final List<Map<String, dynamic>> maps = await db.query('hymns');
      
      _cachedHymns = maps.map((map) => _mapToHymn(map)).toList();
      return _cachedHymns!;
    } catch (e) {
      debugPrint('Error loading hymns from database: $e');
      return [];
    }
  }

  Future<Hymn?> getHymnById(int id) async {
    final allHymns = await getHymnsFromDatabase();
    try {
      return allHymns.firstWhere((hymn) => hymn.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Hymn>> getHymnsByCategory(String category) async {
    final allHymns = await getHymnsFromDatabase();
    return allHymns.where((hymn) => hymn.category == category).toList();
  }

  Future<List<Hymn>> searchHymns(String query) async {
    final allHymns = await getHymnsFromDatabase();
    final queryLower = query.toLowerCase();
    return allHymns.where((hymn) =>
      hymn.title.toLowerCase().contains(queryLower) ||
      (hymn.author?.toLowerCase().contains(queryLower) ?? false) ||
      hymn.displayLyrics.any((line) => line.toLowerCase().contains(queryLower)) ||
      hymn.tags.any((tag) => tag.toLowerCase().contains(queryLower))
    ).toList();
  }

  Future<List<Hymn>> getHymnsByLiturgicalSeason(String season) async {
    final allHymns = await getHymnsFromDatabase();
    return allHymns.where((hymn) =>
      hymn.liturgicalSeason?.toLowerCase() == season.toLowerCase()
    ).toList();
  }

  Future<List<Hymn>> getHymnsByTheme(String theme) async {
    final allHymns = await getHymnsFromDatabase();
    final themeLower = theme.toLowerCase();
    return allHymns.where((hymn) =>
      hymn.themes?.toLowerCase().contains(themeLower) ?? false ||
      hymn.tags.any((tag) => tag.toLowerCase().contains(themeLower))
    ).toList();
  }

  Hymn _mapToHymn(Map<String, dynamic> map) {
    return Hymn(
      id: map['ID'] as int,
      title: map['title'] as String? ?? '',
      category: map['main_category'] as String? ?? '',
      lyrics: [], // Lyrics are stored separately in hymn_file
      midiFile: map['midi_file'] as String?,
      audioFile: map['mp3_file'] as String?,
      pdfFile: map['pdf'] as String?,
      author: null, // Author not in database
      composer: null, // Composer not in database
      hymnNumber: map['number'] as int?,
      tags: [],
      firstLine: map['first_line'] as String?,
      oldNumber: map['old_number'] as String?,
      lastAccessed: null,
      bpm: null,
      timeSignature: null,
      keySignature: null,
      tempoNotes: null,
      yearComposed: null,
      liturgicalSeason: null,
      themes: null,
      originalId: null,
      openCount: 0,
      isFavorite: false,
      content: null,
      meter: null,
      copyrightStatus: null,
      primaryTune: null,
      alternateTunes: null,
      sourceAttribution: null,
      slug: null,
    );
  }

  void clearCache() {
    _cachedHymns = null;
  }

  Future<void> close() async {
    final db = await _db;
    await db.close();
    _database = null;
    _cachedHymns = null;
  }
}
