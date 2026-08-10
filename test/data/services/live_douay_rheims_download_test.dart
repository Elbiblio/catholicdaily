import 'dart:io';

import 'package:catholic_daily/data/models/bible_version.dart';
import 'package:catholic_daily/data/services/bible_source_registry.dart';
import 'package:catholic_daily/data/services/offline_bible_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final runLiveAudit =
      Platform.environment['RUN_LIVE_BIBLE_DOWNLOAD_AUDIT'] == '1';

  test(
    'downloads and normalizes the live Douay-Rheims database',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final tempDir = Directory.systemTemp.createTempSync(
        'douay_rheims_live_audit_',
      );
      try {
        final source = BibleSourceRegistry.instance.requireById('douay_rheims');
        final service = OfflineBibleService(
          documentsDirectoryProvider: () async => tempDir,
        );
        await service.downloadVersion(
          BibleVersion(
            id: source.id,
            name: source.displayName,
            abbreviation: source.abbreviation,
            downloadUrl: source.sourceUrl,
            dbFilename: source.assetDbName,
          ),
          (_) {},
        );

        final installed = File('${tempDir.path}/engdra.db');
        expect(installed.existsSync(), isTrue);
        final database = await databaseFactory.openDatabase(
          installed.path,
          options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
        );
        try {
          final books = Sqflite.firstIntValue(
            await database.rawQuery('SELECT COUNT(*) FROM books'),
          );
          final john316 = await database.rawQuery('''
            SELECT v.text
            FROM verses v
            JOIN books b ON b._id = v.book_id
            WHERE b.shortname = 'John'
              AND v.chapter_id = 3
              AND v.verse_id = 16
          ''');
          expect(books, 73);
          expect(john316.single['text'], contains('God so loved the world'));
        } finally {
          await database.close();
        }
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    },
    skip: runLiveAudit ? false : 'Set RUN_LIVE_BIBLE_DOWNLOAD_AUDIT=1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
