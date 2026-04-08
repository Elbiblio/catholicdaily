import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'base_service.dart';

class PrebuiltPrayerService extends BaseService<PrebuiltPrayerService> {
  static PrebuiltPrayerService get instance => BaseService.init(() => PrebuiltPrayerService._());
  
  PrebuiltPrayerService._();

  static const String _databaseName = 'prayers.db';
  static const String _tableName = 'prayers';
  
  Database? _database;
  bool _isInitialized = false;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    await _initializeDatabase();
    return _database!;
  }

  Future<void> _initializeDatabase() async {
    if (_isInitialized) return;
    
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(docsDir.path, _databaseName);
      
      // Check if database already exists
      final dbExists = await databaseExists(dbPath);
      
      if (!dbExists) {
        // Copy prebuilt database from assets
        final data = await rootBundle.load('assets/$_databaseName');
        final bytes = data.buffer.asUint8List();
        
        await _saveDatabaseToFile(dbPath, bytes);
      }
      
      _database = await openDatabase(dbPath);
      _isInitialized = true;
      
    } catch (e) {
      throw Exception('Failed to initialize prayer database: $e');
    }
  }

  Future<void> _saveDatabaseToFile(String dbPath, List<int> bytes) async {
    final file = File(dbPath);
    await file.writeAsBytes(bytes);
  }

  Future<String?> getPrayer(String date, String languageCode) async {
    try {
      final db = await _db;
      final results = await db.query(
        _tableName,
        where: 'date = ? AND language_code = ? AND rite_type = ?',
        whereArgs: [date, languageCode, 'prayers_of_faithful'],
        limit: 1,
      );

      if (results.isEmpty) return null;
      return results.first['content'] as String?;
      
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasPrayer(String date, String languageCode) async {
    try {
      final db = await _db;
      final results = await db.query(
        _tableName,
        where: 'date = ? AND language_code = ? AND rite_type = ?',
        whereArgs: [date, languageCode, 'prayers_of_faithful'],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _isInitialized = false;
    }
  }
}
