import 'daily_reading.dart';
import 'navigable_item.dart';

class ReadingSession {
  final List<DailyReading> readings;
  final Map<String, String> readingTexts;
  final int currentIndex;
  final List<NavigableItem> navigableItems;
  final int navigableIndex;

  const ReadingSession({
    required this.readings,
    required this.readingTexts,
    required this.currentIndex,
    this.navigableItems = const [],
    this.navigableIndex = 0,
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

  bool get hasNextNavigable => navigableIndex >= 0 && navigableIndex < navigableItems.length - 1;
  bool get hasPrevNavigable => navigableIndex > 0 && navigableIndex < navigableItems.length;

  String? textFor(String reference) => readingTexts[reference];

  ReadingSession copyWith({
    List<DailyReading>? readings,
    Map<String, String>? readingTexts,
    int? currentIndex,
    List<NavigableItem>? navigableItems,
    int? navigableIndex,
  }) {
    return ReadingSession(
      readings: readings ?? this.readings,
      readingTexts: readingTexts ?? this.readingTexts,
      currentIndex: currentIndex ?? this.currentIndex,
      navigableItems: navigableItems ?? this.navigableItems,
      navigableIndex: navigableIndex ?? this.navigableIndex,
    );
  }
}
