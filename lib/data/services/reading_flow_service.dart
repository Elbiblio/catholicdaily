import '../models/daily_reading.dart';
import '../models/reading_session.dart';
import '../models/navigable_item.dart';
import '../../ui/utils/reading_title_formatter.dart';
import 'psalm_resolver_service.dart';
import 'readings_service.dart';
import 'base_service.dart';
import 'order_of_mass_service.dart';
import 'order_of_mass_preference_service.dart';

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
  final OrderOfMassService _orderOfMassService = OrderOfMassService();
  final OrderOfMassPreferenceService _orderOfMassPreference = OrderOfMassPreferenceService();

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
        final rawText = await _readingsService.getReadingText(
          reading.reading,
          psalmResponse: reading.psalmResponse,
          incipit: reading.incipit,
        );
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
    List<NavigableItem>? navigableItems,
    int? navigableIndex,
  }) {
    return ReadingSession(
      readings: List<DailyReading>.from(readings),
      readingTexts: Map<String, String>.from(readingTexts),
      currentIndex: selectedIndex,
      navigableItems: navigableItems ?? readings.map((r) => NavigableItem.fromReading(r)).toList(),
      navigableIndex: navigableIndex ?? selectedIndex,
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
    final showOrderOfMass = await _orderOfMassPreference.getShowOrderOfMass();
    
    if (!showOrderOfMass) {
      return readings.map((r) => NavigableItem.fromReading(r)).toList();
    }

    final orderOfMassSections = await _orderOfMassService.getSectionsForDate(date);
    final navigableItems = <NavigableItem>[];
    
    // Add introductory rites before readings
    final introductoryRitesItems = orderOfMassSections
        .where((s) => s.insertionPoint == 'introductory_rites')
        .expand((s) => s.items)
        .toList();
    
    for (final item in introductoryRitesItems) {
      navigableItems.add(NavigableItem.fromOrderOfMass(item, 'introductory_rites'));
    }

    // Add readings interspersed with order of mass items
    for (int i = 0; i < readings.length; i++) {
      final reading = readings[i];
      navigableItems.add(NavigableItem.fromReading(reading));

      // Check if this is the first reading
      if (i == 0) {
        final beforeFirstReadingItems = orderOfMassSections
            .where((s) => s.insertionPoint == 'before_first_reading')
            .expand((s) => s.items)
            .toList();
        for (final item in beforeFirstReadingItems) {
          navigableItems.add(NavigableItem.fromOrderOfMass(item, 'before_first_reading'));
        }
      }

      // Check if this is the gospel reading
      final isGospel = _isGospelReading(reading);
      if (isGospel) {
        final afterGospelItems = orderOfMassSections
            .where((s) => s.insertionPoint == 'after_gospel')
            .expand((s) => s.items)
            .toList();
        for (final item in afterGospelItems) {
          navigableItems.add(NavigableItem.fromOrderOfMass(item, 'after_gospel'));
        }
      }
    }

    // Add concluding rites after all readings
    final concludingRitesItems = orderOfMassSections
        .where((s) => s.insertionPoint == 'concluding_rites')
        .expand((s) => s.items)
        .toList();
    
    for (final item in concludingRitesItems) {
      navigableItems.add(NavigableItem.fromOrderOfMass(item, 'concluding_rites'));
    }

    return navigableItems;
  }

  bool _isGospelReading(DailyReading reading) {
    final position = reading.position?.toLowerCase() ?? '';
    if (position.contains('gospel')) {
      return true;
    }
    final reference = reading.reading.toLowerCase();
    return reference.startsWith('matt ') ||
        reference.startsWith('mark ') ||
        reference.startsWith('luke ') ||
        reference.startsWith('john ');
  }
}
