import 'package:flutter_test/flutter_test.dart';
import '../lib/data/services/reading_flow_service.dart';
import '../lib/data/models/daily_reading.dart';

void main() {
  group('Reading Preview Tests', () {
    late ReadingFlowService readingFlow;

    setUp(() {
      readingFlow = ReadingFlowService.instance;
    });

    test('buildPreview creates proper preview from full text', () {
      final reading = DailyReading(
        reading: 'John 3:16',
        position: 'Gospel',
        date: DateTime.now(),
      );
      
      final fullText = 'For God so loved the world that he gave his only Son, so that everyone who believes in him might not perish but might have eternal life.';
      
      final preview = readingFlow.buildPreview(reading, fullText);
      
      expect(preview, isNotEmpty);
      expect(preview, contains('For God so loved the world'));
      expect(preview.length, lessThanOrEqualTo(163)); // 160 + '...'
    });

    test('buildPreview handles empty text', () {
      final reading = DailyReading(
        reading: 'Matt 1:1',
        position: 'First Reading',
        date: DateTime.now(),
      );
      
      final preview = readingFlow.buildPreview(reading, '');
      
      expect(preview, equals('Tap to open this reading.'));
    });

    test('buildPreview truncates long text properly', () {
      final reading = DailyReading(
        reading: 'Gen 1:1-31',
        position: 'First Reading',
        date: DateTime.now(),
      );
      
      final longText = 'This is a very long text that should definitely be truncated because it exceeds the maximum length limit for reading previews which is set to 160 characters. ' +
          'This additional text ensures that we go well beyond that limit to test the truncation functionality properly.';
      
      final preview = readingFlow.buildPreview(reading, longText);
      
      expect(preview, endsWith('...'));
      expect(preview.length, lessThanOrEqualTo(163)); // 160 + '...'
    });

    test('buildPreview removes verse numbers from beginning', () {
      final reading = DailyReading(
        reading: 'Ps 23:1',
        position: 'Responsorial Psalm',
        date: DateTime.now(),
      );
      
      final textWithVerse = '1. The LORD is my shepherd; there is nothing I lack.';
      
      final preview = readingFlow.buildPreview(reading, textWithVerse);
      
      expect(preview, isNot(contains('1. ')));
      expect(preview, startsWith('The LORD is my shepherd'));
    });
  });
}
