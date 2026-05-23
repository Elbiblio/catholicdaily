import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'base_service.dart';

class LectionaryTextOverrideService
    extends BaseService<LectionaryTextOverrideService> {
  static LectionaryTextOverrideService get instance =>
      BaseService.init(() => LectionaryTextOverrideService._());

  LectionaryTextOverrideService._();

  Map<String, String>? _overrides;
  Map<String, List<String>>? _keysByReferenceAndType;

  Future<String?> lookup({
    required String reference,
    required String? readingType,
    required String? incipit,
  }) async {
    final normalizedIncipit = _normalizeIncipit(incipit);

    final overrides = await _loadOverrides();
    final exact = overrides[_key(reference, readingType, normalizedIncipit)];
    if (exact != null) {
      return exact;
    }

    final fallbackKeys =
        _keysByReferenceAndType?[_referenceTypeKey(reference, readingType)] ??
        const <String>[];
    if (fallbackKeys.length == 1) {
      return overrides[fallbackKeys.first];
    }

    return null;
  }

  Future<Map<String, String>> _loadOverrides() async {
    if (_overrides != null) {
      return _overrides!;
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/data/lectionary_text_overrides.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _overrides = const {};
        return _overrides!;
      }

      final parsed = <String, String>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final map = item.map((key, value) => MapEntry('$key', value));
        final reference = '${map['reference'] ?? ''}'.trim();
        final readingType = '${map['readingType'] ?? ''}'.trim();
        final incipit = _normalizeIncipit('${map['incipit'] ?? ''}');
        final text = '${map['text'] ?? ''}'.trim();
        if (reference.isEmpty || incipit.isEmpty || text.isEmpty) {
          continue;
        }
        final key = _key(reference, readingType, incipit);
        parsed[key] = text;
      }

      _overrides = parsed;
      _keysByReferenceAndType = <String, List<String>>{};
      for (final key in parsed.keys) {
        final parts = key.split('|');
        if (parts.length < 3) continue;
        final referenceTypeKey = '${parts[0]}|${parts[1]}';
        _keysByReferenceAndType!
            .putIfAbsent(referenceTypeKey, () => <String>[])
            .add(key);
      }
      return parsed;
    } catch (e) {
      debugPrint('LectionaryTextOverrideService: failed to load overrides: $e');
      _overrides = const {};
      _keysByReferenceAndType = const <String, List<String>>{};
      return _overrides!;
    }
  }

  String _key(String reference, String? readingType, String normalizedIncipit) {
    return [
      _normalizeReference(reference),
      _normalizeReadingType(readingType),
      normalizedIncipit,
    ].join('|');
  }

  String _referenceTypeKey(String reference, String? readingType) {
    return [
      _normalizeReference(reference),
      _normalizeReadingType(readingType),
    ].join('|');
  }

  String _normalizeReference(String value) {
    return value
        .trim()
        .replaceAll('.', ':')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  String _normalizeReadingType(String? value) {
    final lower = (value ?? '').toLowerCase();
    if (lower.contains('first')) return 'first';
    if (lower.contains('second') || lower.contains('epistle')) return 'second';
    if (lower.contains('gospel')) return 'gospel';
    return lower.trim();
  }

  String _normalizeIncipit(String? value) {
    return (value ?? '')
        .trim()
        .replaceAll(RegExp(r'[,:;.\s]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }
}
