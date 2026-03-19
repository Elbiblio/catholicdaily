/// Intelligent Text Refinement Service
///
/// Provides regex-based text cleaning for biblical readings.
/// Handles two categories of structural redundancy:
///
///   1. Redundant introductory temporal phrases
///      "In those days: That same night the word came…"
///      → "In those days: the word came…"
///
///   2. Repeated prophetic formulae with embedded instructions
///      "Thus says the LORD GOD: O my people… Prophesy, and say to them,
///       Thus says the LORD GOD: Behold…"
///      → "Thus says the LORD GOD: Behold…"
///
/// Gospel pronoun correction ("He said…" → "Jesus said…") is intentionally
/// NOT handled here — that responsibility belongs to
/// [OfficialLectionaryIncipitService._applyGospelPronounCorrections], which
/// has the full verb-list and verse-prefix logic.
class IntelligentTextRefinementService {
  static final IntelligentTextRefinementService _instance =
      IntelligentTextRefinementService._internal();
  factory IntelligentTextRefinementService() => _instance;
  IntelligentTextRefinementService._internal();

  // ── Instruction keywords that appear between two repeated formulae ─────────
  // When found between two occurrences of the same prophetic formula, the
  // first occurrence (plus the instruction clause) is stripped, leaving only
  // the second.
  static const List<String> _instructionKeywords = [
    'prophesy',
    'say to them',
    'and say to them',
    'speak to',
    'tell the house',
    'tell the people',
    'command',
    'commanded',
  ];

  static final List<_RepeatedSayingRule> _repeatedSayingRules = [
    _buildRepeatedSayingRule('Thus says the LORD GOD'),
    _buildRepeatedSayingRule('Thus says the Lord'),
    _buildRepeatedSayingRule('Thus saith the LORD GOD'),
    _buildRepeatedSayingRule('The word of the LORD came to me'),
    _buildRepeatedSayingRule('The word of the Lord came to me'),
    _buildRepeatedSayingRule('Hear the word of the LORD'),
    _buildRepeatedSayingRule('Hear the word of the Lord'),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════════════════

  /// Main entry point.  Applies cleaning transformations in order:
  ///   1. Remove redundant introductory temporal phrases
  ///   2. Collapse repeated prophetic formulae
  String refineReadingText(String text) {
    if (text.isEmpty) return text;

    // Only examine the first 200 characters for pattern detection — the
    // redundancies we target always appear at the very start of a reading.
    final preview = text.length > 200 ? text.substring(0, 200) : text;

    String refined = _removeRedundantIntroductoryPhrases(text, preview);
    refined = _removeRepeatedSayings(refined, refined.length > 200 ? refined.substring(0, 200) : refined);
    return refined;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Stage 1 — Redundant introductory temporal phrases
  // ══════════════════════════════════════════════════════════════════════════

  /// Strips leading temporal sub-phrases that duplicate (or are implied by)
  /// a liturgical incipit that will be prepended externally.
  ///
  /// Patterns applied in order of decreasing specificity:
  ///
  ///   1. "In those days: Now that [same] night…"
  ///      → "In those days: …"
  ///   2. "In those days: That [same] night…"
  ///      → "In those days: …"
  ///   3. "In those days: In those days…"  (exact-phrase repetition)
  ///      → "In those days: …"
  ///   4. "In those days: Then in those days…"
  ///      → "In those days: …"
  ///   5. "Now in those days…" / "Now that [same] night…"
  ///      → ∅  (entire leading phrase removed)
  ///   6. "That [same/very] night/day/morning/…"
  ///      → ∅  (standalone temporal phrase removed)
  String _removeRedundantIntroductoryPhrases(String fullText, String preview) {
    // ── Pattern 1: "In those days: Now that [same] night/day/…" ─────────────
    final complexCombinedPattern = RegExp(
      r'^\s*((?:In those days|At that time|In that time)[,:.]\s*)Now\s+that\s+(?:same\s+|very\s+)?(night|day|morning|evening|afternoon|time|hour|moment)[,:.]?\s*',
      caseSensitive: false,
    );

    // ── Pattern 2: "In those days: That [same/very] night/day/…" ────────────
    final combinedTemporalPattern = RegExp(
      r'^\s*((?:In those days|At that time|In that time)[,:.]\s*)(?:that|this)\s+(?:same\s+|very\s+)?(night|day|morning|evening|afternoon|time|hour|moment)[,:.]?\s*',
      caseSensitive: false,
    );

    // ── Pattern 3: "In those days: In those days / At that time" ────────────
    final redundantInThoseDaysPattern = RegExp(
      r'^\s*((?:In those days|At that time)[,:.]\s*)(?:in those days|at that time|on that day|that night|that day)[,:.]?\s*',
      caseSensitive: false,
    );

    // ── Pattern 4: "In those days: Then in those days / At that time" ────────
    final sequentialTemporalPattern = RegExp(
      r'^\s*((?:In those days|At that time|On that day)[,:.]\s*)(?:then\s+)?(?:in those days|at that time|on that day)[,:.]?\s*',
      caseSensitive: false,
    );

    // ── Pattern 5: Leading "Now …" temporal phrase ────────────────────────────
    // Covers "Now in those days", "Now at that time", "Now that same night", etc.
    final nowTemporalPattern = RegExp(
      r'^\s*Now\s+(?:in those days|at that time|on that day|(?:that|this)\s+(?:same\s+|very\s+)?(?:night|day|morning|evening|afternoon|time|hour|moment))[,: .]?\s*',
      caseSensitive: false,
    );

    // ── Pattern 6: Bare temporal phrase — "That [same/very] night/day/…" ─────
    // This is the primary fix for cases like "That same night the word of the
    // LORD came to Nathan…" when prepended by "In those days,".
    final simpleTemporalPattern = RegExp(
      r'^\s*(?:that|this)\s+(?:same\s+|very\s+)?(night|day|morning|evening|afternoon|time|hour|moment)\s*[,:.]?\s*',
      caseSensitive: false,
    );

    // Apply in order of specificity — most specific first.
    if (complexCombinedPattern.hasMatch(preview)) {
      return fullText.replaceFirstMapped(complexCombinedPattern, (m) => m.group(1)!);
    }
    if (combinedTemporalPattern.hasMatch(preview)) {
      return fullText.replaceFirstMapped(combinedTemporalPattern, (m) => m.group(1)!);
    }
    if (redundantInThoseDaysPattern.hasMatch(preview)) {
      return fullText.replaceFirstMapped(redundantInThoseDaysPattern, (m) => m.group(1)!);
    }
    if (sequentialTemporalPattern.hasMatch(preview)) {
      return fullText.replaceFirstMapped(sequentialTemporalPattern, (m) => m.group(1)!);
    }
    if (nowTemporalPattern.hasMatch(preview)) {
      return fullText.replaceFirst(nowTemporalPattern, '');
    }
    if (simpleTemporalPattern.hasMatch(preview)) {
      return fullText.replaceFirst(simpleTemporalPattern, '');
    }

    return fullText;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Stage 2 — Repeated prophetic formulae
  // ══════════════════════════════════════════════════════════════════════════

  /// Collapses duplicate prophetic formulae such as:
  ///
  ///   "Thus says the LORD GOD: O my people, I will open your graves:
  ///    Prophesy, and say to them: Thus says the LORD GOD: Behold…"
  ///   → "Thus says the LORD GOD: Behold…"
  ///
  /// Two sub-cases:
  ///   A. Two occurrences with an instruction keyword between them (e.g.
  ///      "prophesy", "say to them") — strip everything before the second
  ///      occurrence.
  ///   B. Immediate back-to-back repetition with only punctuation between —
  ///      replace both with a single normalised form.
  String _removeRepeatedSayings(String fullText, String preview) {
    for (final rule in _repeatedSayingRules) {
      final matches = rule.pattern.allMatches(preview).toList();

      if (matches.length >= 2) {
        final first = matches.first;
        final second = matches[1];
        final between = preview.substring(first.end, second.start).toLowerCase();

        // Sub-case A: instruction keyword between the two formulae.
        final containsInstruction = _instructionKeywords.any(
          (kw) => between.contains(kw.toLowerCase()),
        );
        if (containsInstruction) {
          return fullText.substring(second.start).trimLeft();
        }

        // Sub-case B: no instruction — keep the first formula, strip only
        // what lies between the first formula's end and the start of the
        // second formula (up to the next punctuation mark).
        final removalStart = first.start;
        var removalEnd = first.end;
        for (final mark in const [':', ';', '.']) {
          final idx = preview.indexOf(mark, first.end);
          if (idx != -1 && idx < second.start) {
            removalEnd = idx + 1;
            break;
          }
        }
        return fullText.replaceRange(removalStart, removalEnd, '${rule.normalized}: ');
      }

      // Immediate duplicate: "Thus says the LORD: Thus says the LORD: …"
      if (rule.immediateDuplicate.hasMatch(preview)) {
        return fullText.replaceFirst(rule.immediateDuplicate, '${rule.normalized}: ');
      }
    }

    return fullText;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Rule builder helpers
  // ══════════════════════════════════════════════════════════════════════════

  static _RepeatedSayingRule _buildRepeatedSayingRule(String phrase) {
    final escaped = _phrasePattern(phrase);
    return _RepeatedSayingRule(
      pattern: RegExp(escaped, caseSensitive: false),
      normalized: phrase,
      immediateDuplicate: RegExp(
        r'^\s*' + escaped + r'[,:.]\s*' + escaped + r'[,:.]\s*',
        caseSensitive: false,
      ),
    );
  }

  static String _phrasePattern(String phrase) => phrase
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map(RegExp.escape)
      .join(r'\s+');

  // ══════════════════════════════════════════════════════════════════════════
  // Debug helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns a step-by-step breakdown of every transformation applied.
  RefinementDebugInfo debugRefinement(String text) {
    final preview = text.length > 200 ? text.substring(0, 200) : text;
    final afterIntro   = _removeRedundantIntroductoryPhrases(text, preview);
    final afterReduced = _removeRepeatedSayings(
      afterIntro,
      afterIntro.length > 200 ? afterIntro.substring(0, 200) : afterIntro,
    );
    return RefinementDebugInfo(
      original:            text,
      afterIntroRemoval:   afterIntro,
      afterRepeatedRemoval: afterReduced,
      finalResult:         afterReduced,
      changesDetected:     text != afterReduced,
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _RepeatedSayingRule {
  final RegExp pattern;
  final String normalized;
  final RegExp immediateDuplicate;

  const _RepeatedSayingRule({
    required this.pattern,
    required this.normalized,
    required this.immediateDuplicate,
  });
}

/// Step-by-step breakdown of the refinement pipeline for a given input.
class RefinementDebugInfo {
  final String original;
  final String afterIntroRemoval;
  final String afterRepeatedRemoval;
  final String finalResult;
  final bool changesDetected;

  const RefinementDebugInfo({
    required this.original,
    required this.afterIntroRemoval,
    required this.afterRepeatedRemoval,
    required this.finalResult,
    required this.changesDetected,
  });

  String _clip(String s) =>
      s.length > 100 ? '${s.substring(0, 100)}…' : s;

  @override
  String toString() => 'RefinementDebugInfo(changesDetected: $changesDetected)\n'
      '  original:  "${_clip(original)}"\n'
      '  introPass: "${_clip(afterIntroRemoval)}"\n'
      '  sayingPass:"${_clip(afterRepeatedRemoval)}"';
}
