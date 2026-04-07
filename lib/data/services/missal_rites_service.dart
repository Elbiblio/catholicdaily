import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'base_service.dart';

class MissalRite {
  final String date;
  final String languageCode;
  final String riteType;
  final String content;
  final String source;
  final DateTime createdAt;

  MissalRite({
    required this.date,
    required this.languageCode,
    required this.riteType,
    required this.content,
    required this.source,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'language_code': languageCode,
      'rite_type': riteType,
      'content': content,
      'source': source,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MissalRite.fromMap(Map<String, dynamic> map) {
    return MissalRite(
      date: map['date'] as String,
      languageCode: map['language_code'] as String,
      riteType: map['rite_type'] as String,
      content: map['content'] as String,
      source: map['source'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class MissalRitesService extends BaseService<MissalRitesService> {
  static MissalRitesService get instance => BaseService.init(() => MissalRitesService._());

  MissalRitesService._();

  static const String _databaseName = 'missal_rites.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'missal_rites';

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(docsDir.path, _databaseName);

    return await openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName(
        date TEXT NOT NULL,
        language_code TEXT NOT NULL,
        rite_type TEXT NOT NULL,
        content TEXT NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (date, language_code, rite_type)
      )
    ''');

    // Create indexes for fast lookup
    await db.execute('CREATE INDEX idx_date_language ON $_tableName(date, language_code)');
    await db.execute('CREATE INDEX idx_rite_type ON $_tableName(rite_type)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future database upgrades
  }

  Future<String?> getRite(String date, String languageCode, String riteType) async {
    final db = await _db;
    final results = await db.query(
      _tableName,
      where: 'date = ? AND language_code = ? AND rite_type = ?',
      whereArgs: [date, languageCode, riteType],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return MissalRite.fromMap(results.first).content;
  }

  Future<bool> hasRite(String date, String languageCode, String riteType) async {
    final db = await _db;
    final results = await db.query(
      _tableName,
      where: 'date = ? AND language_code = ? AND rite_type = ?',
      whereArgs: [date, languageCode, riteType],
      limit: 1,
    );
    return results.isNotEmpty;
  }

  Future<void> saveRite(
    String date,
    String languageCode,
    String riteType,
    String content,
    String source,
  ) async {
    final db = await _db;
    final rite = MissalRite(
      date: date,
      languageCode: languageCode,
      riteType: riteType,
      content: content,
      source: source,
      createdAt: DateTime.now(),
    );

    await db.insert(
      _tableName,
      rite.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MissalRite>> getRitesForDate(String date, String languageCode) async {
    final db = await _db;
    final results = await db.query(
      _tableName,
      where: 'date = ? AND language_code = ?',
      whereArgs: [date, languageCode],
      orderBy: 'rite_type ASC',
    );

    return results.map((map) => MissalRite.fromMap(map)).toList();
  }

  Future<Map<String, String>> getAllRitesForDate(String date, String languageCode) async {
    final rites = await getRitesForDate(date, languageCode);
    final Map<String, String> riteMap = {};
    for (final rite in rites) {
      riteMap[rite.riteType] = rite.content;
    }
    return riteMap;
  }

  Future<void> downloadAndStoreRitesForDateRange(
    DateTime startDate,
    DateTime endDate,
    List<String> languageCodes,
    Function(String, String, String)? onProgress,
  ) async {
    // This method is a placeholder for future API integration.
    // Currently, rites are fetched on-demand from DivinumOfficiumLoaderService.
    // When external APIs become available, this method should:
    // 1. Call the external API for each date in the range
    // 2. Store the downloaded rites in the database via saveRite()
    // 3. Call onProgress() with status updates
    // 4. Handle errors and retry logic
    throw UnimplementedError(
      'API download not yet implemented. '
      'Use DivinumOfficiumLoaderService for on-demand fetching.'
    );
  }

  Future<void> clearAllRites() async {
    final db = await _db;
    await db.delete(_tableName);
  }

  Future<void> deleteRite(String date, String languageCode, String riteType) async {
    final db = await _db;
    await db.delete(
      _tableName,
      where: 'date = ? AND language_code = ? AND rite_type = ?',
      whereArgs: [date, languageCode, riteType],
    );
  }

  Future<int> getRiteCount() async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<String>> getAvailableDates() async {
    final db = await _db;
    final results = await db.rawQuery('SELECT DISTINCT date FROM $_tableName ORDER BY date DESC');
    return results.map((row) => row['date'] as String).toList();
  }

  Future<void> close() async {
    final db = await _db;
    await db.close();
    _database = null;
  }
}
