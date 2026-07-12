import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'base_service.dart';

class LocalLectionaryExtractTextService
    extends BaseService<LocalLectionaryExtractTextService> {
  static LocalLectionaryExtractTextService get instance =>
      BaseService.init(() => LocalLectionaryExtractTextService._());

  LocalLectionaryExtractTextService._();

  static const _sourceIndexPath =
      'assets/data/local_lectionary_extract_text_sources.json';

  List<_LocalExtractTextSource>? _sources;
  final Map<String, Future<String?>> _textCache = <String, Future<String?>>{};

  Future<String?> lookup({
    required DateTime date,
    required String regionCode,
    required String bibleVersionId,
    required String reference,
    required String? position,
  }) async {
    final sources = await _loadSources();
    final key = _matchKey(
      date: date,
      regionCode: regionCode,
      bibleVersionId: bibleVersionId,
      reference: reference,
      position: position,
    );

    final match = sources.where((source) => source.matchKey == key).toList();
    if (match.length != 1) {
      return null;
    }

    return _textCache.putIfAbsent(
      match.single.id,
      () => _extractSourceText(match.single),
    );
  }

  Future<List<_LocalExtractTextSource>> _loadSources() async {
    if (_sources != null) return _sources!;

    try {
      final raw = await rootBundle.loadString(_sourceIndexPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _sources = const <_LocalExtractTextSource>[];
        return _sources!;
      }

      _sources = decoded
          .whereType<Map<String, dynamic>>()
          .map(_LocalExtractTextSource.fromJson)
          .toList(growable: false);
      return _sources!;
    } catch (e) {
      debugPrint(
        'LocalLectionaryExtractTextService: failed to load sources: $e',
      );
      _sources = const <_LocalExtractTextSource>[];
      return _sources!;
    }
  }

  static Future<String?> _extractSourceText(
    _LocalExtractTextSource source,
  ) async {
    try {
      final raw = await rootBundle.loadString(source.sourcePath);
      final lines = raw
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .split('\n');
      final start = lines.indexWhere(
        (line) => line.contains(source.startMarker),
      );
      if (start < 0) return null;

      final contentStart = lines.indexWhere(
        (line) => line.contains(source.contentStartMarker),
        start,
      );
      if (contentStart < 0) return null;

      final end = lines.indexWhere(
        (line) => line.contains(source.endMarker),
        contentStart,
      );
      if (end < 0) return null;

      return lines
          .sublist(contentStart, end)
          .where((line) => !_isPaginationLine(line))
          .join('\n')
          .trim();
    } catch (e) {
      debugPrint(
        'LocalLectionaryExtractTextService: failed to extract ${source.id}: $e',
      );
      return null;
    }
  }

  static bool _isPaginationLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    if (RegExp(r'^=+$').hasMatch(trimmed)) return true;
    if (RegExp(r'^PAGE\s+\d+$', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(
      '^\\d+\\s+[A-Z][A-Z\\s]+(?:[-\\u2013]\\s+YEAR\\s+[IVX]+)?\$',
    ).hasMatch(trimmed)) {
      return true;
    }
    if (RegExp(r'^[A-Z]+\s+\d+$').hasMatch(trimmed)) return true;
    return trimmed == '@' ||
        trimmed == '\u00aa' ||
        trimmed == '\u00c2\u00aa' ||
        trimmed == '\u00c3\u201a\u00c2\u00aa';
  }

  static String _matchKey({
    required DateTime date,
    required String regionCode,
    required String bibleVersionId,
    required String reference,
    required String? position,
  }) {
    return [
      _dateKey(date),
      regionCode.trim().toLowerCase(),
      bibleVersionId.trim().toLowerCase(),
      _normalizeReference(reference),
      _normalizePosition(position),
    ].join('|');
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _normalizeReference(String value) {
    return value
        .trim()
        .replaceAll('.', ':')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  static String _normalizePosition(String? value) {
    final lower = (value ?? '').toLowerCase();
    if (lower.contains('psalm')) return 'psalm';
    if (lower.contains('first')) return 'first';
    if (lower.contains('second') || lower.contains('epistle')) return 'second';
    if (lower.contains('gospel')) return 'gospel';
    return lower.trim();
  }
}

class _LocalExtractTextSource {
  final String id;
  final DateTime date;
  final String regionCode;
  final String bibleVersionId;
  final String reference;
  final String position;
  final String sourcePath;
  final String startMarker;
  final String contentStartMarker;
  final String endMarker;

  const _LocalExtractTextSource({
    required this.id,
    required this.date,
    required this.regionCode,
    required this.bibleVersionId,
    required this.reference,
    required this.position,
    required this.sourcePath,
    required this.startMarker,
    required this.contentStartMarker,
    required this.endMarker,
  });

  factory _LocalExtractTextSource.fromJson(Map<String, dynamic> json) {
    return _LocalExtractTextSource(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      regionCode: json['region'] as String,
      bibleVersionId: json['bibleVersion'] as String,
      reference: json['reference'] as String,
      position: json['position'] as String,
      sourcePath: json['sourcePath'] as String,
      startMarker: json['startMarker'] as String,
      contentStartMarker: json['contentStartMarker'] as String,
      endMarker: json['endMarker'] as String,
    );
  }

  String get matchKey => LocalLectionaryExtractTextService._matchKey(
    date: date,
    regionCode: regionCode,
    bibleVersionId: bibleVersionId,
    reference: reference,
    position: position,
  );
}
