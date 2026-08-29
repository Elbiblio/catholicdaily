import '../models/daily_reading.dart';
import '../models/reading_session.dart';
import 'reading_narration_composer.dart';

class ReadingNarrationQueueItem {
  final String id;
  final String slotKey;
  final DailyReading reading;
  final ReadingNarration narration;

  const ReadingNarrationQueueItem({
    required this.id,
    required this.slotKey,
    required this.reading,
    required this.narration,
  });
}

class ReadingNarrationQueueBuilder {
  final ReadingNarrationComposer composer;

  const ReadingNarrationQueueBuilder({required this.composer});

  List<ReadingNarrationQueueItem> buildCurrent(
    ReadingSession session, {
    bool showIncipit = true,
    String? displayedGospelAcclamation,
  }) {
    final current = session.currentReading;
    if (current == null) return const <ReadingNarrationQueueItem>[];
    final item = _buildItem(
      current,
      session.textFor(current.reading) ?? '',
      showIncipit: showIncipit,
      displayedPsalmResponse:
          session.psalmSources[current.reading]?.responseText,
      displayedGospelAcclamation: displayedGospelAcclamation,
    );
    return item == null
        ? const <ReadingNarrationQueueItem>[]
        : <ReadingNarrationQueueItem>[item];
  }

  List<ReadingNarrationQueueItem> buildReadAll(
    ReadingSession session, {
    Iterable<DailyReading> selectedReadings = const <DailyReading>[],
    bool showIncipit = true,
    Map<String, String> displayedGospelAcclamations = const <String, String>{},
  }) {
    final selectedBySlot = <String, DailyReading>{
      for (final reading in selectedReadings) _slotKey(reading): reading,
    };
    final primaryBySlot = <String, DailyReading>{};
    final slotOrder = <String>[];

    for (final reading in session.readings) {
      final slot = _slotKey(reading);
      if (!primaryBySlot.containsKey(slot)) {
        primaryBySlot[slot] = reading;
        slotOrder.add(slot);
      }
      if (!_isAlternative(reading)) {
        primaryBySlot[slot] = reading;
      }
    }

    final result = <ReadingNarrationQueueItem>[];
    for (final slot in slotOrder) {
      final reading = selectedBySlot[slot] ?? primaryBySlot[slot]!;
      final item = _buildItem(
        reading,
        session.textFor(reading.reading) ?? '',
        showIncipit: showIncipit,
        displayedPsalmResponse:
            session.psalmSources[reading.reading]?.responseText,
        displayedGospelAcclamation:
            displayedGospelAcclamations[reading.reading],
      );
      if (item != null) result.add(item);
    }
    return List<ReadingNarrationQueueItem>.unmodifiable(result);
  }

  List<ReadingNarrationQueueItem> buildCurrentBibleChapter({
    required String reference,
    required String displayedText,
  }) {
    final reading = DailyReading(
      reading: reference,
      position: 'Bible Chapter',
      date: DateTime(0),
    );
    final narration = composer.compose(
      reading: reading,
      displayedText: displayedText,
      showIncipit: false,
      isBibleChapter: true,
    );
    if (!narration.isAvailable) return const <ReadingNarrationQueueItem>[];
    return <ReadingNarrationQueueItem>[
      ReadingNarrationQueueItem(
        id: 'bible:${reference.trim().toLowerCase()}',
        slotKey: 'bible chapter',
        reading: reading,
        narration: narration,
      ),
    ];
  }

  ReadingNarrationQueueItem? _buildItem(
    DailyReading reading,
    String displayedText, {
    required bool showIncipit,
    String? displayedPsalmResponse,
    String? displayedGospelAcclamation,
  }) {
    final narration = composer.compose(
      reading: reading,
      displayedText: displayedText,
      showIncipit: showIncipit,
      displayedPsalmResponse: displayedPsalmResponse,
      displayedGospelAcclamation: displayedGospelAcclamation,
    );
    if (!narration.isAvailable) return null;
    final slot = _slotKey(reading);
    return ReadingNarrationQueueItem(
      id: '${reading.date.toIso8601String()}:$slot:${reading.reading}',
      slotKey: slot,
      reading: reading,
      narration: narration,
    );
  }

  static bool _isAlternative(DailyReading reading) => RegExp(
    r'(?:\(alternative(?:\s+\d+|\s+shorter form)?\)|\(?shorter form\)?)\s*$',
    caseSensitive: false,
  ).hasMatch(reading.position ?? '');

  static String _slotKey(DailyReading reading) {
    return (reading.position ?? 'Reading')
        .replaceFirst(
          RegExp(
            r'\s*(?:\(alternative(?:\s+\d+|\s+shorter form)?\)|\(?shorter form\)?)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }
}
