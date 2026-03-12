/// Responsorial Psalm Verse Parser
/// 
/// Handles complex Psalm verse references like:
/// - Ps 25:4bc-5ab, 6+7bc, 8-9
/// - Ps 42:2-3, 43:3-4
/// - Ps 103:1-2, 3-4, 5-6
/// 
/// The notation system:
/// - Letters (a, b, c) refer to parts of verses
/// - Hyphen (-) indicates a range
/// - Comma (,) separates different verse groups
/// - Plus (+) indicates consecutive verses to be combined
class ResponsorialPsalmParser {
  /// Parse a complex Psalm reference into individual verse ranges
  static List<PsalmVerseRange> parse(String reference) {
    final ranges = <PsalmVerseRange>[];
    
    // Extract book info first (e.g., "Ps 25")
    final bookMatch = RegExp(r'Ps\s+(\d+)').firstMatch(reference);
    if (bookMatch == null) return [];
    
    final chapter = int.parse(bookMatch.group(1)!);
    
    // Extract verse part (everything after the chapter)
    final versePart = reference.substring(bookMatch.end).trim();
    if (versePart.startsWith(':')) {
      final actualVersePart = versePart.substring(1); // Remove ':'
      
      // Handle comma-separated parts (e.g., "4bc-5ab, 6+7bc, 8-9")
      if (actualVersePart.contains(',')) {
        final parts = actualVersePart.split(',');
        for (var part in parts) {
          final trimmed = part.trim();
          if (trimmed.isNotEmpty) {
            final parsedRanges = _parseVersePart(chapter, trimmed);
            ranges.addAll(parsedRanges);
          }
        }
      } else {
        ranges.addAll(_parseVersePart(chapter, actualVersePart));
      }
    }
    
    return ranges;
  }
  
  /// Parse a verse part (e.g., "4bc-5ab", "6+7bc", "8-9")
  static List<PsalmVerseRange> _parseVersePart(int chapter, String versePart) {
    final result = <PsalmVerseRange>[];
    
    // Handle ranges with hyphens
    if (versePart.contains('-')) {
      final parts = versePart.split('-');
      if (parts.length == 2) {
        final start = _parseVerseWithNotation(parts[0]);
        final end = _parseVerseWithNotation(parts[1]);
        
        // If both have the same base verse, it's a single range with parts
        if (start.verse == end.verse) {
          result.add(PsalmVerseRange(
            chapter: chapter,
            startVerse: start.verse,
            endVerse: end.verse,
            startPart: start.part,
            endPart: end.part,
          ));
        } else {
          // Different verses - create a range
          result.add(PsalmVerseRange(
            chapter: chapter,
            startVerse: start.verse,
            endVerse: end.verse,
            startPart: start.part,
            endPart: end.part,
          ));
        }
      }
    } else if (versePart.contains('+')) {
      // Handle plus notation (consecutive verses)
      final parts = versePart.split('+');
      for (var part in parts) {
        final verse = _parseVerseWithNotation(part);
        result.add(PsalmVerseRange(
          chapter: chapter,
          startVerse: verse.verse,
          endVerse: verse.verse,
          startPart: verse.part,
          endPart: verse.part,
        ));
      }
    } else {
      // Single verse
      final verse = _parseVerseWithNotation(versePart);
      result.add(PsalmVerseRange(
        chapter: chapter,
        startVerse: verse.verse,
        endVerse: verse.verse,
        startPart: verse.part,
        endPart: verse.part,
      ));
    }
    
    return result;
  }
  
  /// Parse verse with possible letter notation (e.g., "4bc", "5ab", "8")
  /// For database purposes, we only need the verse number, not the parts
  static _VerseWithNotation _parseVerseWithNotation(String verseStr) {
    final match = RegExp(r'(\d+)').firstMatch(verseStr);
    if (match != null) {
      final verse = int.parse(match.group(1)!);
      return _VerseWithNotation(verse: verse, part: null);
    }
    
    // Fallback - treat as whole verse
    return _VerseWithNotation(verse: int.tryParse(verseStr) ?? 1, part: null);
  }
  
  /// Get a human-readable description of the parsed ranges
  static String getDescription(List<PsalmVerseRange> ranges) {
    if (ranges.isEmpty) return '';
    
    // Group consecutive verses
    final verses = <int>[];
    for (var range in ranges) {
      for (var v = range.startVerse; v <= range.endVerse; v++) {
        if (!verses.contains(v)) {
          verses.add(v);
        }
      }
    }
    verses.sort();
    
    // Group into consecutive ranges
    final groups = <List<int>>[];
    List<int>? currentGroup;
    
    for (var verse in verses) {
      if (currentGroup == null) {
        currentGroup = [verse];
      } else if (verse == currentGroup.last + 1) {
        currentGroup.add(verse);
      } else {
        groups.add(currentGroup);
        currentGroup = [verse];
      }
    }
    if (currentGroup != null) {
      groups.add(currentGroup);
    }
    
    // Build description
    final descriptions = <String>[];
    for (var group in groups) {
      if (group.length == 1) {
        descriptions.add('${group.first}');
      } else {
        descriptions.add('${group.first}-${group.last}');
      }
    }
    
    final chapter = ranges.isNotEmpty ? ranges.first.chapter : 25;
    return 'Psalm $chapter:${descriptions.join(', ')}';
  }
}

/// Represents a parsed Psalm verse range
class PsalmVerseRange {
  final int chapter;
  final int startVerse;
  final int endVerse;
  final String? startPart;
  final String? endPart;
  
  PsalmVerseRange({
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
    this.startPart,
    this.endPart,
  });
  
  /// Check if this range includes a specific verse part
  bool includes(int verse, [String? part]) {
    if (verse < startVerse || verse > endVerse) return false;
    
    if (part == null) return true;
    
    // Check part inclusion
    if (verse == startVerse && startPart != null && part != startPart) return false;
    if (verse == endVerse && endPart != null && part != endPart) return false;
    
    return true;
  }
  
  @override
  String toString() {
    var result = 'Psalm $chapter:$startVerse';
    if (endVerse != startVerse) {
      result += '-$endVerse';
    }
    
    if (startPart != null || endPart != null) {
      if (startPart != null) result += startPart!;
      if (endPart != null && endPart != startPart) result += '-$endPart!';
    }
    
    return result;
  }
}

/// Internal class for parsing verse with notation
class _VerseWithNotation {
  final int verse;
  final String? part;
  
  _VerseWithNotation({required this.verse, required this.part});
}
