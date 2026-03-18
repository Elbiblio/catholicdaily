import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/official_lectionary_incipit_service.dart';

void main() {
  group('Official Lectionary Incipit Service Tests', () {
    late OfficialLectionaryIncipitService service;

    setUp(() {
      service = OfficialLectionaryIncipitService();
    });

    test('should return correct incipit for Daniel 3 (narrative)', () {
      final incipit = service.getOfficialIncipit('Dan 3:25, 34-43');
      expect(incipit, equals('In those days,'));
    });

    test('should return prophetic incipit for Daniel 7 (vision)', () {
      final incipit = service.getOfficialIncipit('Dan 7:13-14');
      expect(incipit, equals('Thus says the LORD:'));
    });

    test('should return correct incipit for Matthew', () {
      final incipit = service.getOfficialIncipit('Matt 18:21-35');
      expect(incipit, equals('At that time,'));
    });

    test('should return discourse incipit for Matthew 5 (Sermon on Mount)', () {
      final incipit = service.getOfficialIncipit('Matt 5:1-12');
      expect(incipit, equals('Jesus said to his disciples:'));
    });

    test('should return correct incipit for Romans', () {
      final incipit = service.getOfficialIncipit('Rom 5:1-8');
      expect(incipit, equals('Brethren:'));
    });

    test('should return correct incipit for Exodus', () {
      final incipit = service.getOfficialIncipit('Exod 17:3-7');
      expect(incipit, equals('In those days,'));
    });

    test('should return narrative incipit for Exodus 1', () {
      final incipit = service.getOfficialIncipit('Exod 1:1-7');
      expect(incipit, equals('In those days,'));
    });

    test('should return correct incipit for Isaiah', () {
      final incipit = service.getOfficialIncipit('Isa 55:10-11');
      expect(incipit, equals('Thus says the LORD:'));
    });

    test('should return correct incipit for Genesis 1', () {
      final incipit = service.getOfficialIncipit('Gen 1:1-5');
      expect(incipit, equals('In the beginning,'));
    });

    test('should return correct incipit for Luke 1', () {
      final incipit = service.getOfficialIncipit('Luke 1:1-7');
      expect(incipit, equals('In those days,'));
    });

    test('should return correct incipit for Luke 3', () {
      final incipit = service.getOfficialIncipit('Luke 3:1-6');
      expect(incipit, equals('At that time,'));
    });

    test('should return correct incipit for John 1', () {
      final incipit = service.getOfficialIncipit('John 1:1-5');
      expect(incipit, equals('In the beginning was the Word:'));
    });

    test('should return correct incipit for Acts', () {
      final incipit = service.getOfficialIncipit('Acts 2:1-4');
      expect(incipit, equals('In those days,'));
    });

    test('should return correct incipit for Hebrews', () {
      final incipit = service.getOfficialIncipit('Heb 1:1-4');
      expect(incipit, equals('Brethren:'));
    });

    test('should return correct incipit for 1 Timothy', () {
      final incipit = service.getOfficialIncipit('1 Tim 1:1-2');
      expect(incipit, equals('My child,'));
    });

    test('should return correct incipit for 1 Peter', () {
      final incipit = service.getOfficialIncipit('1 Pet 1:1-3');
      expect(incipit, equals('Beloved:'));
    });

    test('should return correct incipit for Revelation', () {
      final incipit = service.getOfficialIncipit('Rev 1:1-3');
      expect(incipit, equals('I, John, saw:'));
    });

    test('should return null for unknown book', () {
      final incipit = service.getOfficialIncipit('Unknown 1:1');
      expect(incipit, isNull);
    });

    test('should correctly identify books that use incipits', () {
      expect(service.usesIncipit('Dan 3:25, 34-43'), isTrue);
      expect(service.usesIncipit('Matt 18:21-35'), isTrue);
      expect(service.usesIncipit('Rom 5:1-8'), isTrue);
      expect(service.usesIncipit('Exod 17:3-7'), isTrue);
      expect(service.usesIncipit('Unknown 1:1'), isFalse);
    });

    test('should handle numbered books correctly', () {
      final incipit = service.getOfficialIncipit('1 Sam 3:3-10');
      expect(incipit, equals('In those days,'));
    });

    test('should handle complex references', () {
      final incipit = service.getOfficialIncipit('Dan 3:25, 34-43');
      expect(incipit, equals('In those days,'));
    });

    group('Contextual Accuracy Tests', () {
      test('Daniel 3 (furnace) should be narrative', () {
        expect(service.getOfficialIncipit('Dan 3:1-30'), equals('In those days,'));
        expect(service.getOfficialIncipit('Dan 3:25, 34-43'), equals('In those days,'));
      });

      test('Daniel 7+ should be prophetic', () {
        expect(service.getOfficialIncipit('Dan 7:1-14'), equals('Thus says the LORD:'));
        expect(service.getOfficialIncipit('Dan 8:1-14'), equals('Thus says the LORD:'));
        expect(service.getOfficialIncipit('Dan 12:1-13'), equals('Thus says the LORD:'));
      });

      test('Genesis 1-2 should be creation narrative', () {
        expect(service.getOfficialIncipit('Gen 1:1-31'), equals('In the beginning,'));
        expect(service.getOfficialIncipit('Gen 2:1-25'), equals('In the beginning,'));
        expect(service.getOfficialIncipit('Gen 3:1-24'), equals('In the beginning,'));
      });

      test('Matthew 5-7 should be discourse', () {
        expect(service.getOfficialIncipit('Matt 5:1-12'), equals('Jesus said to his disciples:'));
        expect(service.getOfficialIncipit('Matt 6:1-4'), equals('Jesus said to his disciples:'));
        expect(service.getOfficialIncipit('Matt 7:1-5'), equals('Jesus said to his disciples:'));
      });

      test('Luke 1-2 should be infancy narrative', () {
        expect(service.getOfficialIncipit('Luke 1:1-38'), equals('In those days,'));
        expect(service.getOfficialIncipit('Luke 2:1-20'), equals('In those days,'));
      });

      test('John 1 should be prologue', () {
        expect(service.getOfficialIncipit('John 1:1-18'), equals('In the beginning was the Word:'));
      });

      test('processReading suppresses duplicate gospel incipit when the opener already names Jesus', () {
        final result = service.processReading(
          'Matt 5:1-12',
          '1 Jesus said to his disciples, Take care not to perform righteous deeds in order that people may see them.',
        );

        expect(result.incipit, isNull);
        expect(result.correctedText, startsWith('1 Jesus said to his disciples'));
      });

      test('processReading rewrites leading gospel temporal pronouns to Jesus', () {
        final result = service.processReading(
          'Luke 5:1-11',
          '1 While the people pressed upon him to hear the word of God, he was standing by the lake of Gennesaret.',
        );

        expect(result.incipit, equals('At that time,'));
        expect(result.correctedText, startsWith('1 While the people pressed upon Jesus'));
      });

      test('Exodus 1-2 should be early narrative', () {
        expect(service.getOfficialIncipit('Exod 1:1-22'), equals('In those days,'));
        expect(service.getOfficialIncipit('Exod 2:1-10'), equals('In those days,'));
      });

      test('should return narrative incipit for Exodus 20', () {
        final incipit = service.getOfficialIncipit('Exod 20:1-17');
        expect(incipit, equals('In those days,'));
      });
    });
  });
}
