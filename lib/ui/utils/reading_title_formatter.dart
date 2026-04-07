class ReadingTitleFormatter {
  static String build({required String reference, String? position}) {
    final shortBook = _extractShortBook(reference);
    if (shortBook == null) return 'A reading from Sacred Scripture';

    final book = _bookNames[shortBook] ?? shortBook;
    final positionLabel = (position ?? '').toLowerCase();

    // Check for gospel first - this takes precedence over psalm check
    if (_gospels.contains(shortBook) || positionLabel == 'gospel' || positionLabel == 'gospel (alternative)' || positionLabel == 'gospel at procession') {
      return 'A reading from the holy Gospel according to $book';
    }

    if (positionLabel == 'alleluia psalm' || positionLabel == 'alleluia psalm (alternative)') {
      return positionLabel.contains('(alternative)') ? 'Alleluia Psalm (Alternative)' : 'Alleluia Psalm';
    }

    // Only check for psalm if position explicitly indicates it's a psalm
    if (positionLabel == 'responsorial psalm' || positionLabel == 'responsorial psalm (alternative)') {
      return positionLabel.contains('(alternative)') ? 'Responsorial Psalm (Alternative)' : 'Responsorial Psalm';
    }

    final pauline = _paulineHeadings[shortBook];
    if (pauline != null) return pauline;

    final catholic = _catholicEpistleHeadings[shortBook];
    if (catholic != null) return catholic;

    if (shortBook == 'Acts') return 'A reading from the Acts of the Apostles';

    if (shortBook == 'Rev') return 'A reading from the Book of Revelation';

    if (shortBook == 'Song') return 'A reading from the Song of Songs';

    if (_prophets.contains(shortBook)) {
      return 'A reading from the Book of the Prophet $book';
    }

    if (book.startsWith('first book of') ||
        book.startsWith('second book of') ||
        book.startsWith('third book of')) {
      return 'A reading from the $book';
    }

    return 'A reading from the Book of $book';
  }

  static String? _extractShortBook(String reference) {
    final match = RegExp(r'^(.+?)\s+\d+:').firstMatch(reference.trim());
    return match?.group(1)?.trim();
  }

  static const Set<String> _gospels = {'Matt', 'Mark', 'Luke', 'John'};

  static const Set<String> _prophets = {
    'Isa', 'Jer', 'Lam', 'Bar', 'Ezek', 'Dan', 'Hos', 'Joel', 'Amos', 'Obad',
    'Jonah', 'Mic', 'Nah', 'Hab', 'Zeph', 'Hagg', 'Zech', 'Mal'
  };

  static const Map<String, String> _paulineHeadings = {
    'Rom': 'A reading from the Letter of Saint Paul to the Romans',
    '1 Cor': 'A reading from the first Letter of Saint Paul to the Corinthians',
    '2 Cor':
        'A reading from the second Letter of Saint Paul to the Corinthians',
    'Gal': 'A reading from the Letter of Saint Paul to the Galatians',
    'Eph': 'A reading from the Letter of Saint Paul to the Ephesians',
    'Phil': 'A reading from the Letter of Saint Paul to the Philippians',
    'Col': 'A reading from the Letter of Saint Paul to the Colossians',
    '1 Thess':
        'A reading from the first Letter of Saint Paul to the Thessalonians',
    '2 Thess':
        'A reading from the second Letter of Saint Paul to the Thessalonians',
    '1 Tim': 'A reading from the first Letter of Saint Paul to Timothy',
    '2 Tim': 'A reading from the second Letter of Saint Paul to Timothy',
    'Titus': 'A reading from the Letter of Saint Paul to Titus',
    'Phlm': 'A reading from the Letter of Saint Paul to Philemon',
    'Heb': 'A reading from the Letter to the Hebrews',
  };

  static const Map<String, String> _catholicEpistleHeadings = {
    'James': 'A reading from the Letter of Saint James',
    '1 Pet': 'A reading from the first Letter of Saint Peter',
    '2 Pet': 'A reading from the second Letter of Saint Peter',
    '1 John': 'A reading from the first Letter of Saint John',
    '2 John': 'A reading from the second Letter of Saint John',
    '3 John': 'A reading from the third Letter of Saint John',
    'Jude': 'A reading from the Letter of Saint Jude',
  };

  static const Map<String, String> _bookNames = {
    'Gen': 'Genesis',
    'Exod': 'Exodus',
    'Lev': 'Leviticus',
    'Num': 'Numbers',
    'Deut': 'Deuteronomy',
    'Josh': 'Joshua',
    'Judg': 'Judges',
    'Ruth': 'Ruth',
    '1 Sam': 'first book of Samuel',
    '2 Sam': 'second book of Samuel',
    '1 Kgs': 'first book of Kings',
    '2 Kgs': 'second book of Kings',
    '1 Chr': 'first book of Chronicles',
    '2 Chr': 'second book of Chronicles',
    'Ezra': 'Ezra',
    'Neh': 'Nehemiah',
    'Tob': 'Tobit',
    'Jud': 'Judith',
    'Esth': 'Esther',
    '1 Macc': 'first book of Maccabees',
    '2 Macc': 'second book of Maccabees',
    'Job': 'Job',
    'Ps': 'Psalms',
    'Prov': 'Proverbs',
    'Eccles': 'Ecclesiastes',
    'Song': 'Song of Songs',
    'Wis': 'Wisdom',
    'Sir': 'Sirach',
    'Isa': 'Isaiah',
    'Jer': 'Jeremiah',
    'Lam': 'Lamentations',
    'Bar': 'Baruch',
    'Ezek': 'Ezekiel',
    'Dan': 'Daniel',
    'Hos': 'Hosea',
    'Joel': 'Joel',
    'Amos': 'Amos',
    'Obad': 'Obadiah',
    'Jonah': 'Jonah',
    'Mic': 'Micah',
    'Nah': 'Nahum',
    'Hab': 'Habakkuk',
    'Zeph': 'Zephaniah',
    'Hagg': 'Haggai',
    'Zech': 'Zechariah',
    'Mal': 'Malachi',
    'Matt': 'Matthew',
    'Mark': 'Mark',
    'Luke': 'Luke',
    'John': 'John',
    'Acts': 'Acts of the Apostles',
    'Rom': 'Romans',
    '1 Cor': 'first Corinthians',
    '2 Cor': 'second Corinthians',
    'Gal': 'Galatians',
    'Eph': 'Ephesians',
    'Phil': 'Philippians',
    'Col': 'Colossians',
    '1 Thess': 'first Thessalonians',
    '2 Thess': 'second Thessalonians',
    '1 Tim': 'first Timothy',
    '2 Tim': 'second Timothy',
    'Titus': 'Titus',
    'Phlm': 'Philemon',
    'Heb': 'Hebrews',
    'James': 'James',
    '1 Pet': 'first Peter',
    '2 Pet': 'second Peter',
    '1 John': 'first John',
    '2 John': 'second John',
    '3 John': 'third John',
    'Jude': 'Jude',
    'Rev': 'Revelation',
  };
}
