import '../models/daily_reading.dart';
import '../models/reading_session.dart';
import '../../ui/utils/reading_title_formatter.dart';
import 'psalm_resolver_service.dart';
import 'readings_service.dart';
import 'base_service.dart';

class HydratedReadingSet {
  final List<DailyReading> readings;
  final Map<String, String> readingTitles;
  final Map<String, String> readingPreviews;
  final Map<String, String> readingTexts;

  const HydratedReadingSet({
    required this.readings,
    required this.readingTitles,
    required this.readingPreviews,
    required this.readingTexts,
  });
}

class ReadingFlowService extends BaseService<ReadingFlowService> {
  static ReadingFlowService get instance => BaseService.init(() => ReadingFlowService._());
  
  ReadingFlowService._();

  final PsalmResolverService _psalmResolver = PsalmResolverService.instance;
  final ReadingsService _readingsService = ReadingsService.instance;

  Future<HydratedReadingSet> hydrateReadingSet({
    required DateTime date,
    required List<DailyReading> readings,
  }) async {
    final enrichedReadings = await _psalmResolver.enrichReadingsForDisplay(
      date: date,
      readings: readings,
    );

    final titles = <String, String>{};
    final previews = <String, String>{};
    final texts = <String, String>{};

    await Future.wait(
      enrichedReadings.map((reading) async {
        final text = await _readingsService.getReadingText(
          reading.reading,
          psalmResponse: reading.psalmResponse,
          incipit: reading.incipit,
        );
        titles[reading.reading] = ReadingTitleFormatter.build(
          reference: reading.reading,
          position: reading.position,
        );
        previews[reading.reading] = buildPreview(reading, text);
        texts[reading.reading] = text;
      }),
    );

    return HydratedReadingSet(
      readings: enrichedReadings,
      readingTitles: titles,
      readingPreviews: previews,
      readingTexts: texts,
    );
  }

  Future<String> getReadingText(DailyReading reading) {
    return _readingsService.getReadingText(
      reading.reading,
      psalmResponse: reading.psalmResponse,
      incipit: reading.incipit,
    );
  }

  ReadingSession buildSession({
    required List<DailyReading> readings,
    required Map<String, String> readingTexts,
    required int selectedIndex,
  }) {
    return ReadingSession(
      readings: List<DailyReading>.from(readings),
      readingTexts: Map<String, String>.from(readingTexts),
      currentIndex: selectedIndex,
    );
  }

  String buildPreview(DailyReading reading, String fullText) {
    if (fullText.trim().isEmpty) {
      return 'Tap to open this reading.';
    }

    final firstLine = fullText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    final withoutVerse = firstLine.replaceFirst(RegExp(r'^\d+[.]\s*'), '');
    if (withoutVerse.length <= 160) {
      return withoutVerse;
    }
    return '${withoutVerse.substring(0, 160).trimRight()}...';
  }
}
