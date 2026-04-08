import '../models/prayer.dart';

class PrayerContentParser {
  static const String _latinMarker = 'In Latin';
  static const String _latinMarkerColon = 'In Latin:';

  static Prayer parsePrayerContent(Prayer originalPrayer) {
    final contentByLanguage = <String, List<String>>{};
    final availableLanguages = <String>[];

    // Parse text content
    final englishContent = <String>[];
    final latinContent = <String>[];
    bool isLatinSection = false;

    for (final line in originalPrayer.text) {
      final trimmedLine = line.trim();
      
      if (trimmedLine == _latinMarker || trimmedLine == _latinMarkerColon) {
        isLatinSection = true;
        continue;
      }

      if (isLatinSection) {
        if (trimmedLine.isNotEmpty) {
          latinContent.add(line);
        }
      } else {
        if (trimmedLine.isNotEmpty) {
          englishContent.add(line);
        }
      }
    }

    // Add English content if available
    if (englishContent.isNotEmpty) {
      contentByLanguage['en'] = englishContent;
      availableLanguages.add('en');
    }

    // Add Latin content if available
    if (latinContent.isNotEmpty) {
      contentByLanguage['la'] = latinContent;
      availableLanguages.add('la');
    }

    // Parse HTML content if available
    if (originalPrayer.htmlContent != null && originalPrayer.htmlContent!.isNotEmpty) {
      final htmlLanguages = _parseHtmlContent(originalPrayer.htmlContent!);
      contentByLanguage.addAll(htmlLanguages);
      
      // Update available languages from HTML parsing
      for (final lang in htmlLanguages.keys) {
        if (!availableLanguages.contains(lang)) {
          availableLanguages.add(lang);
        }
      }
    }

    // Only update if we found language-separated content
    if (contentByLanguage.isNotEmpty) {
      return originalPrayer.copyWith(
        contentByLanguage: contentByLanguage,
        availableLanguages: availableLanguages,
      );
    }

    return originalPrayer;
  }

  static Map<String, List<String>> _parseHtmlContent(String htmlContent) {
    final contentByLanguage = <String, List<String>>{};
    final englishContent = <String>[];
    final latinContent = <String>[];
    
    final lines = htmlContent.split('\n');
    bool isLatinSection = false;

    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // Check for Latin markers in HTML
      if (trimmedLine.contains('<b>') && 
          (trimmedLine.contains(_latinMarker) || trimmedLine.contains(_latinMarkerColon))) {
        isLatinSection = true;
        continue;
      }

      // Skip HTML tags but keep content
      final cleanLine = _cleanHtmlLine(line);
      
      if (isLatinSection) {
        if (cleanLine.isNotEmpty) {
          latinContent.add(cleanLine);
        }
      } else {
        if (cleanLine.isNotEmpty) {
          englishContent.add(cleanLine);
        }
      }
    }

    if (englishContent.isNotEmpty) {
      contentByLanguage['en'] = englishContent;
    }
    
    if (latinContent.isNotEmpty) {
      contentByLanguage['la'] = latinContent;
    }

    return contentByLanguage;
  }

  static String _cleanHtmlLine(String line) {
    String cleaned = line;

    // Remove common HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decode named HTML entities
    cleaned = cleaned.replaceAll('&nbsp;', '\u00A0');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&quot;', '"');
    cleaned = cleaned.replaceAll('&apos;', "'");
    cleaned = cleaned.replaceAll('&aelig;', 'æ');
    cleaned = cleaned.replaceAll('&AElig;', 'Æ');
    cleaned = cleaned.replaceAll('&oelig;', 'œ');
    cleaned = cleaned.replaceAll('&OElig;', 'Œ');
    cleaned = cleaned.replaceAll('&rsquo;', '\u2019');
    cleaned = cleaned.replaceAll('&lsquo;', '\u2018');
    cleaned = cleaned.replaceAll('&rdquo;', '\u201D');
    cleaned = cleaned.replaceAll('&ldquo;', '\u201C');
    cleaned = cleaned.replaceAll('&mdash;', '\u2014');
    cleaned = cleaned.replaceAll('&ndash;', '\u2013');
    cleaned = cleaned.replaceAll('&hellip;', '\u2026');

    // Decode numeric HTML entities (e.g. &#230; &#x00E6;)
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'&#x([0-9A-Fa-f]+);'),
      (m) {
        final codePoint = int.tryParse(m.group(1)!, radix: 16);
        return codePoint != null ? String.fromCharCode(codePoint) : m.group(0)!;
      },
    );
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final codePoint = int.tryParse(m.group(1)!);
        return codePoint != null ? String.fromCharCode(codePoint) : m.group(0)!;
      },
    );

    return cleaned.trim();
  }
}
