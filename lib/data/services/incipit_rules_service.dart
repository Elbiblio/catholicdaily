import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

/// A rule authored from the comparison dataset (`incipit_comparison_dataset.csv`)
/// that overrides the CSV-derived incipit for a specific reading.
///
/// Rules are ONLY authored when ≥2 of 5 external sources (USCCB, Universalis,
/// Vatican, CBCEW, CCCB) agree on the canonical opening. Conflicting cases are
/// left unruled and fall through to the existing CSV pipeline.
class IncipitRule {
  final String ruleId;
  final String matchBookNormalized;
  final int? matchChapter;
  final RegExp? matchOpeningRegex;
  final String failureClass;
  final String transformType;
  final String replacement;
  final String rationale;
  final String sources;
  final String locale;

  const IncipitRule({
    required this.ruleId,
    required this.matchBookNormalized,
    required this.matchChapter,
    required this.matchOpeningRegex,
    required this.failureClass,
    required this.transformType,
    required this.replacement,
    required this.rationale,
    required this.sources,
    required this.locale,
  });
}

class RuleMatch {
  final IncipitRule rule;
  final String transformed;
  const RuleMatch({required this.rule, required this.transformed});
}

/// Loads and indexes `assets/incipit_rules.csv` and matches rules against a
/// reading reference + first verse body.
///
/// Matching semantics:
///   1. Reference is parsed for book + starting chapter.
///   2. Candidate rules = those whose `match_book` normalizes-equal to the
///      reading's book AND (`match_chapter` is empty OR equals the chapter).
///   3. A rule fires if `match_opening_regex` is empty OR matches the first
///      verse body (case-insensitive). First matching rule wins (rules are
///      applied in CSV order).
///
/// Transform types:
///   - `replace_opening` — `replacement` is the entire new first-line. Supports
///     `{VERSE}` placeholder for the original first verse body.
///   - `prefix_inject` — `replacement` is prepended to the first verse body
///     with a ", " separator. E.g. replacement="At that time" + verse="He said…"
///     → "At that time, He said…".
class IncipitRulesService {
  static final IncipitRulesService _instance = IncipitRulesService._();
  factory IncipitRulesService() => _instance;
  IncipitRulesService._();

  List<IncipitRule>? _rules;

  Future<List<IncipitRule>> _load() async {
    if (_rules != null) return _rules!;
    try {
      final raw = await rootBundle.loadString('assets/incipit_rules.csv');
      _rules = _parseCsv(raw);
      debugPrint('Loaded ${_rules!.length} incipit rules');
      return _rules!;
    } catch (e) {
      debugPrint('Failed to load incipit_rules.csv: $e');
      _rules = const [];
      return _rules!;
    }
  }

  /// Extracts the first non-empty verse body from [fullText] (stripping any
  /// leading verse-number prefix like "1. ") and matches rules against it.
  /// Returns null when no rule fires.
  Future<RuleMatch?> matchForText({
    required String reference,
    required String fullText,
    String? locale = 'en',
  }) async {
    final firstVerse = _extractFirstVerseBody(fullText);
    if (firstVerse.isEmpty) return null;
    return match(reference: reference, firstVerse: firstVerse, locale: locale);
  }

  /// Returns a [RuleMatch] if any rule applies; otherwise null.
  /// [locale] defaults to "en". Pass null to match all locales.
  Future<RuleMatch?> match({
    required String reference,
    required String firstVerse,
    String? locale = 'en',
  }) async {
    final rules = await _load();
    if (rules.isEmpty) return null;

    final parsed = _parseReference(reference);
    if (parsed == null) return null;
    final (bookNorm, chapter) = parsed;

    final verseLower = firstVerse.trim();

    for (final r in rules) {
      if (r.matchBookNormalized != bookNorm) continue;
      if (r.matchChapter != null && r.matchChapter != chapter) continue;
      if (locale != null &&
          r.locale.isNotEmpty &&
          !_localeMatches(locale, r.locale)) {
        continue;
      }
      if (r.matchOpeningRegex != null &&
          !r.matchOpeningRegex!.hasMatch(verseLower)) {
        continue;
      }

      final out = _applyTransform(r, verseLower);
      if (out.isEmpty) continue;
      return RuleMatch(rule: r, transformed: out);
    }
    return null;
  }

  String _applyTransform(IncipitRule r, String verseBody) {
    switch (r.transformType) {
      case 'replace_opening':
        return r.replacement.replaceAll('{VERSE}', verseBody);
      case 'prefix_inject':
        final prefix = r.replacement.trim();
        if (prefix.isEmpty) return verseBody;
        final v = verseBody.trim();
        if (v.isEmpty) return prefix;
        return '$prefix, $v';
      default:
        return '';
    }
  }

  /// Test hook: install rules programmatically, bypassing the asset file.
  void debugSetRules(List<IncipitRule> rules) {
    _rules = List.unmodifiable(rules);
  }

  void resetCache() {
    _rules = null;
  }

  bool _localeMatches(String requested, String ruleLocale) {
    final req = requested.toLowerCase().replaceAll('_', '-').trim();
    final rule = ruleLocale.toLowerCase().replaceAll('_', '-').trim();
    if (req == rule) return true;
    if (rule == 'en' && req.startsWith('en-')) return true;
    if (rule == 'fr' && req.startsWith('fr-')) return true;
    return false;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// Returns (normalizedBook, startChapter) or null if unparseable.
  (String, int)? _parseReference(String reference) {
    final m = RegExp(r'^\s*([0-9]?\s*[A-Za-z]+)\s+(\d+)').firstMatch(reference);
    if (m == null) return null;
    final chapter = int.tryParse(m.group(2)!);
    if (chapter == null) return null;
    return (_normalizeBook(m.group(1)!), chapter);
  }

  static String _normalizeBook(String book) {
    final lower = book.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    return _bookAliases[lower] ?? lower;
  }

  // Mirrors BOOK_ALIASES in scripts/active/grammatical_rule_master.py. Keep
  // the two in sync: rules CSV stores the canonical long form.
  static const Map<String, String> _bookAliases = {
    'matt': 'matthew',
    'mt': 'matthew',
    'mk': 'mark',
    'lk': 'luke',
    'jn': 'john',
    'gen': 'genesis',
    'gn': 'genesis',
    'exod': 'exodus',
    'ex': 'exodus',
    'lev': 'leviticus',
    'num': 'numbers',
    'deut': 'deuteronomy',
    'dt': 'deuteronomy',
    'josh': 'joshua',
    'judg': 'judges',
    'jdg': 'judges',
    '1 sam': '1 samuel',
    '2 sam': '2 samuel',
    '1 kgs': '1 kings',
    '2 kgs': '2 kings',
    '1 chr': '1 chronicles',
    '2 chr': '2 chronicles',
    'neh': 'nehemiah',
    'tob': 'tobit',
    'jdt': 'judith',
    'esth': 'esther',
    '1 macc': '1 maccabees',
    '2 macc': '2 maccabees',
    'ps': 'psalm',
    'prov': 'proverbs',
    'eccl': 'ecclesiastes',
    'song': 'song of songs',
    'wis': 'wisdom',
    'sir': 'sirach',
    'isa': 'isaiah',
    'jer': 'jeremiah',
    'lam': 'lamentations',
    'bar': 'baruch',
    'ezek': 'ezekiel',
    'dan': 'daniel',
    'hos': 'hosea',
    'obad': 'obadiah',
    'mic': 'micah',
    'nah': 'nahum',
    'hab': 'habakkuk',
    'zeph': 'zephaniah',
    'hag': 'haggai',
    'zech': 'zechariah',
    'mal': 'malachi',
    'rom': 'romans',
    '1 cor': '1 corinthians',
    '2 cor': '2 corinthians',
    'gal': 'galatians',
    'eph': 'ephesians',
    'phil': 'philippians',
    'col': 'colossians',
    '1 thess': '1 thessalonians',
    '2 thess': '2 thessalonians',
    '1 tim': '1 timothy',
    '2 tim': '2 timothy',
    'philem': 'philemon',
    'heb': 'hebrews',
    'jas': 'james',
    '1 pet': '1 peter',
    '2 pet': '2 peter',
    '1 jn': '1 john',
    '2 jn': '2 john',
    '3 jn': '3 john',
    'rev': 'revelation',
  };

  String _extractFirstVerseBody(String fullText) {
    for (final line in fullText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    }
    return '';
  }

  List<IncipitRule> _parseCsv(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) return const [];

    final out = <IncipitRule>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length < 10) continue;
      try {
        final matchChapterStr = cols[2].trim();
        final openingRegexStr = cols[3].trim();
        out.add(
          IncipitRule(
            ruleId: cols[0].trim(),
            matchBookNormalized: _normalizeBook(cols[1]),
            matchChapter: matchChapterStr.isEmpty
                ? null
                : int.tryParse(matchChapterStr),
            matchOpeningRegex: openingRegexStr.isEmpty
                ? null
                : RegExp(openingRegexStr, caseSensitive: false),
            failureClass: cols[4].trim(),
            transformType: cols[5].trim(),
            replacement: cols[6],
            rationale: cols[7].trim(),
            sources: cols[8].trim(),
            locale: cols[9].trim().isEmpty ? 'en' : cols[9].trim(),
          ),
        );
      } catch (e) {
        debugPrint('Skipping malformed incipit rule at line $i: $e');
      }
    }
    return List.unmodifiable(out);
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char == ',' && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    values.add(buffer.toString());
    return values;
  }
}
