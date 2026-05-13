import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'incipit_rules_service.dart';
import 'reading_reference_parser.dart';

class IncipitDecision {
  final String opening;
  final String operation;
  final String joinStyle;
  final String locale;
  final double confidence;
  final List<String> sourceIds;
  final List<String> rejectedAlternatives;
  final List<String> warnings;

  const IncipitDecision({
    required this.opening,
    required this.operation,
    required this.joinStyle,
    required this.locale,
    required this.confidence,
    required this.sourceIds,
    this.rejectedAlternatives = const [],
    required this.warnings,
  });

  bool get usesOpening => opening.trim().isNotEmpty && operation != 'rawText';

  String get auditRow {
    final fields = [
      locale,
      operation,
      confidence.toStringAsFixed(2),
      joinStyle,
      sourceIds.join('|'),
      rejectedAlternatives.join('|'),
      warnings.join('|'),
      opening.replaceAll('\n', ' '),
    ];
    return fields.map(_auditCell).join(',');
  }

  static String _auditCell(String value) {
    if (!RegExp(r'[,"\r\n]').hasMatch(value)) return value;
    return '"${value.replaceAll('"', '""')}"';
  }
}

class IncipitDecisionService {
  static final IncipitDecisionService _instance = IncipitDecisionService._();
  factory IncipitDecisionService() => _instance;
  IncipitDecisionService._();

  final IncipitRulesService _rules = IncipitRulesService();
  List<_IncipitEvidence>? _evidence;

  Future<IncipitDecision> decide({
    required String reference,
    required String fullText,
    String? csvIncipit,
    String? locale,
    String? readingType,
  }) async {
    final effectiveLocale = _normalizeLocale(locale);
    final parsed = _parseReading(reference, readingType);
    final firstVerse = _extractFirstVerseBody(fullText);
    final rejected = <String>[];

    if (parsed == null || firstVerse.isEmpty) {
      return _raw(
        locale: effectiveLocale,
        warnings: const ['unparseable_reference_or_empty_text'],
      );
    }

    final evidenceDecision = await _fromSourceEvidence(
      parsed: parsed,
      firstVerse: firstVerse,
      locale: effectiveLocale,
    );
    if (evidenceDecision != null) {
      return evidenceDecision;
    }

    final ruleDecision = await _fromLegacyRule(
      parsed: parsed,
      reference: reference,
      fullText: fullText,
      firstVerse: firstVerse,
      locale: effectiveLocale,
      rejected: rejected,
    );
    if (ruleDecision != null) return ruleDecision;

    final csvDecision = _fromCsvIncipit(
      parsed: parsed,
      firstVerse: firstVerse,
      csvIncipit: csvIncipit,
      locale: effectiveLocale,
      rejected: rejected,
    );
    if (csvDecision != null) return csvDecision;

    final generatedDecision = _generatedFallback(
      parsed: parsed,
      firstVerse: firstVerse,
      locale: effectiveLocale,
      rejected: rejected,
    );
    if (generatedDecision != null) return generatedDecision;

    return _raw(
      locale: effectiveLocale,
      warnings: ['low_confidence_no_incipit_generated', ...rejected],
    );
  }

  Future<List<_IncipitEvidence>> _loadEvidence() async {
    if (_evidence != null) return _evidence!;
    try {
      final raw = await rootBundle.loadString('assets/incipit_evidence.csv');
      _evidence = _parseEvidenceCsv(raw);
      return _evidence!;
    } catch (e) {
      debugPrint('Failed to load incipit_evidence.csv: $e');
      _evidence = const [];
      return _evidence!;
    }
  }

  Future<IncipitDecision?> _fromSourceEvidence({
    required _ParsedReading parsed,
    required String firstVerse,
    required String locale,
  }) async {
    final all = await _loadEvidence();
    if (all.isEmpty) return null;

    final candidates = all.where((e) {
      if (e.bookKey != parsed.bookKey) return false;
      if (e.chapter != parsed.chapter) return false;
      if (e.startVerse != parsed.startVerse) return false;
      if (!_readingTypesCompatible(e.readingType, parsed.readingType)) {
        return false;
      }
      if (!_localeCompatible(locale, e.localeProfile)) return false;
      if (e.firstVerseFingerprint.isNotEmpty &&
          _tokenOverlapRatio(firstVerse, e.firstVerseFingerprint) < 0.45) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aScore = _evidenceScore(a, locale);
      final bScore = _evidenceScore(b, locale);
      return bScore.compareTo(aScore);
    });

    final chosen = candidates.first;
    final warnings = <String>[];
    if (chosen.operation != 'rawText') {
      final validation = _validateOpening(
        parsed: parsed,
        firstVerse: firstVerse,
        opening: chosen.opening,
        evidenceId: chosen.sourceId,
      );
      if (!validation.accepted) {
        return _raw(
          locale: locale,
          warnings: [
            'source_evidence_rejected:${chosen.sourceId}',
            ...validation.warnings,
          ],
        );
      }
      warnings.addAll(validation.warnings);
    }

    return IncipitDecision(
      opening: chosen.opening,
      operation: chosen.operation,
      joinStyle: chosen.joinStyle,
      locale: locale,
      confidence: chosen.confidence,
      sourceIds: [chosen.sourceId],
      rejectedAlternatives: const [],
      warnings: warnings,
    );
  }

  Future<IncipitDecision?> _fromLegacyRule({
    required _ParsedReading parsed,
    required String reference,
    required String fullText,
    required String firstVerse,
    required String locale,
    required List<String> rejected,
  }) async {
    final match = await _rules.matchForText(
      reference: reference,
      fullText: fullText,
      locale: locale,
    );
    if (match == null) return null;

    final validation = _validateOpening(
      parsed: parsed,
      firstVerse: firstVerse,
      opening: match.transformed,
      evidenceId: match.rule.ruleId,
      legacyRule: true,
    );

    if (!validation.accepted) {
      rejected.add('legacy_rule_quarantined:${match.rule.ruleId}');
      rejected.addAll(validation.warnings);
      return null;
    }

    return IncipitDecision(
      opening: _sentenceCaseLectionaryOpening(match.transformed),
      operation: 'verifiedRule',
      joinStyle: _inferJoinStyle(match.transformed, parsed),
      locale: locale,
      confidence: 0.82,
      sourceIds: [match.rule.ruleId, match.rule.sources],
      rejectedAlternatives: List.unmodifiable(rejected),
      warnings: validation.warnings,
    );
  }

  IncipitDecision? _fromCsvIncipit({
    required _ParsedReading parsed,
    required String firstVerse,
    required String? csvIncipit,
    required String locale,
    required List<String> rejected,
  }) {
    final cleaned = _normalizeCsvIncipit(csvIncipit);
    if (cleaned == null) return null;

    final validation = _validateOpening(
      parsed: parsed,
      firstVerse: firstVerse,
      opening: cleaned,
      evidenceId: 'csv_incipit',
    );
    if (!validation.accepted) {
      rejected.add('csv_incipit_rejected');
      rejected.addAll(validation.warnings);
      return null;
    }

    return IncipitDecision(
      opening: cleaned,
      operation: 'cleanedCsvIncipit',
      joinStyle: _inferJoinStyle(cleaned, parsed),
      locale: locale,
      confidence: 0.64,
      sourceIds: const ['csv_incipit'],
      rejectedAlternatives: List.unmodifiable(rejected),
      warnings: validation.warnings,
    );
  }

  IncipitDecision? _generatedFallback({
    required _ParsedReading parsed,
    required String firstVerse,
    required String locale,
    required List<String> rejected,
  }) {
    final letterOpening = _letterFormula(parsed, firstVerse);
    if (letterOpening != null) {
      final validation = _validateOpening(
        parsed: parsed,
        firstVerse: firstVerse,
        opening: letterOpening,
        evidenceId: 'generated_letter_formula',
      );
      if (validation.accepted) {
        return IncipitDecision(
          opening: letterOpening,
          operation: 'generatedFallback',
          joinStyle: 'colon',
          locale: locale,
          confidence: 0.50,
          sourceIds: const ['generated_letter_formula'],
          rejectedAlternatives: List.unmodifiable(rejected),
          warnings: validation.warnings,
        );
      }
      rejected.add('generated_letter_formula_rejected');
      rejected.addAll(validation.warnings);
    }

    final propheticOpening = _propheticFormula(firstVerse, parsed);
    if (propheticOpening != null) {
      final validation = _validateOpening(
        parsed: parsed,
        firstVerse: firstVerse,
        opening: propheticOpening,
        evidenceId: 'generated_prophetic_formula',
      );
      if (validation.accepted) {
        return IncipitDecision(
          opening: propheticOpening,
          operation: 'generatedFallback',
          joinStyle: 'colon',
          locale: locale,
          confidence: 0.52,
          sourceIds: const ['generated_prophetic_formula'],
          rejectedAlternatives: List.unmodifiable(rejected),
          warnings: validation.warnings,
        );
      }
      rejected.add('generated_prophetic_formula_rejected');
      rejected.addAll(validation.warnings);
    }

    final stripped = _stripVerseAndLeadingConjunction(firstVerse);
    if (stripped == firstVerse.trim()) return null;
    if (!_startsWithNamedSubject(stripped)) return null;
    if (_startsWithPronoun(stripped)) return null;

    final validation = _validateOpening(
      parsed: parsed,
      firstVerse: firstVerse,
      opening: stripped,
      evidenceId: 'generated_conjunction_cleanup',
    );
    if (!validation.accepted) {
      rejected.add('generated_cleanup_rejected');
      rejected.addAll(validation.warnings);
      return null;
    }

    return IncipitDecision(
      opening: stripped,
      operation: 'generatedFallback',
      joinStyle: 'comma',
      locale: locale,
      confidence: 0.45,
      sourceIds: const ['generated_conjunction_cleanup'],
      rejectedAlternatives: List.unmodifiable(rejected),
      warnings: validation.warnings,
    );
  }

  String? _letterFormula(_ParsedReading parsed, String firstVerse) {
    if (parsed.readingType != 'second_reading') return null;
    if (_firstClauseAlreadyHasLetterAddress(firstVerse)) return null;
    if (_paulineBooks.contains(parsed.bookKey)) return 'Brethren';
    if (_catholicEpistles.contains(parsed.bookKey)) return 'Beloved';
    return null;
  }

  bool _firstClauseAlreadyHasLetterAddress(String firstVerse) {
    final firstWords = _normalizeText(
      firstVerse,
    ).split(' ').where((word) => word.isNotEmpty).take(10).join(' ');
    return firstWords.startsWith('beloved') ||
        firstWords.startsWith('brethren') ||
        firstWords.startsWith('brothers and sisters') ||
        RegExp(r'\b(?:brethren|beloved)\b').hasMatch(firstWords) ||
        firstWords.contains('brothers and sisters');
  }

  String? _propheticFormula(String firstVerse, _ParsedReading parsed) {
    if (!_propheticBooks.contains(parsed.bookKey)) return null;
    final stripped = firstVerse
        .replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '')
        .replaceFirst(
          RegExp(r'^(?:for|and|but|now|then)\s+', caseSensitive: false),
          '',
        )
        .trim();
    final match = RegExp(
      r'^(thus says the (?:Lord|LORD)(?:\s+God| GOD)?)\b',
      caseSensitive: false,
    ).firstMatch(stripped);
    if (match == null) return null;
    return match
        .group(1)!
        .replaceFirst(RegExp(r'\bLord\b'), 'LORD')
        .replaceFirst(RegExp(r'\bGod\b'), 'GOD');
  }

  IncipitDecision _raw({
    required String locale,
    required List<String> warnings,
  }) {
    return IncipitDecision(
      opening: '',
      operation: 'rawText',
      joinStyle: 'none',
      locale: locale,
      confidence: 0,
      sourceIds: const ['raw_text'],
      rejectedAlternatives: const [],
      warnings: List.unmodifiable(warnings),
    );
  }

  _ValidationResult _validateOpening({
    required _ParsedReading parsed,
    required String firstVerse,
    required String opening,
    required String evidenceId,
    bool legacyRule = false,
  }) {
    final warnings = <String>[];
    final trimmed = opening.trim();
    if (trimmed.isEmpty) {
      return const _ValidationResult(false, ['empty_opening']);
    }

    final lower = _normalizeText(trimmed);
    final firstLower = _normalizeText(firstVerse);

    if (_knownContaminatedEvidenceIds.contains(evidenceId)) {
      warnings.add('known_contaminated_evidence');
      return _ValidationResult(false, warnings);
    }
    if (RegExp(r'(^|\s)\d+[a-z]?\.\s').hasMatch(trimmed)) {
      warnings.add('verse_number_leakage');
      return _ValidationResult(false, warnings);
    }
    if (_containsBoilerplate(lower)) {
      warnings.add('boilerplate_or_acclamation_contamination');
      return _ValidationResult(false, warnings);
    }
    if (_hasDoubledFormula(lower)) {
      warnings.add('doubled_formula');
      return _ValidationResult(false, warnings);
    }
    if (_hasUnresolvedPronounAfterFormula(lower)) {
      warnings.add('unresolved_pronoun_after_formula');
      return _ValidationResult(false, warnings);
    }
    if (lower.startsWith('at that time') && parsed.readingType != 'gospel') {
      warnings.add('gospel_formula_on_non_gospel');
      return _ValidationResult(false, warnings);
    }
    if ((lower.startsWith('brethren') ||
            lower.startsWith('brothers and sisters') ||
            lower.startsWith('beloved')) &&
        parsed.readingType == 'gospel') {
      warnings.add('letter_formula_on_gospel');
      return _ValidationResult(false, warnings);
    }
    if (lower.startsWith('jesus said') && parsed.bookKey == 'acts') {
      warnings.add('jesus_speaker_on_acts_reading');
      return _ValidationResult(false, warnings);
    }
    if (lower.contains('nicodemus') && parsed.bookKey != 'john') {
      warnings.add('unrelated_book_wording_nicodemus');
      return _ValidationResult(false, warnings);
    }
    if (parsed.bookKey == 'acts' &&
        firstLower.contains('saul') &&
        lower.startsWith('jesus')) {
      warnings.add('wrong_speaker_risk_saul_context');
      return _ValidationResult(false, warnings);
    }
    if (legacyRule &&
        lower.startsWith('jesus') &&
        parsed.readingType != 'gospel' &&
        !firstLower.contains('jesus')) {
      warnings.add('legacy_rule_speaker_not_supported_by_context');
      return _ValidationResult(false, warnings);
    }

    return _ValidationResult(true, warnings);
  }

  _ParsedReading? _parseReading(String reference, String? readingType) {
    final ranges = ReadingReferenceParser.parse(reference);
    if (ranges.isEmpty) return null;
    final first = ranges.first;
    final bookKey = _normalizeBook(first.book);
    return _ParsedReading(
      reference: reference,
      book: first.book,
      bookKey: bookKey,
      chapter: first.startChapter,
      startVerse: first.startVerse,
      readingType: _normalizeReadingType(readingType, bookKey),
    );
  }

  String _extractFirstVerseBody(String fullText) {
    for (final line in fullText.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed
          .replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '')
          .replaceFirst(RegExp(r'^\d+[a-z]?\s+'), '')
          .trim();
    }
    return '';
  }

  String? _normalizeCsvIncipit(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;

    value = value.replaceFirstMapped(
      RegExp(r'^(.+?:\s*)\d+[a-z]?\.\s*(.*)$', dotAll: true),
      (m) => '${m.group(1)!}${m.group(2)!}',
    );
    value = value.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    value = _sentenceCaseLectionaryOpening(value);
    return value.isEmpty ? null : value;
  }

  String _sentenceCaseLectionaryOpening(String value) {
    var result = value.trim();
    final replacements = <String, String>{
      'AT THAT TIME': 'At that time',
      'IN THOSE DAYS': 'In those days',
      'JESUS': 'Jesus',
      'MOSES': 'Moses',
      'PETER': 'Peter',
      'PAUL': 'Paul',
      'SAUL': 'Saul',
      'BRETHREN': 'Brethren',
      'BELOVED': 'Beloved',
      'THUS SAYS THE LORD': 'Thus says the LORD',
      'THE LORD': 'The LORD',
      'WHEN': 'When',
      'NOW': 'Now',
      'ON': 'On',
      'THEN': 'Then',
      'BEFORE': 'Before',
      'AFTER': 'After',
    };
    for (final entry in replacements.entries) {
      result = result.replaceFirst(
        RegExp('^${RegExp.escape(entry.key)}\\b'),
        entry.value,
      );
    }
    return result;
  }

  String _inferJoinStyle(String opening, _ParsedReading parsed) {
    final lower = _normalizeText(opening);
    if (lower.startsWith('at that time jesus said') ||
        lower.startsWith('at that time jesus told') ||
        lower.startsWith('at that time jesus spoke')) {
      return 'comma';
    }
    if (lower.startsWith('in those days')) return 'colon';
    if (lower.startsWith('thus says')) return 'colon';
    if (lower.startsWith('brethren') ||
        lower.startsWith('brothers and sisters') ||
        lower.startsWith('beloved')) {
      return 'colon';
    }
    if (lower.contains(' said') ||
        lower.contains(' spoke') ||
        lower.contains(' told') ||
        lower.contains(' saying')) {
      return 'colon';
    }
    return parsed.readingType == 'gospel' ? 'comma' : 'auto';
  }

  bool _readingTypesCompatible(String evidence, String actual) {
    if (evidence.isEmpty || evidence == 'any') return true;
    return evidence == actual;
  }

  double _evidenceScore(_IncipitEvidence evidence, String locale) {
    final localeScore = _localeScore(locale, evidence.localeProfile);
    final operationScore = evidence.operation == 'rawText' ? 2.0 : 3.0;
    return operationScore + localeScore + evidence.confidence;
  }

  bool _localeCompatible(String requested, String profile) {
    if (profile.isEmpty || profile == 'all') return true;
    if (requested == profile) return true;
    if (requested == 'en' && profile == 'en') return true;
    if (requested.startsWith('en-NG') && profile == 'en-JB-general') {
      return true;
    }
    if (requested == 'en-JB-general' && profile.startsWith('en-NG')) {
      return true;
    }
    final requestedBase = requested.split('-').first;
    final profileBase = profile.split('-').first;
    return profile == requestedBase ||
        requestedBase == profileBase && profile == 'en';
  }

  double _localeScore(String requested, String profile) {
    if (requested == profile) return 2.0;
    if (profile == 'en' && requested.startsWith('en')) return 1.0;
    if (_localeCompatible(requested, profile)) return 0.75;
    return 0.0;
  }

  String _normalizeLocale(String? locale) {
    final value = (locale == null || locale.trim().isEmpty)
        ? 'en'
        : locale.trim().replaceAll('_', '-');
    final parts = value.split('-');
    if (parts.length == 1) return parts.first.toLowerCase();
    final language = parts.first.toLowerCase();
    final region = parts[1].toUpperCase();
    if (parts.length == 2) return '$language-$region';
    final rest = parts.skip(2).map((p) => p.toLowerCase()).join('-');
    return '$language-$region-$rest';
  }

  String _normalizeReadingType(String? readingType, String bookKey) {
    final value = (readingType ?? '').toLowerCase();
    if (value.contains('gospel')) return 'gospel';
    if (value.contains('second')) return 'second_reading';
    if (value.contains('first')) return 'first_reading';
    if (_gospels.contains(bookKey)) return 'gospel';
    if (_paulineBooks.contains(bookKey) ||
        _catholicEpistles.contains(bookKey) ||
        bookKey == 'revelation') {
      return 'second_reading';
    }
    return 'first_reading';
  }

  String _normalizeBook(String book) {
    final lower = ReadingReferenceParser.normalizeBookKey(book);
    return _bookAliases[lower] ?? lower;
  }

  String _stripVerseAndLeadingConjunction(String value) {
    var result = value.trim();
    result = result.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    result = result.replaceFirst(
      RegExp(
        r'^(?:and|but|now|then|so|for|therefore|moreover|again)\s+',
        caseSensitive: false,
      ),
      '',
    );
    if (result.isNotEmpty &&
        !RegExp(r'''^["'\u201C]''').hasMatch(result) &&
        result[0].toLowerCase() == result[0]) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    return result.trim();
  }

  bool _startsWithNamedSubject(String value) {
    return RegExp(
      r'^(Jesus|Saul|Paul|Peter|John|Moses|Samuel|David|Solomon|Elijah|Elisha|Isaiah|Jeremiah|Ezekiel|Daniel|The LORD|The Lord|The angel|The apostles|The disciples)\b',
    ).hasMatch(value.trim());
  }

  bool _startsWithPronoun(String value) {
    return RegExp(
      r'^(?:he|she|they|it|him|her|them)\b',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  bool _containsBoilerplate(String normalized) {
    const rejected = [
      'a reading from',
      'the word of the lord',
      'thanks be to god',
      'the gospel of the lord',
      'praise to you lord jesus christ',
      'alleluia',
      'gospel acclamation',
      'responsorial psalm',
    ];
    return rejected.any(normalized.contains);
  }

  bool _hasDoubledFormula(String normalized) {
    for (final formula in _formulaOpeners) {
      final matches = RegExp(
        '\\b${RegExp.escape(formula)}\\b',
      ).allMatches(normalized).length;
      if (matches > 1) return true;
    }
    return false;
  }

  bool _hasUnresolvedPronounAfterFormula(String normalized) {
    return RegExp(
      r'^(?:at that time|in those days|on that day)\s*(?::|,)?\s*(?:he|she|they|it|him|her|them)\b',
    ).hasMatch(normalized);
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenOverlapRatio(String a, String b) {
    final aw = RegExp(
      r'\w+',
    ).allMatches(_normalizeText(a)).map((m) => m.group(0)!).toSet();
    final bw = RegExp(
      r'\w+',
    ).allMatches(_normalizeText(b)).map((m) => m.group(0)!).toSet();
    if (aw.isEmpty || bw.isEmpty) return 0;
    return aw.intersection(bw).length / bw.length;
  }

  List<_IncipitEvidence> _parseEvidenceCsv(String raw) {
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= 1) return const [];

    final out = <_IncipitEvidence>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length < 15) continue;
      final chapter = int.tryParse(cols[3].trim());
      final startVerse = int.tryParse(cols[4].trim());
      final confidence = double.tryParse(cols[12].trim()) ?? 0;
      if (chapter == null || startVerse == null) continue;
      out.add(
        _IncipitEvidence(
          sourceId: cols[0].trim(),
          reference: cols[1].trim(),
          bookKey: _normalizeBook(cols[2].trim()),
          chapter: chapter,
          startVerse: startVerse,
          readingType: cols[5].trim(),
          localeProfile: cols[6].trim(),
          calendarScope: cols[7].trim(),
          translationFamily: cols[8].trim(),
          opening: cols[9].trim(),
          operation: cols[10].trim(),
          joinStyle: cols[11].trim().isEmpty ? 'auto' : cols[11].trim(),
          confidence: confidence,
          firstVerseFingerprint: cols[13].trim(),
          notes: cols[14].trim(),
        ),
      );
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

class _ParsedReading {
  final String reference;
  final String book;
  final String bookKey;
  final int chapter;
  final int startVerse;
  final String readingType;

  const _ParsedReading({
    required this.reference,
    required this.book,
    required this.bookKey,
    required this.chapter,
    required this.startVerse,
    required this.readingType,
  });
}

class _IncipitEvidence {
  final String sourceId;
  final String reference;
  final String bookKey;
  final int chapter;
  final int startVerse;
  final String readingType;
  final String localeProfile;
  final String calendarScope;
  final String translationFamily;
  final String opening;
  final String operation;
  final String joinStyle;
  final double confidence;
  final String firstVerseFingerprint;
  final String notes;

  const _IncipitEvidence({
    required this.sourceId,
    required this.reference,
    required this.bookKey,
    required this.chapter,
    required this.startVerse,
    required this.readingType,
    required this.localeProfile,
    required this.calendarScope,
    required this.translationFamily,
    required this.opening,
    required this.operation,
    required this.joinStyle,
    required this.confidence,
    required this.firstVerseFingerprint,
    required this.notes,
  });
}

class _ValidationResult {
  final bool accepted;
  final List<String> warnings;

  const _ValidationResult(this.accepted, this.warnings);
}

const Set<String> _knownContaminatedEvidenceIds = {'gt_081'};

const Set<String> _gospels = {'matthew', 'mark', 'luke', 'john'};

const Set<String> _paulineBooks = {
  'romans',
  '1 corinthians',
  '2 corinthians',
  'galatians',
  'ephesians',
  'philippians',
  'colossians',
  '1 thessalonians',
  '2 thessalonians',
  '1 timothy',
  '2 timothy',
  'titus',
  'philemon',
  'hebrews',
};

const Set<String> _catholicEpistles = {
  'james',
  '1 peter',
  '2 peter',
  '1 john',
  '2 john',
  '3 john',
  'jude',
};

const Set<String> _propheticBooks = {
  'isaiah',
  'jeremiah',
  'lamentations',
  'baruch',
  'ezekiel',
  'daniel',
  'hosea',
  'joel',
  'amos',
  'obadiah',
  'jonah',
  'micah',
  'nahum',
  'habakkuk',
  'zephaniah',
  'haggai',
  'zechariah',
  'malachi',
};

const List<String> _formulaOpeners = [
  'at that time',
  'in those days',
  'on that day',
  'thus says the lord',
  'brothers and sisters',
  'brethren',
  'beloved',
];

const Map<String, String> _bookAliases = {
  'matt': 'matthew',
  'mt': 'matthew',
  'mk': 'mark',
  'lk': 'luke',
  'jn': 'john',
  'acts of apostles': 'acts',
  'acts': 'acts',
  'act': 'acts',
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
  'apocalypse': 'revelation',
  'gen': 'genesis',
  'gn': 'genesis',
  'exod': 'exodus',
  'ex': 'exodus',
  'deut': 'deuteronomy',
  'dt': 'deuteronomy',
  '1 sam': '1 samuel',
  '2 sam': '2 samuel',
  '1 kgs': '1 kings',
  '2 kgs': '2 kings',
  '1 chr': '1 chronicles',
  '2 chr': '2 chronicles',
  'isa': 'isaiah',
  'jer': 'jeremiah',
  'ezek': 'ezekiel',
  'hos': 'hosea',
  'mic': 'micah',
  'zeph': 'zephaniah',
  'zech': 'zechariah',
  'mal': 'malachi',
  'wis': 'wisdom',
  'sir': 'sirach',
};
