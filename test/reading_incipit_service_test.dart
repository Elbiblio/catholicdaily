import 'package:flutter_test/flutter_test.dart';
import 'package:catholic_daily/data/services/official_lectionary_incipit_service.dart';

void main() {
  group('OfficialLectionaryIncipitService Tests', () {
    late OfficialLectionaryIncipitService service;

    setUp(() {
      service = OfficialLectionaryIncipitService();
    });

    test('should return correct incipit for Daniel', () {
      final incipit = service.getOfficialIncipit('Dan 3:25, 34-43');
      expect(incipit, equals('In those days,'));
    });

    test('should return prophetic incipit for Daniel prophetic chapters', () {
      final incipit = service.getOfficialIncipit('Dan 7:13-14');
      expect(incipit, equals('Thus says the LORD:'));
    });

    test('should return correct incipit for Matthew', () {
      final incipit = service.getOfficialIncipit('Matt 18:21-35');
      expect(incipit, equals('At that time,'));
    });

    test('should return correct incipit for Romans', () {
      final incipit = service.getOfficialIncipit('Rom 5:1-8');
      expect(incipit, equals('Brethren:'));
    });

    test('should return correct incipit for Exodus', () {
      final incipit = service.getOfficialIncipit('Exod 17:3-7');
      expect(incipit, equals('In those days,'));
    });

    test('should return correct incipit for Isaiah', () {
      final incipit = service.getOfficialIncipit('Isa 55:10-11');
      expect(incipit, equals('Thus says the LORD:'));
    });

    test('should return correct incipit for Psalms', () {
      final incipit = service.getOfficialIncipit('Ps 25:4-5');
      expect(incipit, equals('The LORD says:'));
    });

    test('should handle numbered books correctly', () {
      final incipit = service.getOfficialIncipit('1 Sam 3:10-11');
      expect(incipit, equals('In those days,'));
    });

    test('should return null for unknown book', () {
      final incipit = service.getOfficialIncipit('Unknown 1:1');
      expect(incipit, isNull);
    });

    test('should return null for invalid reference', () {
      final incipit = service.getOfficialIncipit('invalid reference');
      expect(incipit, isNull);
    });

    test('should correctly identify books that use incipits', () {
      expect(service.usesIncipit('Dan 3:25, 34-43'), isTrue);
      expect(service.usesIncipit('Matt 18:21-35'), isTrue);
      expect(service.usesIncipit('Rom 5:1-8'), isTrue);
      expect(service.usesIncipit('Exod 17:3-7'), isTrue);
    });

    test('should correctly identify books that do not use incipits', () {
      expect(service.usesIncipit('Unknown 1:1'), isFalse);
      expect(service.usesIncipit('invalid'), isFalse);
    });

    test('should return all book-specific rules', () {
      final bookRules = service.getBookSpecificRules();
      expect(bookRules, contains('Dan'));
      expect(bookRules, contains('Matt'));
      expect(bookRules, contains('Rom'));
      expect(bookRules, isNotEmpty);
    });

    test('should return all passage-specific rules', () {
      final passageRules = service.getPassageSpecificRules();
      expect(passageRules, contains('Dan 3'));
      expect(passageRules, contains('Dan 7'));
      expect(passageRules, isNotEmpty);
    });
  });
}
