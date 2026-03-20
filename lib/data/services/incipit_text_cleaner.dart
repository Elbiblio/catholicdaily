/// Shared utilities for cleaning Bible reading text when an incipit is
/// prepended ahead of the first verse.
///
/// The helpers here encapsulate the logic that trims redundant opening clauses
/// so that only one copy of the incipit-style sentence is rendered.
String cleanFirstLineForIncipit(String text, String incipitPrefix) {
  final lines = text.split('\n');
  if (lines.isEmpty) return text;

  final firstIdx = lines.indexWhere((line) => line.trim().isNotEmpty);
  if (firstIdx == -1) return text;

  var firstLine = lines[firstIdx].trim();

  // Strip verse-number prefixes such as "12." or "35a "
  firstLine = firstLine.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
  firstLine = firstLine.replaceFirst(RegExp(r'^\d+[a-z]?\s+'), '');

  final stripped = _stripRedundantIncipitClause(firstLine, incipitPrefix);

  // Empty string = the entire first line was the incipit phrase.
  // Remove that line and return whatever follows so the caller can produce
  // "Incipit: [next verse content]" rather than doubling the incipit text.
  if (stripped.isEmpty) {
    lines[firstIdx] = '';
    // Return the remaining content (may itself be empty if the reading had
    // only one verse — callers must guard against that).
    return lines.join('\n').trimLeft();
  }

  // No redundancy detected — leave the text untouched.
  if (stripped == firstLine) return text;

  var result = stripped;

  // Strip any residual leading narrative connector.
  final incipitLower = incipitPrefix.toLowerCase();
  if (incipitLower.contains('in those days') ||
      incipitLower.contains('at that time')) {
    result = result.replaceFirst(
      RegExp(
        r'^(?:Now,?\s*|Then,?\s*|And,?\s*|But,?\s*|So,?\s*|For,?\s*|'
        r'On that day,?\s*|At that time,?\s*|In those days,?\s*|'
        r'One day,?\s*|Once,?\s*|On (?:that|one|a certain) '
        r'(?:day|occasion),?\s*)',
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

  // Capitalize the first character when it is a letter and not already
  // inside an opening quotation mark.  Speech that starts with a quote
  // (e.g. '"I am the light…') is already capitalised inside the quote.
  if (result.isNotEmpty) {
    final ch = result[0];
    if (ch != '"' && ch != '\u201C' && ch != "'") {
      result = ch.toUpperCase() + result.substring(1);
    }
  }

  lines[firstIdx] = result;
  return lines.join('\n');
}

/// Finds and removes the portion of [firstLine] that duplicates content
/// already expressed in [incipitPrefix], returning the non-redundant remainder.
///
/// Returns [firstLine] unchanged when insufficient overlap is detected.
/// Returns an **empty string** when the ENTIRE first line is the incipit
/// phrase — the caller should skip that line and advance to the next verse.
String _stripRedundantIncipitClause(String firstLine, String incipitPrefix) {
  final incipitTokens = _tokenizeForIncipitComparison(incipitPrefix);
  if (incipitTokens.length < 2) return firstLine;

  // ── Sequential token alignment ──────────────────────────────────────────
  // Walk the incipit tokens in order, searching for each one inside a
  // sliding window over the lower-cased verse text.  Tokens not found within
  // the window are silently skipped, which accommodates pronoun/synonym
  // substitutions such as "people" → "them" or "him" → "Jesus".
  //
  // Positions are tracked on a punctuation-normalised copy of the line (where
  // non-word chars become spaces, preserving byte length for safe substring ops).
  final lowerLine =
      firstLine.toLowerCase().replaceAll(RegExp(r"[^\w\s']"), ' ');

  int lastMatchEnd = -1;
  int matchedCount = 0;
  int searchFrom = 0;
  // Characters to scan ahead per token — large enough for verbose prophetic
  // formulae, small enough to avoid false-positive matches deep in the verse.
  const int kWindowPerToken = 90;

  for (final token in incipitTokens) {
    final windowEnd =
        (searchFrom + kWindowPerToken).clamp(0, lowerLine.length);
    final segment = lowerLine.substring(searchFrom, windowEnd);
    final match =
        RegExp('\\b${RegExp.escape(token)}\\b').firstMatch(segment);
    if (match != null) {
      lastMatchEnd = searchFrom + match.end;
      searchFrom = lastMatchEnd;
      matchedCount++;
    }
    // Unmatched token → keep searchFrom where it is; the next token gets its
    // own fresh window starting from the same position.
  }

  final ratio = matchedCount / incipitTokens.length;

  // Detect prophetic-formula redundancy independently of token ratio, because
  // short formulae like "Thus says the LORD" share few tokens with a verse
  // that begins "The LORD spoke to Ahaz, saying, …".
  final isPropheticRedundancy = _isPropheticIncipit(incipitPrefix) &&
      _clauseStartsWithPropheticRedundancy(firstLine);

  if (!isPropheticRedundancy && ratio < 0.6) return firstLine;
  if (lastMatchEnd < 0) return firstLine;

  // ── Build the remainder ─────────────────────────────────────────────────
  var remainder = firstLine.substring(lastMatchEnd).trimLeft();
  
  // Strip verse-number prefixes such as "18." from the remainder for the check
  var remainderForCheck = remainder.replaceFirst(RegExp(r'^\d+[a-z]?\.\s*'), '');
  remainderForCheck = remainderForCheck.replaceFirst(RegExp(r'^\d+[a-z]?\s+'), '');
  
  // Check if the remainder starts with "The Lord" - if so, discard the entire incipit
  if (_firstPropheticLineHasTheLord(remainderForCheck)) {
    return remainder;
  }
  
  //if first line starts with theLord and is Prophetic, trim first incipit
  if (_firstPropheticLineHasTheLord(firstLine)) {
    //last matched end becomes end of first of incipit usually last appearance of :
    final colonIndex = firstLine.indexOf(':', lastMatchEnd - 1);
    if (colonIndex != -1) {
      remainder = firstLine.substring(colonIndex + 1).trimLeft();
    }
  }

  // Strip punctuation that linked the incipit portion to the real content.
  remainder = remainder.replaceFirst(RegExp(r'^[,;:!?.–—\-]+\s*'), '');

  // ── Prophetic-formula extension ─────────────────────────────────────────
  // After matching "lord" in "The LORD spoke to Ahaz, saying, 'Ask a sign…'"
  // the naive remainder is "spoke to Ahaz, saying, 'Ask a sign…'".
  // Strip everything through "saying, " so only the divine word remains.
  if (isPropheticRedundancy) {
    final sayingMatch = RegExp(r'\bsaying\b[,;:]?\s*', caseSensitive: false)
        .firstMatch(remainder);
    if (sayingMatch != null) {
      remainder = remainder.substring(sayingMatch.end).trimLeft();
    } else {
      // No "saying" clause found → the remainder is just a short formula
      // fragment (e.g. "spoke to Ahaz", 3 words).  The entire line IS the
      // incipit; signal the caller to skip it.
      final wc = _wordCount(remainder);
      if (wc <= 4) return '';
    }
  }

  // Strip a bare "saying" lead-in that may start the remainder itself.
  remainder = remainder.replaceFirst(
    RegExp(r'''^["'\u201C\u201D]*\s*saying[,;:]?\s*''', caseSensitive: false),
    '',
  );

  remainder = remainder.trimLeft();

  // ── Trivial-fragment guard ──────────────────────────────────────────────
  // A single-word remainder is almost always a proper noun standing in for a
  // pronoun (e.g. "him" → "Jesus").  The whole line was effectively the
  // incipit; tell the caller to skip it entirely.
  if (_wordCount(remainder) <= 1 && ratio >= 0.75) return '';

  return remainder;
}

int _wordCount(String s) =>
    s.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

List<String> _tokenizeForIncipitComparison(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r"[^\w\s']"), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && !_incipitStopWords.contains(token))
      .toList();
}

/// Returns true when [text] contains [word] as a complete word.
bool _containsWord(String text, String word) {
  // Both halves use non-raw string literals so '\b' is the regex word-boundary
  // escape — NOT the literal two-character sequence that a raw r'\b' produces.
  return RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false)
      .hasMatch(text);
}

bool _isPropheticIncipit(String incipit) {
  final lower = incipit.toLowerCase();
  return _propheticIncipitIndicators.any(lower.contains);
}

bool _clauseStartsWithPropheticRedundancy(String clause) {
  var normalized = clause.trimLeft().toLowerCase();
  if (normalized.isEmpty) return false;

  normalized = normalized.replaceFirst(
    RegExp(r'^(?:again|then|now|and|so|but)\s+'),
    '',
  );

  for (final prefix in _propheticClausePrefixes) {
    if (normalized.startsWith(prefix)) {
      return true;
    }
  }
  return false;
}

bool _firstPropheticLineHasTheLord(String clause) {
  var normalized = clause.trimLeft().toLowerCase();
  if (normalized.isEmpty) return false;

  //regex ignore case test if the clause starts with 'The Lord'
  if (RegExp(r'^the lord', caseSensitive: false).hasMatch(normalized)) {
    return true;
  }

  return false;
}

const Set<String> _incipitStopWords = {
  'a',
  'an',
  'the',
  'to',
  'of',
  'in',
  'on',
  'at',
  'by',
  'for',
  'with',
  'and',
  'or',
  'but',
  'so',
  'that',
  'this',
  'these',
  'those',
  'is',
  'are',
  'was',
  'were',
  'be',
  'been',
  'being',
  'from',
  'as',
  'it',
  'its',
  'into',
  'than',
  'while',
  'after',
  'before',
  'once',
  'when',
  'there',
  'here',
  'because',
  'even',
  'also',
  'yet',
  'still',
  'again',
  'then',
  'now',
};

const List<String> _propheticIncipitIndicators = [
  'thus says the lord',
  'thus says the lord god',
  'thus saith the lord',
  'the lord says',
  'the lord said',
  'the lord spoke',
  'the word of the lord',
  'hear the word of the lord',
];

const List<String> _propheticClausePrefixes = [
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
