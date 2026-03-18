import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:catholic_daily/data/services/readings_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  setupFlutterTestEnvironment();
  
  group('Bible Retrieval Integration Tests', () {
    late Database rsvceDb;
    late ReadingsService readingsService;
    late Directory tempDocsDir;
    late void Function() cleanupMocks;

    setUpAll(() async {
      tempDocsDir = await createTempTestDir('catholic_daily_bible_integration_');
      cleanupMocks = mockMethodChannels(tempDocsPath: tempDocsDir.path);

      // Load databases from assets first
      final rsvceAsset = await rootBundle.load('assets/rsvce.db');
      
      // Write to temporary files for testing
      final tempDir = Directory.systemTemp;
      final rsvcePath = join(tempDir.path, 'test_rsvce.db');
      
      final rsvceFile = File(rsvcePath);
      
      await rsvceFile.writeAsBytes(rsvceAsset.buffer.asUint8List());
      
      // Open databases
      rsvceDb = await openDatabase(rsvcePath);
      readingsService = ReadingsService.instance;
    });

    tearDownAll(() async {
      await rsvceDb.close();
      cleanupMocks();
      cleanupTempDir(tempDocsDir);
    });

    /// Helper function to get book text (replaces dbHelper.getBookText)
    Future<String> getBookText({
      required String dbName,
      required String bookName,
      required int chapterNumber,
      required int start,
      required int end,
    }) async {
      try {
        final db = rsvceDb;
        
        // Find the book
        final bookResult = await db.query(
          'books',
          where: 'shortname = ?',
          whereArgs: [bookName],
          limit: 1,
        );
        
        if (bookResult.isEmpty) {
          return '1. Sample verse for $bookName $chapterNumber:$start-$end (book not found)';
        }
        
        final bookId = bookResult.first['_id'];
        
        // Get verses
        final verses = await db.query(
          'verses',
          where: 'book_id = ? AND chapter_id = ? AND verse_id >= ? AND verse_id <= ?',
          whereArgs: [bookId, chapterNumber, start, end],
          orderBy: 'verse_id',
        );
        
        if (verses.isEmpty) {
          return '1. Sample verse for $bookName $chapterNumber:$start-$end (verses not found)';
        }
        
        // Format verses
        final buffer = StringBuffer();
        for (final verse in verses) {
          buffer.writeln('${verse['verse_id']}. ${verse['text']}');
        }
        
        return buffer.toString();
      } catch (e) {
        return '1. Sample verse for $bookName $chapterNumber:$start-$end (error: $e)';
      }
    }

    test('Database initialization should work', () async {
      // Test that we can initialize the Bible database and readings service
      try {
        expect(rsvceDb, isNotNull);
        expect(readingsService, isNotNull);
        
        print('✅ Bible database and readings service initialized successfully');
      } catch (e) {
        print('❌ Database initialization failed: $e');
        rethrow;
      }
    });

    test('RSVCE database should contain books', () async {
      try {
        // Test book count
        final bookCountResult = await rsvceDb.rawQuery('SELECT COUNT(*) as count FROM books');
        final bookCount = bookCountResult.first['count'] as int;
        expect(bookCount, greaterThan(0));
        print('✅ Found $bookCount books in RSVCE database');
        
        // Test specific books we need
        final testBooks = ['Exod', 'Ps', 'Rom', 'John', 'Matt', 'Isa'];
        for (final bookShortName in testBooks) {
          final result = await rsvceDb.query(
            'books',
            where: 'shortname = ?',
            whereArgs: [bookShortName],
            limit: 1,
          );
          
          expect(result.isNotEmpty, true, reason: 'Book $bookShortName should exist');
          if (result.isNotEmpty) {
            print('✅ Found book: $bookShortName (ID: ${result.first['_id']})');
          }
        }
      } catch (e) {
        print('❌ Book test failed: $e');
        rethrow;
      }
    });

    test('RSVCE database should contain verses for test readings', () async {
      try {
        // Test verses for Exodus 17:3-7
        final exodResult = await rsvceDb.query(
          'books',
          where: 'shortname = ?',
          whereArgs: ['Exod'],
          limit: 1,
        );
        
        expect(exodResult.isNotEmpty, true, reason: 'Exodus book should exist');
        final exodId = exodResult.first['_id'];
        
        final verses = await rsvceDb.query(
          'verses',
          where: 'book_id = ? AND chapter_id = ? AND verse_id >= ? AND verse_id <= ?',
          whereArgs: [exodId, 17, 3, 7],
          orderBy: 'verse_id',
        );
        
        expect(verses.length, 5, reason: 'Should find 5 verses for Exodus 17:3-7');
        print('✅ Found ${verses.length} verses for Exodus 17:3-7');
        
        // Test first verse content
        final firstVerse = verses.first;
        expect(firstVerse['verse_id'], 3);
        expect(firstVerse['text'], isNotEmpty);
        print('✅ First verse: ${firstVerse['verse_id']}. ${firstVerse['text']}');
        
      } catch (e) {
        print('❌ Verse test failed: $e');
        rethrow;
      }
    });

    test('getBookText should return actual Bible text', () async {
      try {
        final text = await getBookText(
          dbName: 'rsvce',
          bookName: 'Exod',
          chapterNumber: 17,
          start: 3,
          end: 7,
        );
        
        expect(text, isNotEmpty);
        expect(text, isNot(contains('sample verse')), reason: 'Should not return sample text');
        expect(text, contains('3.'), reason: 'Should contain verse numbers');
        expect(text, contains('thirsted'), reason: 'Should contain actual verse content');
        
        print('✅ getBookText returned actual Bible content:');
        print('First 200 chars: ${text.substring(0, text.length > 200 ? 200 : text.length)}...');
        print('Total length: ${text.length} characters');
        
      } catch (e) {
        print('❌ getBookText test failed: $e');
        rethrow;
      }
    });

    test('ReadingsService should parse references correctly', () async {
      try {
        final testReferences = [
          'Exod 17:3-7',
          'Ps 95:1-9',
          'Rom 5:1-8',
          'John 4:5-42',
        ];
        
        for (final reference in testReferences) {
          final text = await readingsService.getReadingText(reference);
          
          expect(text, isNotEmpty, reason: 'Should return text for $reference');
          expect(text, isNot(contains('not available')), reason: 'Should not be unavailable for $reference');
          
          print('✅ $reference: ${text.length} characters');
          if (text.length > 100) {
            print('   Preview: ${text.substring(0, 100)}...');
          } else {
            print('   Full: $text');
          }
        }
        
      } catch (e) {
        print('❌ ReadingsService test failed: $e');
        rethrow;
      }
    });

    test('Should get readings for March 8, 2026', () async {
      try {
        final date = DateTime(2026, 3, 8);
        final readings = await readingsService.getReadingsForDate(date);
        
        print('✅ Found ${readings.length} readings for March 8, 2026:');
        
        for (int i = 0; i < readings.length; i++) {
          final reading = readings[i];
          print('   ${i + 1}. ${reading.position}: ${reading.reading}');
          
          // Test getting full text for each reading
          final fullText = await readingsService.getReadingText(reading.reading);
          expect(fullText, isNotEmpty);
          expect(fullText, isNot(contains('not available')), reason: 'Should get actual text for ${reading.reading}');
          
          print('     Text length: ${fullText.length} characters');
        }
        
        expect(readings.length, 5, reason: 'Should find 5 readings (including alternative Gospel)');
        
      } catch (e) {
        print('❌ March 8, 2026 readings test failed: $e');
        rethrow;
      }
    });

    test('Should handle edge cases gracefully', () async {
      try {
        // Test non-existent book
        final text1 = await getBookText(
          dbName: 'rsvce',
          bookName: 'NonExistent',
          chapterNumber: 1,
          start: 1,
          end: 1,
        );
        
        expect(text1, contains('book not found'), reason: 'Should return book not found text for non-existent book');
        print('✅ Handled non-existent book gracefully');
        
        // Test non-existent chapter
        final text2 = await getBookText(
          dbName: 'rsvce',
          bookName: 'Exod',
          chapterNumber: 999,
          start: 1,
          end: 1,
        );
        
        expect(text2, contains('verses not found'), reason: 'Should return verses not found text for non-existent chapter');
        print('✅ Handled non-existent chapter gracefully');
        
        // Test invalid reference format
        final text3 = await readingsService.getReadingText('Invalid Reference');
        expect(text3, contains('unavailable'), reason: 'Should handle invalid reference');
        print('✅ Handled invalid reference gracefully');
        
      } catch (e) {
        print('❌ Edge case test failed: $e');
        rethrow;
      }
    });

    test('Should verify all March 8, 2026 readings have actual content', () async {
      try {
        final date = DateTime(2026, 3, 8);
        final readings = await readingsService.getReadingsForDate(date);
        
        final expectedReadings = [
          {'position': 'First Reading', 'reference': 'Exod 17:3-7'},
          {'position': 'Responsorial Psalm', 'reference': 'Ps 95:1-2, 6-7, 8-9'},
          {'position': 'Second Reading', 'reference': 'Rom 5:1-2, 5-8'},
          {'position': 'Gospel', 'reference': 'John 4:5-42'},
          {'position': 'Gospel (alternative)', 'reference': 'John 4:5-15, 19b-26, 39a, 40-42'},
        ];
        
        for (int i = 0; i < readings.length && i < expectedReadings.length; i++) {
          final reading = readings[i];
          final expected = expectedReadings[i];
          
          expect(reading.position, expected['position'], reason: 'Position should match');
          expect(reading.reading, expected['reference'], reason: 'Reference should match');
          
          final fullText = await readingsService.getReadingText(reading.reading);
          
          expect(fullText, isNotEmpty, reason: 'Should get text for ${reading.reading}');
          expect(fullText, isNot(contains('sample verse')), reason: 'Should not be sample text');
          expect(fullText, isNot(contains('not available')), reason: 'Should not be unavailable');
          
          print('✅ ${reading.position}:');
          print('   Reference: ${reading.reading}');
          print('   Text length: ${fullText.length} characters');
          final preview = fullText.substring(0, fullText.length > 100 ? 100 : fullText.length);
          print('   Preview: $preview...');
        }
        
      } catch (e) {
        print('❌ Content verification test failed: $e');
        rethrow;
      }
    });
  });
}
