import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fetches live Prayers of the Faithful from biddingprayers.com via the
/// WordPress REST API (category 11 = "Prayers of the Faithful for Today").
///
/// Strategy:
/// 1. Compute the ISO-week Monday for the requested date.
/// 2. Query wp-json/wp/v2/posts with after/before spanning that week.
/// 3. Parse the HTML content.rendered to extract Option-1 petitions for
///    the specific weekday.
/// 4. Cache per ISO-week string to avoid redundant network calls.
class BiddingPrayersService {
  BiddingPrayersService._();
  static final BiddingPrayersService instance = BiddingPrayersService._();

  static const String _baseUrl = 'https://biddingprayers.com/wp-json/wp/v2/posts';
  static const int _categoryId = 11;
  static const Duration _timeout = Duration(seconds: 12);

  // Cache: ISO-week key (e.g. "2026-W16") -> parsed day petitions map
  final Map<String, Map<String, List<String>>> _weekCache = {};

  // -------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------

  /// Returns Option-1 petitions for [date] as a formatted string, or null
  /// if the content is unavailable (network error, not yet published, etc.).
  Future<String?> getPetitionsForDate(DateTime date) async {
    final weekKey = _isoWeekKey(date);
    if (!_weekCache.containsKey(weekKey)) {
      await _fetchAndCacheWeek(date, weekKey);
    }
    final dayMap = _weekCache[weekKey];
    if (dayMap == null) return null;

    final dayKey = _dayKey(date);
    final petitions = dayMap[dayKey];
    if (petitions == null || petitions.isEmpty) return null;

    return _formatPetitions(petitions, date);
  }

  // -------------------------------------------------------------------
  // Fetching
  // -------------------------------------------------------------------

  Future<void> _fetchAndCacheWeek(DateTime date, String weekKey) async {
    try {
      final monday = _mondayOf(date);
      final sunday = monday.add(const Duration(days: 6));

      // after/before use ISO 8601; WP compares against post published date.
      // We add one day of buffer on each side for timezone safety.
      final after = monday.subtract(const Duration(days: 1)).toIso8601String();
      final before = sunday.add(const Duration(days: 1)).toIso8601String();

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'categories': '$_categoryId',
        'after': after,
        'before': before,
        'per_page': '1',
        'orderby': 'date',
        'order': 'asc',
        '_fields': 'content,date,title',
      });

      debugPrint('BiddingPrayers: fetching $uri');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('BiddingPrayers: HTTP ${response.statusCode}');
        _weekCache[weekKey] = {};
        return;
      }

      final List<dynamic> posts = jsonDecode(response.body) as List<dynamic>;
      if (posts.isEmpty) {
        debugPrint('BiddingPrayers: no post found for week $weekKey');
        _weekCache[weekKey] = {};
        return;
      }

      final html = (posts.first['content']?['rendered'] as String?) ?? '';
      debugPrint('BiddingPrayers: parsing HTML (${html.length} chars)');
      _weekCache[weekKey] = _parseWeekHtml(html, monday);
    } catch (e) {
      debugPrint('BiddingPrayers: fetch error – $e');
      _weekCache[weekKey] = {};
    }
  }

  // -------------------------------------------------------------------
  // HTML parsing
  // -------------------------------------------------------------------

  /// Parses the post HTML and returns a map of day-key -> list of petitions.
  ///
  /// The HTML structure (confirmed from live responses):
  ///   <h3 ...>Monday – June 9th 2025 (...)</h3>
  ///   <ol class="wp-block-list">
  ///     <li>petition 1...</li>
  ///     <li>petition 2...</li>
  ///   </ol>
  ///   <p><strong>OPTION #2:</strong></p>
  ///   <ol>...</ol>   ← we stop before this
  ///
  /// We only extract Option 1 (the first <ol> after each <h3> day heading).
  Map<String, List<String>> _parseWeekHtml(String html, DateTime weekMonday) {
    final result = <String, List<String>>{};

    // Normalise line endings
    final normalized = html.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Split on <h3 …> day section headers.
    // Each section starts with a day name.
    final h3Pattern = RegExp(
      r'<h3[^>]*>(.*?)</h3>',
      caseSensitive: false,
      dotAll: true,
    );

    final sections = <_Section>[];
    for (final m in h3Pattern.allMatches(normalized)) {
      sections.add(_Section(
        heading: _stripTags(m.group(1) ?? ''),
        startIndex: m.end,
      ));
    }

    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final dayName = _extractDayName(section.heading);
      if (dayName == null) continue;

      final end = i + 1 < sections.length
          ? sections[i + 1].startIndex
          : normalized.length;
      final chunk = normalized.substring(section.startIndex, end);

      final petitions = _extractOption1Petitions(chunk);
      if (petitions.isNotEmpty) {
        result[dayName.toLowerCase()] = petitions;
      }
    }

    return result;
  }

  /// Extracts only the first <ol> block (Option 1) petitions from a day chunk.
  List<String> _extractOption1Petitions(String chunk) {
    // Find where OPTION #2 begins so we don't bleed into it
    final option2 = RegExp(r'OPTION\s*#?\s*2', caseSensitive: false);
    final option2Match = option2.firstMatch(chunk);
    final relevantChunk =
        option2Match != null ? chunk.substring(0, option2Match.start) : chunk;

    // Extract all <li> items from the first <ol>
    final olPattern = RegExp(
      r'<ol[^>]*>(.*?)</ol>',
      caseSensitive: false,
      dotAll: true,
    );
    final olMatch = olPattern.firstMatch(relevantChunk);
    if (olMatch == null) return [];

    final liPattern = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );

    final petitions = <String>[];
    for (final li in liPattern.allMatches(olMatch.group(1) ?? '')) {
      final text = _cleanPetitionText(li.group(1) ?? '');
      if (text.isNotEmpty) {
        petitions.add(text);
      }
    }

    // Also pick up standing intentions (I. / II. paragraphs before OPTION #2)
    final standingPattern = RegExp(
      r'<p[^>]*>\s*(?:I{1,2})\.\s*(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final m in standingPattern.allMatches(relevantChunk)) {
      final text = _cleanPetitionText(m.group(1) ?? '');
      if (text.isNotEmpty) {
        petitions.add(text);
      }
    }

    return petitions;
  }

  // -------------------------------------------------------------------
  // Formatting
  // -------------------------------------------------------------------

  String _formatPetitions(List<String> petitions, DateTime date) {
    final response = 'Lord, hear our prayer.';
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    buffer.writeln('(Universal Prayer)');
    buffer.writeln();
    buffer.writeln('Response: $response');
    buffer.writeln();

    for (var i = 0; i < petitions.length; i++) {
      buffer.writeln('${i + 1}. ${petitions[i]}');
      buffer.writeln('   R. $response');
      if (i < petitions.length - 1) buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  /// Returns the lowercase English day name from a heading like
  /// "Monday – June 9th 2025 (Memorial of...)" → "monday"
  String? _extractDayName(String heading) {
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final lower = heading.toLowerCase();
    for (final day in days) {
      if (lower.startsWith(day)) return day;
    }
    return null;
  }

  /// Day key used as map key, matching _extractDayName output.
  String _dayKey(DateTime date) {
    const names = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    // DateTime weekday: 1=Monday … 7=Sunday
    return names[date.weekday - 1];
  }

  /// ISO week key, e.g. "2026-W16"
  String _isoWeekKey(DateTime date) {
    final monday = _mondayOf(date);
    // ISO week number: day of year of Monday / 7 + 1 (approx; good enough for cache key)
    final jan4 = DateTime(monday.year, 1, 4);
    final jan4Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final weekNum = (monday.difference(jan4Monday).inDays ~/ 7) + 1;
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  DateTime _mondayOf(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#8217;', "'")
        .replaceAll('&#8216;', "'")
        .replaceAll('&#8220;', '"')
        .replaceAll('&#8221;', '"')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanPetitionText(String html) {
    // Remove <br> and replace with space so inline I./II. don't merge
    final withBreaks = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    return _stripTags(withBreaks)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _Section {
  final String heading;
  final int startIndex;
  const _Section({required this.heading, required this.startIndex});
}
