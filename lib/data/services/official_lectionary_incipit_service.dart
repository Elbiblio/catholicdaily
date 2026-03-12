/// Official Catholic Lectionary Incipit Service
/// Based on the General Instruction of the Lectionary (GILM) and official Ordo Lectionum Missae guidelines
/// This service provides accurate incipits according to the official Catholic liturgical standards
class OfficialLectionaryIncipitService {
  static final OfficialLectionaryIncipitService _instance = OfficialLectionaryIncipitService._internal();
  factory OfficialLectionaryIncipitService() => _instance;
  OfficialLectionaryIncipitService._internal();

  /// Official incipit patterns from the General Instruction of the Lectionary (GILM 124)
  /// These are the standard introductory phrases used in the Catholic Lectionary
  static const Map<String, List<String>> _officialIncipits = {
    // Latin originals and their English translations (updated with colons)
    'In illis diebus': ['In those days:'],
    'In illo tempore': ['At that time:'],
    'Dixit Dominus': ['Thus says the LORD:', 'The LORD said:'],
    'Dixit Moses': ['Moses said:'],
    'Dixit Petrus': ['Peter said:'],
    'Dixit Paulus': ['Paul said:'],
    'Fratres': ['Brethren:'],
    'In principio': ['In the beginning:'],
    'Haec dicit Dominus': ['Thus says the LORD:'],
    'Loquens Dominus': ['The LORD said:'],
    'Respondens': ['Answering:'],
    'Accessit': ['Then came:', 'Then:'],
    'Cum autem': ['Now when:', 'Now:'],
    'Post haec': ['After this:', 'After these things:'],
    'Tunc': ['Then:', 'Now:'],
    'Et factum est': ['And it came to pass:', 'And it happened:'],
  };

  /// Contextual rules for specific biblical books and passages
  /// Based on actual lectionary usage patterns
  static const Map<String, String> _bookSpecificRules = {
    // Old Testament Narrative Books (historical narratives)
    'Gen': 'In the beginning:', // Genesis 1, otherwise narrative
    'Exod': 'The LORD said to Moses:', // Exodus narratives
    'Lev': 'The LORD said to Moses:', // Levitical laws
    'Num': 'The LORD said to Moses:', // Numbers narratives
    'Deut': 'Moses said to the people:', // Deuteronomic discourse
    'Josh': 'In those days:', // Conquest narratives
    'Judg': 'In those days:', // Judges narratives
    'Ruth': 'In those days:', // Ruth narrative
    '1 Sam': 'In those days:', // Samuel narratives
    '2 Sam': 'In those days:', // David narratives
    '1 Kgs': 'In those days:', // Kings narratives
    '2 Kgs': 'In those days:', // Kings narratives
    '1 Chr': 'In those days:', // Chronicles
    '2 Chr': 'In those days:', // Chronicles
    'Ezra': 'In those days:', // Ezra narrative
    'Neh': 'In those days:', // Nehemiah narrative
    'Tob': 'In those days,', // Tobit narrative
    'Jdt': 'In those days,', // Judith narrative
    'Est': 'In those days,', // Esther narrative
    '1 Macc': 'In those days,', // Maccabees narrative
    '2 Macc': 'In those days,', // Maccabees narrative

    // Old Testament Prophetic Books (prophetic oracles)
    'Isa': 'Thus says the LORD:', // Isaiah prophetic
    'Jer': 'Thus says the LORD:', // Jeremiah prophetic
    'Lam': 'Thus says the LORD:', // Lamentations
    'Bar': 'Thus says the LORD:', // Baruch prophetic
    'Ezek': 'Thus says the LORD:', // Ezekiel prophetic
    'Dan': 'In those days,', // Daniel - mixed narrative/prophetic, context-dependent
    'Hos': 'Thus says the LORD:', // Hosea prophetic
    'Joel': 'Thus says the LORD:', // Joel prophetic
    'Amos': 'Thus says the LORD:', // Amos prophetic
    'Obad': 'Thus says the LORD:', // Obadiah prophetic
    'Jonah': 'The word of the LORD came to Jonah:', // Jonah prophetic narrative
    'Mic': 'Thus says the LORD:', // Micah prophetic
    'Nah': 'Thus says the LORD:', // Nahum prophetic
    'Hab': 'Thus says the LORD:', // Habakkuk prophetic
    'Zeph': 'Thus says the LORD:', // Zephaniah prophetic
    'Hag': 'Thus says the LORD:', // Haggai prophetic
    'Zech': 'Thus says the LORD:', // Zechariah prophetic
    'Mal': 'Thus says the LORD:', // Malachi prophetic

    // Old Testament Wisdom Books
    'Job': 'Job answered:', // Job dialogues
    'Ps': 'The LORD says:', // Psalms (when used as readings)
    'Prov': 'Hear, my children:', // Proverbs wisdom
    'Eccl': 'I said to myself:', // Ecclesiastes reflections
    'Song': 'The beloved says:', // Song of Songs
    'Wis': 'Wisdom has been given to us:', // Wisdom
    'Sir': 'My son,', // Sirach wisdom

    // New Testament Gospels
    'Matt': 'At that time,', // Matthew narratives/discourses
    'Mark': 'At that time,', // Mark narratives
    'Luke': 'At that time,', // Luke narratives
    'John': 'At that time,', // John narratives

    // New Testament Acts
    'Acts': 'In those days,', // Acts narratives

    // New Testament Epistles (Pauline and Catholic)
    'Rom': 'Brethren:', // Romans
    '1 Cor': 'Brethren:', // 1 Corinthians
    '2 Cor': 'Brethren:', // 2 Corinthians
    'Gal': 'Brethren:', // Galatians
    'Eph': 'Brethren:', // Ephesians
    'Phil': 'Brethren:', // Philippians
    'Col': 'Brethren:', // Colossians
    '1 Thess': 'Brethren:', // 1 Thessalonians
    '2 Thess': 'Brethren:', // 2 Thessalonians
    '1 Tim': 'My child,', // 1 Timothy
    '2 Tim': 'My child,', // 2 Timothy
    'Titus': 'My child,', // Titus
    'Phlm': 'I appeal to you, my child:', // Philemon
    'Heb': 'Brethren:', // Hebrews
    'Jas': 'Brethren:', // James
    '1 Pet': 'Beloved:', // 1 Peter
    '2 Pet': 'Beloved:', // 2 Peter
    '1 John': 'Beloved:', // 1 John
    '2 John': 'The elder to the chosen lady:', // 2 John
    '3 John': 'The elder to Gaius:', // 3 John
    'Jude': 'Beloved:', // Jude
    'Rev': 'I, John, saw:', // Revelation
  };

  /// Special contextual rules for specific passages
  /// These override the general book-specific rules
  static const Map<String, String> _passageSpecificRules = {
    // Daniel - special case: narrative vs prophetic
    'Dan 3': 'In those days,', // Daniel 3 (furnace) - narrative
    'Dan 6': 'In those days,', // Daniel 6 (lions den) - narrative
    'Dan 7': 'Thus says the LORD:', // Daniel 7+ - prophetic visions
    'Dan 8': 'Thus says the LORD:',
    'Dan 9': 'Thus says the LORD:',
    'Dan 10': 'Thus says the LORD:',
    'Dan 11': 'Thus says the LORD:',
    'Dan 12': 'Thus says the LORD:',

    // Genesis special cases
    'Gen 1': 'In the beginning,', // Creation account
    'Gen 2': 'In the beginning,', // Garden of Eden
    'Gen 3': 'In the beginning,', // Fall

    // Exodus special cases
    'Exod 1': 'In those days,', // Early Exodus narrative
    'Exod 2': 'In those days,', // Moses' birth
    'Exod 20': 'The LORD said to Moses:', // Ten Commandments

    // Matthew special cases
    'Matt 5': 'Jesus said to his disciples:', // Sermon on the Mount
    'Matt 6': 'Jesus said to his disciples:', // Sermon on the Mount
    'Matt 7': 'Jesus said to his disciples:', // Sermon on the Mount

    // Luke special cases
    'Luke 1': 'In those days,', // Infancy narrative
    'Luke 2': 'In those days,', // Infancy narrative

    // John special cases
    'John 1': 'In the beginning was the Word:', // Prologue

    // Acts special cases
    'Acts 2': 'In those days,', // Pentecost
    'Acts 9': 'In those days,', // Paul's conversion

    // Romans special cases
    'Rom 1': 'Brethren:', // Opening of Romans
    'Rom 8': 'Brethren:', // Romans 8 (important theological passage)

    // 1 Corinthians special cases
    '1 Cor 13': 'Brethren:', // Love chapter
    '1 Cor 15': 'Brethren:', // Resurrection chapter

    // Hebrews special cases
    'Heb 1': 'Brethren:', // Opening of Hebrews
    'Heb 11': 'Brethren:', // Faith chapter

    // Revelation special cases
    'Rev 1': 'I, John, saw:', // Opening vision
    'Rev 21': 'I, John, saw:', // New Jerusalem
    'Rev 22': 'I, John, saw:', // Final vision
  };

  /// Get the official lectionary incipit for a given biblical reference
  String? getOfficialIncipit(String readingReference) {
    // First check for passage-specific rules (most specific)
    for (final entry in _passageSpecificRules.entries) {
      if (readingReference.startsWith(entry.key)) {
        return entry.value;
      }
    }

    // Then check book-specific rules
    final bookAbbr = _extractBookAbbreviation(readingReference);
    if (bookAbbr != null && _bookSpecificRules.containsKey(bookAbbr)) {
      return _bookSpecificRules[bookAbbr];
    }

    // Default to no incipit if no rule matches
    return null;
  }

  /// Extract book abbreviation from biblical reference
  String? _extractBookAbbreviation(String readingReference) {
    final patterns = [
      RegExp(r'^([A-Za-z]{1,3})\s+\d+'), // 1-3 letter books
      RegExp(r'^([A-Za-z]{1,4})\s+\d+'), // 4 letter books like "Matt", "John"
      RegExp(r'^([A-Za-z]{1,5})\s+\d+'), // 5 letter books like "Acts", "James"
      RegExp(r'^([1-3]\s[A-Za-z]{1,3})\s+\d+'), // Numbered books like "1 Sam", "2 Kgs"
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(readingReference);
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  /// Check if a reading typically uses an incipit in the lectionary
  bool usesIncipit(String readingReference) {
    return getOfficialIncipit(readingReference) != null;
  }

  /// Get all official incipits for reference
  Map<String, List<String>> getOfficialIncipits() {
    return Map.from(_officialIncipits);
  }

  /// Get book-specific rules for reference
  Map<String, String> getBookSpecificRules() {
    return Map.from(_bookSpecificRules);
  }

  /// Get passage-specific rules for reference
  Map<String, String> getPassageSpecificRules() {
    return Map.from(_passageSpecificRules);
  }
}
