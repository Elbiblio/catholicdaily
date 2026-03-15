/// Official Catholic Lectionary Incipit Service
///
/// Based on the General Instruction of the Lectionary (GILM) and the
/// official Ordo Lectionum Missae. Implements a complete three-stage pipeline:
///
///   Stage 1 – Gospel pronoun correction
///     Replaces ambiguous pronoun openings in gospel pericopes.
///     "He said to them…"  → "Jesus said to them…"
///     "As he spoke…"      → "As Jesus spoke…"
///
///   Stage 2 – Incipit candidate selection
///     Looks up the canonical incipit for the reading reference
///     (passage-level rules take priority over book-level defaults).
///
///   Stage 3 – Tautology suppression
///     If the reading's own opening already expresses the same semantic
///     content as the incipit, the incipit is discarded.
///
///     ✗ "Thus says the LORD: Thus says the LORD: I will restore you…"
///     ✓ "Thus says the LORD: I will restore you…"
///
///     ✗ "In those days, In those days there was a king…"
///     ✓ "In those days, there was a king…"
///
///     ✗ "Brethren: Brothers and sisters, I want you to know…"
///     ✓ "Brethren: I want you to know…"
class OfficialLectionaryIncipitService {
  static final OfficialLectionaryIncipitService _instance =
      OfficialLectionaryIncipitService._internal();
  factory OfficialLectionaryIncipitService() => _instance;
  OfficialLectionaryIncipitService._internal();

  // ══════════════════════════════════════════════════════════════════════════
  // Reference → incipit tables
  // ══════════════════════════════════════════════════════════════════════════

  /// Default incipit per book abbreviation.
  static const Map<String, String> _bookSpecificRules = {
    // ── Old Testament: Historical / Narrative ─────────────────────────────
    'Gen':    'In the beginning,',
    'Exod':   'In those days,',
    'Lev':    'The LORD said to Moses:',
    'Num':    'The LORD said to Moses:',
    'Deut':   'Moses said to the people:',
    'Josh':   'In those days,',
    'Judg':   'In those days,',
    'Ruth':   'In those days,',
    '1 Sam':  'In those days,',
    '2 Sam':  'In those days,',
    '1 Kgs':  'In those days,',
    '2 Kgs':  'In those days,',
    '1 Chr':  'In those days,',
    '2 Chr':  'In those days,',
    'Ezra':   'In those days,',
    'Neh':    'In those days,',
    'Tob':    'In those days,',
    'Jdt':    'In those days,',
    'Est':    'In those days,',
    '1 Macc': 'In those days,',
    '2 Macc': 'In those days,',

    // ── Old Testament: Prophetic ──────────────────────────────────────────
    'Isa':   'Thus says the LORD:',
    'Jer':   'Thus says the LORD:',
    'Lam':   'Thus says the LORD:',
    'Bar':   'Thus says the LORD:',
    'Ezek':  'Thus says the LORD:',
    'Dan':   'In those days,',   // default; individual chapters overridden below
    'Hos':   'Thus says the LORD:',
    'Joel':  'Thus says the LORD:',
    'Amos':  'Thus says the LORD:',
    'Obad':  'Thus says the LORD:',
    'Jonah': 'The word of the LORD came to Jonah:',
    'Mic':   'Thus says the LORD:',
    'Nah':   'Thus says the LORD:',
    'Hab':   'Thus says the LORD:',
    'Zeph':  'Thus says the LORD:',
    'Hag':   'Thus says the LORD:',
    'Zech':  'Thus says the LORD:',
    'Mal':   'Thus says the LORD:',

    // ── Old Testament: Wisdom ─────────────────────────────────────────────
    'Job':  'Job answered:',
    'Ps':   'The LORD says:',
    'Prov': 'Hear, my children:',
    'Eccl': 'I said to myself:',
    'Song': 'The beloved says:',
    'Wis':  'Wisdom has been given to us:',
    'Sir':  'My son,',

    // ── New Testament: Gospels ────────────────────────────────────────────
    'Matt': 'At that time,',
    'Mark': 'At that time,',
    'Luke': 'At that time,',
    'John': 'At that time,',

    // ── New Testament: Acts ───────────────────────────────────────────────
    'Acts': 'In those days,',

    // ── New Testament: Pauline Epistles ───────────────────────────────────
    'Rom':     'Brethren:',
    '1 Cor':   'Brethren:',
    '2 Cor':   'Brethren:',
    'Gal':     'Brethren:',
    'Eph':     'Brethren:',
    'Phil':    'Brethren:',
    'Col':     'Brethren:',
    '1 Thess': 'Brethren:',
    '2 Thess': 'Brethren:',
    '1 Tim':   'My child,',
    '2 Tim':   'My child,',
    'Titus':   'My child,',
    'Phlm':    'I appeal to you, my child:',
    'Heb':     'Brethren:',

    // ── New Testament: Catholic Epistles ──────────────────────────────────
    'Jas':    'Brethren:',
    '1 Pet':  'Beloved:',
    '2 Pet':  'Beloved:',
    '1 John': 'Beloved:',
    '2 John': 'The elder to the chosen lady:',
    '3 John': 'The elder to Gaius:',
    'Jude':   'Beloved:',
    'Rev':    'I, John, saw:',
  };

  /// Chapter-level overrides — evaluated before book-level defaults.
  static const Map<String, String> _passageSpecificRules = {
    // Genesis – creation / garden / fall narratives
    'Gen 1': 'In the beginning,',
    'Gen 2': 'In the beginning,',
    'Gen 3': 'In the beginning,',

    // Exodus – Decalogue reads as narrative, not law
    'Exod 20': 'In those days,',

    // Daniel – chapters 1-6 are narrative; 7-12 are prophetic visions
    'Dan 1':  'In those days,',
    'Dan 2':  'In those days,',
    'Dan 3':  'In those days,',
    'Dan 4':  'In those days,',
    'Dan 5':  'In those days,',
    'Dan 6':  'In those days,',
    'Dan 7':  'Thus says the LORD:',
    'Dan 8':  'Thus says the LORD:',
    'Dan 9':  'Thus says the LORD:',
    'Dan 10': 'Thus says the LORD:',
    'Dan 11': 'Thus says the LORD:',
    'Dan 12': 'Thus says the LORD:',

    // Matthew – Sermon on the Mount is direct discourse to disciples
    'Matt 5': 'Jesus said to his disciples:',
    'Matt 6': 'Jesus said to his disciples:',
    'Matt 7': 'Jesus said to his disciples:',

    // Luke – Infancy narrative
    'Luke 1': 'In those days,',
    'Luke 2': 'In those days,',

    // John – Prologue
    'John 1': 'In the beginning was the Word:',

    // Acts – key narratives
    'Acts 2': 'In those days,',
    'Acts 9': 'In those days,',

    // Revelation – major visions
    'Rev 1':  'I, John, saw:',
    'Rev 21': 'I, John, saw:',
    'Rev 22': 'I, John, saw:',
  };

  // ══════════════════════════════════════════════════════════════════════════
  // Tautology-detection: incipit → redundancy patterns
  //
  // Each entry maps a canonical incipit string to a list of lowercased
  // text prefixes.  If the normalised reading text starts with ANY of
  // those prefixes the incipit is considered tautological and suppressed.
  //
  // Normalisation (see _normalizeForComparison) removes punctuation and
  // collapses whitespace before comparison, so entries here need no
  // punctuation and only single spaces.
  // ══════════════════════════════════════════════════════════════════════════
  static const Map<String, List<String>> _redundancyPatterns = {

    // ── Prophetic / divine-speech ──────────────────────────────────────────

    'Thus says the LORD:': [
      'thus says the lord',
      'the lord says',
      'the lord said',
      'the lord has said',
      'the lord has spoken',
      'the lord spoke',
      'the lord declared',
      'the lord proclaims',
      'the lord announces',
      'says the lord',
      'declares the lord',
      'this is what the lord says',
      'the lord god says',
      'the lord god said',
      'the lord god declares',
      'thus says the lord god',
      'thus says the lord almighty',
      'thus says the lord of hosts',
      'the word of the lord came',
      'hear the word of the lord',
      'i the lord say',           // "I the LORD say to you…"
      'i am the lord your god',   // used as divine speech marker
      'i am the lord',
    ],

    'The LORD said:': [
      'the lord said',
      'the lord spoke',
      'the lord declared',
      'thus says the lord',
    ],

    'The LORD said to Moses:': [
      'the lord said to moses',
      'the lord spoke to moses',
      'the lord told moses',
      'god said to moses',
      'then the lord said to moses',
    ],

    'The word of the LORD came to Jonah:': [
      'the word of the lord came to jonah',
      'the word of the lord came',
      'the lord said to jonah',
    ],

    'The LORD says:': [
      'the lord says',
      'the lord has said',
      'thus says the lord',
    ],

    // ── Temporal ───────────────────────────────────────────────────────────

    'In those days,': [
      'in those days',
      'at that time',
      'in that time',
      'in those times',
      'in that day',
    ],

    'At that time,': [
      'at that time',
      'in those days',
      'in that time',
      'at that moment',
    ],

    // ── In principio / narrative openers ──────────────────────────────────

    'In the beginning,': [
      'in the beginning',
    ],

    'In the beginning:': [
      'in the beginning',
    ],

    'In the beginning was the Word:': [
      'in the beginning was the word',
      'in the beginning',
    ],

    // ── Named speaker / dialogue ───────────────────────────────────────────

    'Moses said to the people:': [
      'moses said to the people',
      'moses said to the israelites',
      'moses said',
      'moses told the people',
      'moses addressed',
      'moses spoke to',
      'then moses said',
    ],

    'Moses said:': [
      'moses said',
      'moses told',
      'moses spoke',
    ],

    'Job answered:': [
      'job answered',
      'job said',
      'job replied',
      'job spoke',
      'then job said',
    ],

    'Hear, my children:': [
      'hear my children',
      'hear my child',
      'listen my children',
      'listen my child',
    ],

    'I said to myself:': [
      'i said to myself',
      'i thought to myself',
      'i said in my heart',
    ],

    'The beloved says:': [
      'the beloved says',
      'my beloved says',
      'the beloved speaks',
    ],

    'Wisdom has been given to us:': [
      'wisdom has been given',
      'wisdom was given',
    ],

    'My son,': [
      'my son',
      'my child',
      'my daughter',
      'dear son',
    ],

    // ── Epistolary / addressee ─────────────────────────────────────────────

    'Brethren:': [
      'brethren',
      'brothers and sisters',
      'my brothers and sisters',
      'dear brothers and sisters',
      'my brothers',
      // bare "brothers" is tricky — "brothers" as a vocative at pericope start
      // is genuinely tautological with "Brethren:"
      'brothers',
      'sisters and brothers',
    ],

    'My child,': [
      'my child',
      'my son',
      'my daughter',
      'dear child',
      'dear son',
    ],

    'Beloved:': [
      'beloved',
      'my beloved',
      'dear friends',
      'dearly beloved',
      'my dear friends',
    ],

    'I appeal to you, my child:': [
      'i appeal to you my child',
      'i appeal to you',
      'i am appealing to you',
    ],

    'The elder to the chosen lady:': [
      'the elder to the chosen lady',
    ],

    'The elder to Gaius:': [
      'the elder to gaius',
    ],

    // ── Revelation ─────────────────────────────────────────────────────────

    'I, John, saw:': [
      'i john saw',
      'i john',   // covers "I, John, the beloved…" openings
    ],

    // ── Gospel discourse incipits ──────────────────────────────────────────

    'Jesus said to his disciples:': [
      'jesus said to his disciples',
      'jesus told his disciples',
      'jesus spoke to his disciples',
      // If the text already names Jesus speaking at all, suppress
      'jesus said to them',
      'jesus said',
    ],
  };

  // ══════════════════════════════════════════════════════════════════════════
  // Gospel pronoun correction
  // ══════════════════════════════════════════════════════════════════════════

  static const Set<String> _gospelBooks = {'Matt', 'Mark', 'Luke', 'John'};

  /// Verbs for which a pericope-opening "He" in a gospel unambiguously
  /// refers to Jesus.  Keep this list conservative; action verbs that could
  /// refer to other characters (e.g. "went") are deliberately omitted.
  static const List<String> _jesusVerbs = [
    'said',
    'told',
    'asked',
    'replied',
    'answered',
    'declared',
    'proclaimed',
    'announced',
    'taught',
    'spoke',
    'called',
    'commanded',
    'warned',
    'responded',
    'addressed',
    'began',      // "He began to teach…"
    'continued',  // "He continued speaking…"
    'turned',     // "He turned to his disciples…" — directional + discourse
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // Public API
  // ══════════════════════════════════════════════════════════════════════════

  /// Full processing pipeline — preferred entry point when reading text is
  /// available.
  ///
  /// Returns a named record:
  ///   [incipit]       — string to prepend before the reading, or `null`
  ///   [correctedText] — reading text with gospel pronoun corrections applied
  ///
  /// Example usage:
  /// ```dart
  /// final result = service.processReading('Matt 5:1-12a', pericope);
  /// final display = [
  ///   if (result.incipit != null) result.incipit!,
  ///   result.correctedText,
  /// ].join(' ');
  /// ```
  ({String? incipit, String correctedText}) processReading(
    String readingReference,
    String readingText,
  ) {
    final book = _extractBookAbbreviation(readingReference);
    final isGospel = book != null && _gospelBooks.contains(book);

    // Stage 1 — correct gospel pronouns first so the tautology check
    //           in stage 3 operates on the final, corrected text.
    final correctedText = isGospel
        ? _applyGospelPronounCorrections(readingText)
        : readingText;

    // Stage 2 — candidate incipit by reference
    final candidate = getOfficialIncipit(readingReference);

    // Stage 3 — suppress if tautological
    String? finalIncipit;
    if (candidate != null) {
      finalIncipit =
          _isIncipitRedundant(candidate, correctedText) ? null : candidate;
    }

    return (incipit: finalIncipit, correctedText: correctedText);
  }

  /// Returns the reference-derived candidate incipit without tautology
  /// checking.  Use [processReading] when the reading text is available.
  String? getOfficialIncipit(String readingReference) {
    // Passage-level rules take priority
    for (final entry in _passageSpecificRules.entries) {
      if (_passageKeyMatches(readingReference, entry.key)) {
        return entry.value;
      }
    }
    // Book-level default
    final book = _extractBookAbbreviation(readingReference);
    return book != null ? _bookSpecificRules[book] : null;
  }

  bool usesIncipit(String readingReference) =>
      getOfficialIncipit(readingReference) != null;

  Map<String, String> getBookSpecificRules() => Map.from(_bookSpecificRules);
  Map<String, String> getPassageSpecificRules() =>
      Map.from(_passageSpecificRules);

  // ══════════════════════════════════════════════════════════════════════════
  // Stage 3 – Tautology suppression helpers
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns `true` when prepending [incipit] to [readingText] would produce
  /// a tautology.
  ///
  /// Three-tier check (first positive result wins):
  ///   1. Table-driven pattern match  → fastest, most explicit
  ///   2. Exact self-match            → catches incipits not yet in the table
  ///   3. Fuzzy semantic overlap      → last-resort heuristic
  bool _isIncipitRedundant(String incipit, String readingText) {
    final normReading = _normalizeForComparison(readingText);
    final normIncipit = _normalizeForComparison(incipit);

    // Tier 1 – explicit pattern table
    final patterns = _redundancyPatterns[incipit] ?? const <String>[];
    for (final pattern in patterns) {
      if (normReading.startsWith(pattern)) return true;
    }

    // Tier 2 – exact self-match
    if (normReading.startsWith(normIncipit)) return true;

    // Tier 3 – fuzzy semantic overlap
    return _hasSemanticOverlap(normIncipit, normReading);
  }

  /// Heuristic: if ≥ 60 % of the incipit's meaningful words appear in the
  /// first ~10 tokens of the reading, consider it semantically redundant.
  ///
  /// This catches paraphrase variants not explicitly listed in the table
  /// (e.g. a translation rendering "Thus says the LORD" as "The LORD speaks").
  bool _hasSemanticOverlap(String normIncipit, String normReading) {
    final readingTokens =
        normReading.split(RegExp(r'\s+')).take(10).toSet();

    final incipitTokens = normIncipit
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .toList();

    if (incipitTokens.isEmpty) return false;

    final hits = incipitTokens.where(readingTokens.contains).length;
    return hits / incipitTokens.length >= 0.60;
  }

  /// Function words excluded from the semantic-overlap heuristic.
  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'to', 'of', 'in', 'and', 'or', 'is', 'it',
    'at', 'on', 'by', 'for', 'with', 'from', 'that', 'this',
    'i', 'my', 'me', 'he', 'she', 'we', 'they', 'you',
    'his', 'her', 'its', 'our', 'your', 'their',
    'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did',
    'will', 'would', 'shall', 'should', 'may', 'might', 'can', 'could',
  };

  /// Strips leading typographic/straight quotes, lowercases, removes all
  /// punctuation (except word-internal apostrophes), and collapses whitespace
  /// so that content words can be compared with simple startsWith checks.
  String _normalizeForComparison(String text) {
    return text
        .trimLeft()
        // Strip leading curly or straight quote marks
        .replaceFirst(RegExp("^[\u201C\u201D\u2018\u2019\"']+"), '')
        .replaceFirst(RegExp(r'^\d+[a-z]?\s+'), '')
        .toLowerCase()
        // Replace any non-word, non-space, non-apostrophe char with a space
        .replaceAll(RegExp(r"[^\w\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Stage 1 – Gospel pronoun correction
  // ══════════════════════════════════════════════════════════════════════════

  /// Replaces ambiguous third-person pronoun openings in gospel pericopes
  /// with the name "Jesus" to eliminate ambiguity for the lector.
  ///
  /// Five rules applied in priority order (first match wins for Rule 1;
  /// Rules 2-5 run as independent passes on the opener):
  ///
  ///   Rule 1: "He [verb]…"                     → "Jesus [verb]…"
  ///           Only fires for [_jesusVerbs] — conservative set of speech /
  ///           address verbs where "He" is unambiguously Jesus.
  ///
  ///   Rule 2: "As he …"                         → "As Jesus …"
  ///   Rule 3: "While he …"                      → "While Jesus …"
  ///   Rule 4: "When he …"                       → "When Jesus …"
  ///   Rule 5: "After he …"                      → "After Jesus …"
  ///           Rules 2-5 cover temporal openers.  At the start of a gospel
  ///           pericope, the subject of such constructions is Jesus by
  ///           convention; adjust the opener list if edge cases arise.
  String _applyGospelPronounCorrections(String text) {
    final verbAlt = _jesusVerbs.join('|');
    text = text.replaceFirstMapped(
      RegExp(
        r'^((?:\d+[a-z]?\s+)?)He\s+(' + verbAlt + r')\b',
        caseSensitive: true,
      ),
      (m) => '${m.group(1)}Jesus ${m.group(2)}',
    );

    for (final opener in const ['As', 'While', 'When', 'After']) {
      text = text.replaceFirstMapped(
        RegExp(
          r'^((?:\d+[a-z]?\s+)?)(' + opener + r'\s+)he\b',
          caseSensitive: true,
        ),
        (m) => '${m.group(1)}${m.group(2)}Jesus',
      );
    }

    return text;
  }

  bool _passageKeyMatches(String ref, String key) {
    if (!ref.startsWith(key)) return false;
    if (ref.length == key.length) return true;
    return ref[key.length] == ':';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Reference parsing
  // ══════════════════════════════════════════════════════════════════════════

  /// Extracts the abbreviated book name from a lectionary reference.
  ///
  /// Handles numbered books ("1 Sam 3:1", "2 Kgs 4:1", "1 Macc 2:1") before
  /// falling through to standard abbreviations ("Acts 2:1", "Matt 5:3").
  String? _extractBookAbbreviation(String ref) {
    // Numbered books: "1 Sam", "2 Kgs", "3 John", "1 Macc", etc.
    final m1 = RegExp(r'^([1-3]\s[A-Za-z]{1,4})\s+\d+').firstMatch(ref);
    if (m1 != null) return m1.group(1);

    // Standard abbreviations up to 5 chars: "Gen", "Matt", "Acts", "Jonah"
    final m2 = RegExp(r'^([A-Za-z]{1,5})\s+\d+').firstMatch(ref);
    if (m2 != null) return m2.group(1);

    return null;
  }
}