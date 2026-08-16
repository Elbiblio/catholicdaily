import 'daily_reading.dart';
import 'navigable_item.dart';
import '../services/improved_liturgical_calendar_service.dart';
import 'resolved_responsorial_psalm.dart';

class ReadingSession {
  final List<DailyReading> readings;
  final Map<String, String> readingTexts;
  final Map<String, ResolvedResponsorialPsalm> psalmSources;
  final int currentIndex;
  final List<NavigableItem> navigableItems;
  final int navigableIndex;
  final LiturgicalDay? liturgicalDay;

  const ReadingSession({
    required this.readings,
    required this.readingTexts,
    this.psalmSources = const <String, ResolvedResponsorialPsalm>{},
    required this.currentIndex,
    this.navigableItems = const [],
    this.navigableIndex = 0,
    this.liturgicalDay,
  });

  factory ReadingSession.empty() {
    return const ReadingSession(
      readings: [],
      readingTexts: {},
      currentIndex: 0,
      navigableItems: [],
      navigableIndex: 0,
    );
  }

  bool get isEmpty => readings.isEmpty;
  bool get hasNavigableItems => navigableItems.isNotEmpty;

  DailyReading? get currentReading {
    if (currentIndex < 0 || currentIndex >= readings.length) {
      return null;
    }
    return readings[currentIndex];
  }

  NavigableItem? get currentNavigableItem {
    if (navigableIndex < 0 || navigableIndex >= navigableItems.length) {
      return null;
    }
    return navigableItems[navigableIndex];
  }

  bool get hasNext => currentIndex >= 0 && currentIndex < readings.length - 1;
  bool get hasPrev => currentIndex > 0 && currentIndex < readings.length;

  bool get hasNextNavigable =>
      navigableIndex >= 0 && navigableIndex < navigableItems.length - 1;
  bool get hasPrevNavigable =>
      navigableIndex > 0 && navigableIndex < navigableItems.length;

  String? textFor(String reference) => readingTexts[reference];

  static bool sameReadingSet(
    List<DailyReading> first,
    List<DailyReading> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final a = first[index];
      final b = second[index];
      if (a.reading != b.reading ||
          a.position != b.position ||
          !_sameCalendarDate(a.date, b.date)) {
        return false;
      }
    }
    return true;
  }

  ReadingSession selectReading(int index) {
    if (index < 0 || index >= readings.length) return this;
    final reading = readings[index];
    final resolvedNavigableIndex = navigableItems.indexWhere(
      (item) =>
          item.isReading &&
          item.reading?.reading == reading.reading &&
          item.reading?.position == reading.position,
    );
    return copyWith(
      currentIndex: index,
      navigableIndex: resolvedNavigableIndex >= 0
          ? resolvedNavigableIndex
          : index,
    );
  }

  static bool _sameCalendarDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  ReadingSession copyWith({
    List<DailyReading>? readings,
    Map<String, String>? readingTexts,
    Map<String, ResolvedResponsorialPsalm>? psalmSources,
    int? currentIndex,
    List<NavigableItem>? navigableItems,
    int? navigableIndex,
    LiturgicalDay? liturgicalDay,
  }) {
    return ReadingSession(
      readings: readings ?? this.readings,
      readingTexts: readingTexts ?? this.readingTexts,
      psalmSources: psalmSources ?? this.psalmSources,
      currentIndex: currentIndex ?? this.currentIndex,
      navigableItems: navigableItems ?? this.navigableItems,
      navigableIndex: navigableIndex ?? this.navigableIndex,
      liturgicalDay: liturgicalDay ?? this.liturgicalDay,
    );
  }
}
