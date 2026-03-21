import 'package:flutter_test/flutter_test.dart';
import '../lib/data/services/improved_liturgical_calendar_service.dart';

void main() {
  group('Concise Header Tests', () {
    test('formats regular weekday in Lent correctly', () {
      final liturgicalDay = LiturgicalDay(
        date: DateTime(2026, 3, 19), // Thursday
        title: '',
        rank: null,
        color: LiturgicalColor.purple,
        season: LiturgicalSeason.lent,
        weekNumber: 4,
        dayOfWeek: DayOfWeek.thursday,
      );
      
      // Simulate the _buildConciseHeader logic
      String header = _buildConciseHeader(liturgicalDay);
      
      expect(header, equals('Thursday of the 4th week of Lent'));
    });

    test('formats solemnity correctly with title case', () {
      final liturgicalDay = LiturgicalDay(
        date: DateTime(2026, 3, 19),
        title: 'Saint Joseph, Spouse of the Blessed Virgin Mary',
        rank: 'Solemnity',
        color: LiturgicalColor.white,
        season: LiturgicalSeason.lent,
        weekNumber: 4,
        dayOfWeek: DayOfWeek.thursday,
      );
      
      String header = _buildConciseHeader(liturgicalDay);
      
      expect(header, equals('Saint Joseph, Spouse Of The Blessed Virgin Mary'));
    });

    test('formats Sunday in Lent correctly', () {
      final liturgicalDay = LiturgicalDay(
        date: DateTime(2026, 3, 22), // Sunday
        title: '',
        rank: null,
        color: LiturgicalColor.purple,
        season: LiturgicalSeason.lent,
        weekNumber: 5,
        dayOfWeek: DayOfWeek.sunday,
      );
      
      String header = _buildConciseHeader(liturgicalDay);
      
      expect(header, equals('5th Sunday of Lent'));
    });

    test('formats special Sunday correctly', () {
      final liturgicalDay = LiturgicalDay(
        date: DateTime(2026, 4, 5), // Palm Sunday
        title: 'Palm Sunday of the Passion of the Lord',
        rank: 'Solemnity',
        color: LiturgicalColor.red,
        season: LiturgicalSeason.lent,
        weekNumber: 6,
        dayOfWeek: DayOfWeek.sunday,
      );
      
      String header = _buildConciseHeader(liturgicalDay);
      
      expect(header, equals('Palm Sunday of the Passion of the Lord'));
    });

    test('handles ordinal suffixes correctly', () {
      expect(_getOrdinalSuffix(1), equals('st'));
      expect(_getOrdinalSuffix(2), equals('nd'));
      expect(_getOrdinalSuffix(3), equals('rd'));
      expect(_getOrdinalSuffix(4), equals('th'));
      expect(_getOrdinalSuffix(11), equals('th'));
      expect(_getOrdinalSuffix(12), equals('th'));
      expect(_getOrdinalSuffix(13), equals('th'));
      expect(_getOrdinalSuffix(21), equals('st'));
      expect(_getOrdinalSuffix(22), equals('nd'));
      expect(_getOrdinalSuffix(23), equals('rd'));
    });

    test('Canterbury font used for Sundays and solemnities', () {
      final weekday = LiturgicalDay(
        date: DateTime(2026, 3, 19), // Thursday
        title: '',
        rank: null,
        color: LiturgicalColor.purple,
        season: LiturgicalSeason.lent,
        weekNumber: 4,
        dayOfWeek: DayOfWeek.thursday,
      );
      
      final sunday = LiturgicalDay(
        date: DateTime(2026, 3, 22), // Sunday
        title: '',
        rank: null,
        color: LiturgicalColor.purple,
        season: LiturgicalSeason.lent,
        weekNumber: 5,
        dayOfWeek: DayOfWeek.sunday,
      );
      
      final solemnity = LiturgicalDay(
        date: DateTime(2026, 3, 19),
        title: 'Saint Joseph',
        rank: 'Solemnity',
        color: LiturgicalColor.white,
        season: LiturgicalSeason.lent,
        weekNumber: 4,
        dayOfWeek: DayOfWeek.thursday,
      );
      
      expect(_shouldUseCanterburyFont(weekday), isFalse);
      expect(_shouldUseCanterburyFont(sunday), isTrue);
      expect(_shouldUseCanterburyFont(solemnity), isTrue);
    });
  });
}

// Helper functions to simulate the PremiumBrowseScreen methods
String _buildConciseHeader(LiturgicalDay liturgicalDay) {
  // Check if it's Sunday with special formatting first
  if (liturgicalDay.dayOfWeek.name == 'sunday') {
    if (liturgicalDay.title.isNotEmpty && 
        !liturgicalDay.title.toLowerCase().contains('of lent')) {
      // Special Sunday (like Palm Sunday, Easter Sunday) - use title directly
      return liturgicalDay.title;
    } else if (liturgicalDay.title.isNotEmpty && 
               liturgicalDay.title.toLowerCase().contains('sunday')) {
      // If "Sunday" is already in the title, use title directly
      return liturgicalDay.title;
    } else {
      // Regular Sunday in Lent/Advent/Easter/etc.
      return '${liturgicalDay.weekNumber}${_getOrdinalSuffix(liturgicalDay.weekNumber)} Sunday of ${liturgicalDay.seasonName}';
    }
  }
  
  // Check if it's a solemnity (but not special Sundays already handled)
  if (liturgicalDay.rank != null && 
      liturgicalDay.rank!.toLowerCase().contains('solemnity')) {
    // For solemnities, use title case instead of all caps
    if (liturgicalDay.title.isNotEmpty) {
      return _toTitleCase(liturgicalDay.title);
    }
    return 'Solemnity';
  }
  
  // For regular weekdays, show "Thursday of the x week of Lent" format
  return liturgicalDay.weekDescription;
}

String _getOrdinalSuffix(int number) {
  if (number >= 11 && number <= 13) return 'th';
  switch (number % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

bool _shouldUseCanterburyFont(LiturgicalDay liturgicalDay) {
  // Use Canterbury font for Sundays and solemnities
  if (liturgicalDay.dayOfWeek.name == 'sunday') {
    return true;
  }
  
  if (liturgicalDay.rank != null && 
      liturgicalDay.rank!.toLowerCase().contains('solemnity')) {
    return true;
  }
  
  return false;
}

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
  }).join(' ');
}
