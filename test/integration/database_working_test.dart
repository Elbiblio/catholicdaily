import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:catholic_daily/data/services/readings_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database Working Test', () {
    test('Should be able to open database files directly', () async {
      try {
        // Test opening RSVCE database from a temp copy
        final assetPath = join('assets', 'rsvce.db');
        print('Testing RSVCE database at: $assetPath');
        
        final assetFile = File(assetPath);
        expect(assetFile.existsSync(), true, reason: 'RSVCE database file should exist');
        print('✅ RSVCE file exists: ${assetFile.lengthSync()} bytes');

        final tempDir = Directory.systemTemp;
        final tempPath = join(tempDir.path, 'database_working_rsvce.db');
        final tempFile = File(tempPath);
        await tempFile.writeAsBytes(await assetFile.readAsBytes());

        final rsvceDb = await openDatabase(tempPath);
        
        // Test book query
        final bookCount = await rsvceDb.rawQuery('SELECT COUNT(*) as count FROM books');
        expect(bookCount.first['count'], greaterThan(0));
        print('✅ RSVCE database: ${bookCount.first['count']} books');
        
        // Test Exodus lookup
        final exodResult = await rsvceDb.query('books', where: 'shortname = ?', whereArgs: ['Exod'], limit: 1);
        expect(exodResult.isNotEmpty, true);
        print('✅ Exodus found: ID ${exodResult.first['_id']}');
        
        // Test verses for Exodus 17:3-7
        final exodId = exodResult.first['_id'];
        final verses = await rsvceDb.query(
          'verses',
          where: 'book_id = ? AND chapter_id = ? AND verse_id >= ? AND verse_id <= ?',
          whereArgs: [exodId, 17, 3, 7],
          orderBy: 'verse_id',
        );
        
        expect(verses.length, 5);
        print('✅ Found ${verses.length} verses for Exodus 17:3-7');
        print('   First verse: ${verses.first['verse_id']}. ${verses.first['text']}');
        
        await rsvceDb.close();
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
        
        final readingsService = ReadingsService.instance;
        final readings = await readingsService.getReadingsForDate(
          DateTime(2026, 3, 8),
        );

        expect(readings, isNotEmpty);
        print('✅ Found ${readings.length} CSV-backed readings for March 8, 2026');

        for (final reading in readings) {
          print('   ${reading.position}: ${reading.reading}');
        }
        
      } catch (e) {
        print('❌ Direct database test failed: $e');
        rethrow;
      }
    });

    test('Should verify asset loading works', () async {
      try {
        // Test if we can load assets like the app does
        print('Testing asset loading...');
        
        try {
          final rsvceAsset = await rootBundle.load('assets/rsvce.db');
          print('✅ RSVCE asset loaded: ${rsvceAsset.lengthInBytes} bytes');
        } catch (e) {
          print('❌ RSVCE asset loading failed: $e');
          rethrow;
        }
        
        try {
          final standardAsset = await rootBundle.loadString('standard_lectionary_complete.csv');
          final memorialAsset = await rootBundle.loadString('memorial_feasts.csv');
          expect(standardAsset, isNotEmpty);
          expect(memorialAsset, isNotEmpty);
          print('✅ Standard CSV asset loaded: ${standardAsset.length} chars');
          print('✅ Memorial CSV asset loaded: ${memorialAsset.length} chars');
        } catch (e) {
          print('❌ CSV asset loading failed: $e');
          rethrow;
        }
        
      } catch (e) {
        print('❌ Asset loading test failed: $e');
        rethrow;
      }
    });
  });
}
