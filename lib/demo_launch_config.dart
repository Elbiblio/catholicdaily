import 'data/models/liturgical_region.dart';
import 'data/services/bible_version_preference.dart';

enum DemoLaunchScreen { home, mass }

class DemoLaunchConfig {
  final DemoLaunchScreen screen;
  final DateTime? date;
  final LiturgicalRegion? region;
  final BibleVersionType? bibleVersion;

  const DemoLaunchConfig({
    required this.screen,
    required this.date,
    required this.region,
    required this.bibleVersion,
  });

  factory DemoLaunchConfig.fromEnvironment() {
    return DemoLaunchConfig.parse(
      screen: const String.fromEnvironment('CATHOLIC_DAILY_DEMO_SCREEN'),
      date: const String.fromEnvironment('CATHOLIC_DAILY_DEMO_DATE'),
      regionCode: const String.fromEnvironment('CATHOLIC_DAILY_DEMO_REGION'),
      bibleVersionId: const String.fromEnvironment(
        'CATHOLIC_DAILY_DEMO_BIBLE_VERSION',
      ),
    );
  }

  factory DemoLaunchConfig.parse({
    required String screen,
    required String date,
    required String regionCode,
    required String bibleVersionId,
  }) {
    final parsedScreen = _parseScreen(screen);
    final parsedDate = _parseDate(date);
    final parsedRegion = regionCode.trim().isEmpty
        ? null
        : LiturgicalRegion.fromCode(regionCode);
    final parsedVersion = bibleVersionId.trim().isEmpty
        ? null
        : BibleVersionType.fromDbName(bibleVersionId.trim().toLowerCase());

    return DemoLaunchConfig(
      screen: parsedScreen,
      date: parsedDate,
      region: parsedRegion,
      bibleVersion: parsedVersion,
    );
  }

  bool get enabled =>
      screen != DemoLaunchScreen.home ||
      date != null ||
      region != null ||
      bibleVersion != null;

  static DemoLaunchScreen _parseScreen(String value) {
    switch (value.trim().toLowerCase()) {
      case 'mass':
      case 'mass-flow':
      case 'readings':
        return DemoLaunchScreen.mass;
      default:
        return DemoLaunchScreen.home;
    }
  }

  static DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    final parts = normalized.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }
}
