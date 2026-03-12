import 'readings_backend_io.dart';
import 'ultimate_gospel_acclamation_mapper.dart';

/// Service for fetching Gospel Acclamation passage text
class GospelAcclamationService {
  static final GospelAcclamationService _instance = GospelAcclamationService._internal();
  factory GospelAcclamationService() => _instance;
  GospelAcclamationService._internal();

  final ReadingsBackendIo _backend = ReadingsBackendIo();
  final UltimateGospelAcclamationMapper _mapper =
      UltimateGospelAcclamationMapper.instance;

  bool shouldResolveReference(String acclamation) {
    final clean = _stripLeadingAlleluia(acclamation).trim();
    if (clean.isEmpty) return false;
    if (clean.length > 120) return false;

    final refPattern = RegExp(
      r'^(?:See\s+|Cf\.?\s+)?(?:(?:[1-3]\s)?[A-Za-z]+(?:\s+[A-Za-z]+)*)\s+\d+:\d+',
      caseSensitive: false,
    );
    if (!refPattern.hasMatch(clean)) return false;

    final lower = clean.toLowerCase();
    final textIndicators = [
      'says the lord',
      'says the lord;',
      'says the lord.',
      'hear my voice',
      'i know them',
      'follow me',
      'restore to me',
      'deliver me',
      'rejoice',
      'blessed are',
    ];

    for (final indicator in textIndicators) {
      if (lower.contains(indicator)) {
        return false;
      }
    }

    return true;
  }

  /// Get the full passage text for a Gospel Acclamation reference
  /// Example: "Joel 2:12-13" -> Returns the actual verse text
  Future<String> getAcclamationText(String reference) async {
    final original = reference.trim();
    if (original.isEmpty) return original;

    if (!shouldResolveReference(original)) {
      return original;
    }

    try {
      final cleanReference = _normalizeReference(
        _stripLeadingAlleluia(original),
      );
      
      final text = await _backend.getReadingText(cleanReference);
      if (text.trim().isEmpty || text.startsWith('Reading text unavailable')) {
        return _fallbackReferenceText(original);
      }
      
      final cleanedText = _cleanAcclamationText(text);
      if (cleanedText.isEmpty || cleanedText.startsWith('Reading text unavailable')) {
        return _fallbackReferenceText(original);
      }
      
      return cleanedText;
    } catch (e) {
      return _fallbackReferenceText(original);
    }
  }

  String _stripLeadingAlleluia(String value) {
    return value.replaceFirst(RegExp(r'^Alleluia\.\s*', caseSensitive: false), '');
  }

  String _normalizeReference(String value) {
    final trimmed = value.trim();
    const replacements = <String, String>{
      'Mt ': 'Matthew ',
      'Mk ': 'Mark ',
      'Lk ': 'Luke ',
      'Jn ': 'John ',
      'Ps ': 'Psalm ',
    };

    for (final entry in replacements.entries) {
      if (trimmed.startsWith(entry.key)) {
        return '${entry.value}${trimmed.substring(entry.key.length)}';
      }
    }

    return trimmed;
  }

  String _fallbackReferenceText(String original) {
    final mappedText = _mapper.getTextForReference(original);
    if (mappedText != null && mappedText.trim().isNotEmpty) {
      return mappedText.trim();
    }
    return original;
  }

  /// Clean up the acclamation text for display
  String _cleanAcclamationText(String text) {
    // Remove verse numbers (e.g., "12. " at start of lines)
    final lines = text.split('\n');
    final cleanedLines = <String>[];
    
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      // Remove verse number at start
      var withoutVerseNumber = trimmed.replaceFirst(RegExp(r'^\d+\.\s*'), '');
      
      // Remove any incipit that might have been added - expanded patterns
      // Common incipit patterns to remove
      final incipitPatterns = [
        r'^[A-Za-z\s]+:\s*', // Book name with colon
        r'^Thus says the (LORD|Lord):\s*',
        r'^The (LORD|Lord) said:\s*',
        r'^Moses said:\s*',
        r'^Peter said:\s*',
        r'^Paul said:\s*',
        r'^Jesus said:\s*',
        r'^At that time:\s*',
        r'^In those days:\s*',
        r'^In the beginning:\s*',
        r'^Brethren:\s*',
        r'^Brothers and sisters:\s*',
        r'^Dearly beloved:\s*',
        r'^Dearest brothers and sisters:\s*',
        r'^Then:\s*',
        r'^Now:\s*',
        r'^After this:\s*',
        r'^And it came to pass:\s*',
        r'^And it happened:\s*',
        r'^Answering:\s*',
        r'^Then came:\s*',
        r'^Now when:\s*',
      ];
      
      for (final pattern in incipitPatterns) {
        withoutVerseNumber = withoutVerseNumber.replaceFirst(RegExp(pattern, caseSensitive: false), '');
      }
      
      // Remove any remaining speaker attribution patterns
      withoutVerseNumber = withoutVerseNumber.replaceFirst(RegExp(r'^[A-Za-z]+\s+(said|replied|answered|declared|proclaimed):\s*', caseSensitive: false), '');
      
      // Remove any leading transition words
      withoutVerseNumber = withoutVerseNumber.replaceFirst(RegExp(r'^(Then|And|Now|So|But|For)\s+', caseSensitive: false), '');
      
      if (withoutVerseNumber.trim().isNotEmpty) {
        cleanedLines.add(withoutVerseNumber.trim());
      }
    }
    
    // Join lines and clean up punctuation
    var result = cleanedLines.join(' ').trim();
    
    // Remove trailing punctuation and ensure proper ending
    result = result.replaceAll(RegExp(r'[,:;]\s*$'), '');
    if (!result.endsWith('.')) {
      result += '.';
    }
    
    return result;
  }

  /// Check if a reference is likely a Gospel Acclamation
  bool isGospelAcclamation(String reference) {
    final cleanRef = reference.toLowerCase();
    return cleanRef.contains('alleluia') || 
           cleanRef.contains('praise') || 
           cleanRef.contains('glory') ||
           cleanRef.contains('blessed');
  }

  /// Get a formatted acclamation with Alleluia prefix
  Future<String> getFormattedAcclamation(String reference) async {
    final acclamationText = await getAcclamationText(reference);
    
    // Add Alleluia prefix if not already present
    if (!acclamationText.toLowerCase().startsWith('alleluia')) {
      return 'Alleluia, alleluia. $acclamationText';
    }
    
    return acclamationText;
  }
}
