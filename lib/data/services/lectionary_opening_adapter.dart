class LectionaryOpeningAdaptation {
  final String text;
  final bool applied;
  final String reason;
  final int anchorCharacters;

  const LectionaryOpeningAdaptation({
    required this.text,
    required this.applied,
    required this.reason,
    required this.anchorCharacters,
  });
}

class LectionaryOpeningAdapter {
  static const int defaultSourceLimit = 220;
  static const int defaultSearchWindow = 250;
  static const int defaultMinimumAnchorCharacters = 50;

  LectionaryOpeningAdaptation adapt({
    required String sourceOpening,
    required String renderedText,
    int sourceLimit = defaultSourceLimit,
    int searchWindow = defaultSearchWindow,
    int minimumAnchorCharacters = defaultMinimumAnchorCharacters,
  }) {
    final sourcePrefixWindow = _takePrefix(sourceOpening, sourceLimit);
    final renderedPrefixWindow = _takePrefix(renderedText, searchWindow);

    final sourceTokens = _tokenize(sourcePrefixWindow);
    final renderedTokens = _tokenize(renderedPrefixWindow);
    if (sourceTokens.isEmpty || renderedTokens.isEmpty) {
      return _unchanged(renderedText, 'empty-input');
    }

    final anchor = _findBestAnchor(
      sourceTokens: sourceTokens,
      renderedTokens: renderedTokens,
      minimumAnchorCharacters: minimumAnchorCharacters,
    );
    if (anchor == null) {
      final fullAnchor = _findBestAnchor(
        sourceTokens: sourceTokens,
        renderedTokens: _tokenize(renderedText),
        minimumAnchorCharacters: minimumAnchorCharacters,
      );
      return _unchanged(
        renderedText,
        fullAnchor == null ? 'no-strong-anchor' : 'no-early-anchor',
      );
    }
    if (anchor.ambiguous) {
      return _unchanged(renderedText, 'ambiguous-anchor');
    }

    final sourceAnchorStart = sourceTokens[anchor.sourceStart].start;
    final renderedAnchorStart = renderedTokens[anchor.renderedStart].start;
    final sourcePrefix = sourcePrefixWindow.substring(0, sourceAnchorStart);

    if (sourcePrefix.trim().isEmpty) {
      return _unchanged(renderedText, 'empty-source-prefix');
    }

    return LectionaryOpeningAdaptation(
      text: '$sourcePrefix${renderedText.substring(renderedAnchorStart)}',
      applied: true,
      reason: 'adapted',
      anchorCharacters: anchor.normalizedCharacters,
    );
  }

  LectionaryOpeningAdaptation _unchanged(String text, String reason) {
    return LectionaryOpeningAdaptation(
      text: text,
      applied: false,
      reason: reason,
      anchorCharacters: 0,
    );
  }

  _Anchor? _findBestAnchor({
    required List<_Token> sourceTokens,
    required List<_Token> renderedTokens,
    required int minimumAnchorCharacters,
  }) {
    _Anchor? best;
    var bestCount = 0;

    for (
      var sourceIndex = 0;
      sourceIndex < sourceTokens.length;
      sourceIndex++
    ) {
      for (
        var renderedIndex = 0;
        renderedIndex < renderedTokens.length;
        renderedIndex++
      ) {
        var length = 0;
        while (sourceIndex + length < sourceTokens.length &&
            renderedIndex + length < renderedTokens.length &&
            sourceTokens[sourceIndex + length].normalized ==
                renderedTokens[renderedIndex + length].normalized) {
          length++;
        }
        if (length == 0) continue;

        final normalizedCharacters = _normalizedCharacterCount(
          sourceTokens,
          sourceIndex,
          length,
        );
        if (normalizedCharacters < minimumAnchorCharacters) continue;

        if (length > bestCount) {
          bestCount = length;
          best = _Anchor(
            sourceStart: sourceIndex,
            renderedStart: renderedIndex,
            tokenCount: length,
            normalizedCharacters: normalizedCharacters,
          );
        } else if (length == bestCount && best != null) {
          best = best.copyWith(ambiguous: true);
        }
      }
    }

    return best;
  }

  static int _normalizedCharacterCount(
    List<_Token> tokens,
    int start,
    int length,
  ) {
    var count = 0;
    for (var i = start; i < start + length; i++) {
      count += tokens[i].normalized.length;
      if (i > start) count += 1;
    }
    return count;
  }

  static String _takePrefix(String text, int limit) {
    if (text.length <= limit) return text;
    return text.substring(0, limit);
  }

  static List<_Token> _tokenize(String text) {
    final tokens = <_Token>[];
    final regex = RegExp(r"[A-Za-z0-9]+(?:'[A-Za-z0-9]+)?");
    for (final match in regex.allMatches(text)) {
      tokens.add(
        _Token(
          normalized: match.group(0)!.toLowerCase(),
          start: match.start,
          end: match.end,
        ),
      );
    }
    return tokens;
  }
}

class _Anchor {
  final int sourceStart;
  final int renderedStart;
  final int tokenCount;
  final int normalizedCharacters;
  final bool ambiguous;

  const _Anchor({
    required this.sourceStart,
    required this.renderedStart,
    required this.tokenCount,
    required this.normalizedCharacters,
    this.ambiguous = false,
  });

  _Anchor copyWith({bool? ambiguous}) {
    return _Anchor(
      sourceStart: sourceStart,
      renderedStart: renderedStart,
      tokenCount: tokenCount,
      normalizedCharacters: normalizedCharacters,
      ambiguous: ambiguous ?? this.ambiguous,
    );
  }
}

class _Token {
  final String normalized;
  final int start;
  final int end;

  const _Token({
    required this.normalized,
    required this.start,
    required this.end,
  });
}
