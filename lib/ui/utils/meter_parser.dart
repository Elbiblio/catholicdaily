class MeterPattern {
  final List<int> beatsPerLine;
  final bool isDoubled;
  final String canonical;

  const MeterPattern({required this.beatsPerLine, required this.isDoubled, required this.canonical});

  static const Map<String, MeterPattern> commonPatterns = {
    'CM': MeterPattern(beatsPerLine: [8, 6, 8, 6], isDoubled: false, canonical: '8.6.8.6'),
    'LM': MeterPattern(beatsPerLine: [8, 8, 8, 8], isDoubled: false, canonical: '8.8.8.8'),
    'SM': MeterPattern(beatsPerLine: [6, 6, 8, 6], isDoubled: false, canonical: '6.6.8.6'),
    'LMD': MeterPattern(beatsPerLine: [8, 8, 8, 8], isDoubled: true, canonical: '8.8.8.8.D'),
    'CMD': MeterPattern(beatsPerLine: [8, 6, 8, 6], isDoubled: true, canonical: '8.6.8.6.D'),
    'SMD': MeterPattern(beatsPerLine: [6, 6, 8, 6], isDoubled: true, canonical: '6.6.8.6.D'),
  };

  static MeterPattern? parse(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9.]'), '');
    if (commonPatterns.containsKey(cleaned)) return commonPatterns[cleaned];

    final parts = cleaned.split('.').where((p) => p.isNotEmpty).map(int.tryParse).whereType<int>().toList();
    if (parts.isEmpty || parts.any((p) => p <= 0)) return null;

    final isDoubled = cleaned.endsWith('.D');
    final canonical = parts.join('.');
    return MeterPattern(beatsPerLine: parts, isDoubled: isDoubled, canonical: canonical);
  }

  static List<int> expandBeats(MeterPattern pattern) {
    if (!pattern.isDoubled) return pattern.beatsPerLine;
    final doubled = <int>[];
    for (final beats in pattern.beatsPerLine) {
      doubled.addAll([beats, beats]);
    }
    return doubled;
  }
}

class TunePhraseMap {
  final List<int> lineBeats;
  final int pickupBeats;
  final int? bpm;
  final String? timeSignature;

  const TunePhraseMap({required this.lineBeats, required this.pickupBeats, this.bpm, this.timeSignature});

  factory TunePhraseMap.fromMap(Map<String, dynamic> map) {
    final rawLineBeats = map['line_beats'];
    final lineBeats = (rawLineBeats is List)
        ? rawLineBeats.whereType<int>().toList()
        : <int>[];
    final pickupBeats = (map['pickup_beats'] as int?) ?? 0;
    final bpm = map['bpm'] as int?;
    final timeSignature = map['time_signature'] as String?;
    return TunePhraseMap(lineBeats: lineBeats, pickupBeats: pickupBeats, bpm: bpm, timeSignature: timeSignature);
  }

  bool get isValid => lineBeats.isNotEmpty && lineBeats.every((b) => b > 0);
}
