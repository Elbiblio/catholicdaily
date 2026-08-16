import '../models/daily_reading.dart';
import '../models/reading_session.dart';
import '../models/navigable_item.dart';
import '../models/resolved_responsorial_psalm.dart';
import '../../ui/utils/reading_title_formatter.dart';
import 'bible_version_preference.dart';
import 'liturgical_region_preference_service.dart';
import 'local_lectionary_extract_text_service.dart';
import 'psalm_resolver_service.dart';
import 'readings_service.dart';
import 'base_service.dart';
import 'improved_liturgical_calendar_service.dart';

class HydratedReadingSet {
  final List<DailyReading> readings;
  final Map<String, String> readingTitles;
  final Map<String, String> readingPreviews;
  final Map<String, String> readingTexts;
  final Map<String, ResolvedResponsorialPsalm> psalmSources;

  const HydratedReadingSet({
    required this.readings,
    required this.readingTitles,
    required this.readingPreviews,
    required this.readingTexts,
    this.psalmSources = const <String, ResolvedResponsorialPsalm>{},
  });
}

class ReadingFlowService extends BaseService<ReadingFlowService> {
  static ReadingFlowService get instance =>
      BaseService.init(() => ReadingFlowService._());

  ReadingFlowService._();

  final PsalmResolverService _psalmResolver = PsalmResolverService.instance;
  final ReadingsService _readingsService = ReadingsService.instance;
  final LocalLectionaryExtractTextService _localExtractText =
      LocalLectionaryExtractTextService.instance;

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
    final psalmSources = <String, ResolvedResponsorialPsalm>{};
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    final versionPrefs = await BibleVersionPreference.getInstance();

    await Future.wait(
      enrichedReadings.map((reading) async {
        final isResponsorial = (reading.position ?? '').toLowerCase().contains(
          'responsorial psalm',
        );
        String? rawText;
        if (isResponsorial) {
          final resolved = await _readingsService.resolveResponsorialPsalm(
            reading.reading,
            psalmResponse: reading.psalmResponse,
            date: date,
            territory: regionPrefs.currentRegion.code,
            celebrationId: _celebrationId(reading),
            readingSetKind: _readingSetKind(reading),
          );
          rawText = resolved.text;
          psalmSources[reading.reading] = resolved;
        } else {
          rawText = await _localExtractText.lookup(
            date: date,
            regionCode: regionPrefs.currentRegion.code,
            bibleVersionId: versionPrefs.currentDbName,
            reference: reading.reading,
            position: reading.position,
          );
          rawText ??= await _readingsService.getReadingText(
            reading.reading,
            psalmResponse: reading.psalmResponse,
            incipit: reading.incipit,
            readingType: reading.position,
          );
        }
        final openingAdaptation = await _localExtractText.adaptOpening(
          date: date,
          regionCode: regionPrefs.currentRegion.code,
          bibleVersionId: versionPrefs.currentDbName,
          reference: reading.reading,
          position: reading.position,
          renderedText: rawText,
        );
        if (openingAdaptation?.applied == true) {
          rawText = openingAdaptation!.text;
        }
        // Text is already processed by IncipitProcessingService in ReadingsService
        final text = rawText;
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
      psalmSources: psalmSources,
    );
  }

  Future<String> getReadingText(DailyReading reading) async {
    final regionPrefs = await LiturgicalRegionPreferenceService.getInstance();
    return _readingsService.getReadingText(
      reading.reading,
      psalmResponse: reading.psalmResponse,
      incipit: reading.incipit,
      readingType: reading.position,
      date: reading.date,
      territory: regionPrefs.currentRegion.code,
      celebrationId: _celebrationId(reading),
      readingSetKind: _readingSetKind(reading),
    );
  }

  String _celebrationId(DailyReading reading) {
    final source = reading.source ?? '';
    final match = RegExp(r'(?:celebration|proper):([^|;]+)').firstMatch(source);
    final explicit = match?.group(1)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return (reading.feast ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _readingSetKind(DailyReading reading) {
    final position = (reading.position ?? '').toLowerCase();
    if (position.contains('vigil')) return 'vigil';
    if ((reading.source ?? '').contains('weekday')) return 'weekday';
    return 'celebration';
  }

  ReadingSession buildSession({
    required List<DailyReading> readings,
    required Map<String, String> readingTexts,
    required int selectedIndex,
    Map<String, ResolvedResponsorialPsalm> psalmSources =
        const <String, ResolvedResponsorialPsalm>{},
    List<NavigableItem>? navigableItems,
    int? navigableIndex,
    LiturgicalDay? liturgicalDay,
  }) {
    return ReadingSession(
      readings: List<DailyReading>.from(readings),
      readingTexts: Map<String, String>.from(readingTexts),
      psalmSources: Map<String, ResolvedResponsorialPsalm>.from(psalmSources),
      currentIndex: selectedIndex,
      navigableItems:
          navigableItems ??
          readings.map((r) => NavigableItem.fromReading(r)).toList(),
      navigableIndex: navigableIndex ?? selectedIndex,
      liturgicalDay: liturgicalDay,
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

  Future<List<NavigableItem>> buildNavigableFlow({
    required DateTime date,
    required List<DailyReading> readings,
  }) async {
    // Return only readings without interspersed Order of Mass items
    // Order of Mass is now accessed separately via the Mass screen
    return readings.map((r) => NavigableItem.fromReading(r)).toList();
  }
}
