import 'dart:io';

import 'package:catholic_daily/data/models/bible_version.dart';
import 'package:catholic_daily/data/services/offline_bible_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('offline_bible_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'catalog exposes bundled Bibles and only the supported Catholic download',
    () async {
      final service = OfflineBibleService(
        documentsDirectoryProvider: () async => tempDir,
      );
      final manifest = <dynamic>[
        {
          'tableName': 'engkjv_vpl',
          'englishName': 'King James Version',
          'shortName': 'KJV',
          'dbFilename': 'engkjv.db',
          'downloadUrl': 'https://example.test/engkjv.db',
          'preinstalled': true,
        },
        {
          'tableName': 'engdra_vpl',
          'englishName': 'Douay-Rheims',
          'shortName': 'DR',
          'dbFilename': 'engdra.db',
          'downloadUrl': 'https://api.elbiblio.com/dbs/engdra.db',
          'preinstalled': true,
        },
      ];

      final versions = await service.supportedVersionsFromManifest(manifest);

      expect(versions.map((version) => version.id), [
        'rsvce',
        'nabre',
        'douay_rheims',
      ]);
      expect(versions.last.dbFilename, 'engdra.db');
      expect(
        versions.last.isDownloaded,
        isFalse,
        reason: 'remote preinstalled flags do not describe this device',
      );
    },
  );

  test(
    'a legacy raw or corrupt database is not treated as installed',
    () async {
      File(
        '${tempDir.path}${Platform.pathSeparator}engdra.db',
      ).writeAsBytesSync(const [1, 2, 3, 4]);
      final service = OfflineBibleService(
        documentsDirectoryProvider: () async => tempDir,
      );

      final installed = await service.installedSourceIds();

      expect(installed, isNot(contains('douay_rheims')));
    },
  );

  test('download validates a temporary file before publishing it', () async {
    const bytes = <int>[1, 2, 3, 4, 5];
    final client = MockClient((_) async => http.Response.bytes(bytes, 200));
    final service = OfflineBibleService(
      client: client,
      documentsDirectoryProvider: () async => tempDir,
      databaseValidator: (filePath) async {
        return File(filePath).readAsBytesSync().join(',') == bytes.join(',');
      },
    );
    final progress = <double>[];

    await service.downloadVersion(_douayRheims(), progress.add);

    expect(
      File(
        '${tempDir.path}${Platform.pathSeparator}engdra.db',
      ).readAsBytesSync(),
      bytes,
    );
    expect(
      File(
        '${tempDir.path}${Platform.pathSeparator}engdra.db.part',
      ).existsSync(),
      isFalse,
    );
    expect(progress.last, 1);
  });

  test(
    'failed validation removes the partial file and preserves an installed copy',
    () async {
      final target = File('${tempDir.path}${Platform.pathSeparator}engdra.db')
        ..writeAsBytesSync(const [9, 9, 9]);
      final service = OfflineBibleService(
        client: MockClient((_) async => http.Response.bytes(const [1, 2], 200)),
        documentsDirectoryProvider: () async => tempDir,
        databaseValidator: (_) async => false,
      );

      await expectLater(
        service.downloadVersion(_douayRheims(), (_) {}),
        throwsA(isA<Exception>()),
      );

      expect(target.readAsBytesSync(), const [9, 9, 9]);
      expect(
        File(
          '${tempDir.path}${Platform.pathSeparator}engdra.db.part',
        ).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'recovers an interrupted replacement before starting a download',
    () async {
      final backup = File(
        '${tempDir.path}${Platform.pathSeparator}engdra.db.previous',
      )..writeAsBytesSync(const [9, 8, 7]);
      final target = File('${tempDir.path}${Platform.pathSeparator}engdra.db');
      final service = OfflineBibleService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
        documentsDirectoryProvider: () async => tempDir,
        databaseValidator: (_) async => true,
      );

      await expectLater(
        service.downloadVersion(_douayRheims(), (_) {}),
        throwsA(isA<Exception>()),
      );

      expect(target.readAsBytesSync(), const [9, 8, 7]);
      expect(backup.existsSync(), isFalse);
    },
  );
}

BibleVersion _douayRheims() => BibleVersion(
  id: 'douay_rheims',
  name: 'Douay-Rheims Bible',
  abbreviation: 'DR',
  downloadUrl: 'https://api.elbiblio.com/dbs/engdra.db',
  dbFilename: 'engdra.db',
);
