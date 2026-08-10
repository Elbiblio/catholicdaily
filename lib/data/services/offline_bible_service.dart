import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/bible_source.dart';
import '../models/bible_version.dart';
import 'bible_source_registry.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef DownloadedDatabaseValidator = Future<bool> Function(String filePath);

class OfflineBibleService {
  static const String _versionsUrl =
      'https://api.elbiblio.com/dbs/versions.json';

  final http.Client? _client;
  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final DownloadedDatabaseValidator? _databaseValidator;

  OfflineBibleService({
    http.Client? client,
    DocumentsDirectoryProvider? documentsDirectoryProvider,
    DownloadedDatabaseValidator? databaseValidator,
  }) : _client = client,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _databaseValidator = databaseValidator;

  Future<List<BibleVersion>> fetchAvailableVersions() async {
    final client = _client ?? http.Client();
    try {
      final response = await client.get(Uri.parse(_versionsUrl));
      if (response.statusCode != 200) return _bundledVersions();
      final decoded = json.decode(response.body);
      if (decoded is! List<dynamic>) return _bundledVersions();
      return supportedVersionsFromManifest(decoded);
    } catch (error) {
      developer.log(
        'Error fetching Bible versions',
        error: error,
        name: 'OfflineBibleService',
      );
      return _bundledVersions();
    } finally {
      if (_client == null) client.close();
    }
  }

  Future<List<BibleVersion>> supportedVersionsFromManifest(
    List<dynamic> manifest,
  ) async {
    final versions = _bundledVersions();
    final registry = BibleSourceRegistry.instance;

    for (final source in registry.downloadableLocalSources) {
      final entry = manifest
          .whereType<Map>()
          .cast<Map<dynamic, dynamic>>()
          .where(
            (item) =>
                item['dbFilename'] == source.assetDbName &&
                item['tableName'] == source.downloadTableName,
          );
      if (entry.isEmpty) continue;

      versions.add(
        BibleVersion(
          id: source.id,
          name: source.displayName,
          abbreviation: source.abbreviation,
          downloadUrl: source.sourceUrl,
          dbFilename: source.assetDbName,
          isDownloaded: await _isVersionDownloaded(source.assetDbName!),
        ),
      );
    }

    return versions;
  }

  List<BibleVersion> _bundledVersions() => BibleSourceRegistry
      .instance
      .selectableBundledSources
      .map(
        (source) => BibleVersion(
          id: source.id,
          name: source.displayName,
          abbreviation: source.abbreviation,
          dbFilename: source.assetDbName,
          isDownloaded: true,
        ),
      )
      .toList(growable: true);

  Future<bool> _isVersionDownloaded(String dbName) async {
    final docsDir = await _documentsDirectoryProvider();
    final file = File(path.join(docsDir.path, dbName));
    await _recoverInterruptedReplacement(file);
    if (!await file.exists()) return false;
    return _hasNormalizedSchema(file.path);
  }

  Future<Set<String>> installedSourceIds() async {
    final installed = BibleSourceRegistry.instance.selectableBundledSources
        .map((source) => source.id)
        .toSet();
    for (final source
        in BibleSourceRegistry.instance.downloadableLocalSources) {
      if (await _isVersionDownloaded(source.assetDbName!)) {
        installed.add(source.id);
      }
    }
    return installed;
  }

  Future<String?> getDatabasePath(String dbName) async {
    final docsDir = await _documentsDirectoryProvider();
    final file = File(path.join(docsDir.path, dbName));
    await _recoverInterruptedReplacement(file);
    if (await file.exists()) return file.path;
    return null;
  }

  Future<void> downloadVersion(
    BibleVersion version,
    Function(double) onProgress,
  ) async {
    final source = BibleSourceRegistry.instance.byId(version.id);
    if (source == null || !source.isDownloadableLocal) {
      throw ArgumentError.value(
        version.id,
        'version',
        'Unsupported downloadable Bible source',
      );
    }
    final downloadUrl = version.downloadUrl;
    final dbName = version.dbFilename ?? source.assetDbName;
    if (downloadUrl == null || dbName == null) {
      throw StateError('The Bible download metadata is incomplete.');
    }
    if (path.basename(dbName) != dbName) {
      throw StateError('The Bible database filename is unsafe.');
    }

    final docsDir = await _documentsDirectoryProvider();
    await docsDir.create(recursive: true);
    final target = File(path.join(docsDir.path, dbName));
    final rawPartial = File('${target.path}.download');
    final preparedPartial = File('${target.path}.part');
    final backup = File('${target.path}.previous');
    final client = _client ?? http.Client();

    try {
      await _recoverInterruptedReplacement(target);
      await _deleteIfPresent(rawPartial);
      await _deleteIfPresent(preparedPartial);

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('download_http_${response.statusCode}');
      }

      final expectedLength = response.contentLength;
      var downloadedLength = 0;
      final sink = rawPartial.openWrite(mode: FileMode.writeOnly);
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloadedLength += chunk.length;
          if (expectedLength != null && expectedLength > 0) {
            onProgress((downloadedLength / expectedLength).clamp(0.0, 1.0));
          }
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      if (downloadedLength == 0 ||
          (expectedLength != null && downloadedLength != expectedLength)) {
        throw StateError('download_incomplete');
      }

      if (_databaseValidator != null) {
        if (!await _databaseValidator(rawPartial.path)) {
          throw StateError('download_invalid_database');
        }
        await rawPartial.rename(preparedPartial.path);
      } else {
        await _normalizeDownloadedDatabase(
          source: source,
          sourceFile: rawPartial,
          destinationFile: preparedPartial,
        );
        if (!await _hasNormalizedSchema(preparedPartial.path)) {
          throw StateError('download_invalid_normalized_database');
        }
      }

      if (await target.exists()) await target.rename(backup.path);
      try {
        await preparedPartial.rename(target.path);
      } catch (_) {
        if (await backup.exists() && !await target.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
      await _deleteIfPresent(backup);
      onProgress(1);
    } catch (error) {
      developer.log(
        'Error downloading Bible version',
        error: error,
        name: 'OfflineBibleService',
      );
      throw Exception('Failed to download ${version.name}');
    } finally {
      await _deleteIfPresent(rawPartial);
      await _deleteIfPresent(preparedPartial);
      if (_client == null) client.close();
    }
  }

  Future<void> _normalizeDownloadedDatabase({
    required BibleSource source,
    required File sourceFile,
    required File destinationFile,
  }) async {
    _initializeDesktopDatabaseFactory();
    final tableName = source.downloadTableName!;
    if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(tableName)) {
      throw StateError('Unsafe downloaded Bible table name.');
    }

    Database? input;
    Database? output;
    try {
      input = await databaseFactory.openDatabase(
        sourceFile.path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      if (!await _hasVplSchema(input, tableName)) {
        throw StateError('The downloaded Bible schema is unsupported.');
      }

      await _deleteIfPresent(destinationFile);
      output = await databaseFactory.openDatabase(
        destinationFile.path,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await output.execute('''
        CREATE TABLE books (
          _id INTEGER PRIMARY KEY,
          text TEXT NOT NULL,
          shortname TEXT NOT NULL UNIQUE
        )
      ''');
      await output.execute('''
        CREATE TABLE verses (
          _id INTEGER PRIMARY KEY AUTOINCREMENT,
          book_id INTEGER NOT NULL,
          chapter_id INTEGER NOT NULL,
          verse_id INTEGER NOT NULL,
          text TEXT NOT NULL
        )
      ''');

      var bookId = 0;
      for (final entry in _douayBookMetadata.entries) {
        final rows = await input.query(
          tableName,
          columns: const ['chapter', 'startVerse', 'verseText'],
          where: 'book = ?',
          whereArgs: [entry.key],
          orderBy:
              'CAST(chapter AS INTEGER), CAST(startVerse AS INTEGER), canon_order',
        );
        if (rows.isEmpty) {
          throw StateError('Downloaded Bible is missing ${entry.key}.');
        }

        bookId += 1;
        final metadata = entry.value;
        await output.insert('books', {
          '_id': bookId,
          'text': metadata.name,
          'shortname': metadata.shortName,
        });
        final batch = output.batch();
        for (final row in rows) {
          final chapter = int.tryParse('${row['chapter']}');
          final verse = int.tryParse('${row['startVerse']}');
          final text = row['verseText'] as String?;
          if (chapter == null || verse == null || text == null) {
            throw StateError('Downloaded Bible contains an invalid verse row.');
          }
          batch.insert('verses', {
            'book_id': bookId,
            'chapter_id': chapter,
            'verse_id': verse,
            'text': text.trim(),
          });
        }
        await batch.commit(noResult: true);
      }
      await output.execute(
        'CREATE INDEX verses_lookup ON verses(book_id, chapter_id, verse_id)',
      );
    } finally {
      await output?.close();
      await input?.close();
    }
  }

  Future<bool> _hasVplSchema(Database database, String tableName) async {
    try {
      final columns = await database.rawQuery('PRAGMA table_info($tableName)');
      final names = columns.map((row) => row['name']).toSet();
      const required = {
        'canon_order',
        'book',
        'chapter',
        'startVerse',
        'verseText',
      };
      if (!names.containsAll(required)) return false;
      final count = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM $tableName'),
      );
      return count != null && count >= 30000;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasNormalizedSchema(String filePath) async {
    _initializeDesktopDatabaseFactory();
    Database? database;
    try {
      database = await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('books', 'verses')",
      );
      if (tables.length != 2) return false;
      final bookCount = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM books'),
      );
      final verseCount = Sqflite.firstIntValue(
        await database.rawQuery('SELECT COUNT(*) FROM verses'),
      );
      return bookCount == _douayBookMetadata.length &&
          verseCount != null &&
          verseCount >= 30000;
    } catch (_) {
      return false;
    } finally {
      await database?.close();
    }
  }

  void _initializeDesktopDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<void> deleteVersion(String dbName) async {
    try {
      final docsDir = await _documentsDirectoryProvider();
      await _deleteIfPresent(File(path.join(docsDir.path, dbName)));
    } catch (error) {
      developer.log(
        'Error deleting Bible version',
        error: error,
        name: 'OfflineBibleService',
      );
      throw Exception('Failed to delete version');
    }
  }

  Future<void> _deleteIfPresent(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<void> _recoverInterruptedReplacement(File target) async {
    final backup = File('${target.path}.previous');
    if (await target.exists()) {
      await _deleteIfPresent(backup);
      return;
    }
    if (await backup.exists()) {
      await backup.rename(target.path);
    }
  }
}

class _BibleBookMetadata {
  final String name;
  final String shortName;

  const _BibleBookMetadata(this.name, this.shortName);
}

const _douayBookMetadata = <String, _BibleBookMetadata>{
  'GEN': _BibleBookMetadata('Genesis', 'Gen'),
  'EXO': _BibleBookMetadata('Exodus', 'Exod'),
  'LEV': _BibleBookMetadata('Leviticus', 'Lev'),
  'NUM': _BibleBookMetadata('Numbers', 'Num'),
  'DEU': _BibleBookMetadata('Deuteronomy', 'Deut'),
  'JOS': _BibleBookMetadata('Joshua', 'Josh'),
  'JDG': _BibleBookMetadata('Judges', 'Judg'),
  'RUT': _BibleBookMetadata('Ruth', 'Ruth'),
  '1SA': _BibleBookMetadata('I Samuel', '1 Sam'),
  '2SA': _BibleBookMetadata('II Samuel', '2 Sam'),
  '1KI': _BibleBookMetadata('I Kings', '1 Kgs'),
  '2KI': _BibleBookMetadata('II Kings', '2 Kgs'),
  '1CH': _BibleBookMetadata('I Chronicles', '1 Chr'),
  '2CH': _BibleBookMetadata('II Chronicles', '2 Chr'),
  'EZR': _BibleBookMetadata('Ezra', 'Ezra'),
  'NEH': _BibleBookMetadata('Nehemiah', 'Neh'),
  'EST': _BibleBookMetadata('Esther', 'Esth'),
  'JOB': _BibleBookMetadata('Job', 'Job'),
  'PSA': _BibleBookMetadata('Psalms', 'Ps'),
  'PRO': _BibleBookMetadata('Proverbs', 'Prov'),
  'ECC': _BibleBookMetadata('Ecclesiastes', 'Eccles'),
  'SNG': _BibleBookMetadata('Song of Songs', 'Song'),
  'ISA': _BibleBookMetadata('Isaiah', 'Isa'),
  'JER': _BibleBookMetadata('Jeremiah', 'Jer'),
  'LAM': _BibleBookMetadata('Lamentations', 'Lam'),
  'EZK': _BibleBookMetadata('Ezekiel', 'Ezek'),
  'DAN': _BibleBookMetadata('Daniel', 'Dan'),
  'HOS': _BibleBookMetadata('Hosea', 'Hos'),
  'JOL': _BibleBookMetadata('Joel', 'Joel'),
  'AMO': _BibleBookMetadata('Amos', 'Amos'),
  'OBA': _BibleBookMetadata('Obadiah', 'Obad'),
  'JON': _BibleBookMetadata('Jonah', 'Jonah'),
  'MIC': _BibleBookMetadata('Micah', 'Mic'),
  'NAM': _BibleBookMetadata('Nahum', 'Nah'),
  'HAB': _BibleBookMetadata('Habakkuk', 'Hab'),
  'ZEP': _BibleBookMetadata('Zephaniah', 'Zeph'),
  'HAG': _BibleBookMetadata('Haggai', 'Hagg'),
  'ZEC': _BibleBookMetadata('Zechariah', 'Zech'),
  'MAL': _BibleBookMetadata('Malachi', 'Mal'),
  'TOB': _BibleBookMetadata('Tobit', 'Tob'),
  'JDT': _BibleBookMetadata('Judith', 'Jud'),
  'WIS': _BibleBookMetadata('Wisdom', 'Wis'),
  'SIR': _BibleBookMetadata('Sirach', 'Sir'),
  'BAR': _BibleBookMetadata('Baruch', 'Bar'),
  '1MA': _BibleBookMetadata('1 Maccabees', '1 Macc'),
  '2MA': _BibleBookMetadata('2 Maccabees', '2 Macc'),
  'MAT': _BibleBookMetadata('Matthew', 'Matt'),
  'MRK': _BibleBookMetadata('Mark', 'Mark'),
  'LUK': _BibleBookMetadata('Luke', 'Luke'),
  'JHN': _BibleBookMetadata('John', 'John'),
  'ACT': _BibleBookMetadata('Acts of the Apostles', 'Acts'),
  'ROM': _BibleBookMetadata('Romans', 'Rom'),
  '1CO': _BibleBookMetadata('I Corinthians', '1 Cor'),
  '2CO': _BibleBookMetadata('II Corinthians', '2 Cor'),
  'GAL': _BibleBookMetadata('Galatians', 'Gal'),
  'EPH': _BibleBookMetadata('Ephesians', 'Eph'),
  'PHP': _BibleBookMetadata('Philippians', 'Phil'),
  'COL': _BibleBookMetadata('Colossians', 'Col'),
  '1TH': _BibleBookMetadata('I Thessalonians', '1 Thess'),
  '2TH': _BibleBookMetadata('II Thessalonians', '2 Thess'),
  '1TI': _BibleBookMetadata('I Timothy', '1 Tim'),
  '2TI': _BibleBookMetadata('II Timothy', '2 Tim'),
  'TIT': _BibleBookMetadata('Titus', 'Titus'),
  'PHM': _BibleBookMetadata('Philemon', 'Phlm'),
  'HEB': _BibleBookMetadata('Hebrews', 'Heb'),
  'JAS': _BibleBookMetadata('James', 'James'),
  '1PE': _BibleBookMetadata('I Peter', '1 Pet'),
  '2PE': _BibleBookMetadata('II Peter', '2 Pet'),
  '1JN': _BibleBookMetadata('I John', '1 John'),
  '2JN': _BibleBookMetadata('II John', '2 John'),
  '3JN': _BibleBookMetadata('III John', '3 John'),
  'JUD': _BibleBookMetadata('Jude', 'Jude'),
  'REV': _BibleBookMetadata('Revelation', 'Rev'),
};
