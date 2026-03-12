import 'improved_liturgical_calendar_service.dart';

/// A complete set of proper readings for a celebration.
class ProperReadingSet {
  final String firstReading;
  final String psalm;
  final String? psalmResponse;
  final String? secondReading;
  final String gospel;
  final String? gospelAcclamation;
  final String? alternativeFirstReading;
  final String? alternativeGospel;

  const ProperReadingSet({
    required this.firstReading,
    required this.psalm,
    this.psalmResponse,
    this.secondReading,
    required this.gospel,
    this.gospelAcclamation,
    this.alternativeFirstReading,
    this.alternativeGospel,
  });
}

/// Represents an optional memorial or feast that can be celebrated on a given day.
class OptionalCelebration {
  final String id;
  final String title;
  final CelebrationRank rank;
  final LiturgicalColor color;
  final int month;
  final int day;
  final String? commonType;

  const OptionalCelebration({
    required this.id,
    required this.title,
    required this.rank,
    required this.color,
    required this.month,
    required this.day,
    this.commonType,
  });

  /// Whether this celebration has its own proper readings
  bool get hasProperReadings =>
      OptionalMemorialService._properReadingsMap.containsKey(id);
}

enum CelebrationRank {
  solemnity,
  feast,
  obligatoryMemorial,
  optionalMemorial,
}

/// Service that provides optional memorials and feasts for any given date,
/// based on the General Roman Calendar (romcal data).
/// 
/// On days with optional memorials, the faithful may choose to celebrate:
/// 1. The ferial (weekday) readings
/// 2. The optional memorial with its proper/common readings
///
/// Rules:
/// - Optional memorials are suppressed during Lent (become commemorations only)
/// - Privileged weekdays (Advent Dec 17-24, Octave of Christmas, Lent) suppress optional memorials
/// - Solemnities and feasts always take precedence
class OptionalMemorialService {
  static final OptionalMemorialService instance = OptionalMemorialService._();
  OptionalMemorialService._();

  /// Get all optional celebrations for a given date.
  /// Returns empty list if no optional celebrations exist or if they are suppressed.
  List<OptionalCelebration> getOptionalCelebrations(DateTime date) {
    final month = date.month;
    final day = date.day;
    final key = _dateKey(month, day);

    // Check if optional memorials are suppressed for this date
    if (_isOptionalMemorialSuppressed(date)) {
      return [];
    }

    return _fixedOptionalCelebrations[key] ?? [];
  }

  List<OptionalCelebration> getAllCelebrationsForDate(DateTime date) {
    final month = date.month;
    final day = date.day;
    final key = _dateKey(month, day);
    return _fixedOptionalCelebrations[key] ?? [];
  }

  /// Check if a date has any optional celebrations available
  bool hasOptionalCelebrations(DateTime date) {
    return getOptionalCelebrations(date).isNotEmpty;
  }

  bool isSuppressedDate(DateTime date) {
    return _isOptionalMemorialSuppressed(date);
  }

  /// Get proper readings for an optional celebration, if any exist.
  /// Returns null if the celebration uses common/weekday readings.
  ProperReadingSet? getProperReadings(String celebrationId) {
    return _properReadingsMap[celebrationId];
  }

  /// Get the common type for fallback reading selection
  String? getCommonType(String celebrationId) {
    final celebrations = _fixedOptionalCelebrations.values
        .expand((list) => list)
        .where((c) => c.id == celebrationId);
    if (celebrations.isEmpty) return null;
    return celebrations.first.commonType;
  }

  /// Get all celebration IDs that have proper readings defined
  Set<String> get celebrationIdsWithReadings => _properReadingsMap.keys.toSet();

  /// Get all celebration IDs from the fixed calendar
  Set<String> get allCelebrationIds => _fixedOptionalCelebrations.values
      .expand((list) => list)
      .map((c) => c.id)
      .toSet();

  bool _isOptionalMemorialSuppressed(DateTime date) {
    // During Lent, optional memorials become commemorations only
    // We need Easter to compute Lent dates
    final easter = _calculateEasterSunday(date.year);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final holyThursday = easter.subtract(const Duration(days: 3));

    // Lent: Ash Wednesday to Holy Thursday (exclusive)
    if (!date.isBefore(ashWednesday) && date.isBefore(holyThursday)) {
      return true;
    }

    // Advent Dec 17-24: privileged weekdays suppress optional memorials
    if (date.month == 12 && date.day >= 17 && date.day <= 24) {
      return true;
    }

    // Octave of Christmas (Dec 25 - Jan 1): no optional memorials
    if ((date.month == 12 && date.day >= 25) ||
        (date.month == 1 && date.day <= 1)) {
      return true;
    }

    // Easter Octave: no optional memorials
    final easterOctaveEnd = easter.add(const Duration(days: 7));
    if (!date.isBefore(easter) && !date.isAfter(easterOctaveEnd)) {
      return true;
    }

    return false;
  }

  DateTime _calculateEasterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  String _dateKey(int month, int day) => '$month-$day';

  // ═══════════════════════════════════════════════════════════════════════
  // PROPER READINGS MAP
  // Maps celebration IDs to their proper scripture readings.
  // Format: [First Reading, Psalm, (Second Reading if applicable), Gospel]
  // Where a celebration has no proper readings, the weekday readings are used,
  // or readings from the Common of Saints appropriate to the saint type.
  // ═══════════════════════════════════════════════════════════════════════

  static final Map<String, ProperReadingSet> _properReadingsMap = {
    // ───── FEASTS WITH PROPER READINGS ─────
    'conversion_of_saint_paul': const ProperReadingSet(
      firstReading: 'Acts 22:3-16', psalm: 'Ps 117:1-2',
      psalmResponse: 'Go out to all the world and tell the Good News.',
      gospel: 'Mark 16:15-18', gospelAcclamation: 'Jn 15:16',
    ),
    'presentation_of_the_lord': const ProperReadingSet(
      firstReading: 'Mal 3:1-4', psalm: 'Ps 24:7-10',
      psalmResponse: 'Who is this king of glory? It is the Lord!',
      secondReading: 'Heb 2:14-18', gospel: 'Luke 2:22-40',
      gospelAcclamation: 'Lk 2:32', alternativeGospel: 'Luke 2:22-32',
    ),
    'holy_family': const ProperReadingSet(
      firstReading: 'Sirach 3:2-6, 12-14', psalm: 'Ps 128:1-5',
      psalmResponse: 'Blessed are those who fear the Lord and walk in his ways.',
      secondReading: 'Col 3:12-21', gospel: 'Matt 2:13-15, 19-23',
      gospelAcclamation: 'Lk 2:51', alternativeFirstReading: 'Col 3:12-17',
    ),
    'chair_of_saint_peter': const ProperReadingSet(
      firstReading: '1 Pet 5:1-4', psalm: 'Ps 23:1-6',
      psalmResponse: 'The Lord is my shepherd; there is nothing I shall want.',
      gospel: 'Matt 16:13-19', gospelAcclamation: 'Mt 16:18',
    ),
    'mark_evangelist': const ProperReadingSet(
      firstReading: '1 Pet 5:5b-14', psalm: 'Ps 89:2-3, 6-7, 16-17',
      psalmResponse: 'For ever I will sing the goodness of the Lord.',
      gospel: 'Mark 16:15-20', gospelAcclamation: '1 Cor 1:23-24',
    ),
    'philip_and_james_apostles': const ProperReadingSet(
      firstReading: '1 Cor 15:1-8', psalm: 'Ps 19:2-5',
      psalmResponse: 'Their message goes out through all the earth.',
      gospel: 'John 14:6-14', gospelAcclamation: 'Jn 14:6',
    ),
    'matthias_apostle': const ProperReadingSet(
      firstReading: 'Acts 1:15-17, 21-26', psalm: 'Ps 113:1-8',
      psalmResponse: 'The Lord will give him a seat with the leaders of his people.',
      gospel: 'John 15:9-17', gospelAcclamation: 'Jn 15:16',
    ),
    'visitation_of_mary': const ProperReadingSet(
      firstReading: 'Zeph 3:14-18', psalm: 'Isa 12:2-6',
      psalmResponse: 'Among you is the great and Holy One of Israel.',
      gospel: 'Luke 1:39-56', gospelAcclamation: 'Lk 1:45',
    ),
    'thomas_apostle': const ProperReadingSet(
      firstReading: 'Eph 2:19-22', psalm: 'Ps 117:1-2',
      psalmResponse: 'Go out to all the world and tell the Good News.',
      gospel: 'John 20:24-29', gospelAcclamation: 'Jn 20:29',
    ),
    'mary_magdalene': const ProperReadingSet(
      firstReading: 'Song 3:1-4', psalm: 'Ps 63:2-6, 8-9',
      psalmResponse: 'My soul is thirsting for you, O Lord my God.',
      gospel: 'John 20:1-2, 11-18', gospelAcclamation: 'Jn 20:18',
    ),
    'james_apostle': const ProperReadingSet(
      firstReading: '2 Cor 4:7-15', psalm: 'Ps 126:1-6',
      psalmResponse: 'Those who sow in tears shall reap rejoicing.',
      gospel: 'Matt 20:20-28', gospelAcclamation: 'Jn 15:16',
    ),
    'transfiguration_of_the_lord': const ProperReadingSet(
      firstReading: 'Dan 7:9-10, 13-14', psalm: 'Ps 97:1-2, 5-6, 9',
      psalmResponse: 'The Lord is king, the most high over all the earth.',
      secondReading: '2 Pet 1:16-19', gospel: 'Mark 9:2-10',
      gospelAcclamation: 'Mt 17:5',
    ),
    'lawrence_of_rome_deacon': const ProperReadingSet(
      firstReading: '2 Cor 9:6-10', psalm: 'Ps 112:1-2, 5-9',
      psalmResponse: 'Blessed the man who is gracious and lends to those in need.',
      gospel: 'John 12:24-26', gospelAcclamation: 'Jn 8:12',
    ),
    'bartholomew_apostle': const ProperReadingSet(
      firstReading: 'Rev 21:9b-14', psalm: 'Ps 145:10-13, 17-18',
      psalmResponse: 'Your friends make known, O Lord, the glorious splendor of your kingdom.',
      gospel: 'John 1:45-51', gospelAcclamation: 'Jn 1:49',
    ),
    'nativity_of_blessed_virgin_mary': const ProperReadingSet(
      firstReading: 'Mic 5:1-4', psalm: 'Ps 13:6',
      psalmResponse: 'With delight I rejoice in the Lord.',
      gospel: 'Matt 1:18-23', gospelAcclamation: 'Lk 1:45',
    ),
    'exaltation_of_holy_cross': const ProperReadingSet(
      firstReading: 'Num 21:4b-9', psalm: 'Ps 78:1-2, 34-38',
      psalmResponse: 'Do not forget the works of the Lord!',
      secondReading: 'Phil 2:6-11', gospel: 'John 3:13-17',
      gospelAcclamation: 'Cf. Phil 2:8-9',
    ),
    'matthew_apostle': const ProperReadingSet(
      firstReading: 'Eph 4:1-7, 11-13', psalm: 'Ps 19:2-5',
      psalmResponse: 'Their message goes out through all the earth.',
      gospel: 'Matt 9:9-13', gospelAcclamation: 'Mt 9:13',
    ),
    'michael_gabriel_raphael_archangels': const ProperReadingSet(
      firstReading: 'Dan 7:9-10, 13-14', psalm: 'Ps 138:1-5',
      psalmResponse: 'In the sight of the angels I will sing your praises, Lord.',
      gospel: 'John 1:47-51', gospelAcclamation: 'Ps 103:21',
    ),
    'luke_evangelist': const ProperReadingSet(
      firstReading: '2 Tim 4:10-17b', psalm: 'Ps 145:10-13, 17-18',
      psalmResponse: 'Your friends make known, O Lord, the glorious splendor of your kingdom.',
      gospel: 'Luke 10:1-9', gospelAcclamation: 'Jn 15:16',
    ),
    'simon_and_jude_apostles': const ProperReadingSet(
      firstReading: 'Eph 2:19-22', psalm: 'Ps 19:2-5',
      psalmResponse: 'Their message goes out through all the earth.',
      gospel: 'Luke 6:12-16', gospelAcclamation: 'Te Deum',
    ),
    'dedication_of_lateran_basilica': const ProperReadingSet(
      firstReading: 'Ezek 47:1-2, 8-9, 12', psalm: 'Ps 46:2-3, 5-6, 8-9',
      psalmResponse: 'The waters of the river gladden the city of God, the holy dwelling of the Most High.',
      secondReading: '1 Cor 3:9c-11, 16-17', gospel: 'John 2:13-22',
      gospelAcclamation: '2 Chr 7:16',
    ),
    'andrew_apostle': const ProperReadingSet(
      firstReading: 'Rom 10:9-18', psalm: 'Ps 19:2-5',
      psalmResponse: 'Their message goes out through all the earth.',
      gospel: 'Matt 4:18-22', gospelAcclamation: 'Mt 4:19',
    ),
    'stephen_first_martyr': const ProperReadingSet(
      firstReading: 'Acts 6:8-10; 7:54-59', psalm: 'Ps 31:3cd-4, 6, 8ab, 16bc-17',
      psalmResponse: 'Into your hands, O Lord, I commend my spirit.',
      gospel: 'Matt 10:17-22', gospelAcclamation: 'Ps 118:26',
    ),
    'john_apostle': const ProperReadingSet(
      firstReading: '1 John 1:1-4', psalm: 'Ps 97:1-2, 5-6, 11-12',
      psalmResponse: 'Rejoice in the Lord, you just!',
      gospel: 'John 20:2-8', gospelAcclamation: 'Te Deum',
    ),
    'holy_innocents': const ProperReadingSet(
      firstReading: '1 John 1:5—2:2', psalm: 'Ps 124:2-5, 7b-8',
      psalmResponse: 'Our soul has been rescued like a bird from the fowler\'s snare.',
      gospel: 'Matt 2:13-18', gospelAcclamation: 'Te Deum',
    ),

    // ───── OBLIGATORY MEMORIALS WITH PROPER READINGS ─────
    'immaculate_heart_of_mary': const ProperReadingSet(
      firstReading: 'Isa 61:9-11', psalm: '1 Sam 2:1, 4-8',
      psalmResponse: 'My heart exults in the Lord, my Savior.',
      gospel: 'Luke 2:41-51', gospelAcclamation: 'Lk 2:19',
    ),
    'our_lady_of_sorrows': const ProperReadingSet(
      firstReading: 'Heb 5:7-9', psalm: 'Ps 31:2-6, 15-16, 20',
      psalmResponse: 'Save me, O Lord, in your kindness.',
      gospel: 'John 19:25-27', gospelAcclamation: 'Lk 2:35',
    ),
    'our_lady_of_the_rosary': const ProperReadingSet(
      firstReading: 'Acts 1:12-14', psalm: 'Luke 1:46-55',
      psalmResponse: 'Blessed are you, Virgin Mary, who bore the Son of the eternal Father.',
      gospel: 'Luke 1:26-38', gospelAcclamation: 'Lk 1:28',
    ),
    'presentation_of_blessed_virgin_mary': const ProperReadingSet(
      firstReading: 'Zech 2:14-17', psalm: 'Luke 1:46-55',
      psalmResponse: 'Blessed are you, Virgin Mary, who bore the Son of the eternal Father.',
      gospel: 'Matt 12:46-50', gospelAcclamation: 'Lk 11:28',
    ),
    'passion_of_john_the_baptist': const ProperReadingSet(
      firstReading: 'Jer 1:17-19', psalm: 'Ps 71:1-6, 15, 17',
      psalmResponse: 'Since my mother\'s womb, you have been my strength.',
      gospel: 'Mark 6:17-29', gospelAcclamation: 'Mt 5:10',
    ),

    // ───── OPTIONAL MEMORIALS WITH PROPER READINGS ─────
    'most_holy_name_of_jesus': const ProperReadingSet(
      firstReading: 'Phil 2:1-11', psalm: 'Ps 8:4-9',
      psalmResponse: 'O Lord, our God, how wonderful your name in all the earth!',
      gospel: 'Luke 2:21-24', gospelAcclamation: 'At the name of Jesus every knee should bend, in heaven and on earth and under the earth, and every tongue confess that Jesus Christ is Lord, to the glory of God the Father.',
    ),
    'joseph_the_worker': const ProperReadingSet(
      firstReading: 'Gen 1:26—2:3', psalm: 'Ps 90:2-4, 12-14, 16',
      psalmResponse: 'Lord, give success to the work of our hands.',
      gospel: 'Matt 13:54-58', gospelAcclamation: 'Ps 68:20',
    ),
    'dedication_of_basilica_of_saint_mary_major': const ProperReadingSet(
      firstReading: 'Rev 21:1-5a', psalm: 'Jdt 13:18-19',
      psalmResponse: 'You are the highest honor of our race.',
      gospel: 'Luke 11:27-28', gospelAcclamation: 'Lk 11:28',
    ),
    'our_lady_of_mount_carmel': const ProperReadingSet(
      firstReading: 'Zech 2:14-17', psalm: 'Ps 15:1-5',
      psalmResponse: 'Who shall dwell on your holy mountain, O Lord?',
      gospel: 'Matt 12:46-50', gospelAcclamation: 'Lk 11:28',
    ),
    'our_lady_of_fatima': const ProperReadingSet(
      firstReading: 'Isa 61:9-11', psalm: 'Ps 45:11-12, 14-17',
      psalmResponse: 'Listen to me, daughter; see and bend your ear.',
      gospel: 'Luke 11:27-28', gospelAcclamation: 'Lk 1:28',
    ),
    'our_lady_of_lourdes': const ProperReadingSet(
      firstReading: 'Isa 66:10-14c', psalm: 'Jdt 13:18-19',
      psalmResponse: 'You are the highest honor of our race.',
      gospel: 'John 2:1-11', gospelAcclamation: 'Lk 1:28',
    ),
    'our_lady_of_guadalupe': const ProperReadingSet(
      firstReading: 'Rev 11:19a; 12:1-6a, 10ab', psalm: 'Jdt 13:18-19',
      psalmResponse: 'You are the highest honor of our race.',
      gospel: 'Luke 1:39-47', gospelAcclamation: 'Lk 1:45',
      alternativeFirstReading: 'Zech 2:14-17', alternativeGospel: 'Luke 1:26-38',
    ),
    'our_lady_of_loreto': const ProperReadingSet(
      firstReading: 'Isa 7:10-14', psalm: 'Ps 130:1-5',
      psalmResponse: 'With the Lord there is mercy, and fullness of redemption.',
      gospel: 'Luke 1:26-38', gospelAcclamation: 'Lk 1:28',
    ),
    'most_holy_name_of_mary': const ProperReadingSet(
      firstReading: 'Gal 4:4-7', psalm: 'Ps 87:1-3, 5-7',
      psalmResponse: 'Glorious things are told of you, O city of God.',
      gospel: 'Luke 1:39-47', gospelAcclamation: 'Lk 1:28',
    ),
    'queenship_of_blessed_virgin_mary': const ProperReadingSet(
      firstReading: 'Isa 9:1-6', psalm: 'Ps 113:1-8',
      psalmResponse: 'The queen stands at your right hand, arrayed in gold.',
      gospel: 'Luke 1:26-38', gospelAcclamation: 'Lk 1:28',
    ),

    // ───── SAINTS WITH PROPER/SEMI-PROPER READINGS ─────
    // These saints have readings commonly assigned in lectionaries
    'patrick_of_ireland': const ProperReadingSet(
      firstReading: '1 Pet 4:7b-11', psalm: 'Ps 96:1-3, 7-8, 10',
      psalmResponse: 'Proclaim God\'s marvelous deeds to all the nations.',
      gospel: 'Luke 5:1-11', gospelAcclamation: 'Mk 1:17',
    ),
    'teresa_of_calcutta': const ProperReadingSet(
      firstReading: '1 John 4:7-16', psalm: 'Ps 23:1-6',
      psalmResponse: 'The Lord is my shepherd; there is nothing I shall want.',
      gospel: 'Matt 25:31-40', gospelAcclamation: 'I give you a new commandment: love one another as I have loved you.',
    ),
    'john_paul_ii_pope': const ProperReadingSet(
      firstReading: 'Isa 52:7-10', psalm: 'Ps 16:1-2, 5, 7-8, 11',
      psalmResponse: 'You are my inheritance, O Lord.',
      gospel: 'John 21:15-17', gospelAcclamation: 'Jn 10:14',
    ),
    'john_xxiii_pope': const ProperReadingSet(
      firstReading: 'Ezek 34:11-16', psalm: 'Ps 23:1-6',
      psalmResponse: 'The Lord is my shepherd; there is nothing I shall want.',
      gospel: 'John 21:15-17', gospelAcclamation: 'Jn 10:14',
    ),
    'faustina_kowalska': const ProperReadingSet(
      firstReading: '1 Cor 1:26-31', psalm: 'Ps 103:1-4, 8, 10',
      psalmResponse: 'The Lord is kind and merciful.',
      gospel: 'Luke 12:35-40', gospelAcclamation: 'Blessed are those servants whom the master finds vigilant on his arrival.',
    ),
    'martin_de_porres': const ProperReadingSet(
      firstReading: 'Phil 4:4-9', psalm: 'Ps 131:1-3',
      psalmResponse: 'In you, Lord, I have found my peace.',
      gospel: 'John 15:9-17', gospelAcclamation: 'I give you a new commandment: love one another as I have loved you.',
    ),
    'rose_of_lima': const ProperReadingSet(
      firstReading: '2 Cor 10:17—11:2', psalm: 'Ps 31:3-4, 6, 8',
      psalmResponse: 'Into your hands, O Lord, I commend my spirit.',
      gospel: 'Matt 13:44-46', gospelAcclamation: 'Blessed are you, Father, Lord of heaven and earth; you have revealed to little ones the mysteries of the Kingdom.',
    ),
    'thomas_becket': const ProperReadingSet(
      firstReading: '2 Tim 2:8-13; 3:10-12', psalm: 'Ps 34:2-9',
      psalmResponse: 'The Lord delivered me from all my fears.',
      gospel: 'Matt 16:24-27', gospelAcclamation: 'Mt 5:10',
    ),
    'teresa_benedicta_of_the_cross': const ProperReadingSet(
      firstReading: 'Hos 2:16b, 17b-18, 21-22', psalm: 'Ps 45:11-12, 14-17',
      psalmResponse: 'Listen to me, daughter; see and bend your ear.',
      gospel: 'Matt 25:1-13', gospelAcclamation: 'Mt 5:10',
    ),
    'maximilian_mary_kolbe': const ProperReadingSet(
      firstReading: 'Wis 3:1-9', psalm: 'Ps 116:10-19',
      psalmResponse: 'Precious in the eyes of the Lord is the death of his faithful.',
      gospel: 'John 15:12-17', gospelAcclamation: 'Jn 15:13',
    ),
    'hildegard_of_bingen': const ProperReadingSet(
      firstReading: 'Wis 7:7-14', psalm: 'Ps 119:89-91, 130, 135, 175',
      psalmResponse: 'Your word is a lamp for my feet, a light for my path.',
      gospel: 'John 17:20-26', gospelAcclamation: 'Jn 15:9',
    ),
    'catherine_of_alexandria': const ProperReadingSet(
      firstReading: '2 Cor 10:17—11:2', psalm: 'Ps 31:3-4, 6, 8',
      psalmResponse: 'Into your hands, O Lord, I commend my spirit.',
      gospel: 'Matt 25:1-13', gospelAcclamation: 'Mt 5:10',
    ),
  };

  // ═══════════════════════════════════════════════════════════════════════
  // FIXED OPTIONAL CELEBRATIONS BY DATE
  // Complete list from the General Roman Calendar (romcal source)
  // ═══════════════════════════════════════════════════════════════════════

  static final Map<String, List<OptionalCelebration>> _fixedOptionalCelebrations = {
    // JANUARY
    '1-3': [
      const OptionalCelebration(id: 'most_holy_name_of_jesus', title: 'The Most Holy Name of Jesus', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 1, day: 3, commonType: 'None'),
    ],
    '1-7': [
      const OptionalCelebration(id: 'raymond_of_penyafort', title: 'Saint Raymond of Penyafort, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 1, day: 7, commonType: 'Pastors'),
    ],
    '1-13': [
      const OptionalCelebration(id: 'hilary_of_poitiers', title: 'Saint Hilary, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 1, day: 13, commonType: 'Bishops'),
    ],
    '1-20': [
      const OptionalCelebration(id: 'fabian_i_pope', title: 'Saint Fabian, Pope and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 1, day: 20, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'sebastian_of_milan', title: 'Saint Sebastian, Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 1, day: 20, commonType: 'Martyrs'),
    ],
    '1-22': [
      const OptionalCelebration(id: 'vincent_of_saragossa', title: 'Saint Vincent, Deacon and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 1, day: 22, commonType: 'Martyrs'),
    ],
    '1-27': [
      const OptionalCelebration(id: 'angela_merici', title: 'Saint Angela Merici, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 1, day: 27, commonType: 'Virgins'),
    ],
    // FEBRUARY
    '2-3': [
      const OptionalCelebration(id: 'blaise_of_sebaste', title: 'Saint Blaise, Bishop and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 2, day: 3, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'ansgar_of_hamburg', title: 'Saint Ansgar, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 3, commonType: 'Bishops'),
    ],
    '2-8': [
      const OptionalCelebration(id: 'jerome_emiliani', title: 'Saint Jerome Emiliani', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 8, commonType: 'Educators'),
      const OptionalCelebration(id: 'josephine_bakhita', title: 'Saint Josephine Bakhita, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 8, commonType: 'Virgins'),
    ],
    '2-11': [
      const OptionalCelebration(id: 'our_lady_of_lourdes', title: 'Our Lady of Lourdes', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 11, commonType: 'BlessedVirginMary'),
    ],
    '2-17': [
      const OptionalCelebration(id: 'seven_holy_founders_of_servites', title: 'The Seven Holy Founders of the Servite Order', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 17, commonType: 'Religious'),
    ],
    '2-21': [
      const OptionalCelebration(id: 'peter_damian', title: 'Saint Peter Damian, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 21, commonType: 'Bishops'),
    ],
    '2-27': [
      const OptionalCelebration(id: 'gregory_of_narek', title: 'Saint Gregory of Narek, Abbot and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 2, day: 27, commonType: 'DoctorsOfTheChurch'),
    ],
    // MARCH
    '3-4': [
      const OptionalCelebration(id: 'casimir_of_poland', title: 'Saint Casimir', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 4, commonType: 'Saints'),
    ],
    '3-8': [
      const OptionalCelebration(id: 'john_of_god', title: 'Saint John of God, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 8, commonType: 'Religious'),
    ],
    '3-9': [
      const OptionalCelebration(id: 'frances_of_rome', title: 'Saint Frances of Rome, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 9, commonType: 'Religious'),
    ],
    '3-17': [
      const OptionalCelebration(id: 'patrick_of_ireland', title: 'Saint Patrick, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 17, commonType: 'Bishops'),
    ],
    '3-18': [
      const OptionalCelebration(id: 'cyril_of_jerusalem', title: 'Saint Cyril of Jerusalem, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 18, commonType: 'Bishops'),
    ],
    '3-23': [
      const OptionalCelebration(id: 'turibius_of_mogrovejo', title: 'Saint Turibius of Mogrovejo, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 3, day: 23, commonType: 'Bishops'),
    ],
    // APRIL
    '4-2': [
      const OptionalCelebration(id: 'francis_of_paola', title: 'Saint Francis of Paola, Hermit', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 2, commonType: 'Religious'),
    ],
    '4-4': [
      const OptionalCelebration(id: 'isidore_of_seville', title: 'Saint Isidore, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 4, commonType: 'Bishops'),
    ],
    '4-5': [
      const OptionalCelebration(id: 'vincent_ferrer', title: 'Saint Vincent Ferrer, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 5, commonType: 'Missionaries'),
    ],
    '4-13': [
      const OptionalCelebration(id: 'martin_i_pope', title: 'Saint Martin I, Pope and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 4, day: 13, commonType: 'Martyrs'),
    ],
    '4-21': [
      const OptionalCelebration(id: 'anselm_of_canterbury', title: 'Saint Anselm, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 21, commonType: 'Bishops'),
    ],
    '4-23': [
      const OptionalCelebration(id: 'george_of_lydda', title: 'Saint George, Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 4, day: 23, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'adalbert_of_prague', title: 'Saint Adalbert, Bishop and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 4, day: 23, commonType: 'Martyrs'),
    ],
    '4-24': [
      const OptionalCelebration(id: 'fidelis_of_sigmaringen', title: 'Saint Fidelis of Sigmaringen, Priest and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 4, day: 24, commonType: 'Martyrs'),
    ],
    '4-28': [
      const OptionalCelebration(id: 'peter_chanel', title: 'Saint Peter Chanel, Priest and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 4, day: 28, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'louis_grignion_de_montfort', title: 'Saint Louis Grignion de Montfort, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 28, commonType: 'Pastors'),
    ],
    '4-30': [
      const OptionalCelebration(id: 'pius_v_pope', title: 'Saint Pius V, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 4, day: 30, commonType: 'Popes'),
    ],
    // MAY
    '5-1': [
      const OptionalCelebration(id: 'joseph_the_worker', title: 'Saint Joseph the Worker', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 1, commonType: 'None'),
    ],
    '5-10': [
      const OptionalCelebration(id: 'john_of_avila', title: 'Saint John of Ávila, Priest and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 10, commonType: 'Pastors'),
    ],
    '5-12': [
      const OptionalCelebration(id: 'nereus_and_achilleus', title: 'Saints Nereus and Achilleus, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 5, day: 12, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'pancras_of_rome', title: 'Saint Pancras, Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 5, day: 12, commonType: 'Martyrs'),
    ],
    '5-13': [
      const OptionalCelebration(id: 'our_lady_of_fatima', title: 'Our Lady of Fatima', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 13, commonType: 'BlessedVirginMary'),
    ],
    '5-18': [
      const OptionalCelebration(id: 'john_i_pope', title: 'Saint John I, Pope and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 5, day: 18, commonType: 'Martyrs'),
    ],
    '5-20': [
      const OptionalCelebration(id: 'bernardine_of_siena', title: 'Saint Bernardine of Siena, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 20, commonType: 'Missionaries'),
    ],
    '5-21': [
      const OptionalCelebration(id: 'christopher_magallanes', title: 'Saint Christopher Magallanes, Priest, and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 5, day: 21, commonType: 'Martyrs'),
    ],
    '5-22': [
      const OptionalCelebration(id: 'rita_of_cascia', title: 'Saint Rita of Cascia, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 22, commonType: 'Religious'),
    ],
    '5-25': [
      const OptionalCelebration(id: 'bede_the_venerable', title: 'Saint Bede the Venerable, Priest and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 25, commonType: 'DoctorsOfTheChurch'),
      const OptionalCelebration(id: 'gregory_vii_pope', title: 'Saint Gregory VII, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 25, commonType: 'Popes'),
      const OptionalCelebration(id: 'mary_magdalene_de_pazzi', title: 'Saint Mary Magdalene de\' Pazzi, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 25, commonType: 'Virgins'),
    ],
    '5-27': [
      const OptionalCelebration(id: 'augustine_of_canterbury', title: 'Saint Augustine of Canterbury, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 27, commonType: 'Bishops'),
    ],
    '5-29': [
      const OptionalCelebration(id: 'paul_vi_pope', title: 'Saint Paul VI, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 5, day: 29, commonType: 'Popes'),
    ],
    // JUNE
    '6-2': [
      const OptionalCelebration(id: 'marcellinus_and_peter', title: 'Saints Marcellinus and Peter, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 6, day: 2, commonType: 'Martyrs'),
    ],
    '6-6': [
      const OptionalCelebration(id: 'norbert_of_xanten', title: 'Saint Norbert, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 6, day: 6, commonType: 'Bishops'),
    ],
    '6-9': [
      const OptionalCelebration(id: 'ephrem_the_syrian', title: 'Saint Ephrem, Deacon and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 6, day: 9, commonType: 'DoctorsOfTheChurch'),
    ],
    '6-19': [
      const OptionalCelebration(id: 'romuald_of_ravenna', title: 'Saint Romuald, Abbot', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 6, day: 19, commonType: 'Abbots'),
    ],
    '6-22': [
      const OptionalCelebration(id: 'paulinus_of_nola', title: 'Saint Paulinus of Nola, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 6, day: 22, commonType: 'Bishops'),
      const OptionalCelebration(id: 'john_fisher_and_thomas_more', title: 'Saints John Fisher, Bishop, and Thomas More, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 6, day: 22, commonType: 'Martyrs'),
    ],
    '6-27': [
      const OptionalCelebration(id: 'cyril_of_alexandria', title: 'Saint Cyril of Alexandria, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 6, day: 27, commonType: 'Bishops'),
    ],
    '6-30': [
      const OptionalCelebration(id: 'first_martyrs_of_rome', title: 'The First Martyrs of the Holy Roman Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 6, day: 30, commonType: 'Martyrs'),
    ],
    // JULY
    '7-4': [
      const OptionalCelebration(id: 'elizabeth_of_portugal', title: 'Saint Elizabeth of Portugal', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 4, commonType: 'MercyWorkers'),
    ],
    '7-5': [
      const OptionalCelebration(id: 'anthony_zaccaria', title: 'Saint Anthony Zaccaria, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 5, commonType: 'Pastors'),
    ],
    '7-6': [
      const OptionalCelebration(id: 'maria_goretti', title: 'Saint Maria Goretti, Virgin and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 7, day: 6, commonType: 'VirginMartyrs'),
    ],
    '7-9': [
      const OptionalCelebration(id: 'augustine_zhao_rong', title: 'Saint Augustine Zhao Rong, Priest, and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 7, day: 9, commonType: 'Martyrs'),
    ],
    '7-13': [
      const OptionalCelebration(id: 'henry_ii_emperor', title: 'Saint Henry', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 13, commonType: 'Saints'),
    ],
    '7-14': [
      const OptionalCelebration(id: 'camillus_de_lellis', title: 'Saint Camillus de Lellis, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 14, commonType: 'MercyWorkers'),
    ],
    '7-16': [
      const OptionalCelebration(id: 'our_lady_of_mount_carmel', title: 'Our Lady of Mount Carmel', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 16, commonType: 'BlessedVirginMary'),
    ],
    '7-20': [
      const OptionalCelebration(id: 'apollinaris_of_ravenna', title: 'Saint Apollinaris, Bishop and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 7, day: 20, commonType: 'Martyrs'),
    ],
    '7-21': [
      const OptionalCelebration(id: 'lawrence_of_brindisi', title: 'Saint Lawrence of Brindisi, Priest and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 21, commonType: 'DoctorsOfTheChurch'),
    ],
    '7-23': [
      const OptionalCelebration(id: 'bridget_of_sweden', title: 'Saint Bridget, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 23, commonType: 'Religious'),
    ],
    '7-24': [
      const OptionalCelebration(id: 'sharbel_makhluf', title: 'Saint Sharbel Makhlūf, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 24, commonType: 'Monks'),
    ],
    '7-30': [
      const OptionalCelebration(id: 'peter_chrysologus', title: 'Saint Peter Chrysologus, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 7, day: 30, commonType: 'Bishops'),
    ],
    // AUGUST
    '8-2': [
      const OptionalCelebration(id: 'eusebius_of_vercelli', title: 'Saint Eusebius of Vercelli, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 2, commonType: 'Bishops'),
      const OptionalCelebration(id: 'peter_julian_eymard', title: 'Saint Peter Julian Eymard, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 2, commonType: 'Religious'),
    ],
    '8-5': [
      const OptionalCelebration(id: 'dedication_of_basilica_of_saint_mary_major', title: 'The Dedication of the Basilica of Saint Mary Major', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 5, commonType: 'BlessedVirginMary'),
    ],
    '8-7': [
      const OptionalCelebration(id: 'sixtus_ii_pope', title: 'Saint Sixtus II, Pope, and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 8, day: 7, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'cajetan_of_thiene', title: 'Saint Cajetan, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 7, commonType: 'Pastors'),
    ],
    '8-9': [
      const OptionalCelebration(id: 'teresa_benedicta_of_the_cross', title: 'Saint Teresa Benedicta of the Cross, Virgin and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 8, day: 9, commonType: 'Martyrs'),
    ],
    '8-12': [
      const OptionalCelebration(id: 'jane_frances_de_chantal', title: 'Saint Jane Frances de Chantal, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 12, commonType: 'Religious'),
    ],
    '8-13': [
      const OptionalCelebration(id: 'pontian_and_hippolytus', title: 'Saints Pontian, Pope, and Hippolytus, Priest, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 8, day: 13, commonType: 'Martyrs'),
    ],
    '8-16': [
      const OptionalCelebration(id: 'stephen_of_hungary', title: 'Saint Stephen of Hungary', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 16, commonType: 'Saints'),
    ],
    '8-19': [
      const OptionalCelebration(id: 'john_eudes', title: 'Saint John Eudes, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 19, commonType: 'Pastors'),
    ],
    '8-23': [
      const OptionalCelebration(id: 'rose_of_lima', title: 'Saint Rose of Lima, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 23, commonType: 'Virgins'),
    ],
    '8-25': [
      const OptionalCelebration(id: 'louis_ix_of_france', title: 'Saint Louis', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 25, commonType: 'Saints'),
      const OptionalCelebration(id: 'joseph_of_calasanz', title: 'Saint Joseph of Calasanz, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 8, day: 25, commonType: 'Educators'),
    ],
    // SEPTEMBER
    '9-5': [
      const OptionalCelebration(id: 'teresa_of_calcutta', title: 'Saint Teresa of Calcutta, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 9, day: 5, commonType: 'Virgins'),
    ],
    '9-9': [
      const OptionalCelebration(id: 'peter_claver', title: 'Saint Peter Claver, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 9, day: 9, commonType: 'Pastors'),
    ],
    '9-12': [
      const OptionalCelebration(id: 'most_holy_name_of_mary', title: 'The Most Holy Name of Mary', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 9, day: 12, commonType: 'None'),
    ],
    '9-17': [
      const OptionalCelebration(id: 'hildegard_of_bingen', title: 'Saint Hildegard of Bingen, Abbess and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 9, day: 17, commonType: 'Virgins'),
      const OptionalCelebration(id: 'robert_bellarmine', title: 'Saint Robert Bellarmine, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 9, day: 17, commonType: 'Bishops'),
    ],
    '9-19': [
      const OptionalCelebration(id: 'januarius_of_benevento', title: 'Saint Januarius, Bishop and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 9, day: 19, commonType: 'Martyrs'),
    ],
    '9-26': [
      const OptionalCelebration(id: 'cosmas_and_damian', title: 'Saints Cosmas and Damian, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 9, day: 26, commonType: 'Martyrs'),
    ],
    '9-28': [
      const OptionalCelebration(id: 'wenceslaus_of_bohemia', title: 'Saint Wenceslaus, Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 9, day: 28, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'lawrence_ruiz', title: 'Saint Lawrence Ruiz and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 9, day: 28, commonType: 'Martyrs'),
    ],
    // OCTOBER
    '10-5': [
      const OptionalCelebration(id: 'faustina_kowalska', title: 'Saint Faustina Kowalska, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 5, commonType: 'Virgins'),
    ],
    '10-6': [
      const OptionalCelebration(id: 'bruno_of_cologne', title: 'Saint Bruno, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 6, commonType: 'Monks'),
    ],
    '10-9': [
      const OptionalCelebration(id: 'denis_of_paris', title: 'Saint Denis, Bishop, and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 10, day: 9, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'john_leonardi', title: 'Saint John Leonardi, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 9, commonType: 'Missionaries'),
    ],
    '10-11': [
      const OptionalCelebration(id: 'john_xxiii_pope', title: 'Saint John XXIII, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 11, commonType: 'Popes'),
    ],
    '10-14': [
      const OptionalCelebration(id: 'callistus_i_pope', title: 'Saint Callistus I, Pope and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 10, day: 14, commonType: 'Martyrs'),
    ],
    '10-16': [
      const OptionalCelebration(id: 'hedwig_of_silesia', title: 'Saint Hedwig, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 16, commonType: 'Religious'),
      const OptionalCelebration(id: 'margaret_mary_alacoque', title: 'Saint Margaret Mary Alacoque, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 16, commonType: 'Virgins'),
    ],
    '10-19': [
      const OptionalCelebration(id: 'john_de_brebeuf_and_isaac_jogues', title: 'Saints John de Brébeuf and Isaac Jogues, Priests, and Companions, Martyrs', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 10, day: 19, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'paul_of_the_cross', title: 'Saint Paul of the Cross, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 19, commonType: 'Pastors'),
    ],
    '10-22': [
      const OptionalCelebration(id: 'john_paul_ii_pope', title: 'Saint John Paul II, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 22, commonType: 'Popes'),
    ],
    '10-23': [
      const OptionalCelebration(id: 'john_of_capistrano', title: 'Saint John of Capistrano, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 23, commonType: 'Missionaries'),
    ],
    '10-24': [
      const OptionalCelebration(id: 'anthony_mary_claret', title: 'Saint Anthony Mary Claret, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 10, day: 24, commonType: 'Bishops'),
    ],
    // NOVEMBER
    '11-3': [
      const OptionalCelebration(id: 'martin_de_porres', title: 'Saint Martin de Porres, Religious', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 3, commonType: 'Religious'),
    ],
    '11-15': [
      const OptionalCelebration(id: 'albert_the_great', title: 'Saint Albert the Great, Bishop and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 15, commonType: 'Bishops'),
    ],
    '11-16': [
      const OptionalCelebration(id: 'margaret_of_scotland', title: 'Saint Margaret of Scotland', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 16, commonType: 'MercyWorkers'),
      const OptionalCelebration(id: 'gertrude_the_great', title: 'Saint Gertrude, Virgin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 16, commonType: 'Virgins'),
    ],
    '11-18': [
      const OptionalCelebration(id: 'dedication_of_basilicas_of_peter_and_paul', title: 'The Dedication of the Basilicas of Saints Peter and Paul, Apostles', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 18, commonType: 'None'),
    ],
    '11-23': [
      const OptionalCelebration(id: 'clement_i_pope', title: 'Saint Clement I, Pope and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 11, day: 23, commonType: 'Martyrs'),
      const OptionalCelebration(id: 'columban_of_luxeuil', title: 'Saint Columban, Abbot', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 11, day: 23, commonType: 'Abbots'),
    ],
    '11-25': [
      const OptionalCelebration(id: 'catherine_of_alexandria', title: 'Saint Catherine of Alexandria, Virgin and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 11, day: 25, commonType: 'VirginMartyrs'),
    ],
    // DECEMBER
    '12-4': [
      const OptionalCelebration(id: 'john_damascene', title: 'Saint John Damascene, Priest and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 4, commonType: 'DoctorsOfTheChurch'),
    ],
    '12-6': [
      const OptionalCelebration(id: 'nicholas_of_myra', title: 'Saint Nicholas, Bishop', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 6, commonType: 'Bishops'),
    ],
    '12-9': [
      const OptionalCelebration(id: 'juan_diego', title: 'Saint Juan Diego Cuauhtlatoatzin', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 9, commonType: 'Saints'),
    ],
    '12-10': [
      const OptionalCelebration(id: 'our_lady_of_loreto', title: 'Our Lady of Loreto', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 10, commonType: 'BlessedVirginMary'),
    ],
    '12-11': [
      const OptionalCelebration(id: 'damasus_i_pope', title: 'Saint Damasus I, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 11, commonType: 'Popes'),
    ],
    '12-12': [
      const OptionalCelebration(id: 'our_lady_of_guadalupe', title: 'Our Lady of Guadalupe', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 12, commonType: 'BlessedVirginMary'),
    ],
    '12-21': [
      const OptionalCelebration(id: 'peter_canisius', title: 'Saint Peter Canisius, Priest and Doctor of the Church', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 21, commonType: 'DoctorsOfTheChurch'),
    ],
    '12-23': [
      const OptionalCelebration(id: 'john_of_kanty', title: 'Saint John of Kanty, Priest', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 23, commonType: 'Pastors'),
    ],
    '12-29': [
      const OptionalCelebration(id: 'thomas_becket', title: 'Saint Thomas Becket, Bishop and Martyr', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.red, month: 12, day: 29, commonType: 'Martyrs'),
    ],
    '12-31': [
      const OptionalCelebration(id: 'sylvester_i_pope', title: 'Saint Sylvester I, Pope', rank: CelebrationRank.optionalMemorial, color: LiturgicalColor.white, month: 12, day: 31, commonType: 'Popes'),
    ],
  };
}
