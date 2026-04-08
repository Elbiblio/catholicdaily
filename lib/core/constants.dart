// Core constants for the Catholic Daily app
// Centralizes magic numbers, durations, and configuration values

/// API and Network Constants
class ApiConstants {
  static const String baseUrl = 'https://api.elbiblio.com';
  static const String apiVersion = '/api';
  static const int defaultTimeoutSeconds = 45;
  static const int shortTimeoutSeconds = 15;
  static const int maxRetries = 3;
}

/// UI Timing Constants
class UiConstants {
  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  
  // Delays for async operations
  static const Duration navigationDelay = Duration(milliseconds: 100);
  static const Duration debounceDelay = Duration(milliseconds: 300);
  static const Duration shimmerDelay = Duration(milliseconds: 1500);
  
  // Loading indicators
  static const int maxLoadingIndicatorLines = 3;
}

/// Layout Constants
class LayoutConstants {
  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  
  // Border radius
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  
  // Component sizes
  static const double iconSizeSm = 16.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double buttonHeight = 48.0;
  static const double appBarHeight = 56.0;
  static const double expandedAppBarHeight = 156.0;
  
  // Card dimensions
  static const double cardElevation = 2.0;
  static const double cardElevationPressed = 4.0;
}

/// Reading Display Constants
class ReadingConstants {
  // Text scaling
  static const double minTextScale = 0.8;
  static const double defaultTextScale = 1.0;
  static const double maxTextScale = 1.5;
  static const double textScaleStep = 0.1;
  
  // Content limits
  static const int maxInsightTextLength = 3000;
  static const int maxShareTextLength = 5000;
  static const int maxVersesPerReading = 200;
  
  // Line heights
  static const double verseLineHeight = 1.6;
  static const double titleLineHeight = 1.2;
  
  // Loading states
  static const int maxLoadingIndicatorLines = 3;
  
  // Font sizes
  static const double verseNumberSize = 12.0;
  static const double referenceFontSize = 16.0;
}

/// Cache Constants
class CacheConstants {
  // Cache durations
  static const Duration psalmResponseCacheDuration = Duration(hours: 24);
  static const Duration readingsCacheDuration = Duration(hours: 12);
  static const Duration insightsCacheDuration = Duration(days: 7);
  static const Duration churchCacheDuration = Duration(days: 30);
  
  // Max cache sizes
  static const int maxBookmarkedReadings = 100;
  static const int maxCachedPsalms = 50;
  static const int maxRecentPrayers = 20;
}

/// Navigation Constants
class NavigationConstants {
  // Routes (if using named routes)
  static const String homeRoute = '/';
  static const String readingRoute = '/reading';
  static const String prayersRoute = '/prayers';
  static const String settingsRoute = '/settings';
  static const String churchLocatorRoute = '/churches';
  
  // Transition durations
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
}

/// Liturgical Constants
class LiturgicalConstants {
  // Season colors with hex values for reference
  static const int adventColor = 0xFF4B0082;      // Purple
  static const int christmasColor = 0xFFFFFFFF;    // White
  static const int lentColor = 0xFF8B4513;       // Rose/Brown
  static const int easterColor = 0xFFFFD700;     // Gold
  static const int ordinaryTimeColor = 0xFF008000; // Green
  
  // Special days
  static const int ashWednesdayOffset = 46;  // Days before Easter
  static const int palmSundayOffset = 7;
  static const int holyThursdayOffset = 3;
  static const int goodFridayOffset = 2;
  static const int holySaturdayOffset = 1;
  static const int easterOffset = 0;
  static const int ascensionOffset = 39;
  static const int pentecostOffset = 49;
  static const int corpusChristiOffset = 60;
}

/// Error Messages
class ErrorMessages {
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Unable to connect. Please check your internet connection.';
  static const String loadingError = 'Failed to load content. Please try again.';
  static const String navigationError = 'Unable to navigate. Please try again.';
  static const String bookmarkError = 'Failed to save bookmark.';
  static const String shareError = 'Unable to share content.';
  static const String ttsError = 'Text-to-speech is not available.';
  static const String locationError = 'Unable to get your location.';
  static const String offlineError = 'This content is not available offline.';
}
