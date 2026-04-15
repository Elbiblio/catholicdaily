// ═══════════════════════════════════════════════════════════════════════════
// IncipitProcessingService
// ═══════════════════════════════════════════════════════════════════════════
//
// Consolidates all incipit extraction, normalization, and deduplication into
// a single synchronous pipeline with three explicit, testable passes.
//
// ┌──────────────────────────────────────────────────────────────────────┐
// │ Pass 1 – NORMALIZE                                                   │
// │   Clean the raw CSV incipit: strip embedded verse numbers,           │
// │   tautological temporal phrases, and leading narrative conjunctions. │
// │   Pronoun resolution ("He …" → "Jesus …") for "At that time" leads. │
// ├──────────────────────────────────────────────────────────────────────┤
// │ Pass 2 – RESOLVE                                                     │
// │   Clean and correct the raw verse text and derive an official incipit │
// │   when none was supplied by the CSV. If a CSV incipit is available,  │
// │   merge it against the first verse via:                               │
// │     a) Verbatim phrase match (_findLoosePhraseMatch)                 │
// │     b) Token-alignment fallback (Pass 3 deduplicator)               │
// ├──────────────────────────────────────────────────────────────────────┤
// │ Pass 3 – DEDUPLICATE                                                 │
// │   Sequential token alignment strips the portion of the first verse  │
// │   that echoes the incipit.  Tolerates pronoun/synonym substitutions  │
// │   ("people" → "them") and comma-boundary truncation.                │
// │   Returns the assembled "Incipit: content" string.                  │
// └──────────────────────────────────────────────────────────────────────┘
//
// Replaces:
//   • incipit_text_cleaner.dart       (cleanFirstLineForIncipit + helpers)
//   • ReadingsBackendIo._cleanCsvIncipit
//   • ReadingsBackendIo._mergeIncipitIntoFirstVerse
//   • ReadingsBackendIo._mergeIncipitWithVerseText
//   • ReadingsBackendIo._splitIncipitParts / _normalizeMergedIncipit
//   • ReadingsBackendIo._findLoosePhraseMatch
//   • ReadingsBackendIo._joinSentenceParts / _joinIncipitAndVerse
//   • ReadingsBackendIo._looksLikeIncipitText

class IncipitProcessingService {
  IncipitProcessingService();

  /// Inject a custom service for testing compatibility.
  IncipitProcessingService.withService(dynamic service);

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Processes [rawText] for [reference] and returns the fully assembled
  /// "Incipit: verse content" string ready for display.
  ///
  /// [csvIncipit] — optional incipit value from the CSV lectionary data.
  String process(
    String reference,
    String rawText, {
    String? csvIncipit,
  }) {
    // ── Pass 1: Normalize CSV incipit ────────────────────────────────────────
    final cleanedCsvIncipit =
        csvIncipit != null && csvIncipit.trim().isNotEmpty
            ? _pass1Normalize(csvIncipit.trim())
            : null;

    // ── Pass 2: Clean text and derive incipit ───────────────────────────────────
    final correctedText = _cleanVerseText(rawText);
    final derivedIncipit = _deriveIncipit(correctedText, reference);

    if (cleanedCsvIncipit != null && cleanedCsvIncipit.isNotEmpty) {
      // CSV incipit provided — merge it against the corrected text.
      return _pass2MergeCsvIncipit(correctedText, cleanedCsvIncipit,
          reference: reference);
    }

    if (derivedIncipit == null || derivedIncipit.trim().isEmpty) {
      return correctedText;
    }

    // ── Pass 3: Deduplicate ──────────────────────────────────────────────
    final cleanIncipit = derivedIncipit.trim().replaceAll(
      RegExp(r'[,:;]\s*$'),
      '',
    );
    return _pass3Assemble(correctedText, cleanIncipit);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pass 1 — Normalize raw CSV incipit
  // ─────────────────────────────────────────────────────────────────────────

  /// Cleans a raw CSV incipit value before merging it with the verse text.
  ///
  /// CSV incipits often contain:
  ///   "At that time: 1. An account of…"  → "At that time, An account of…"
  ///   "Brethren: 32. What more…"          → "Brethren: What more…"
  String _pass1Normalize(String raw) {
    var r = raw.trim();
    if (r.isEmpty) return r;

    // Strip embedded verse number after a colon prefix.
    // "At that time: 1. An account" → "At that time: An account"
    r = r.replaceFirstMapped(
      RegExp(r'^(.+?:\s*)\d+[a-z]?\.\s*(.*)$', dotAll: true),
      (m) => '${m.group(1)!}${m.group(2)!}',
    );

    // Strip bare verse number with no prefix.
    // "1. Jacob called…" → "Jacob called…"
    if (RegExp(r'^\d+[a-z]?\.\s').hasMatch(r)) {
      r = r.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    }

    // Remove tautological temporal phrases and leading conjunctions that
    // appear immediately after known incipit prefixes.
    //   "At that time: One day, while…"  → "At that time, while…"
    //   "In those days: Now the king…"   → "In those days, The king…"
    final prefixMatch = RegExp(
      r'^((?:At that time|In those days'
      r'|Jesus said to (?:his disciples|the crowds?|them)'
      r'|Thus says the LORD'
      r'|Brethren'
      r'|Beloved'
      r'|My son'
      r'|The LORD said)[,:]\s*)',
      caseSensitive: false,
    ).firstMatch(r);

    if (prefixMatch != null) {
      final prefix = prefixMatch.group(1)!;
      var after = r.substring(prefix.length).trim();

      // Strip tautological temporal openers.
      after = after.replaceFirst(
        RegExp(
          r'^(?:one day,?\s*|once,?\s*'
          r'|on (?:that|one|a certain) (?:day|occasion),?\s*'
          r'|at that (?:time|very moment),?\s*|now,?\s*)',
          caseSensitive: false,
        ),
        '',
      );

      // Strip leading narrative conjunctions.
      after = after.replaceFirst(
        RegExp(
          r'^(?:and|but|then|so|for|now|thus|therefore|moreover)\s+',
          caseSensitive: false,
        ),
        '',
      );

      // Capitalize the first letter of the remainder.
      if (after.isNotEmpty) {
        after = after[0].toUpperCase() + after.substring(1);
      }

      // "At that time" context: resolve opening pronouns to "Jesus".
      if (prefix.toLowerCase().startsWith('at that time') &&
          after.isNotEmpty) {
        after = after.replaceFirstMapped(
          RegExp(
            r'^(?:(While|As|When|After)\s+)(?:he|him)\b',
            caseSensitive: false,
          ),
          (m) => '${m.group(1)} Jesus',
        );
        after = after.replaceFirstMapped(
          RegExp(r'^(?:He|Him)\b', caseSensitive: false),
          (_) => 'Jesus',
        );
      }

      // Reconstruct with a clean separator (no trailing punctuation on prefix).
      final cleanPrefix = prefix.replaceAll(RegExp(r'[,:;\s]+$'), '');
      r = after.isNotEmpty ? '$cleanPrefix, $after' : cleanPrefix;
    }

    return r.trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pass 2 — Merge a CSV incipit against the corrected verse text
  // ─────────────────────────────────────────────────────────────────────────

  /// Merges [csvIncipit] (already normalized via Pass 1) with the first verse
  /// of [text], returning the assembled display string.
  ///
  /// Strategy (in order):
  ///   1. Verbatim phrase match: finds the incipit body verbatim in the verse
  ///      and discards that redundant prefix.
  ///   2. Subset-verse expansion: if every meaningful CSV token is already
  ///      present in the verse, treat the verse as the authoritative body
  ///      and prepend a book-appropriate narrative prefix (e.g. "In those
  ///      days:" for Acts, "Brethren:" for Paul, "Beloved:" for Catholic
  ///      epistles). Preserves words like "rose up" that CSV partials drop.
  ///   3. Token-alignment dedupe (right-to-left): finds the closing incipit
  ///      token in the verse and appends the verse remainder with a comma.
  String _pass2MergeCsvIncipit(String text, String csvIncipit,
      {String reference = ''}) {
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim().isEmpty) continue;

      final originalLine = lines[i].trim();
      final verseMatch =
          RegExp(r'^(\d+[a-z]?)\.\s*(.*)$').firstMatch(originalLine);
      final versePrefix = verseMatch?.group(1);
      final verseBody = (verseMatch?.group(2) ?? originalLine).trim();

      final mergedBody = _mergeCsvIncipitWithVerse(
        csvIncipit,
        verseBody,
        reference: reference,
      );
      lines[i] = versePrefix != null && versePrefix.isNotEmpty
          ? '$versePrefix. $mergedBody'
          : mergedBody;
      return lines.join('\n');
    }
    // Fallback: verse text empty — just return the incipit itself.
    return csvIncipit;
  }

  String _mergeCsvIncipitWithVerse(String csvIncipit, String verseText,
      {String reference = ''}) {
    final cleanedVerse = verseText.trim();
    if (csvIncipit.isEmpty || cleanedVerse.isEmpty) {
      return csvIncipit.isEmpty ? cleanedVerse : csvIncipit;
    }

    final normalizedIncipit = _normalizeTrailingPunct(csvIncipit);

    // ── 2a: Verbatim phrase match ────────────────────────────────────────
    final incipitBody = _incipitBodyAfterColon(csvIncipit);
    if (incipitBody.isNotEmpty) {
      final overlap = _findLoosePhraseMatch(cleanedVerse, incipitBody);
      if (overlap != null) {
        final remainder = cleanedVerse
            .substring(overlap.end)
            .trimLeft()
            .replaceFirst(RegExp(r'^[,;:!?.\-\u2013\u2014]+\s*'), '');
        if (remainder.isEmpty) return normalizedIncipit;
        return _joinWithPeriod(normalizedIncipit, remainder);
      }
    }

    // ── 2b: Subset-verse expansion ───────────────────────────────────────
    final incipitTokensMeaningful = _tokenize(incipitBody);
    if (incipitTokensMeaningful.length >= 2) {
      final lowerVerse = cleanedVerse.toLowerCase();
      final allCovered = incipitTokensMeaningful.every(
        (t) => RegExp('\\b${RegExp.escape(t)}\\b').hasMatch(lowerVerse),
      );
      if (allCovered) {
        final prefix = _selectLectionaryPrefix(
          csvIncipit: csvIncipit,
          reference: reference,
        );
        final body = _stripLeadingNarrativeOpener(cleanedVerse);
        if (body.isNotEmpty && prefix.isNotEmpty) {
          return _joinWithColon(_normalizeTrailingPunct(prefix), body);
        }
      }
    }

    // ── 2c: Token-alignment fallback (Pass 3 deduplicator, right-to-left)
    final deduped = _pass3DeduplicateFirstLine(cleanedVerse, normalizedIncipit);
    if (deduped.isEmpty) return normalizedIncipit;
    if (deduped == cleanedVerse) {
      // No dedupe → incipit and verse do not share wording; use colon so the
      // CSV prefix reads as an introduction ("Jesus said to Nicodemus: For
      // God so loved …"). For single-word openers (BELOVED, BRETHREN,
      // BEHOLD, MY SON, MY BROTHERS) also strip a leading narrative
      // conjunction from the verse so we get "Beloved: if you invoke…"
      // rather than "Beloved: And if you invoke…".
      if (_isSingleOpener(normalizedIncipit)) {
        final stripped = _stripLeadingNarrativeOpener(deduped);
        if (stripped.isNotEmpty) {
          return _joinWithColon(normalizedIncipit, stripped);
        }
      }
      return _joinWithColon(normalizedIncipit, deduped);
    }
    // Dedupe consumed part of the verse → continue the sentence with a comma.
    return _joinWithComma(normalizedIncipit, deduped);
  }

  /// Returns true when [incipit] is a single-word lectionary opener such as
  /// "BELOVED", "BRETHREN", "BEHOLD", "MY SON", "MY BROTHERS".
  bool _isSingleOpener(String incipit) {
    final trimmed = incipit.trim().toLowerCase().replaceAll(RegExp(r'[,:;]$'), '');
    const openers = {
      'beloved',
      'brethren',
      'brothers',
      'brothers and sisters',
      'behold',
      'hear',
      'listen',
      'my son',
      'my sons',
      'my brother',
      'my brothers',
      'my brothers and sisters',
      'dearly beloved',
    };
    return openers.contains(trimmed);
  }

  /// Returns the best lectionary-style prefix for a subset CSV incipit.
  ///
  /// Rules:
  ///   • If the CSV incipit starts with a recognized narrative prefix, use
  ///     the CSV's pre-colon portion (or the whole string when no colon).
  ///   • Otherwise derive a prefix from the scripture book in [reference]:
  ///     Acts / OT historical → "In those days"
  ///     Pauline letters      → "Brethren"
  ///     Catholic epistles    → "Beloved"
  ///     Gospels              → "At that time"
  String _selectLectionaryPrefix({
    required String csvIncipit,
    required String reference,
  }) {
    final lower = csvIncipit.toLowerCase().trimLeft();
    for (final opener in _kIncipitOpeners) {
      if (lower.startsWith(opener)) {
        final prefix = _extractIncipitPrefix(csvIncipit);
        return prefix.isNotEmpty ? prefix : csvIncipit;
      }
    }
    final bookBased = _bookPrefix(reference);
    if (bookBased != null) return bookBased;
    // Fall back to the CSV incipit as-is.
    return csvIncipit;
  }

  /// Returns a lectionary-style narrative prefix ("In those days",
  /// "Brethren", "Beloved", "At that time") based on the book of [reference],
  /// or null when no sensible default applies.
  String? _bookPrefix(String reference) {
    final ref = reference.trim();
    if (ref.isEmpty) return null;

    final bookMatch = RegExp(r'^([0-9]?\s*[A-Za-z]+)').firstMatch(ref);
    final book = bookMatch?.group(1)?.trim();
    if (book == null || book.isEmpty) return null;

    final lower = book.toLowerCase();
    if (lower.startsWith('acts')) return 'In those days';
    if (lower.startsWith('matt') ||
        lower.startsWith('mark') ||
        lower.startsWith('luke') ||
        lower.startsWith('john')) {
      return 'At that time';
    }
    // Pauline epistles
    const pauline = {
      'rom', 'cor', '1cor', '2cor', 'gal', 'eph', 'phil',
      'col', 'thess', '1thess', '2thess', 'tim', '1tim', '2tim',
      'titus', 'phlm', 'heb',
    };
    final normalizedBook = lower.replaceAll(' ', '');
    for (final p in pauline) {
      if (normalizedBook == p || normalizedBook.endsWith(p)) {
        return 'Brethren';
      }
    }
    // Catholic epistles
    const catholic = {
      'jas', 'james', '1pet', '2pet', 'pet',
      '1john', '2john', '3john', 'jude',
    };
    for (final c in catholic) {
      if (normalizedBook == c || normalizedBook.endsWith(c)) {
        return 'Beloved';
      }
    }
    // OT historical / narrative
    const otHistorical = {
      'gen', 'exod', 'lev', 'num', 'deut', 'josh', 'judg', 'ruth',
      '1sam', '2sam', 'sam', '1kgs', '2kgs', 'kgs',
      '1chr', '2chr', 'chr', 'ezra', 'neh', 'tob', 'jud', 'esth',
      '1macc', '2macc', 'macc',
    };
    for (final o in otHistorical) {
      if (normalizedBook == o || normalizedBook.endsWith(o)) {
        return 'In those days';
      }
    }
    return null;
  }

  /// Extracts the leading phrase of a CSV incipit ("In those days", "Brethren",
  /// "Jesus said to Nicodemus", etc.). Returns the segment before the first
  /// colon, or the whole incipit when no colon exists.
  String _extractIncipitPrefix(String incipit) {
    final colonIndex = incipit.indexOf(':');
    if (colonIndex > 0) return incipit.substring(0, colonIndex).trim();
    return incipit.trim();
  }

  /// Strips leading narrative conjunctions ("But", "And", "Now", "Then",
  /// "So", "Therefore", "Moreover", "Again") from a verse body so the
  /// resulting phrase reads naturally after an incipit prefix.
  String _stripLeadingNarrativeOpener(String body) {
    var result = body.trim();
    // Remove a standalone leading verse-number prefix, if any.
    result = result.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    final match = RegExp(
      r'^(?:And|But|Now|Then|So|For|Thus|Therefore|Moreover|Again|Yet)\s+',
      caseSensitive: false,
    ).firstMatch(result);
    if (match != null) {
      result = result.substring(match.end).trimLeft();
    }
    // Capitalize the first letter of the remainder.
    if (result.isNotEmpty) {
      final ch = result[0];
      if (ch != '"' && ch != '\u201C' && ch != "'") {
        result = ch.toUpperCase() + result.substring(1);
      }
    }
    return result;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pass 3 — Deduplicate: assemble final "Incipit: content" string
  // ─────────────────────────────────────────────────────────────────────────

  /// Removes the echoed incipit opening from [text] and returns
  /// "$incipit: $cleanedContent".
  String _pass3Assemble(String text, String incipit) {
    final cleanedText = _pass3ApplyToText(text, incipit);
    return '$incipit: $cleanedText';
  }

  /// Applies the deduplicator to the full text (multi-line).
  String _pass3ApplyToText(String text, String incipitPrefix) {
    final lines = text.split('\n');
    if (lines.isEmpty) return text;

    final firstIdx = lines.indexWhere((l) => l.trim().isNotEmpty);
    if (firstIdx == -1) return text;

    var firstLine = lines[firstIdx].trim();
    firstLine = firstLine.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    firstLine = firstLine.replaceFirst(RegExp(r'^\d+[a-z]?\s+'), '');

    final stripped = _pass3DeduplicateFirstLine(firstLine, incipitPrefix);

    // Empty string signals that the entire first line WAS the incipit phrase.
    // Skip it and return whatever follows.
    if (stripped.isEmpty) {
      lines[firstIdx] = '';
      return lines.join('\n').trimLeft();
    }

    // No redundancy detected.
    if (stripped == firstLine) return text;

    // Post-strip connector cleanup.
    var result = stripped;
    final incipitLower = incipitPrefix.toLowerCase();
    if (incipitLower.contains('in those days') ||
        incipitLower.contains('at that time')) {
      result = result.replaceFirst(
        RegExp(
          r'^(?:Now,?\s*|Then,?\s*|And,?\s*|But,?\s*|So,?\s*|For,?\s*'
          r'|On that day,?\s*|At that time,?\s*|In those days,?\s*'
          r'|One day,?\s*|Once,?\s*'
          r'|On (?:that|one|a certain) (?:day|occasion),?\s*)',
          caseSensitive: false,
        ),
        '',
      );
    } else {
      result = result.replaceFirst(
        RegExp(
          r'^(?:And |But |Now |Then |So |For |Thus |Therefore |Moreover |Again )',
          caseSensitive: false,
        ),
        '',
      );
    }

    if (result.isNotEmpty) {
      final ch = result[0];
      if (ch != '"' && ch != '\u201C' && ch != "'") {
        result = ch.toUpperCase() + result.substring(1);
      }
    }

    lines[firstIdx] = result;
    return lines.join('\n');
  }

  /// Core deduplicator: returns the portion of [firstLine] that is NOT already
  /// covered by [incipitPrefix].
  ///
  /// Strategy (right-to-left, non-sequential):
  ///   1. Count how many incipit tokens appear anywhere in the verse
  ///      (coverage). Requires ≥ 0.5 ratio before we touch the verse.
  ///   2. Walk incipit tokens right-to-left; the first one found in the
  ///      verse defines the strip boundary. This tolerates verb-tense
  ///      substitutions mid-incipit (e.g. CSV says "stood" but the verse
  ///      has "standing") — the closing token ("Eleven", "him", …) still
  ///      pins the end of the echo correctly.
  ///
  /// Returns [firstLine] unchanged when coverage < 0.5 (no redundancy).
  /// Returns **empty string** when the whole line IS the incipit (caller skips it).
  String _pass3DeduplicateFirstLine(String firstLine, String incipitPrefix) {
    final incipitTokens = _tokenize(incipitPrefix);
    if (incipitTokens.length < 2) return firstLine;

    final lowerLine =
        firstLine.toLowerCase().replaceAll(RegExp(r"[^\w\s']"), ' ');

    int matchedCount = 0;
    for (final token in incipitTokens) {
      if (RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(lowerLine)) {
        matchedCount++;
      }
    }

    final ratio = matchedCount / incipitTokens.length;

    final isProphetic = _isPropheticIncipit(incipitPrefix) &&
        _startsWithPropheticRedundancy(firstLine);

    if (!isProphetic && ratio < 0.5) return firstLine;

    // Right-to-left: find the closing incipit token that appears in the
    // verse and strip up to its LAST occurrence in the verse.
    int lastMatchEnd = -1;
    for (var i = incipitTokens.length - 1; i >= 0; i--) {
      final token = incipitTokens[i];
      final matches = RegExp('\\b${RegExp.escape(token)}\\b')
          .allMatches(lowerLine)
          .toList();
      if (matches.isNotEmpty) {
        lastMatchEnd = matches.last.end;
        break;
      }
    }

    if (lastMatchEnd < 0) return firstLine;

    var remainder = firstLine.substring(lastMatchEnd).trimLeft();
    remainder = remainder.replaceFirst(
      RegExp(r'^[,;:!?.\u2013\u2014\-]+\s*'),
      '',
    );

    // Prophetic extension: strip "spoke to X, saying, …" → keep only the word.
    if (isProphetic) {
      final sayingM =
          RegExp(r'\bsaying\b[,;:]?\s*', caseSensitive: false)
              .firstMatch(remainder);
      if (sayingM != null) {
        remainder = remainder.substring(sayingM.end).trimLeft();
      } else {
        // Short formula fragment (e.g. "spoke to Ahaz" = 3 words) → skip line.
        if (_wordCount(remainder) <= 4) return '';
      }
    }

    // Strip bare "saying" lead-in.
    remainder = remainder.replaceFirst(
      RegExp(r'''^["'\u201C\u201D]*\s*saying[,;:]?\s*''', caseSensitive: false),
      '',
    );
    remainder = remainder.trimLeft();

    // Trivial-fragment guard: 1-word remainder at high match ratio = the
    // whole line was the incipit (e.g. "him" → "Jesus").
    if (_wordCount(remainder) <= 1 && ratio >= 0.75) return '';

    return remainder;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Verbatim phrase match: finds [phrase] inside [verseText] allowing for
  /// minor punctuation differences between adjacent tokens.
  RegExpMatch? _findLoosePhraseMatch(String verseText, String phrase) {
    var p = phrase
        .trim()
        .replaceAll('\u201C', '')
        .replaceAll('\u201D', '')
        .replaceFirst(RegExp("^[\"']+"), '')
        .trim();

    while (p.isNotEmpty && '"\':;,.!?'.contains(p[p.length - 1])) {
      p = p.substring(0, p.length - 1).trimRight();
    }
    if (p.isEmpty) return null;

    final tokens = p
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp("[^A-Za-z0-9']"), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.length < 3) return null;

    final pattern = tokens.map(RegExp.escape).join(r'[\s\W_]+');
    return RegExp(pattern, caseSensitive: false).firstMatch(verseText);
  }

  /// Joins [leading] and [trailing] with a period when leading lacks one.
  String _joinWithPeriod(String leading, String trailing) {
    final l = leading.trimRight();
    final t = trailing.trimLeft();
    if (l.isEmpty) return t;
    if (t.isEmpty) return l;
    if (RegExp(r'[.!?]$').hasMatch(l)) return '$l $t';
    return '$l. $t';
  }

  /// Joins [incipit] and [verse] with a colon (or respects existing punctuation).
  String _joinWithColon(String incipit, String verse) {
    final i = incipit.trimRight();
    final v = verse.trimLeft();
    if (i.isEmpty) return v;
    if (v.isEmpty) return i;
    if (RegExp(r'[:,;.!?]$').hasMatch(i)) return '$i $v';
    return '$i: $v';
  }

  /// Joins [incipit] and [verse] with a comma when the incipit ends with a
  /// noun phrase that should flow naturally into the following clause
  /// (e.g. "THEN Peter stood up with the Eleven" + "lifted up his voice").
  /// If the incipit already ends with punctuation, respect it.
  String _joinWithComma(String incipit, String verse) {
    final i = incipit.trimRight();
    final v = verse.trimLeft();
    if (i.isEmpty) return v;
    if (v.isEmpty) return i;
    if (RegExp(r'[:,;.!?]$').hasMatch(i)) return '$i $v';
    // Drop a leading narrative conjunction so the joined sentence reads
    // naturally; keep the casing of the next word intact (e.g. "But God"
    // → "God" should stay capitalized, not become "god").
    final cleanedV = v.replaceFirst(
      RegExp(
        r'^(?:And|But|Now|Then|So|For|Thus|Therefore|Moreover|Again|Yet)\s+',
        caseSensitive: false,
      ),
      '',
    );
    final joined = cleanedV.isEmpty ? v : cleanedV;
    return '$i, $joined';
  }

  /// Extracts the part of an incipit that comes after the first colon.
  /// E.g. "Thus says the LORD: The LORD spoke" → "The LORD spoke".
  /// Returns the whole string if no colon is present.
  String _incipitBodyAfterColon(String incipit) {
    final colonIndex = incipit.indexOf(':');
    if (colonIndex >= 0) return incipit.substring(colonIndex + 1).trim();
    return incipit.trim();
  }

  /// Strips trailing `,:;` from the incipit so it can be used as a display
  /// prefix without double-punctuation.
  String _normalizeTrailingPunct(String incipit) =>
      incipit.trim().replaceAll(RegExp(r'[,:;]+\s*$'), '').trim();

  int _wordCount(String s) =>
      s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  List<String> _tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_kStopWords.contains(t))
      .toList();

  bool _isPropheticIncipit(String incipit) {
    final lower = incipit.toLowerCase();
    return _kPropheticIndicators.any(lower.contains);
  }

  bool _startsWithPropheticRedundancy(String clause) {
    var n = clause.trimLeft().toLowerCase();
    if (n.isEmpty) return false;
    n = n.replaceFirst(RegExp(r'^(?:again|then|now|and|so|but)\s+'), '');
    return _kPropheticClausePrefixes.any(n.startsWith);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Pass 2 — Text cleaning and incipit derivation
  // ─────────────────────────────────────────────────────────────────────────

  /// Cleans and normalizes verse text while PRESERVING newline boundaries
  /// so that per-verse processing (incipit merge, dedupe) works on one verse
  /// at a time — never stripping content across verse boundaries.
  String _cleanVerseText(String rawText) {
    // Split on newlines, clean each line, rejoin. This guarantees that an
    // incipit dedupe cannot accidentally reach into verse 29 while merging
    // verse 13.
    final lines = rawText.split(RegExp(r'\r?\n'));
    final cleaned = <String>[];
    for (final raw in lines) {
      var text = raw;

      // Collapse runs of spaces/tabs (but never newlines) to a single space.
      text = text.replaceAll(RegExp(r'[ \t]+'), ' ');

      // Ensure a single space after closing punctuation and no space before.
      text = text.replaceAllMapped(
        RegExp(r' +([.,;:!?])'),
        (match) => match.group(1)!,
      );
      text = text.replaceAllMapped(
        RegExp(r'([.,;:!?]) +'),
        (match) => '${match.group(1)} ',
      );

      // Strip leftover backslash-number artifacts from some importers.
      text = text.replaceAll(RegExp(r'\\\d+'), '');

      cleaned.add(text.trim());
    }
    // Drop empty lines from the beginning and end; preserve interior blanks.
    while (cleaned.isNotEmpty && cleaned.first.isEmpty) {
      cleaned.removeAt(0);
    }
    while (cleaned.isNotEmpty && cleaned.last.isEmpty) {
      cleaned.removeLast();
    }
    return cleaned.join('\n');
  }

  /// Attempts to derive an official incipit from the verse text.
  /// Returns null if no suitable incipit can be identified.
  String? _deriveIncipit(String text, String reference) {
    if (text.isEmpty) return null;
    
    // Check for book-specific incipit formulas first
    final bookIncipit = _getBookSpecificIncipit(reference, text);
    if (bookIncipit != null) return bookIncipit;
    
    final sentences = text.split(RegExp(r'[.!?]+'));
    if (sentences.isEmpty) return null;
    
    final firstSentence = sentences.first.trim();
    if (firstSentence.isEmpty) return null;
    
    // Check if the first sentence looks like an incipit
    if (_looksLikeIncipit(firstSentence)) {
      return _fixPropheticIncipit(firstSentence);
    }
    
    // Try to extract a shorter incipit from the first sentence
    final words = firstSentence.split(' ');
    if (words.length >= 3) {
      // Take first 3-6 words as potential incipit
      final incipitWords = words.take(6).join(' ');
      if (_looksLikeIncipit(incipitWords)) {
        return _fixPropheticIncipit(incipitWords);
      }
    }
    
    return null;
  }

  /// Gets book-specific incipit formulas for second readings (New Testament)
  String? _getBookSpecificIncipit(String reference, String text) {
    final sentences = text.split(RegExp(r'[.!?]+'));
    if (sentences.isEmpty) return null;
    final firstSentence = sentences.first.trim();
    
    // Paul's letters - use "Brethren:" prefix
    if (RegExp(r'^(Rom|1 Cor|2 Cor|Gal|Eph|Phil|Col|1 Thess|2 Thess|1 Tim|2 Tim|Titus|Philem|Heb)', caseSensitive: false).hasMatch(reference)) {
      // Extract the key phrase from the first sentence
      final keyPhrase = _extractKeyPhrase(firstSentence);
      if (keyPhrase.isNotEmpty) {
        return 'Brethren: $keyPhrase';
      }
    }
    
    // Acts - use narrative style
    if (reference.startsWith('Acts')) {
      if (firstSentence.toLowerCase().startsWith('in those days') ||
          firstSentence.toLowerCase().startsWith('now') ||
          firstSentence.toLowerCase().startsWith('then')) {
        return firstSentence;
      }
      final keyPhrase = _extractKeyPhrase(firstSentence);
      if (keyPhrase.isNotEmpty) {
        // Check if it's about the early church
        if (keyPhrase.toLowerCase().contains('disciples') ||
            keyPhrase.toLowerCase().contains('apostles') ||
            keyPhrase.toLowerCase().contains('church') ||
            keyPhrase.toLowerCase().contains('holy spirit')) {
          return 'In those days: $keyPhrase';
        }
        return keyPhrase;
      }
    }
    
    // Catholic Epistles (Peter, James, John, Jude)
    if (RegExp(r'^(1 Pet|2 Pet|1 John|2 John|3 John|James|Jude)', caseSensitive: false).hasMatch(reference)) {
      final keyPhrase = _extractKeyPhrase(firstSentence);
      if (keyPhrase.isNotEmpty) {
        // For letters, use "Beloved:" or "Brethren:"
        if (reference.contains('John') || reference.contains('Pet')) {
          return 'Beloved: $keyPhrase';
        } else {
          return 'Brethren: $keyPhrase';
        }
      }
    }
    
    // Revelation
    if (reference.startsWith('Rev')) {
      final keyPhrase = _extractKeyPhrase(firstSentence);
      if (keyPhrase.isNotEmpty) {
        return keyPhrase; // Revelation usually stands alone
      }
    }
    
    return null;
  }

  /// Extracts the key phrase from a sentence, removing verse numbers and introductory phrases
  String _extractKeyPhrase(String sentence) {
    var cleaned = sentence.trim();
    
    // Remove verse numbers at the start
    cleaned = cleaned.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
    
    // Remove introductory conjunctions if they appear right after the prefix
    cleaned = cleaned.replaceFirst(RegExp(r'^(and|but)\s+', caseSensitive: false), '');

    // Remove "I write", "We write", "Therefore", "Now", "Thus", "For", "Since", "Because" type phrases
    cleaned = cleaned.replaceFirst(RegExp(r'^(I write|We write|Therefore|Now|Thus|For|Since|Because)\s+', caseSensitive: false), '');
    
    // Remove "I want you to know" type phrases
    cleaned = cleaned.replaceFirst(RegExp(r'^(I want you to know|I do not want you to be unaware|We do not want you to be unaware)\s+', caseSensitive: false), '');
    
    // Capitalize the first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    
    return cleaned.trim();
  }

  /// Fixes prophetic incipits that start with "Again the Lord" or similar patterns
  String _fixPropheticIncipit(String incipit) {
    var fixed = incipit.trim();
    final lower = fixed.toLowerCase();
    
    // Fix "Again the Lord" patterns
    if (lower.startsWith('again the lord')) {
      fixed = fixed.replaceFirst(RegExp(r'^Again\s+', caseSensitive: false), 'The ');
    }
    
    // Fix "Then the Lord said again" patterns  
    if (lower.contains('the lord') && lower.contains('again')) {
      if (lower.startsWith('then')) {
        fixed = fixed.replaceFirst(RegExp(r'^Then\s+', caseSensitive: false), '');
      }
      // Remove "again" from middle of sentence
      fixed = fixed.replaceFirst(RegExp(r'\s+again\s+', caseSensitive: false), ' ');
    }
    
    // Fix "And the Lord spoke again" patterns
    if (lower.startsWith('and the lord') && lower.contains('again')) {
      fixed = fixed.replaceFirst(RegExp(r'^And\s+', caseSensitive: false), '');
      fixed = fixed.replaceFirst(RegExp(r'\s+again\s+', caseSensitive: false), ' ');
    }
    
    // Fix "The Lord spoke again" patterns
    if (lower.startsWith('the lord') && lower.contains('again')) {
      fixed = fixed.replaceFirst(RegExp(r'\s+again\s+', caseSensitive: false), ' ');
    }
    
    // Clean up any double spaces
    fixed = fixed.replaceAll(RegExp(r'\s+'), ' ');
    
    return fixed.trim();
  }

  /// Determines if a text segment looks like a valid incipit.
  /// Checks for common incipit patterns and appropriate length.
  bool _looksLikeIncipit(String text) {
    if (text.length < 10 || text.length > 100) return false;
    
    final lowerText = text.toLowerCase();
    
    // Common incipit indicators
    final incipitPatterns = [
      'at that time',
      'in those days',
      'jesus said',
      'the lord said',
      'the lord says',
      'thus says the lord',
      'brethren',
      'beloved',
      'my son',
      'hear',
      'behold',
      'thus',
    ];
    
    // Check if text starts with any incipit pattern
    for (final pattern in incipitPatterns) {
      if (lowerText.startsWith(pattern)) {
        return true;
      }
    }
    
    // Check for prophetic speech patterns
    if (lowerText.contains('saying') || 
        lowerText.contains('spoke') || 
        lowerText.contains('declared')) {
      return true;
    }
    
    // Check if it's a complete sentence with appropriate structure
    if (RegExp(r'^[A-Z][a-z].*[.!?]$').hasMatch(text)) {
      return true;
    }
    
    return false;
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  // Constants
  // ─────────────────────────────────────────────────────────────────────────────

const Set<String> _kStopWords = {
  'a', 'an', 'the', 'to', 'of', 'in', 'on', 'at', 'by', 'for', 'with',
  'and', 'or', 'but', 'so', 'that', 'this', 'these', 'those',
  'is', 'are', 'was', 'were', 'be', 'been', 'being',
  'from', 'as', 'it', 'its', 'into', 'than', 'while',
  'after', 'before', 'once', 'when', 'there', 'here',
  'because', 'even', 'also', 'yet', 'still', 'again', 'then', 'now',
};

const List<String> _kPropheticIndicators = [
  'thus says the lord',
  'thus says the lord god',
  'thus saith the lord',
  'the lord says',
  'the lord said',
  'the lord spoke',
  'the word of the lord',
  'hear the word of the lord',
];

const List<String> _kIncipitOpeners = [
  'in those days',
  'at that time',
  'brethren',
  'beloved',
  'my son',
  'my sons',
  'my brothers',
  'my brothers and sisters',
  'dearly beloved',
  'thus says the lord',
  'thus says the lord god',
  'thus saith the lord',
  'hear the word of the lord',
  'the word of the lord',
  'on that day',
  'one day',
  'once,',
  'jesus said',
  'the lord said',
  'the lord spoke',
  'the lord says',
  'the spirit of the lord',
];

const List<String> _kPropheticClausePrefixes = [
  'the lord said',
  'the lord spoke',
  'the lord says',
  'the lord declared',
  'the lord god said',
  'the lord god spoke',
  'the lord has said',
  'the lord has spoken',
  'the lord proclaimed',
  'the lord announces',
  'the lord proclaims',
  'the lord will say',
  'the lord god says',
  'the word of the lord came',
  'hear the word of the lord',
  'says the lord',
  'declares the lord',
  'again the lord',
  'then the lord',
];
