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
    var verseCounter = 1; // Start numbering from 1 for display

    for (final groups in stanzaGroups) {
      final stanzaLines = <String>[];
      for (final group in groups) {
        stanzaLines.addAll(_formatVerseGroup(group, verses, verseCounter));
        // Update verse counter based on how many verses were added
        verseCounter += _countVersesInGroup(group);
      }
      if (stanzaLines.isNotEmpty) {
        stanzaLines[0] = _capitalizeFirst(stanzaLines[0]);
        stanzas.add(stanzaLines.join('\n'));
      }
    }

    // Interleave the refrain after every stanza (liturgical format: stanza → R. refrain → …)
    final refrainLine = 'R. ${refrain.trim()}';
    final buffer = StringBuffer();
    for (var i = 0; i < stanzas.length; i++) {
      if (i > 0) buffer.write('\n\n');
      buffer.write(stanzas[i]);
      buffer.write('\n\n');
      buffer.write(refrainLine);
    }
    return buffer.toString().trimRight();
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

    final separatorMatch = RegExp(r'(?:Ps|Psalm)\s+\d+([:\.])', caseSensitive: false).firstMatch(reference);
    if (separatorMatch == null) return stanzas;

    final separatorIndex = separatorMatch.start + separatorMatch.group(0)!.length - 1;

    var versePart = reference.substring(separatorIndex + 1);
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

    // Replace '+' and '&' with ' and ' for unified handling
    final normalized = segment.replaceAll('+', ' and ').replaceAll('&', ' and ');
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
  static List<String> _formatVerseGroup(_VerseGroup group, Map<int, String> verses, int startVerseNumber) {
    final lines = <String>[];
    
    if (group.startVerse == group.endVerse) {
      // Single verse
      final verseText = verses[group.startVerse];
      if (verseText != null) {
        if (group.startParts != null) {
          // Extract specific parts
          final extracted = PsalmVerseSplitter.getVerseParts(verseText, group.startParts!);
          if (extracted != null) {
            lines.add('$startVerseNumber ${extracted.trim()}');
          }
        } else {
          // Use complete verse
          lines.add('$startVerseNumber ${verseText.trim()}');
        }
      }
    } else {
      // Range of verses - combine into a single stanza
      final rangeTexts = <String>[];
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
          rangeTexts.add(textToUse.trim());
        }
      }
      
      if (rangeTexts.isNotEmpty) {
        lines.add('$startVerseNumber ${rangeTexts.join(' ')}');
      }
    }
    
    return lines;
  }
  
  /// Count how many verses are in a group for numbering purposes
  static int _countVersesInGroup(_VerseGroup group) {
    // Each group (whether single verse or range) represents exactly 1 stanza
    return 1;
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
