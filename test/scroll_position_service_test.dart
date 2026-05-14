import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:catholic_daily/data/services/scroll_position_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScrollPositionService', () {
    late ScrollPositionService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = ScrollPositionService();
      await service.initialize();
    });

    test('should save and retrieve scroll position', () async {
      const reference = 'Genesis 1';
      const position = 1234.5;

      await service.saveScrollPosition(reference, position);
      final retrieved = service.getScrollPosition(reference);

      expect(retrieved, equals(position));
    });

    test('should return null for non-existent reference', () {
      final retrieved = service.getScrollPosition('Non-existent');
      expect(retrieved, isNull);
    });

    test('should clear specific position', () async {
      const reference = 'John 3';
      const position = 567.8;

      await service.saveScrollPosition(reference, position);
      await service.clearPosition(reference);

      final retrieved = service.getScrollPosition(reference);
      expect(retrieved, isNull);
    });

    test('should clear all positions', () async {
      await service.saveScrollPosition('Genesis 1', 100.0);
      await service.saveScrollPosition('John 3', 200.0);

      await service.clearAllPositions();

      expect(service.getScrollPosition('Genesis 1'), isNull);
      expect(service.getScrollPosition('John 3'), isNull);
    });

    test('should handle multiple references independently', () async {
      await service.saveScrollPosition('Genesis 1', 100.0);
      await service.saveScrollPosition('John 3', 200.0);
      await service.saveScrollPosition('Psalm 23', 300.0);

      expect(service.getScrollPosition('Genesis 1'), equals(100.0));
      expect(service.getScrollPosition('John 3'), equals(200.0));
      expect(service.getScrollPosition('Psalm 23'), equals(300.0));
    });

    test('should update existing position for same reference', () async {
      const reference = 'Genesis 1';

      await service.saveScrollPosition(reference, 100.0);
      await service.saveScrollPosition(reference, 500.0);

      final retrieved = service.getScrollPosition(reference);
      expect(retrieved, equals(500.0));
    });
  });
}
