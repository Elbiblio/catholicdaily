import 'psalm_verse_splitter.dart';

/// Formats responsorial psalms in lectionary style with refrains
/// 
/// Handles complex notation like "Ps 25:4bc-5ab, 6 and 7bc, 8-9 (R. 6a)"
/// and produces formatted output with repeated refrains.
class LectionaryPsalmFormatter {
  /// Format a responsorial psalm with verses and refrain
  /// 
  /// [reference] - The psalm reference (e.g., "Ps 25:4bc-5ab, 6 and 7bc, 8-9")
  /// [verses] - Map of verse numbers to verse text from database
  /// [refrain] - The response text (e.g., "Remember your mercies, O Lord")
  /// [refrainVerse] - Optional verse number for refrain (e.g., "6a")
  static String format({
    required String reference,
    required Map<int, String> verses,
    required String refrain,
    String? refrainVerse,
  }) {
    final stanzaGroups = _parseStanzaGroups(reference);
    final stanzas = <String>[];

    for (final groups in stanzaGroups) {
      final stanzaLines = <String>[];
      for (final group in groups) {
        stanzaLines.addAll(_formatVerseGroup(group, verses));
      }
      if (stanzaLines.isNotEmpty) {
        if (stanzaLines.isNotEmpty) {
          stanzaLines[0] = _capitalizeFirst(stanzaLines[0]);
        }
        stanzas.add(stanzaLines.join('\n'));
      }
    }

    return stanzas.join('\n\n');
  }

  static String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    final regex = RegExp(r'([A-Za-z])');
    final match = regex.firstMatch(input);
    if (match == null) return input;
    final index = match.start;
    final capitalizedLetter = match.group(1)!.toUpperCase();
    return input.substring(0, index) + capitalizedLetter + input.substring(index + 1);
  }
  
  /// Parse verse groups into stanza collections based on commas
  static List<List<_VerseGroup>> _parseStanzaGroups(String reference) {
    final stanzas = <List<_VerseGroup>>[];

    final colonIndex = reference.indexOf(':');
    if (colonIndex < 0) return stanzas;

    var versePart = reference.substring(colonIndex + 1);
    versePart = versePart.replaceAll(RegExp(r'\s*\(R\.\s*[^)]+\)'), '').trim();

    final segments = versePart.split(',');

    for (var segment in segments) {
      final trimmedSegment = segment.trim();
      if (trimmedSegment.isEmpty) continue;

      final stanzaGroups = <_VerseGroup>[];
      stanzaGroups.addAll(_parseCombinedSegment(trimmedSegment));

      if (stanzaGroups.isNotEmpty) {
        stanzas.add(stanzaGroups);
      }
    }

    return stanzas;
  }

  /// Parse a comma-separated stanza segment that may include '+' or 'and'
  static List<_VerseGroup> _parseCombinedSegment(String segment) {
    final groups = <_VerseGroup>[];

    // Replace '+' with ' and ' for unified handling
    final normalized = segment.replaceAll('+', ' and ');
    final parts = normalized.split(RegExp(r'\band\b'));

    if (parts.length > 1) {
      for (var part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          groups.add(_parseVerseSegment(trimmed));
        }
      }
      return groups;
    }

    groups.add(_parseVerseSegment(segment));
    return groups;
  }
  
  /// Parse a single verse segment
  static _VerseGroup _parseVerseSegment(String segment) {
    // Check for range (e.g., "4bc-5ab" or "8-9")
    if (segment.contains('-')) {
      final parts = segment.split('-');
      if (parts.length == 2) {
        final start = _parseVerseWithParts(parts[0].trim());
        final end = _parseVerseWithParts(parts[1].trim());
        
        return _VerseGroup(
          startVerse: start.verse,
          endVerse: end.verse,
          startParts: start.parts,
          endParts: end.parts,
        );
      }
    }
    
    // Single verse (e.g., "6" or "7bc")
    final parsed = _parseVerseWithParts(segment);
    return _VerseGroup(
      startVerse: parsed.verse,
      endVerse: parsed.verse,
      startParts: parsed.parts,
      endParts: parsed.parts,
    );
  }
  
  /// Parse verse number and optional part letters
  static ({int verse, String? parts}) _parseVerseWithParts(String text) {
    final match = RegExp(r'^(\d+)([a-d]+)?$').firstMatch(text);
    if (match != null) {
      return (
        verse: int.parse(match.group(1)!),
        parts: match.group(2),
      );
    }
    return (verse: int.tryParse(text) ?? 0, parts: null);
  }
  
  /// Format a verse group into lines
  static List<String> _formatVerseGroup(_VerseGroup group, Map<int, String> verses) {
    final lines = <String>[];
    
    if (group.startVerse == group.endVerse) {
      // Single verse
      final verseText = verses[group.startVerse];
      if (verseText != null) {
        if (group.startParts != null) {
          // Extract specific parts
          final extracted = PsalmVerseSplitter.getVerseParts(verseText, group.startParts!);
          if (extracted != null) {
            lines.addAll(_splitIntoLines(extracted));
          }
        } else {
          // Use complete verse
          lines.addAll(_splitIntoLines(verseText));
        }
      }
    } else {
      // Range of verses
      for (var v = group.startVerse; v <= group.endVerse; v++) {
        final verseText = verses[v];
        if (verseText == null) continue;
        
        String? textToUse;
        
        if (v == group.startVerse && group.startParts != null) {
          // First verse with specific parts
          textToUse = PsalmVerseSplitter.getVerseParts(verseText, group.startParts!);
        } else if (v == group.endVerse && group.endParts != null) {
          // Last verse with specific parts
          textToUse = PsalmVerseSplitter.getVerseParts(verseText, group.endParts!);
        } else {
          // Middle verse or complete verse
          textToUse = verseText;
        }
        
        if (textToUse != null) {
          lines.addAll(_splitIntoLines(textToUse));
        }
      }
    }
    
    return lines;
  }
  
  /// Split text into individual lines for display
  static List<String> _splitIntoLines(String text) {
    // Remove verse numbers if present
    text = text.replaceFirst(RegExp(r'^\d+\.\s*'), '');
    
    // Split on semicolons and periods for line breaks
    final parts = PsalmVerseSplitter.splitVerse(text);
    
    return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
}

/// Represents a group of verses in the notation
class _VerseGroup {
  final int startVerse;
  final int endVerse;
  final String? startParts;
  final String? endParts;
  
  _VerseGroup({
    required this.startVerse,
    required this.endVerse,
    this.startParts,
    this.endParts,
  });
  
  @override
  String toString() {
    return 'VerseGroup($startVerse${startParts ?? ""}-$endVerse${endParts ?? ""})';
  }
}
