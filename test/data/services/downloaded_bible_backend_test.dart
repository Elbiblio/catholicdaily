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
    final backend = ReadingsBackendIo();
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
}
