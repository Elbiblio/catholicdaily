/// Psalm Verse Splitter for Catholic Lectionary Notation
/// 
/// Handles splitting psalm verses into parts (a, b, c, d) to support
/// lectionary notation like "4bc-5ab, 6 and 7bc, 8-9"
/// 
/// Since the RSVCE database stores complete verses only, we need to
/// intelligently split them based on punctuation and poetic structure.
class PsalmVerseSplitter {
  /// Split a verse into parts (a, b, c, d) based on punctuation.
  ///
  /// Hebrew poetry is typically bicolon (a/b parallelism). We respect
  /// strong sentence boundaries (. ; ! ?) first; then, within a sentence,
  /// we collapse a multi-clause list into a BINARY split so lectionary
  /// "Xa" notation returns the FIRST HALF of the parallelism rather than
  /// just the opening clause.
  ///
  /// Example:
  ///   "This poor man cried, and the LORD heard him, and saved him out of
  ///    all his troubles."
  ///   → ["This poor man cried, and the LORD heard him",
  ///      "and saved him out of all his troubles"]
  ///   getVersePart("a") returns the full first half (matches Lectionary).
  static List<String> splitVerse(String verseText) {
    var text = verseText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
    text = text.replaceAllMapped(
      RegExp(r',(?=(?:and|but|or|yet|for|nor|so|because|that|who)\b)',
          caseSensitive: false),
      (m) => ', ',
    );

    final parts = <String>[];
    final sentences = text.split(RegExp(r'(?<=[.!?;])\s*'));

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      final subParts = _splitOnConjunctionComma(trimmed);
      if (subParts.length <= 2) {
        parts.addAll(subParts);
      } else {
        // Fold N>2 clauses into a 2-part a/b split at the BALANCED boundary
        // (the conjunction comma whose split yields the most even halves).
        final pair = _balancedBinarySplit(trimmed);
        parts.addAll(pair);
      }
    }

    if (parts.isEmpty) {
      parts.add(text);
    }

    return parts;
  }

  /// Splits [sentence] at the comma+conjunction boundary that produces the
  /// most balanced a/b halves. Falls back to a single-element list when no
  /// comma+conjunction boundary exists.
  static List<String> _balancedBinarySplit(String sentence) {
    final stripped = sentence.replaceFirst(RegExp(r'[.!?;:]\s*$'), '');
    final boundaryPattern = RegExp(
      r',\s*(?=(?:and|but|or|yet|for|nor|so|because|that|who)\b)',
      caseSensitive: false,
    );
    final matches = boundaryPattern.allMatches(stripped).toList();
    if (matches.isEmpty) return [stripped.trim()];

    final length = stripped.length;
    final mid = length / 2;
    // Pick the boundary whose start position is closest to mid.
    RegExpMatch? best;
    num bestDelta = double.infinity;
    for (final m in matches) {
      final delta = (m.start - mid).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = m;
      }
    }
    if (best == null) return [stripped.trim()];

    final a = stripped.substring(0, best.start).trim();
    final b = stripped.substring(best.end).trim();
    final parts = <String>[];
    if (a.isNotEmpty) parts.add(a);
    if (b.isNotEmpty) parts.add(b);
    if (parts.isEmpty) return [stripped.trim()];
    return parts;
  }

  /// Split a clause on comma boundaries that separate independent
  /// sub-clauses in Hebrew poetic parallelism.
  static List<String> _splitOnConjunctionComma(String text) {
    // Strip trailing sentence punctuation before splitting
    final stripped = text.replaceFirst(RegExp(r'[.!?;:]\s*$'), '');
    
    final pattern = RegExp(
      r',\s*(?=(?:and|but|or|yet|for|nor|so|because|that|who)\b)',
      caseSensitive: false,
    );
    final splits = stripped.split(pattern);
    final parts = <String>[];
    for (var segment in splits) {
      segment = segment.trim();
      if (segment.isNotEmpty) {
        parts.add(segment);
      }
    }
    if (parts.isEmpty) {
      parts.add(stripped.trim());
    }
    return parts;
  }
  
  /// Get a specific part (a, b, c, d) from a verse
  /// 
  /// Parts are 0-indexed: a=0, b=1, c=2, d=3
  static String? getVersePart(String verseText, String partLetter) {
    final parts = splitVerse(verseText);
    final index = _partLetterToIndex(partLetter);
    
    if (index >= 0 && index < parts.length) {
      return parts[index];
    }
    
    return null;
  }
  
  /// Get multiple parts from a verse (e.g., "bc" returns parts b and c)
  static String? getVerseParts(String verseText, String partLetters) {
    final parts = splitVerse(verseText);
    final selectedParts = <String>[];
    
    for (var i = 0; i < partLetters.length; i++) {
      final letter = partLetters[i];
      final index = _partLetterToIndex(letter);
      
      if (index >= 0 && index < parts.length) {
        selectedParts.add(parts[index]);
      }
    }
    
    if (selectedParts.isEmpty) return null;
    
    // For consecutive parts like "cd", join them without extra punctuation
    // to preserve the natural flow of the verse
    String joined;
    if (partLetters.length > 1) {
      // Check if parts are consecutive (like cd, bc, etc.)
      bool isConsecutive = true;
      for (var i = 1; i < partLetters.length; i++) {
        final prevIndex = _partLetterToIndex(partLetters[i-1]);
        final currIndex = _partLetterToIndex(partLetters[i]);
        if (currIndex != prevIndex + 1) {
          isConsecutive = false;
          break;
        }
      }
      
      if (isConsecutive) {
        // Join consecutive parts with space to maintain flow
        joined = selectedParts.join(' ');
      } else {
        // Join non-consecutive parts with semicolon
        joined = selectedParts.join('; ');
      }
    } else {
      joined = selectedParts.first;
    }
    
    return joined;
  }
  
  /// Convert part letter (a, b, c, d) to index (0, 1, 2, 3)
  static int _partLetterToIndex(String letter) {
    switch (letter.toLowerCase()) {
      case 'a':
        return 0;
      case 'b':
        return 1;
      case 'c':
        return 2;
      case 'd':
        return 3;
      default:
        return -1;
    }
  }
}
