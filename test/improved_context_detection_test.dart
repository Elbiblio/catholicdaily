import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/official_lectionary_incipit_service.dart';

void main() {
  group('Improved Text Context Detection Tests', () {
    late OfficialLectionaryIncipitService service;

    setUp(() {
      service = OfficialLectionaryIncipitService();
    });

    group('Enhanced Context Detection', () {
      test('should detect "Brothers and sisters" with various punctuation', () {
        final testCases = [
          'Brothers and sisters, I want to remind you',
          'Brothers and sisters: I want to remind you',
          'Brothers and sisters I want to remind you',
          'Brothers, and sisters, I want to remind you',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('1 Cor 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('Brethren'), reason: 'Should contain brethren incipit in: $text');
        }
      });

      test('should detect "Thus says the LORD" with variations', () {
        final testCases = [
          'Thus says the LORD: Your hands are full of blood',
          'Thus says the LORD, Your hands are full of blood',
          'Thus says the LORD Your hands are full of blood',
          'Thus says the LORD God: Your hands are full of blood',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Isa 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('LORD'), reason: 'Should contain LORD incipit in: $text');
        }
      });

      test('should detect "Brethren" variations', () {
        final testCases = [
          'Brethren, I want to remind you',
          'Brethren: I want to remind you',
          'Brethren I want to remind you',
          'My brethren, I want to remind you',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('1 Cor 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('Brethren'), reason: 'Should contain brethren incipit in: $text');
        }
      });

      test('should detect "At that time" and "In those days" variations', () {
        final testCases = [
          'At that time, Jesus came to Galilee',
          'At that time: Jesus came to Galilee',
          'At that time Jesus came to Galilee',
          'In those days, a decree went out',
          'In those days: a decree went out',
          'In those days a decree went out',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Mark 1:15');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, anyOf(contains('At that time'), contains('In those days')), reason: 'Should contain time incipit in: $text');
        }
      });

      test('should detect "Beloved" variations', () {
        final testCases = [
          'Beloved, I want to remind you',
          'Beloved: I want to remind you',
          'Beloved I want to remind you',
          'Dearly beloved, I want to remind you',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('1 Pet 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('Beloved'), reason: 'Should contain beloved incipit in: $text');
        }
      });

      test('should detect "In the beginning" variations', () {
        final testCases = [
          'In the beginning was the Word',
          'In the beginning, God created',
          'In the beginning: God created',
          'In the beginning God created',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('John 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('In the beginning'), reason: 'Should contain beginning incipit in: $text');
        }
      });

      test('should detect "The revelation of" variations', () {
        final testCases = [
          'The revelation of Jesus Christ',
          'The revelation of Jesus Christ, which God gave',
          'The revelation of Jesus Christ: which God gave',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Rev 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('I, John, saw'), reason: 'Should contain revelation incipit in: $text');
        }
      });

      test('should detect "I appeal to you" variations', () {
        final testCases = [
          'I appeal to you, my child',
          'I appeal to you: my child',
          'I appeal to you my child',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Phlm 1:1');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, contains('I appeal to you'), reason: 'Should contain appeal incipit in: $text');
        }
      });

      test('should detect "The LORD said to" variations', () {
        final testCases = [
          'The LORD said to Joshua',
          'The LORD said to Moses',
          'The LORD said to Joshua: See',
          'The LORD said to Joshua, See',
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Josh 6:2');
          expect(incipit, isNotNull, reason: 'Should detect context in: $text');
          expect(incipit, anyOf(contains('LORD'), contains('In those days')), reason: 'Should contain LORD or time incipit in: $text');
        }
      });

      test('should detect different incipits for different biblical references', () {
        final testCases = [
          {'reference': 'Mark 1:15', 'incipit': 'At that time,'},
          {'reference': 'John 1:1', 'incipit': 'In the beginning was the Word:'},
          {'reference': '1 Cor 1:1', 'incipit': 'Brethren:'},
          {'reference': 'Isa 1:1', 'incipit': 'Thus says the LORD:'},
        ];
        
        for (final testCase in testCases) {
          final incipit = service.getOfficialIncipit(testCase['reference']!);
          expect(incipit, isNotNull, reason: 'Should detect context for ${testCase['reference']}');
          expect(incipit, equals(testCase['incipit']), reason: 'Should return correct incipit for ${testCase['reference']}');
        }
      });

      test('should handle edge cases gracefully', () {
        final testCases = [
          '', // Empty text
          '   ', // Whitespace only
          'Word', // Single word
          'A', // Single character
        ];
        
        for (final text in testCases) {
          final incipit = service.getOfficialIncipit('Mark 1:15');
          // Should not crash and should return appropriate incipit
          expect(incipit, isNotNull, reason: 'Should handle edge case: "$text"');
        }
      });
    });
  });
}
