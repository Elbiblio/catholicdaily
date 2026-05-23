import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/saint_profile.dart';
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

  @visibleForTesting
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
}
