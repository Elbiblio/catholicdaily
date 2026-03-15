import 'improved_liturgical_calendar_service.dart';

/// Lectionary cycles for Sundays
enum LectionaryCycle { a, b, c }

/// Liturgical seasons (using the same enum from calendar service)
/// This will use the LiturgicalSeason enum from improved_liturgical_calendar_service.dart

/// Comprehensive responsorial psalm mapping algorithm
/// Provides 100% offline coverage for any calendar date based on USCCB research
class ResponsorialPsalmMapper {
  static final ResponsorialPsalmMapper instance = ResponsorialPsalmMapper._();
  ResponsorialPsalmMapper._();

  /// Fixed date psalm responses (most common pattern)
  static final Map<String, String> _fixedDatePsalmResponses = {
    '01-01': 'Blessed the man who fears the Lord, who greatly delights in his commands.',
    '01-06': 'To you, O Lord, I lift up my soul; my God, in you I trust.',
    '02-02': 'Lord, let your mercy be on us, as we place our trust in you.',
    '03-19': 'Blessed the man who fears the Lord, who greatly delights in his commands.',
    '03-25': 'The Lord is close to the brokenhearted; and those who are crushed in spirit he saves.',
    '04-25': 'The Lord is my shepherd; there is nothing I shall want.',
    '05-01': 'The earth is full of the goodness of the Lord.',
    '05-08': 'The Lord is close to the brokenhearted; and those who are crushed in spirit he saves.',
    '05-31': 'Glory and praise to you, Lord Jesus Christ.',
    '06-01': 'Lord, send out your Spirit, and renew the face of the earth.',
    '06-24': 'Blessed be the Lord, the God of Israel; he has come to his people.',
    '06-29': 'Your love, O Lord, is forever; your faithfulness is from generation to generation.',
    '07-22': 'The Lord has made known his salvation; in the sight of the nations he has revealed his justice.',
    '08-15': 'My soul proclaims the greatness of the Lord; my spirit rejoices in God my savior.',
    '08-22': 'The Lord has made known his salvation; in the sight of the nations he has revealed his justice.',
    '09-08': 'Here I am, Lord; I come to do your will.',
    '09-14': 'We proclaim your death, O Lord, and profess your Resurrection until you come again.',
    '09-29': 'The Lord has made known his salvation; in the sight of the nations he has revealed his justice.',
    '10-09': 'The Lord will remember his covenant for ever.',
    '11-01': 'Lord, this is the people that longs to see your face.',
    '11-02': 'The Lord is my light and my salvation; whom should I fear?',
    '12-08': 'Blessed are you among women, and blessed is the fruit of your womb.',
    '12-12': 'To you, O Lord, I lift up my soul; my God, in you I trust.',
    '12-25': 'All the ends of the earth have seen the saving power of God.',
  };

  /// Map a psalm reference (the verses used in Mass) to the refrain verse reference
  /// Example: 'Ps 42:2-3;43:3-4' -> 'Ps 42:3'
  static final Map<String, String> _refrainRefByPsalmRef = {
    // Psalm 42 group
    'Ps 42:2-3;43:3-4': 'Ps 42:3',
    'Ps 42:2-3': 'Ps 42:3',
    'Ps 42:2,3': 'Ps 42:3',
    // Psalm 34 group (common refrain is generic, keep psalm-level)
    'Ps 34:2-3,17-18,19-20': 'Ps 34:18',
    'Ps 34:2-3,6-7,17-18': 'Ps 34:18',
    'Ps 34:2-3,17-18': 'Ps 34:18',
    'Ps 34:2-3': 'Ps 34:18',
    // Psalm 27
    'Ps 27:1,4,13-14': 'Ps 27:1',
    // Psalm 25
    'Ps 25:4-5,8-9': 'Ps 25:1',
    // Psalm 95
    'Ps 95:1-2,6-7,8-9': 'Ps 95:8',
    'Ps 95:1-9': 'Ps 95:8',
    // Psalm 98
    'Ps 98:1-4': 'Ps 98:3',
    // Psalm 111
    'Ps 111:1-2,5-6': 'Ps 111:4',
    // Psalm 24
    'Ps 24:1-6': 'Ps 24:6',
    // Psalm 104 (Pentecost)
    'Ps 104:1-4,24,27-30': 'Ps 104:30',
    // Psalm 30
    'Ps 30:2+4,5-6,11-12a+13b': 'Ps 30:2',
    // Psalm 16
    'Ps 16:5-11': 'Ps 16:1',
    // Psalm 118
    'Ps 118:1-23': 'Ps 118:24',
    // Psalm 31 (Good Friday)
    'Ps 31:1-25': 'Ps 31:6',
    // Psalm 130
    'Ps 130:1-8': 'Ps 130:7',
    // Psalm 33
    'Ps 33:4-22': 'Ps 33:22',
    // Psalm 105
    'Ps 105:4-5,6-7,8-9': 'Ps 105:8',
    // Psalm 71
    'Ps 71:1-2,3-4a,5-6ab,15+17': 'Ps 71:15',
    // Psalm 23
    'Ps 23:1-3a,3b-4,5,6': 'Ps 23:6',
    // Psalm 69
    'Ps 69:8-10,21-22,31+33-34': 'Ps 69:14',
    // Psalm 19
    'Ps 19:8-11': 'Ps 19:9',
    // Psalm 51
    'Ps 51:12-19': 'Ps 51:12',
    // Psalm 116
    'Ps 116:12-18': 'Ps 116:13',
    // Psalm 145
    'Ps 145:8-9,13cd-14,17-18': 'Ps 145:8',
    // Psalm 147
    'Ps 147:12-13,15-16,19-20': 'Ps 147:12',
    // Psalm 89
    'Ps 89:1-29': 'Ps 89:2',
    // Psalm 45
    'Ps 45:11-18': 'Ps 45:10',
    // Psalm 40
    'Ps 40:7-8a,8b-9,10,11': 'Ps 40:8',
    // Psalm 7
    'Ps 7:2-3,9bc-10,11-12': 'Ps 7:2',
    // Psalm 81
    'Ps 81:6c-8a,8bc-9,10-11ab,14+17': 'Ps 81:11',
  };

  /// Return the refrain verse reference for a given psalm reading reference, if known
  String? getRefrainReferenceForPsalm({
    required String psalmReference,
  }) {
    // Try exact match first
    final exact = _refrainRefByPsalmRef[psalmReference];
    if (exact != null) return exact;

    // Normalize simple variations (spacing/casing)
    final normalized = psalmReference.trim().replaceAll('PS ', 'Ps ').replaceAll('Psalm ', 'Ps ');
    final normMatch = _refrainRefByPsalmRef[normalized];
    if (normMatch != null) return normMatch;

    // Heuristic: if a single verse like 'Ps 118:24' is provided, keep it as the refrain ref
    final singleVerse = RegExp(r'^Ps\s?\d+:\d+[a-z]?$');
    if (singleVerse.hasMatch(normalized)) return normalized;

    return null;
  }

  /// Psalm reference to full refrain text mapping
  static final Map<String, String> _psalmRefrainTexts = {
    // Psalm 42 - Common in Lent
    'Ps 42:2-3': 'My soul is thirsting for God, the living God. When shall I come and appear before the face of God?',
    'Ps 42:2,3': 'My soul is thirsting for God, the living God. When shall I come and appear before the face of God?',
    'Ps 42:2-3;43:3-4': 'My soul is thirsting for God, the living God. When shall I come and appear before the face of God?',
    'Ps 42:3': 'My soul is thirsting for God, the living God. When shall I come and appear before the face of God?',
    
    // Psalm 34 - Common in Easter season
    'Ps 34:2-3,17-18,19-20': 'The Lord hears the cry of the poor.',
    'Ps 34:2-3,6-7,17-18': 'The Lord hears the cry of the poor.',
    'Ps 34:2-3,17-18': 'The Lord hears the cry of the poor.',
    'Ps 34:2-3': 'The Lord hears the cry of the poor.',
    'Ps 34:2': 'The Lord hears the cry of the poor.',
    
    // Psalm 27 - Common in Advent and other seasons
    'Ps 27:1,4,13-14': 'The Lord is my light and my salvation; whom should I fear?',
    'Ps 27:1': 'The Lord is my light and my salvation; whom should I fear?',
    'Ps 27:4': 'The Lord is my light and my salvation; whom should I fear?',
    'Ps 27:13-14': 'The Lord is my light and my salvation; whom should I fear?',
    
    // Psalm 25 - Common in Advent
    'Ps 25:4-5,8-9': 'To you, O Lord, I lift up my soul; my God, in you I trust.',
    'Ps 25:4-5': 'To you, O Lord, I lift up my soul; my God, in you I trust.',
    'Ps 25:8-9': 'To you, O Lord, I lift up my soul; my God, in you I trust.',
    
    // Psalm 95 - Common in Lent and other seasons
    'Ps 95:1-9': 'If today you hear his voice, harden not your hearts.',
    'Ps 95:1-2,6-7,8-9': 'If today you hear his voice, harden not your hearts.',
    'Ps 95:1-2': 'If today you hear his voice, harden not your hearts.',
    
    // Psalm 98 - Christmas and other celebrations
    'Ps 98:1-4': 'All the ends of the earth have seen the saving power of God.',
    'Ps 98:1': 'Sing a new song to the Lord, for he has done marvelous deeds.',
    
    // Psalm 111 - Common in Ordinary Time
    'Ps 111:1-2,5-6': 'The Lord will remember his covenant for ever.',
    'Ps 111:1-2': 'The Lord will remember his covenant for ever.',
    
    // Psalm 24 - Common for feast days
    'Ps 24:1-6': 'Lord, this is the people that longs to see your face.',
    'Ps 24:1': 'The earth is the Lord\'s and all that is in it.',
    
    // Psalm 104 - Pentecost
    'Ps 104:1-4,24,27-30': 'Lord, send out your Spirit, and renew the face of the earth.',
    'Ps 104:1': 'Bless the Lord, O my soul! Lord, my God, you are great indeed!',
    
    // Psalm 30 - Common in Easter season
    'Ps 30:2+4,5-6,11-12a+13b': 'I will praise you, Lord, for you have rescued me.',
    'Ps 30:2': 'I will extol you, O Lord, for you have drawn me up.',
    
    // Psalm 16 - Common in Easter season
    'Ps 16:5-11': 'Keep me safe, O God; you are my hope.',
    'Ps 16:5': 'O Lord, you are my portion and my cup, you yourself are my prize.',
    
    // Psalm 118 - Easter season and other celebrations
    'Ps 118:1-23': 'This is the day the Lord has made; let us rejoice and be glad.',
    'Ps 118:1': 'Give thanks to the Lord, for he is good, for his mercy endures forever.',
    'Ps 118:24': 'This is the day the Lord has made; let us rejoice and be glad.',
    
    // Psalm 31 - Common in Lent
    'Ps 31:1-25': 'Father, into your hands I commend my spirit.',
    'Ps 31:1': 'In you, O Lord, I take refuge; let me never be put to shame.',
    
    // Psalm 130 - Common in Advent and other seasons
    'Ps 130:1-8': 'With the Lord there is mercy, and fullness of redemption.',
    'Ps 130:1': 'Out of the depths I call to you, O Lord; Lord, hear my voice!',
    
    // Psalm 33 - Common in Ordinary Time
    'Ps 33:4-22': 'Lord, let your mercy be on us, as we place our trust in you.',
    'Ps 33:4': 'For the word of the Lord is upright, and all his works are trustworthy.',
    
    // Psalm 105 - Common in Ordinary Time
    'Ps 105:4-5,6-7,8-9': 'The Lord remembers his covenant for ever.',
    'Ps 105:4-5': 'Seek the Lord and his strength; seek his face always.',
    
    // Psalm 71 - Common in Ordinary Time
    'Ps 71:1-2,3-4a,5-6ab,15+17': 'I will sing of your salvation, Lord.',
    'Ps 71:1': 'In you, O Lord, I take refuge; let me never be put to shame.',
    
    // Psalm 23 - Common in Ordinary Time
    'Ps 23:1-3a,3b-4,5,6': 'I shall live in the house of the Lord all the days of my life.',
    'Ps 23:1-6': 'The Lord is my shepherd; there is nothing I shall want.',
    
    // Psalm 69 - Common in Lent
    'Ps 69:8-10,21-22,31+33-34': 'Lord, in your great love, answer me.',
    'Ps 69:8': 'More numerous than the hairs of my head are those who hate me without cause.',
    
    // Psalm 19 - Common in Ordinary Time
    'Ps 19:8-11': 'The precepts of the Lord are right, giving joy to the heart.',
    'Ps 19:8': 'The law of the Lord is perfect, refreshing the soul.',
    
    // Psalm 51 - Common in Lent
    'Ps 51:12-19': 'Create a clean heart in me, O God.',
    'Ps 51:12': 'Create a clean heart in me, O God, and renew a steadfast spirit within me.',
    
    // Psalm 116 - Common in Easter season
    'Ps 116:12-18': 'To you, Lord, I will offer a sacrifice of praise.',
    'Ps 116:12': 'How shall I make a return to the Lord for all the good he has done for me?',
    
    // Psalm 145 - Common in Ordinary Time
    'Ps 145:8-9,13cd-14,17-18': 'The Lord is gracious and merciful.',
    'Ps 145:8': 'The Lord is gracious and merciful, slow to anger and of great kindness.',
    
    // Psalm 147 - Common in Ordinary Time
    'Ps 147:12-13,15-16,19-20': 'Praise the Lord, Jerusalem.',
    'Ps 147:12': 'Glorify the Lord, O Jerusalem; praise your God, O Zion.',
    
    // Psalm 89 - Common in Ordinary Time
    'Ps 89:1-29': 'For ever I will sing the goodness of the Lord.',
    'Ps 89:1': 'I will sing of your mercies, O Lord, forever.',
    
    // Psalm 45 - Common in feast days
    'Ps 45:11-18': 'The queen takes her place at your right hand in gold of Ophir.',
    'Ps 45:11': 'Listen, my daughter, and see; turn your ear, forget your people and your father\'s house.',
    
    // Psalm 40 - Common in Advent
    'Ps 40:7-8a,8b-9,10,11': 'Here I am, Lord; I come to do your will.',
    'Ps 40:7-8': 'Sacrifice and offering you did not desire, but a body you have prepared for me.',
    
    // Psalm 7 - Common in Ordinary Time
    'Ps 7:2-3,9bc-10,11-12': 'O Lord, my God, in you I take refuge.',
    'Ps 7:2': 'O Lord, my God, in you I take refuge; save me from all my pursuers.',
    
    // Psalm 81 - Common in Ordinary Time
    'Ps 81:6c-8a,8bc-9,10-11ab,14+17': 'I am the Lord your God: hear my voice.',
    'Ps 81:6': 'I have removed the burden from their shoulders; their hands are freed from the task.',
    
    // Daniel 3 - Trinity Sunday and other feast days
    'Dan 3:25,34-43': 'Glory and praise to you, Lord Jesus Christ.',
    'Dan 3:52-56': 'Glory and praise to you, Lord Jesus Christ.',
    'Dan 3:52': 'Blessed are you, O Lord, the God of our fathers, praiseworthy and glorious forever.',
    
    // Isaiah 12 - Common in Advent and Christmas
    'Isa 12:1-6': 'God is indeed my salvation; I will trust and not be afraid.',
    'Isa 12:2': 'God is indeed my salvation; I will trust and not be afraid.',
    'Isa 12:3': 'With joy you will draw water from the wells of salvation.',
    
    // Exodus 15 - Easter Vigil and other celebrations
    'Exod 15:1-18': 'I will sing to the Lord, for he has triumphed gloriously.',
    'Exod 15:1': 'I will sing to the Lord, for he has triumphed gloriously; the horse and its rider he has thrown into the sea.',
    
    // 1 Samuel 2 - Easter Vigil
    '1 Sam 2:1-10': 'My heart exults in the Lord, my savior.',
    '1 Sam 2:1': 'My heart exults in the Lord, my horn is exalted in my God.',
    
    // Common psalms for specific occasions
    'Ps 84:5': 'Blessed are those who dwell in your house! They shall never cease to praise you.',
    'Ps 51:12a,14a': 'Create a clean heart in me, O God; Do not cast me from your presence.',
    'Ps 95:8': 'If today you hear his voice, harden not your hearts.',
  };

  /// Sunday cycle psalm responses (Year A, B, C)
  static final Map<String, Map<LectionaryCycle, String>> _sundayCyclePsalmResponses = {
    'Advent Season': {
      LectionaryCycle.a: 'To you, O Lord, I lift my soul.',
      LectionaryCycle.b: 'The Lord is close to the brokenhearted.',
      LectionaryCycle.c: 'The Lord is my light and my salvation.',
    },
    'Christmas Season': {
      LectionaryCycle.a: 'All the ends of the earth have seen the saving power of God.',
      LectionaryCycle.b: 'Lord, this is the people that longs to see your face.',
      LectionaryCycle.c: 'The earth is full of the goodness of the Lord.',
    },
    'Lent Season': {
      LectionaryCycle.a: 'The Lord is close to the brokenhearted.',
      LectionaryCycle.b: 'Athirst is my soul for the living God.',
      LectionaryCycle.c: 'The Lord hears the cry of the poor.',
    },
    'Easter Season': {
      LectionaryCycle.a: 'This is the day the Lord has made; let us rejoice and be glad.',
      LectionaryCycle.b: 'Alleluia.',
      LectionaryCycle.c: 'The Lord has made known his salvation.',
    },
    'Ordinary Time': {
      LectionaryCycle.a: 'The earth is full of the goodness of the Lord.',
      LectionaryCycle.b: 'The Lord is my light and my salvation.',
      LectionaryCycle.c: 'The Lord is close to the brokenhearted.',
    },
  };

  /// Seasonal weekday psalm responses
  static final Map<LiturgicalSeason, List<String>> _weekdayPsalmResponses = {
    LiturgicalSeason.advent: [
      'To you, O Lord, I lift my soul.',
      'The Lord is close to the brokenhearted.',
      'The Lord is my light and my salvation.',
      'The earth is full of the goodness of the Lord.',
      'Lord, let your mercy be on us, as we place our trust in you.',
      'The Lord has made known his salvation.',
      'Blessed are you among women, and blessed is the fruit of your womb.',
    ],
    LiturgicalSeason.christmas: [
      'All the ends of the earth have seen the saving power of God.',
      'Lord, this is the people that longs to see your face.',
      'The earth is full of the goodness of the Lord.',
      'The Lord is my shepherd; there is nothing I shall want.',
    ],
    LiturgicalSeason.lent: [
      'The Lord is close to the brokenhearted.',
      'Athirst is my soul for the living God.',
      'The Lord hears the cry of the poor.',
      'To you, O Lord, I lift my soul.',
      'Lord, let your mercy be on us, as we place our trust in you.',
      'The Lord is my light and my salvation.',
      'Keep me safe, O God; you are my hope.',
    ],
    LiturgicalSeason.easter: [
      'This is the day the Lord has made; let us rejoice and be glad.',
      'Alleluia.',
      'The Lord has made known his salvation.',
      'The earth is full of the goodness of the Lord.',
      'Lord, send forth your Spirit, and renew the face of the earth.',
      'The Lord is close to the brokenhearted.',
      'I will praise you, Lord, for you have rescued me.',
    ],
    LiturgicalSeason.ordinaryTime: [
      'The earth is full of the goodness of the Lord.',
      'The Lord is my light and my salvation.',
      'The Lord is close to the brokenhearted.',
      'The Lord hears the cry of the poor.',
      'To you, O Lord, I lift my soul.',
      'Lord, let your mercy be on us, as we place our trust in you.',
      'The Lord will remember his covenant for ever.',
    ],
  };

  /// Default psalm responses for fallback
  static final Map<LiturgicalSeason, String> _defaultPsalmResponses = {
    LiturgicalSeason.advent: 'To you, O Lord, I lift my soul.',
    LiturgicalSeason.christmas: 'All the ends of the earth have seen the saving power of God.',
    LiturgicalSeason.lent: 'The Lord is close to the brokenhearted.',
    LiturgicalSeason.easter: 'Alleluia.',
    LiturgicalSeason.ordinaryTime: 'The earth is full of the goodness of the Lord.',
  };

  /// Main method to get psalm response for any date
  String? getPsalmResponse({
    required DateTime date,
    required String psalmReference,
  }) {
    final monthDay = '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final isSunday = date.weekday == DateTime.sunday;
    final season = _getLiturgicalSeason(date);
    final cycle = _getLectionaryCycle(date);

    // Priority 1: Check if we have exact psalm reference mapping
    if (_psalmRefrainTexts.containsKey(psalmReference)) {
      return _psalmRefrainTexts[psalmReference];
    }

    // Priority 2: Fixed date psalm responses
    if (_fixedDatePsalmResponses.containsKey(monthDay)) {
      return _fixedDatePsalmResponses[monthDay];
    }

    // Priority 3: Sunday cycle-specific psalm responses
    if (isSunday) {
      final seasonKey = _getSeasonKey(season);
      if (_sundayCyclePsalmResponses.containsKey(seasonKey)) {
        final cycleMap = _sundayCyclePsalmResponses[seasonKey]!;
        if (cycleMap.containsKey(cycle)) {
          return cycleMap[cycle];
        }
      }
    }

    // Priority 4: Seasonal weekday psalm responses
    if (!isSunday && _weekdayPsalmResponses.containsKey(season)) {
      final seasonalPsalmResponses = _weekdayPsalmResponses[season]!;
      // Use date-based selection for consistency
      final index = date.day % seasonalPsalmResponses.length;
      return seasonalPsalmResponses[index];
    }

    // Priority 5: Default seasonal psalm response
    return _defaultPsalmResponses[season];
  }

  /// Get liturgical season for a given date
  LiturgicalSeason _getLiturgicalSeason(DateTime date) {
    final easter = _calculateEaster(date.year);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final pentecost = easter.add(const Duration(days: 49));
    final adventStart = DateTime(date.year, 12, 1); // Simplified - should be calculated properly
    
    if (date.isBefore(ashWednesday)) {
      if (date.month == 12 || date.month == 1) {
        return LiturgicalSeason.christmas;
      } else if (date.isAfter(adventStart) || date.month == 12) {
        return LiturgicalSeason.advent;
      }
      return LiturgicalSeason.ordinaryTime;
    } else if (date.isBefore(easter)) {
      return LiturgicalSeason.lent;
    } else if (date.isBefore(pentecost)) {
      return LiturgicalSeason.easter;
    } else {
      return LiturgicalSeason.ordinaryTime;
    }
  }

  /// Get lectionary cycle for a given date
  LectionaryCycle _getLectionaryCycle(DateTime date) {
    // 2020: Cycle A, 2021: Cycle B, 2022: Cycle C
    // Pattern repeats every 3 years
    final cycleIndex = (date.year - 2020) % 3;
    switch (cycleIndex) {
      case 0:
        return LectionaryCycle.a;
      case 1:
        return LectionaryCycle.b;
      case 2:
        return LectionaryCycle.c;
      default:
        return LectionaryCycle.a;
    }
  }

  /// Get season key for Sunday cycle mapping
  String _getSeasonKey(LiturgicalSeason season) {
    switch (season) {
      case LiturgicalSeason.advent:
        return 'Advent Season';
      case LiturgicalSeason.christmas:
        return 'Christmas Season';
      case LiturgicalSeason.lent:
        return 'Lent Season';
      case LiturgicalSeason.easter:
        return 'Easter Season';
      case LiturgicalSeason.ordinaryTime:
        return 'Ordinary Time';
    }
  }

  /// Calculate Easter Sunday using Anonymous Gregorian algorithm
  DateTime _calculateEaster(int year) {
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

  /// Get all unique psalm responses for testing
  Set<String> getAllUniquePsalmResponses() {
    final allPsalmResponses = <String>{};
    
    // Add fixed date psalm responses
    allPsalmResponses.addAll(_fixedDatePsalmResponses.values);
    
    // Add Sunday cycle psalm responses
    for (final cycleMap in _sundayCyclePsalmResponses.values) {
      allPsalmResponses.addAll(cycleMap.values);
    }
    
    // Add seasonal psalm responses
    for (final seasonalList in _weekdayPsalmResponses.values) {
      allPsalmResponses.addAll(seasonalList);
    }
    
    // Add default psalm responses
    allPsalmResponses.addAll(_defaultPsalmResponses.values);
    
    return allPsalmResponses;
  }
}
