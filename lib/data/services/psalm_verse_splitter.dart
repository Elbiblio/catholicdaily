/// Psalm Verse Splitter for Catholic Lectionary Notation
/// 
/// Handles splitting psalm verses into parts (a, b, c, d) to support
/// lectionary notation like "4bc-5ab, 6 and 7bc, 8-9"
/// 
/// Since the RSVCE database stores complete verses only, we need to
/// intelligently split them based on punctuation and poetic structure.
class PsalmVerseSplitter {
  /// Split a verse into parts (a, b, c, d) based on punctuation
  /// 
  /// Hebrew poetry uses parallelism, so verses typically have 2-4 lines.
  /// Two-pass split:
  ///   1. Split on sentence-ending punctuation (. ; ! ?)
  ///   2. Split each sentence on comma + conjunction boundaries
  /// This produces finer-grained parts so notation like "13cd" resolves
  /// correctly even for long verses.
  static List<String> splitVerse(String verseText) {
    // Remove verse number if present at start
    var text = verseText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
    // Normalise missing spaces after commas before conjunctions
    text = text.replaceAllMapped(
      RegExp(r',(?=(?:and|but|or|yet|for|nor|so|because|that|who)\b)', caseSensitive: false),
      (m) => ', ',
    );

    final parts = <String>[];

    // Pass 1 – split on sentence-ending punctuation
    final sentences = text.split(RegExp(r'(?<=[.!?;])\s*'));

    for (final sentence in sentences) {
      final trimmed = sentence.trim();
      if (trimmed.isEmpty) continue;

      // Pass 2 – split each sentence on comma + conjunction boundaries
      final subParts = _splitOnConjunctionComma(trimmed);
      parts.addAll(subParts);
    }

    if (parts.isEmpty) {
      parts.add(text);
    }

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
