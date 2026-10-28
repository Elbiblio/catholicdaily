import 'dart:math' as math;

import '../models/hymn.dart';

/// A small in-memory index of the bundled hymnal. Rare words carry more weight
/// than words common throughout the collection.
class HymnTextIndex {
  static const _stopWords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'by',
    'for',
    'from',
    'he',
    'her',
    'his',
    'i',
    'in',
    'is',
    'it',
    'me',
    'my',
    'of',
    'on',
    'our',
    'so',
    'that',
    'the',
    'their',
    'them',
    'they',
    'this',
    'to',
    'us',
    'was',
    'we',
    'with',
    'you',
    'your',
    'lord',
    'god',
    'shall',
    'will',
  };

  final Map<int, Map<String, double>> _documents = {};
  final Map<String, int> _documentFrequency = {};
  final Map<String, Set<String>> _queries = {};
  final int _documentCount;

  HymnTextIndex(List<Hymn> hymns) : _documentCount = hymns.length {
    for (final hymn in hymns) {
      final terms = <String, double>{};
      void add(String text, double weight) {
        for (final token in _tokens(text).toSet()) {
          terms[token] = (terms[token] ?? 0) + weight;
        }
      }

      add(hymn.title, 3);
      add(hymn.firstLine ?? '', 1.5);
      add('${hymn.category} ${hymn.tags.join(' ')} ${hymn.themes ?? ''}', 2);
      add(hymn.displayLyrics.join(' '), 1);
      _documents[hymn.id] = terms;
      for (final token in terms.keys) {
        _documentFrequency[token] = (_documentFrequency[token] ?? 0) + 1;
      }
    }
  }

  static Iterable<String> _tokens(String text) => RegExp(r"[a-z]+(?:'[a-z]+)?")
      .allMatches(text.toLowerCase().replaceAll('’', "'"))
      .map((match) => match.group(0)!)
      .where((token) => token.length > 2 && !_stopWords.contains(token));

  /// Returns a relevance score for this reading text.
  double score(Hymn hymn, String readingText) {
    if (_queries.length >= 64 && !_queries.containsKey(readingText)) {
      _queries.clear();
    }
    final query = _queries.putIfAbsent(
      readingText,
      () => _tokens(readingText).toSet(),
    );
    final document = _documents[hymn.id];
    if (query.isEmpty || document == null || _documentCount == 0) return 0;
    double matched = 0;
    double total = 0;
    for (final token in query) {
      final frequency = _documentFrequency[token] ?? 0;
      if (frequency == 0) continue;
      final idf = math.log(1 + (_documentCount + 1) / (frequency + 1));
      total += idf;
      final fieldWeight = document[token] ?? 0;
      if (fieldWeight > 0) matched += idf * math.min(fieldWeight / 4, 1);
    }
    return total == 0 ? 0 : 10 * matched / math.sqrt(total);
  }
}
