/// Universal Deuterocanonical Verse Number Mapper
/// 
/// The Catholic Lectionary uses NAB/Vulgate verse numbering for deuterocanonical additions,
/// which differs from the RSVCE Bible database numbering.
/// 
/// This mapper handles verse number translation for books with deuterocanonical additions:
/// - Daniel 3: Prayer of Azariah and Song of the Three Young Men
/// - Esther: Greek additions (A-F)
/// - Other books as needed
class DeuterocanonicalVerseMapper {
  /// Verse mapping configuration for a specific book/chapter
  static const Map<String, _VerseMappingConfig> _mappings = {
    'Dan_3': _VerseMappingConfig(
      nabGreekStart: 24,
      nabGreekEnd: 90,
      offset: -23,
      dbRowStart: 33362,
      dbRowEnd: 33492,
    ),
    // Add more mappings here as needed for other deuterocanonical books
    // Example for Esther (if needed in the future):
    // 'Est_10': _VerseMappingConfig(...),
  };
  
  /// Convert NAB/Vulgate verse number to RSVCE verse number
  static int nabToRsvce(String bookShortName, int chapter, int nabVerse) {
    final key = '${bookShortName}_$chapter';
    final config = _mappings[key];
    
    if (config == null) {
      return nabVerse; // No mapping needed
    }
    
    if (nabVerse >= config.nabGreekStart && nabVerse <= config.nabGreekEnd) {
      return nabVerse + config.offset;
    }
    
    return nabVerse;
  }
  
  /// Check if a verse is in a deuterocanonical addition that needs translation
  static bool needsTranslation(String bookShortName, int chapter, int nabVerse) {
    final key = '${bookShortName}_$chapter';
    final config = _mappings[key];
    
    if (config == null) return false;
    
    return nabVerse >= config.nabGreekStart && nabVerse <= config.nabGreekEnd;
  }
  
  /// Get database row constraints for querying deuterocanonical sections
  static ({int? startRow, int? endRow})? getRowConstraints(
    String bookShortName,
    int chapter,
  ) {
    final key = '${bookShortName}_$chapter';
    final config = _mappings[key];
    
    if (config == null) return null;
    
    return (startRow: config.dbRowStart, endRow: config.dbRowEnd);
  }
}

/// Configuration for verse number mapping
class _VerseMappingConfig {
  final int nabGreekStart;
  final int nabGreekEnd;
  final int offset;
  final int? dbRowStart;
  final int? dbRowEnd;
  
  const _VerseMappingConfig({
    required this.nabGreekStart,
    required this.nabGreekEnd,
    required this.offset,
    this.dbRowStart,
    this.dbRowEnd,
  });
}
