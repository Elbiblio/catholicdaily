import 'dart:io';
import 'package:catholic_daily/data/services/readings_backend_io.dart';
import 'package:catholic_daily/data/services/reading_flow_service.dart';
import 'test/helpers/test_helpers.dart';

Future<void> main() async {
  setupFlutterTestEnvironment();
  final dir = await createTempTestDir('ci_inspect_');
  final cleanup = mockMethodChannels(tempDocsPath: dir.path);
  final backend = ReadingsBackendIo();
  final flow = ReadingFlowService.instance;
  for (final date in [DateTime(2026, 12, 24), DateTime(2024, 12, 24), DateTime(2026, 4, 4)]) {
    final raw = await backend.getReadingsForDate(date);
    final hydrated = await flow.hydrateReadingSet(date: date, readings: raw);
    stdout.writeln('DATE ${date.toIso8601String().split('T').first} count=${hydrated.readings.length}');
    for (final r in hydrated.readings) {
      stdout.writeln(' - ${r.position} | ${r.reading} | psalm=${r.psalmResponse != null} | accl=${r.gospelAcclamation != null}');
    }
  }
  cleanup();
  cleanupTempDir(dir);
}
