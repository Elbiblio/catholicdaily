import 'daily_reading.dart';

class ReadingSession {
  final List<DailyReading> readings;
  final Map<String, String> readingTexts;
  final int currentIndex;

  const ReadingSession({
    required this.readings,
    required this.readingTexts,
    required this.currentIndex,
  });

  factory ReadingSession.empty() {
    return const ReadingSession(
      readings: [],
      readingTexts: {},
      currentIndex: 0,
    );
  }

  bool get isEmpty => readings.isEmpty;

  DailyReading? get currentReading {
    if (currentIndex < 0 || currentIndex >= readings.length) {
      return null;
    }
    return readings[currentIndex];
  }

  bool get hasNext => currentIndex >= 0 && currentIndex < readings.length - 1;

  bool get hasPrev => currentIndex > 0 && currentIndex < readings.length;

  String? textFor(String reference) => readingTexts[reference];

  ReadingSession copyWith({
    List<DailyReading>? readings,
    Map<String, String>? readingTexts,
    int? currentIndex,
  }) {
    return ReadingSession(
      readings: readings ?? this.readings,
      readingTexts: readingTexts ?? this.readingTexts,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}
