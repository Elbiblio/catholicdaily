import 'dart:io';

import 'package:catholic_daily/data/services/bible_version_preference.dart';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  late Directory tempDir;
  late void Function() clearChannels;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('downloaded_bible_backend_');
    clearChannels = mockMethodChannels(tempDocsPath: tempDir.path);
    final database = await databaseFactory.openDatabase(
      '${tempDir.path}${Platform.pathSeparator}engdra.db',
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await database.execute(
      'CREATE TABLE books (_id INTEGER PRIMARY KEY, text TEXT, shortname TEXT)',
    );
    await database.execute('''
      CREATE TABLE verses (
        _id INTEGER PRIMARY KEY,
        book_id INTEGER,
        chapter_id INTEGER,
        verse_id INTEGER,
        text TEXT
      )
    ''');
    await database.insert('books', {
      '_id': 1,
      'text': 'John',
      'shortname': 'John',
    });
    await database.insert('verses', {
      '_id': 1,
      'book_id': 1,
      'chapter_id': 3,
      'verse_id': 16,
      'text': 'For God so loved the world.',
    });
    await database.close();
  });

  tearDown(() async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.rsvce);
    clearChannels();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('backend opens an installed local Douay-Rheims database', () async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);
    final backend = ReadingsBackendIo(
      minimumDownloadedBookCount: 1,
      minimumDownloadedVerseCount: 1,
    );
    try {
      final chapter = await backend.getChapterText(
        bookShortName: 'John',
        chapter: 3,
      );
      expect(chapter, contains('16. For God so loved the world.'));
    } finally {
      await backend.close();
    }
  });

  test('missing selected download falls back to bundled RSVCE', () async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);
    File('${tempDir.path}${Platform.pathSeparator}engdra.db').deleteSync();
    final backend = ReadingsBackendIo(
      minimumDownloadedBookCount: 1,
      minimumDownloadedVerseCount: 1,
    );
    try {
      final chapter = await backend.getChapterText(
        bookShortName: 'John',
        chapter: 3,
      );

      expect(chapter, isNot(contains('unavailable')));
      expect(preference.currentVersion, BibleVersionType.rsvce);
    } finally {
      await backend.close();
    }
  });

  test('invalid selected download falls back to bundled RSVCE', () async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);
    final databasePath = '${tempDir.path}${Platform.pathSeparator}engdra.db';
    File(databasePath).deleteSync();
    final invalidDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await invalidDatabase.execute('CREATE TABLE unrelated (id INTEGER)');
    await invalidDatabase.close();
    final backend = ReadingsBackendIo(
      minimumDownloadedBookCount: 1,
      minimumDownloadedVerseCount: 1,
    );
    try {
      final chapter = await backend.getChapterText(
        bookShortName: 'John',
        chapter: 3,
      );

      expect(chapter, isNot(contains('unavailable')));
      expect(preference.currentVersion, BibleVersionType.rsvce);
    } finally {
      await backend.close();
    }
  });

  test('selected schema missing verse identity falls back to RSVCE', () async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);
    final databasePath = '${tempDir.path}${Platform.pathSeparator}engdra.db';
    File(databasePath).deleteSync();
    final partialDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await partialDatabase.execute(
      'CREATE TABLE books (_id INTEGER PRIMARY KEY, text TEXT, shortname TEXT)',
    );
    await partialDatabase.execute('''
      CREATE TABLE verses (
        book_id INTEGER,
        chapter_id INTEGER,
        verse_id INTEGER,
        text TEXT
      )
    ''');
    await partialDatabase.insert('books', {
      '_id': 1,
      'text': 'John',
      'shortname': 'John',
    });
    await partialDatabase.insert('verses', {
      'book_id': 1,
      'chapter_id': 3,
      'verse_id': 16,
      'text': 'Partial text that must not be selected.',
    });
    await partialDatabase.close();
    final backend = ReadingsBackendIo(
      minimumDownloadedBookCount: 1,
      minimumDownloadedVerseCount: 1,
    );
    try {
      final chapter = await backend.getChapterText(
        bookShortName: 'John',
        chapter: 3,
      );

      expect(chapter, isNot(contains('unavailable')));
      expect(preference.currentVersion, BibleVersionType.rsvce);
      final movedDatabase = File('$databasePath.replacement-check');
      await File(databasePath).rename(movedDatabase.path);
      expect(movedDatabase.existsSync(), isTrue);
      await movedDatabase.rename(databasePath);
    } finally {
      await backend.close();
    }
  });

  test('empty selected database falls back to bundled RSVCE', () async {
    final preference = await BibleVersionPreference.getInstance();
    await preference.setVersion(BibleVersionType.douayRheims);
    final databasePath = '${tempDir.path}${Platform.pathSeparator}engdra.db';
    File(databasePath).deleteSync();
    final emptyDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await emptyDatabase.execute(
      'CREATE TABLE books (_id INTEGER PRIMARY KEY, text TEXT, shortname TEXT)',
    );
    await emptyDatabase.execute('''
      CREATE TABLE verses (
        _id INTEGER PRIMARY KEY,
        book_id INTEGER,
        chapter_id INTEGER,
        verse_id INTEGER,
        text TEXT
      )
    ''');
    await emptyDatabase.close();
    final backend = ReadingsBackendIo(
      minimumDownloadedBookCount: 1,
      minimumDownloadedVerseCount: 1,
    );
    try {
      final chapter = await backend.getChapterText(
        bookShortName: 'John',
        chapter: 3,
      );

      expect(chapter, isNot(contains('unavailable')));
      expect(preference.currentVersion, BibleVersionType.rsvce);
    } finally {
      await backend.close();
    }
  });
}
