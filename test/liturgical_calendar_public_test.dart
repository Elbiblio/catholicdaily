import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/improved_liturgical_calendar_service.dart';

void main() {
  group('LiturgicalCalendarService Public API Tests', () {
    final service = ImprovedLiturgicalCalendarService.instance;

    test('March 8, 2026 should be 3rd Sunday of Lent (NOT Ordinary Time week 48)', () {
      final date = DateTime(2026, 3, 8);
      final liturgicalDay = service.getLiturgicalDay(date);
      
      print('March 8, 2026 Results:');
      print('  Season: ${liturgicalDay.seasonName}');
      print('  Week Number: ${liturgicalDay.weekNumber}');
      print('  Day: ${liturgicalDay.dayName}');
      print('  Title: ${liturgicalDay.title}');
      print('  Rank: ${liturgicalDay.rank}');
      print('  Color: ${liturgicalDay.color}');
      print('  Full Description: ${liturgicalDay.fullDescription}');
      
      // This should NOT be Ordinary Time week 48
      expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
      expect(liturgicalDay.weekNumber, equals(3));
      expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      expect(liturgicalDay.seasonName, equals('Lent'));
      expect(liturgicalDay.dayName, equals('Sunday'));
      
      // Definitely should NOT be this:
      expect(liturgicalDay.season, isNot(equals(LiturgicalSeason.ordinaryTime)));
      expect(liturgicalDay.weekNumber, isNot(equals(48)));
    });

    test('December 25, 2025 should be Christmas Day', () {
      final date = DateTime(2025, 12, 25);
      final liturgicalDay = service.getLiturgicalDay(date);
      
      print('December 25, 2025 Results:');
      print('  Season: ${liturgicalDay.seasonName}');
      print('  Title: ${liturgicalDay.title}');
      print('  Rank: ${liturgicalDay.rank}');
      
      expect(liturgicalDay.season, equals(LiturgicalSeason.christmas));
      expect(liturgicalDay.title, equals('The Nativity of the Lord'));
      expect(liturgicalDay.rank, equals('Solemnity'));
    });

    test('April 5, 2026 should be Easter Sunday', () {
      final date = DateTime(2026, 4, 5);
      final liturgicalDay = service.getLiturgicalDay(date);
      
      print('April 5, 2026 Results:');
      print('  Season: ${liturgicalDay.seasonName}');
      print('  Title: ${liturgicalDay.title}');
      print('  Rank: ${liturgicalDay.rank}');
      
      expect(liturgicalDay.season, equals(LiturgicalSeason.easter));
      expect(liturgicalDay.title, equals('Easter Sunday'));
      expect(liturgicalDay.rank, equals('Solemnity'));
    });

    group('Lent 2026 Sunday Tests', () {
      test('February 22, 2026 should be 1st Sunday of Lent', () {
        final date = DateTime(2026, 2, 22);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.weekNumber, equals(1));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      });

      test('March 1, 2026 should be 2nd Sunday of Lent', () {
        final date = DateTime(2026, 3, 1);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.weekNumber, equals(2));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      });

      test('March 8, 2026 should be 3rd Sunday of Lent', () {
        final date = DateTime(2026, 3, 8);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.weekNumber, equals(3));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      });

      test('March 15, 2026 should be 4th Sunday of Lent (Laetare)', () {
        final date = DateTime(2026, 3, 15);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.weekNumber, equals(4));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
        expect(liturgicalDay.color, equals(LiturgicalColor.pink)); // Laetare Sunday
      });

      test('March 22, 2026 should be 5th Sunday of Lent', () {
        final date = DateTime(2026, 3, 22);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.weekNumber, equals(5));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      });

      test('March 29, 2026 should be Palm Sunday', () {
        final date = DateTime(2026, 3, 29);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
        expect(liturgicalDay.color, equals(LiturgicalColor.red)); // Palm Sunday
      });
    });

    group('Liturgical Year Boundaries', () {
      test('November 30, 2025 should be 1st Sunday of Advent', () {
        final date = DateTime(2025, 11, 30);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.advent));
        expect(liturgicalDay.weekNumber, equals(1));
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday));
      });

      test('December 24, 2025 should still be Advent', () {
        final date = DateTime(2025, 12, 24);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.advent));
      });

      test('January 6, 2026 should be Christmas season', () {
        final date = DateTime(2026, 1, 6);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.christmas));
      });

      test('February 1, 2026 should be Ordinary Time I', () {
        final date = DateTime(2026, 2, 1);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.season, equals(LiturgicalSeason.ordinaryTime));
      });
    });

    group('Color Tests', () {
      test('Lent weekdays should be purple', () {
        final dates = [
          DateTime(2026, 2, 19), // Friday after Ash Wednesday
          DateTime(2026, 2, 25), // Wednesday
          DateTime(2026, 3, 4),  // Wednesday
          DateTime(2026, 3, 11), // Wednesday
        ];
        
        for (final date in dates) {
          final liturgicalDay = service.getLiturgicalDay(date);
          expect(liturgicalDay.color, equals(LiturgicalColor.purple), 
                 reason: '${date.toIso8601String()} should be purple in Lent');
        }
      });

      test('Ordinary Time should be green', () {
        final date = DateTime(2026, 1, 20); // Ordinary Time I
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.color, equals(LiturgicalColor.green));
      });

      test('Christmas should be white', () {
        final date = DateTime(2025, 12, 25);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.color, equals(LiturgicalColor.white));
      });

      test('Easter should be white', () {
        final date = DateTime(2026, 4, 5);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        expect(liturgicalDay.color, equals(LiturgicalColor.white));
      });
    });

    group('Problematic Dates Test', () {
      test('March 8, 2026 shows the actual issue', () {
        final date = DateTime(2026, 3, 8);
        final liturgicalDay = service.getLiturgicalDay(date);
        
        print('\n=== DETAILED DEBUG FOR MARCH 8, 2026 ===');
        print('Input Date: ${date.toIso8601String()} (${date.weekday})');
        print('Calculated Season: ${liturgicalDay.season}');
        print('Calculated Week: ${liturgicalDay.weekNumber}');
        print('Calculated Day: ${liturgicalDay.dayOfWeek}');
        print('Expected: Lent, Week 3, Sunday');
        print('Actual: ${liturgicalDay.seasonName}, Week ${liturgicalDay.weekNumber}, ${liturgicalDay.dayName}');
        print('Title: "${liturgicalDay.title}"');
        print('Full Description: "${liturgicalDay.fullDescription}"');
        print('========================================\n');
        
        // The actual test - this should pass
        expect(liturgicalDay.season, equals(LiturgicalSeason.lent), 
               reason: 'March 8, 2026 should be in Lent, not Ordinary Time');
        expect(liturgicalDay.weekNumber, equals(3), 
               reason: 'March 8, 2026 should be 3rd week of Lent, not week 48');
        expect(liturgicalDay.dayOfWeek, equals(DayOfWeek.sunday), 
               reason: 'March 8, 2026 is a Sunday');
      });
    });
  });
}
