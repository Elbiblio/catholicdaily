import 'dart:collection';

/// Service for providing appropriate introductory phrases (incipits) for Bible readings
/// Based on the General Introduction to the Lectionary (GILM) paragraph 124
class ReadingIntroductionService {
  static final ReadingIntroductionService _instance = ReadingIntroductionService._internal();
  factory ReadingIntroductionService() => _instance;
  ReadingIntroductionService._internal();

  // Standard incipits from GILM 124
  static const String _atThatTime = "At that time:";
  static const String _inThoseDays = "In those days:";
  static const String _thusSaysTheLord = "Thus says the Lord:";
  static const String _thusSaysTheLordGod = "Thus says the Lord God:";
  static const String _brothersAndSisters = "Brothers and sisters:";
  static const String _beloved = "Beloved:";
  static const String _dearlyBeloved = "Dearly beloved:";
  static const String _dearestBrothersAndSisters = "Dearest brothers and sisters:";

  /// Mapping of biblical books to their typical introductory phrases
  static const Map<String, String> _bookIntroductions = {
    // Old Testament - Prophetic Books (typically use "Thus says the Lord")
    'Isaiah': _thusSaysTheLord,
    'Jeremiah': _thusSaysTheLord,
    'Ezekiel': _thusSaysTheLord,
    'Daniel': _thusSaysTheLord,
    'Hosea': _thusSaysTheLord,
    'Joel': _thusSaysTheLord,
    'Amos': _thusSaysTheLord,
    'Obadiah': _thusSaysTheLord,
    'Jonah': _thusSaysTheLord,
    'Micah': _thusSaysTheLord,
    'Nahum': _thusSaysTheLord,
    'Habakkuk': _thusSaysTheLord,
    'Zephaniah': _thusSaysTheLord,
    'Haggai': _thusSaysTheLord,
    'Zechariah': _thusSaysTheLord,
    'Malachi': _thusSaysTheLord,

    // Old Testament - Historical Books (typically use "In those days")
    'Genesis': _inThoseDays,
    'Exodus': _inThoseDays,
    'Leviticus': _inThoseDays,
    'Numbers': _inThoseDays,
    'Deuteronomy': _inThoseDays,
    'Joshua': _inThoseDays,
    'Judges': _inThoseDays,
    'Ruth': _inThoseDays,
    '1 Samuel': _inThoseDays,
    '2 Samuel': _inThoseDays,
    '1 Kings': _inThoseDays,
    '2 Kings': _inThoseDays,
    '1 Chronicles': _inThoseDays,
    '2 Chronicles': _inThoseDays,
    'Ezra': _inThoseDays,
    'Nehemiah': _inThoseDays,
    'Esther': _inThoseDays,
    'Tobit': _inThoseDays,
    'Judith': _inThoseDays,
    '1 Maccabees': _inThoseDays,
    '2 Maccabees': _inThoseDays,

    // Old Testament - Wisdom Books (typically use "In those days")
    'Job': _inThoseDays,
    'Psalm': _inThoseDays,
    'Proverbs': _inThoseDays,
    'Ecclesiastes': _inThoseDays,
    'Song of Songs': _inThoseDays,
    'Wisdom': _inThoseDays,
    'Sirach': _inThoseDays,

    // New Testament - Gospels (typically use "At that time")
    'Matthew': _atThatTime,
    'Mark': _atThatTime,
    'Luke': _atThatTime,
    'John': _atThatTime,

    // New Testament - Acts (typically use "In those days")
    'Acts': _inThoseDays,

    // New Testament - Epistles (typically use "Brothers and sisters")
    'Romans': _brothersAndSisters,
    '1 Corinthians': _brothersAndSisters,
    '2 Corinthians': _brothersAndSisters,
    'Galatians': _brothersAndSisters,
    'Ephesians': _brothersAndSisters,
    'Philippians': _brothersAndSisters,
    'Colossians': _brothersAndSisters,
    '1 Thessalonians': _brothersAndSisters,
    '2 Thessalonians': _brothersAndSisters,
    '1 Timothy': _brothersAndSisters,
    '2 Timothy': _brothersAndSisters,
    'Titus': _brothersAndSisters,
    'Philemon': _brothersAndSisters,
    'Hebrews': _brothersAndSisters,
    'James': _brothersAndSisters,
    '1 Peter': _brothersAndSisters,
    '2 Peter': _brothersAndSisters,
    '1 John': _brothersAndSisters,
    '2 John': _brothersAndSisters,
    '3 John': _brothersAndSisters,
    'Jude': _brothersAndSisters,

    // New Testament - Revelation (typically use "In those days")
    'Revelation': _inThoseDays,
  };

  /// Special cases where the introduction might vary based on context
  static const Map<String, List<String>> _contextualIntroductions = {
    // Some prophetic books might use "Thus says the Lord God" in certain contexts
    'Ezekiel': [_thusSaysTheLord, _thusSaysTheLordGod],
    'Daniel': [_thusSaysTheLord, _inThoseDays], // Daniel can be prophetic or historical
  };

  /// Gets the appropriate introductory phrase for a reading
  /// 
  /// [readingReference] should be in format like "Dan 3:25, 34-43" or "Matt 18:21-35"
  /// Returns null if no introduction is appropriate
  String? getIntroduction(String readingReference) {
    // Extract book name from reference
    final bookName = _extractBookName(readingReference);
    if (bookName == null) return null;

    // Check for special contextual cases first
    final contextualIntros = _contextualIntroductions[bookName];
    if (contextualIntros != null) {
      // For now, return the first option. In a more sophisticated implementation,
      // we could analyze the specific verses to determine the best fit
      return contextualIntros.first;
    }

    // Return standard introduction
    return _bookIntroductions[bookName];
  }

  /// Extracts the book name from a Bible reference
  /// 
  /// Examples:
  /// "Dan 3:25, 34-43" -> "Daniel"
  /// "Matt 18:21-35" -> "Matthew"
  /// "1 Sam 3:1-10" -> "1 Samuel"
  String? _extractBookName(String reference) {
    // Remove any leading/trailing whitespace
    reference = reference.trim();
    
    // Handle common abbreviations and full names
    final bookPatterns = {
      // Old Testament
      'Gen': 'Genesis',
      'Exod': 'Exodus', 'Ex': 'Exodus',
      'Lev': 'Leviticus', 'Lv': 'Leviticus',
      'Num': 'Numbers', 'Nm': 'Numbers',
      'Deut': 'Deuteronomy', 'Dt': 'Deuteronomy',
      'Josh': 'Joshua', 'Jos': 'Joshua',
      'Judg': 'Judges', 'Jdg': 'Judges',
      'Ruth': 'Ruth', 'Rt': 'Ruth',
      '1 Sam': '1 Samuel', '1 Sa': '1 Samuel',
      '2 Sam': '2 Samuel', '2 Sa': '2 Samuel',
      '1 Kgs': '1 Kings', '1 Ki': '1 Kings',
      '2 Kgs': '2 Kings', '2 Ki': '2 Kings',
      '1 Chr': '1 Chronicles', '1 Ch': '1 Chronicles',
      '2 Chr': '2 Chronicles', '2 Ch': '2 Chronicles',
      'Ezra': 'Ezra', 'Ez': 'Ezra',
      'Neh': 'Nehemiah', 'Ne': 'Nehemiah',
      'Esth': 'Esther', 'Est': 'Esther',
      'Tob': 'Tobit', 'Tb': 'Tobit',
      'Jdt': 'Judith',
      '1 Macc': '1 Maccabees', '1 Mc': '1 Maccabees',
      '2 Macc': '2 Maccabees', '2 Mc': '2 Maccabees',
      'Job': 'Job', 'Jb': 'Job',
      'Ps': 'Psalm',
      'Prov': 'Proverbs', 'Pr': 'Proverbs',
      'Eccl': 'Ecclesiastes', 'Ec': 'Ecclesiastes',
      'Song': 'Song of Songs', 'Song of Songs': 'Song of Songs',
      'Wis': 'Wisdom',
      'Sir': 'Sirach',
      'Isa': 'Isaiah', 'Is': 'Isaiah',
      'Jer': 'Jeremiah', 'Je': 'Jeremiah',
      'Lam': 'Lamentations', 'La': 'Lamentations',
      'Bar': 'Baruch', 'Ba': 'Baruch',
      'Ezek': 'Ezekiel', 'Ez': 'Ezekiel',
      'Dan': 'Daniel', 'Da': 'Daniel',
      'Hos': 'Hosea', 'Ho': 'Hosea',
      'Joel': 'Joel', 'Jl': 'Joel',
      'Amos': 'Amos', 'Am': 'Amos',
      'Obad': 'Obadiah', 'Ob': 'Obadiah',
      'Jonah': 'Jonah', 'Jon': 'Jonah',
      'Mic': 'Micah', 'Mi': 'Micah',
      'Nah': 'Nahum', 'Na': 'Nahum',
      'Hab': 'Habakkuk', 'Hb': 'Habakkuk',
      'Zeph': 'Zephaniah', 'Zp': 'Zephaniah',
      'Hag': 'Haggai', 'Hg': 'Haggai',
      'Zech': 'Zechariah', 'Zc': 'Zechariah',
      'Mal': 'Malachi', 'Ml': 'Malachi',
      
      // New Testament
      'Matt': 'Matthew', 'Mt': 'Matthew',
      'Mark': 'Mark', 'Mk': 'Mark',
      'Luke': 'Luke', 'Lk': 'Luke',
      'John': 'John', 'Jn': 'John',
      'Acts': 'Acts',
      'Rom': 'Romans', 'Rm': 'Romans',
      '1 Cor': '1 Corinthians', '1 Co': '1 Corinthians',
      '2 Cor': '2 Corinthians', '2 Co': '2 Corinthians',
      'Gal': 'Galatians', 'Ga': 'Galatians',
      'Eph': 'Ephesians', 'Ep': 'Ephesians',
      'Phil': 'Philippians', 'Ph': 'Philippians',
      'Col': 'Colossians', 'Co': 'Colossians',
      '1 Thess': '1 Thessalonians', '1 Th': '1 Thessalonians',
      '2 Thess': '2 Thessalonians', '2 Th': '2 Thessalonians',
      '1 Tim': '1 Timothy', '1 Ti': '1 Timothy',
      '2 Tim': '2 Timothy', '2 Ti': '2 Timothy',
      'Titus': 'Titus', 'Ti': 'Titus',
      'Phlm': 'Philemon', 'Phm': 'Philemon',
      'Heb': 'Hebrews',
      'James': 'James', 'Jas': 'James',
      '1 Pet': '1 Peter', '1 Pt': '1 Peter',
      '2 Pet': '2 Peter', '2 Pt': '2 Peter',
      '1 John': '1 John', '1 Jn': '1 John',
      '2 John': '2 John', '2 Jn': '2 John',
      '3 John': '3 John', '3 Jn': '3 John',
      'Jude': 'Jude',
      'Rev': 'Revelation', 'Rv': 'Revelation',
    };

    // Try to match patterns starting with the longest to avoid conflicts
    final sortedPatterns = LinkedHashMap.fromEntries(
      bookPatterns.entries.toList()
        ..sort((a, b) => b.key.length.compareTo(a.key.length))
    );

    for (final entry in sortedPatterns.entries) {
      if (reference.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // If no abbreviation matches, try to extract the first word
    final parts = reference.split(' ');
    if (parts.isNotEmpty) {
      final firstWord = parts.first;
      // Check if it's already a full book name
      if (_bookIntroductions.containsKey(firstWord)) {
        return firstWord;
      }
    }

    return null;
  }

  /// Formats a reading with its appropriate introduction
  /// 
  /// Returns the reading text with the introductory phrase prepended
  /// If no introduction is appropriate, returns the original reading text
  String formatReadingWithIntroduction(String readingReference, String readingText) {
    final introduction = getIntroduction(readingReference);
    
    if (introduction != null && !readingText.trim().startsWith(introduction)) {
      return '$introduction $readingText';
    }
    
    return readingText;
  }

  /// Checks if a reading text already contains an introduction
  bool hasIntroduction(String readingText) {
    final standardIntros = [
      _atThatTime, _inThoseDays, _thusSaysTheLord, _thusSaysTheLordGod,
      _brothersAndSisters, _beloved, _dearlyBeloved, _dearestBrothersAndSisters
    ];
    
    return standardIntros.any((intro) => readingText.trim().startsWith(intro));
  }
}
