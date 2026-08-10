import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/saint_profile.dart';
import '../models/saint_profile_source.dart';
import 'optional_memorial_service.dart';

class SaintProfileService {
  static final SaintProfileService instance = SaintProfileService._();

  SaintProfileService._();

  static const String _assetPath = 'assets/data/saints_profiles.json';

  List<SaintProfile>? _profiles;
  Map<String, SaintProfile>? _byCelebrationId;

  Future<SaintProfile?> findForCelebration(
    OptionalCelebration celebration,
  ) async {
    final curated = await findCuratedForCelebration(celebration);
    if (curated != null) return curated;
    if (!isSaintLikeTitle(celebration.title)) return null;
    return buildFallbackProfile(celebration);
  }

  Future<SaintProfile?> findCuratedForCelebration(
    OptionalCelebration celebration,
  ) async {
    final byId = await _celebrationIndex();
    final directMatch = byId[celebration.id];
    if (directMatch != null) return directMatch;

    final normalizedTitle = normalizeTitle(celebration.title);
    final profiles = await loadProfiles();
    for (final profile in profiles) {
      if (normalizeTitle(profile.name) == normalizedTitle) {
        return profile;
      }
    }
    return null;
  }

  Future<SaintProfile?> findByCelebrationId(String celebrationId) async {
    final byId = await _celebrationIndex();
    return byId[celebrationId];
  }

  SaintProfile buildFallbackProfile(OptionalCelebration celebration) {
    return SaintProfile(
      id: celebration.id,
      celebrationIds: [celebration.id],
      name: cleanDisplayName(celebration.title),
      lifeSpan: '',
      lifeLength: '',
      patronage: const [],
      briefBio:
          'This feast or memorial is included in the app calendar. A fuller '
          'curated biography has not yet been added offline.',
      feastDates: [_formatFeastDate(celebration.month, celebration.day)],
      sources: const [
        SaintSource(
          id: 'catholic-daily-calendar',
          title: 'Catholic Daily calendar',
          authorOrInstitution: 'Catholic Daily',
          publisher: 'Catholic Daily',
          url: null,
          publicationDate: null,
          accessedDate: null,
          tier: SaintSourceTier.discovery,
          reuseBasis: 'Internal calendar identity only',
          supports: ['identity', 'feastDates'],
        ),
      ],
    );
  }

  Future<List<SaintProfile>> loadProfiles() async {
    final cached = _profiles;
    if (cached != null) return cached;

    final source = await rootBundle.loadString(_assetPath);
    final parsed = parseProfiles(source);
    _profiles = parsed;
    _byCelebrationId = null;
    return parsed;
  }

  Future<Map<String, SaintProfile>> _celebrationIndex() async {
    final cached = _byCelebrationId;
    if (cached != null) return cached;

    final map = <String, SaintProfile>{};
    for (final profile in await loadProfiles()) {
      for (final celebrationId in profile.celebrationIds) {
        map[celebrationId] = profile;
      }
    }
    _byCelebrationId = map;
    return map;
  }

  @visibleForTesting
  static List<SaintProfile> parseProfiles(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SaintProfile.fromJson)
        .toList(growable: false);
  }

  static String normalizeTitle(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'\bsaints?\b'), '')
        .replaceAll(RegExp(r'\bsts?\b'), '')
        .replaceAll(RegExp(r'\bpope\b'), '')
        .replaceAll(RegExp(r'\bbishop\b'), '')
        .replaceAll(RegExp(r'\bpriest\b'), '')
        .replaceAll(RegExp(r'\bdoctor of the church\b'), '')
        .replaceAll(RegExp(r'\bvirgin\b'), '')
        .replaceAll(RegExp(r'\bmartyrs?\b'), '')
        .replaceAll(RegExp(r'\breligious\b'), '')
        .replaceAll(RegExp(r'\bdeacon\b'), '')
        .replaceAll(RegExp(r'\band\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  static bool isSaintLikeTitle(String title) {
    final normalized = title.toLowerCase();
    return RegExp(r'\bsaints?\b').hasMatch(normalized) ||
        normalized.contains('our lady') ||
        normalized.contains('blessed virgin mary') ||
        normalized.contains('virgin mary') ||
        normalized.contains('mother of god') ||
        normalized.contains('mother of the church') ||
        normalized.contains('immaculate conception') ||
        normalized.contains('immaculate heart') ||
        normalized.contains('holy innocents') ||
        normalized.contains('holy founders') ||
        normalized.contains('archangels') ||
        normalized.contains('apostle') ||
        normalized.contains('evangelist') ||
        normalized.contains('martyr') ||
        RegExp(r'\bmary\b').hasMatch(normalized);
  }

  static String idFromTitle(String title) {
    final normalized = title
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'saint_profile' : normalized;
  }

  static String cleanDisplayName(String title) {
    return title.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '').trim();
  }

  static String _formatFeastDate(int month, int day) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > names.length || day < 1) return 'Date varies';
    return '${names[month - 1]} $day';
  }
}
