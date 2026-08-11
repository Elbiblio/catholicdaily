import 'dart:collection';

import 'improved_liturgical_calendar_service.dart';
import 'optional_memorial_service.dart';
import 'reading_catalog_service.dart';
import 'saint_profile_service.dart';

class SaintCalendarService {
  static final SaintCalendarService instance = SaintCalendarService._();

  SaintCalendarService._();

  final OptionalMemorialService _optionalMemorials =
      OptionalMemorialService.instance;
  final ReadingCatalogService _catalog = ReadingCatalogService.instance;

  Future<List<OptionalCelebration>> getSaintCelebrationsForDate({
    required DateTime date,
    LiturgicalDay? liturgicalDay,
    List<OptionalCelebration>? optionalCelebrations,
  }) async {
    final merged = LinkedHashMap<String, OptionalCelebration>();

    void add(OptionalCelebration celebration) {
      if (!SaintProfileService.isSaintLikeTitle(celebration.title)) return;
      final key = _dedupeKey(celebration);
      merged.putIfAbsent(key, () => celebration);
    }

    for (final celebration
        in optionalCelebrations ??
            _optionalMemorials.getAllCelebrationsForDate(date)) {
      add(celebration);
    }

    final entries = await _catalog.getMemorialEntriesForMonthDay(
      date.month,
      date.day,
    );
    for (final entry in entries) {
      if (!SaintProfileService.isSaintLikeTitle(entry.title)) continue;
      add(_fromMemorialEntry(entry, date));
    }

    for (final celebration in _nigeriaObservedSaintCelebrations(date)) {
      add(celebration);
    }

    final title = liturgicalDay?.title.trim();
    if (title != null &&
        title.isNotEmpty &&
        SaintProfileService.isSaintLikeTitle(title)) {
      add(
        OptionalCelebration(
          id: SaintProfileService.idFromTitle(title),
          title: title,
          rank: _rankFromString(liturgicalDay?.rank ?? ''),
          color: liturgicalDay?.color ?? LiturgicalColor.white,
          month: date.month,
          day: date.day,
          commonType: null,
        ),
      );
    }

    return merged.values.toList(growable: false);
  }

  List<OptionalCelebration> _nigeriaObservedSaintCelebrations(DateTime date) {
    final celebrations = <OptionalCelebration>[];

    if (_isMondayAfterPentecost(date)) {
      celebrations.add(
        OptionalCelebration(
          id: 'mary_mother_of_the_church',
          title: 'Mary, Mother of the Church',
          rank: CelebrationRank.obligatoryMemorial,
          color: LiturgicalColor.white,
          month: date.month,
          day: date.day,
          commonType: 'BlessedVirginMary',
        ),
      );
    }

    if (_isSaintBarnabas(date)) {
      celebrations.add(
        const OptionalCelebration(
          id: 'saint_barnabas_apostle',
          title: 'Saint Barnabas, Apostle',
          rank: CelebrationRank.obligatoryMemorial,
          color: LiturgicalColor.red,
          month: 6,
          day: 11,
          commonType: 'Apostles',
        ),
      );
    }

    if (_isImmaculateHeartAfterSacredHeart(date)) {
      celebrations.add(
        OptionalCelebration(
          id: 'immaculate_heart_of_mary',
          title: 'The Immaculate Heart of the Blessed Virgin Mary',
          rank: CelebrationRank.obligatoryMemorial,
          color: LiturgicalColor.white,
          month: date.month,
          day: date.day,
          commonType: 'BlessedVirginMary',
        ),
      );
    }

    return celebrations;
  }

  OptionalCelebration _fromMemorialEntry(
    MemorialFeastEntry entry,
    DateTime date,
  ) {
    return OptionalCelebration(
      id: entry.id,
      title: entry.title,
      rank: _rankFromString(entry.rank),
      color: _colorFromString(entry.color),
      month: int.tryParse(entry.month) ?? date.month,
      day: int.tryParse(entry.day) ?? date.day,
      commonType: entry.commonType.isEmpty ? null : entry.commonType,
    );
  }

  String _dedupeKey(OptionalCelebration celebration) {
    final normalizedTitle = SaintProfileService.normalizeTitle(
      celebration.title,
    );
    return normalizedTitle.isEmpty ? celebration.id : normalizedTitle;
  }

  CelebrationRank _rankFromString(String rank) {
    final normalized = rank.toLowerCase();
    if (normalized.contains('solemnity')) return CelebrationRank.solemnity;
    if (normalized.contains('feast')) return CelebrationRank.feast;
    if (normalized.contains('obligatory')) {
      return CelebrationRank.obligatoryMemorial;
    }
    return CelebrationRank.optionalMemorial;
  }

  LiturgicalColor _colorFromString(String color) {
    switch (color.toLowerCase()) {
      case 'green':
        return LiturgicalColor.green;
      case 'purple':
      case 'violet':
        return LiturgicalColor.purple;
      case 'red':
        return LiturgicalColor.red;
      case 'pink':
      case 'rose':
        return LiturgicalColor.pink;
      case 'gold':
        return LiturgicalColor.gold;
      case 'white':
      default:
        return LiturgicalColor.white;
    }
  }

  bool _isMondayAfterPentecost(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.add(const Duration(days: 50)));
  }

  bool _isSaintBarnabas(DateTime date) {
    return date.weekday != DateTime.sunday && date.month == 6 && date.day == 11;
  }

  bool _isImmaculateHeartAfterSacredHeart(DateTime date) {
    final easter = _calculateEasterSunday(date.year);
    return _isSameDate(date, easter.add(const Duration(days: 69)));
  }

  DateTime _calculateEasterSunday(int year) {
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

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
