import 'package:catholic_daily/data/services/bible_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BibleCacheService', () {
    test('refreshContentForVersionChange clears stale cached content', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BibleCacheService();
      await service.initialize();

      await service.addRecentlyOpened(
        reference: 'John 3',
        title: 'John 3',
        content: 'For God so loved the world',
        version: 'rsvce',
      );
      await service.toggleBookmark(
        reference: 'John 3',
        title: 'John 3',
        content: 'For God so loved the world',
        version: 'rsvce',
      );

      await service.refreshContentForVersionChange('nabre');

      final recentContent = await service.getContentForReference('John 3', 'nabre');
      expect(recentContent, isNull);
      expect(service.recentlyOpened.first['version'], 'nabre');
      expect(service.recentlyOpened.first['content'], '');
      expect(service.bookmarked.first['version'], 'nabre');
      expect(service.bookmarked.first['content'], '');
    });
  });
}
