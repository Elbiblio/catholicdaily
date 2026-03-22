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
    // Remove HTML tags but preserve text content
    String cleaned = line;
    
    // Remove common HTML tags
    cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');
    cleaned = cleaned.replaceAll('&nbsp;', ' ');
    cleaned = cleaned.replaceAll('&amp;', '&');
    cleaned = cleaned.replaceAll('&lt;', '<');
    cleaned = cleaned.replaceAll('&gt;', '>');
    cleaned = cleaned.replaceAll('&#146;', "'");
    cleaned = cleaned.replaceAll('&#225;', 'á');
    cleaned = cleaned.replaceAll('&#233;', 'é');
    cleaned = cleaned.replaceAll('&#237;', 'í');
    cleaned = cleaned.replaceAll('&#243;', 'ó');
    cleaned = cleaned.replaceAll('&#250;', 'ú');
    cleaned = cleaned.replaceAll('&#193;', 'Á');
    cleaned = cleaned.replaceAll('&#201;', 'É');
    cleaned = cleaned.replaceAll('&#205;', 'Í');
    cleaned = cleaned.replaceAll('&#211;', 'Ó');
    cleaned = cleaned.replaceAll('&#218;', 'Ú');
    
    return cleaned.trim();
  }
}
