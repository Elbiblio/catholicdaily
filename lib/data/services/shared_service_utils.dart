import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';

/// Shared utilities used across multiple services to reduce duplication
class SharedServiceUtils {
  SharedServiceUtils._();
  
  /// Check if a reference is psalm-like
  static bool isPsalmLikeReference(String reference) {
    final normalized = reference.trim().toLowerCase();
    return normalized.startsWith('ps ') ||
        normalized.startsWith('psalm ') ||
        normalized.startsWith('isa 12') ||
        normalized.startsWith('exod 15') ||
        normalized.startsWith('1 sam 2') ||
        normalized.startsWith('luke 1:');
  }

  /// Check if a reference is gospel-like
  static bool isGospelReference(String reference) {
    final normalized = reference.trim().toLowerCase();
    return normalized.startsWith('matt ') ||
        normalized.startsWith('mark ') ||
        normalized.startsWith('luke ') ||
        normalized.startsWith('john ');
  }

  /// Open asset database with validation and recopy if needed
  static Future<Database> openValidatedAssetDatabase(
    String assetPath, {
    bool readOnly = false,
  }) async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, assetPath);
    } else {
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, assetPath);
    }
    
    // Copy from assets if doesn't exist
    if (!await databaseExists(path)) {
      final data = await rootBundle.load('assets/$assetPath');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes);
    }

    var db = await openDatabase(path, readOnly: readOnly);
    if (!await _hasExpectedSchema(db, assetPath)) {
      await db.close();
      final data = await rootBundle.load('assets/$assetPath');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes, flush: true);
      db = await openDatabase(path, readOnly: readOnly);
    }

    return db;
  }

  /// Check if database has expected schema
  static Future<bool> _hasExpectedSchema(Database db, String assetPath) async {
    try {
      final tableName = assetPath == 'readings.db' ? 'readings' : 'books';
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [tableName],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
