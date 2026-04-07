import 'dart:math' as math;

import 'meter_parser.dart';

class SingAlongTimeline {
  final List<SingAlongLine> lines;
  final List<SingAlongWord> allWords;
  final int totalMs;

  const SingAlongTimeline({
    required this.lines,
    required this.allWords,
    required this.totalMs,
  });

  const SingAlongTimeline.empty()
      : this(lines: const [], allWords: const [], totalMs: 0);

  bool get hasWords => allWords.isNotEmpty;

  factory SingAlongTimeline.fromLyrics(
    List<String> lyrics, {
    required int bpm,
    String? meterRaw,
    TunePhraseMap? tunePhraseMap,
  }) {
    final msPerBeat = 60000 / bpm;
    final introMs = (msPerBeat * 4).round();
    final totalLyricWords = lyrics
        .expand((line) => line.split(RegExp(r'\s+')))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty && !isNonLyricMarker(w))
        .length;
    final availableMs = totalLyricWords > 0
        ? math.max(totalLyricWords * 350, introMs + (totalLyricWords * 250))
        : 0;
    final baseMsPerWord = totalLyricWords > 0 && availableMs > 0
        ? (availableMs - introMs) / totalLyricWords
        : msPerBeat * 0.9;

    // Prefer tune phrase map when available; otherwise fall back to meter pattern
    final tuneBeats = tunePhraseMap?.lineBeats;
    final meterPattern = meterRaw != null ? MeterPattern.parse(meterRaw) : null;
    final meterBeats = meterPattern != null ? MeterPattern.expandBeats(meterPattern) : null;
    final effectiveLineBeats = tuneBeats ?? meterBeats;

    final lines = <SingAlongLine>[];
    final flat = <SingAlongWord>[];
    var currentMs = 0.0;
    var globalIndex = 0;
    currentMs += introMs;
    var lineIndex = 0;

    for (final rawLine in lyrics) {
      if (rawLine.trim().isEmpty) {
        if (lines.isNotEmpty) {
          final prev = lines.removeLast();
          lines.add(prev.copyWith(hasBreakAfter: true));
        }
        continue;
      }

      if (_isNonLyricMarkerLine(rawLine)) {
        continue;
      }

      final splitWords = rawLine
          .split(RegExp(r'\s+'))
          .where((w) => w.trim().isNotEmpty)
          .toList();
      final lineWords = <SingAlongWord>[];

      // Use meter/tune beats to shape line timing if available
      var lineTargetBeats = effectiveLineBeats != null && lineIndex < effectiveLineBeats.length
          ? effectiveLineBeats[lineIndex]
          : null;

      for (final rawWord in splitWords) {
        final word = rawWord.trim();
        if (isNonLyricMarker(word)) {
          continue;
        }

        final cleanWord = word.replaceAll(RegExp(r':$'), '');
        final syllables = syllableCount(cleanWord);

        var wordMs = baseMsPerWord;
        wordMs *= (0.72 + (syllables * 0.16)).clamp(0.75, 1.75);
        if (RegExp(r'[,;:]$').hasMatch(cleanWord)) wordMs += msPerBeat * 0.22;
        if (RegExp(r'[.!?]$').hasMatch(cleanWord)) wordMs += msPerBeat * 0.5;
        if (cleanWord.length > 6) wordMs += 40;
        if (cleanWord.length > 10) wordMs += 55;
        wordMs = wordMs.clamp(140.0, msPerBeat * 2.8);

        // If we have a meter/tune target, bias toward proportional line timing
        if (lineTargetBeats != null && lineTargetBeats > 0) {
          final targetMs = (lineTargetBeats * msPerBeat);
          final bias = 0.4;
          wordMs = wordMs * (1 - bias) + (targetMs / splitWords.length) * bias;
        }

        final start = currentMs.round();
        final end = (currentMs + wordMs).round();

        final timelineWord = SingAlongWord(
          text: cleanWord,
          globalIndex: globalIndex,
          lineIndex: lines.length,
          startMs: start,
          endMs: math.max(end, start + 100),
        );
        lineWords.add(timelineWord);
        flat.add(timelineWord);

        currentMs = timelineWord.endMs.toDouble();
        globalIndex++;
      }

      lines.add(SingAlongLine(words: lineWords, hasBreakAfter: false));
      currentMs += msPerBeat * 0.45;
      lineIndex++;
    }

    final totalMs = flat.isEmpty ? 0 : math.max(flat.last.endMs + 200, 1);
    return SingAlongTimeline(lines: lines, allWords: flat, totalMs: totalMs);
  }

  int wordIndexAt(int ms) {
    if (allWords.isEmpty) return 0;

    var low = 0;
    var high = allWords.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final word = allWords[mid];
      if (ms < word.startMs) {
        high = mid - 1;
      } else if (ms >= word.endMs) {
        low = mid + 1;
      } else {
        return mid;
      }
    }

    return low.clamp(0, allWords.length - 1);
  }

  int lineIndexForWord(int wordIndex) {
    if (allWords.isEmpty) return 0;
    final safe = wordIndex.clamp(0, allWords.length - 1);
    return allWords[safe].lineIndex;
  }

  /// Rebuild timeline with a new BPM (for after calibration)
  SingAlongTimeline rebuildWithBpm(int newBpm) {
    return SingAlongTimeline.fromLyrics(
      _extractLyricsFromLines(),
      bpm: newBpm,
      meterRaw: null, // Would need to store this if needed
      tunePhraseMap: null,
    );
  }

  /// Extract plain lyrics from current lines for rebuilding
  List<String> _extractLyricsFromLines() {
    final lyrics = <String>[];
    for (final line in lines) {
      final lineText = line.words.map((w) => w.text).join(' ');
      lyrics.add(lineText);
      if (line.hasBreakAfter) {
        lyrics.add('');
      }
    }
    return lyrics;
  }

  static int syllableCount(String raw) {
    final word = raw.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (word.isEmpty) return 1;

    final groups = RegExp(r'[aeiouy]+').allMatches(word).length;
    final silentE = word.endsWith('e') && groups > 1 ? 1 : 0;
    return math.max(1, groups - silentE);
  }

  static bool isNonLyricMarker(String word) {
    final lower = word.toLowerCase().trim();
    final markers = {
      'chorus:', 'verse 1:', 'verse 2:', 'verse 3:', 'verse 4:',
      'verse 5:', 'verse 6:', 'verse 7:', 'verse 8:',
      'bridge:', 'refrain:', 'pre-chorus:', 'post-chorus:',
      'intro:', 'outro:', 'instrumental:',
      'tag:', 'tags:', 'repeat:', 'repeat 2x:', 'repeat 3x:',
      'optional:', 'men:', 'women:', 'all:', 'solo:',
      'response:', 'leader:', 'congregation:',
    };

    return markers.contains(lower) ||
        lower.startsWith('verse ') ||
        lower.startsWith('chorus') ||
        lower.startsWith('bridge') ||
        lower.startsWith('refrain') ||
        lower.startsWith('intro') ||
        lower.startsWith('outro');
  }

  static bool _isNonLyricMarkerLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return false;

    if (RegExp(r'^verse\s+\d+:?$').hasMatch(lower)) return true;
    if (RegExp(r'^(chorus|bridge|refrain|intro|outro|instrumental|response|leader|congregation):?$')
        .hasMatch(lower)) {
      return true;
    }

    return false;
  }
}

class SingAlongLine {
  final List<SingAlongWord> words;
  final bool hasBreakAfter;

  const SingAlongLine({required this.words, required this.hasBreakAfter});

  SingAlongLine copyWith({List<SingAlongWord>? words, bool? hasBreakAfter}) {
    return SingAlongLine(
      words: words ?? this.words,
      hasBreakAfter: hasBreakAfter ?? this.hasBreakAfter,
    );
  }
}

class SingAlongWord {
  final String text;
  final int globalIndex;
  final int lineIndex;
  final int startMs;
  final int endMs;

  const SingAlongWord({
    required this.text,
    required this.globalIndex,
    required this.lineIndex,
    required this.startMs,
    required this.endMs,
  });
}
