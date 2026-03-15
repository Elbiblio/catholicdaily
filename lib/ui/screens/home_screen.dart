import 'package:flutter/material.dart';
import 'premium_browse_screen.dart';
import 'search_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import '../../data/models/bible_version.dart';
import '../../data/services/theme_preferences.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/models/reading_session.dart';
import '../../data/services/readings_backend_io.dart';
import '../../data/services/reading_flow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/daily_reading.dart';

typedef ReadingSelectionHandler = void Function(
  String reference,
  String content,
  LiturgicalDay? liturgicalDay, [
  DailyReading? readingData,
  List<DailyReading>? readingSet,
  int? selectedIndex,
]);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.themeStyle,
    required this.onThemeModeChanged,
    required this.onThemeStyleChanged,
  });

  final ThemeMode themeMode;
  final AppThemeStyle themeStyle;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<AppThemeStyle> onThemeStyleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _keyLastTabIndex = 'home_last_tab_index';
  static const _keyLastReadingReference = 'last_reading_reference';
  static const _keyLastReadingContent = 'last_reading_content';

  int _currentIndex = 0;
  String? _lastReadingReference;
  String? _lastReadingContent;
  bool _resumedOnLaunch = false;

  List<BibleVersion> _versions = [];
  bool _isLoading = true;
  ReadingSession _readingSession = ReadingSession.empty();
  final DateTime _currentDate = DateTime.now();
  
  final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();
  final ReadingFlowService _readingFlow = ReadingFlowService.instance;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _currentIndex = prefs.getInt(_keyLastTabIndex) ?? 0;
    _lastReadingReference = prefs.getString(_keyLastReadingReference);
    _lastReadingContent = prefs.getString(_keyLastReadingContent);

    _versions = [
      BibleVersion(
        id: 'rsvce',
        name: 'Revised Standard Version Catholic Edition',
        abbreviation: 'RSVCE',
        isDownloaded: true,
        size: 0,
      ),
    ];
    
    // Load current day's readings
    await _loadCurrentReadings();
    
    setState(() => _isLoading = false);

    if (!_resumedOnLaunch &&
        (_lastReadingReference?.isNotEmpty ?? false) &&
        (_lastReadingContent?.isNotEmpty ?? false)) {
      _resumedOnLaunch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openReading(
          reference: _lastReadingReference!,
          content: _lastReadingContent!,
          liturgicalDay: null,
        );
      });
    }
  }

  Future<void> _loadCurrentReadings() async {
    try {
      final rawReadings = await _readingsBackend.getReadingsForDate(_currentDate);

      final hydrated = await _readingFlow.hydrateReadingSet(
        date: _currentDate,
        readings: rawReadings,
      );

      _readingSession = _readingFlow.buildSession(
        readings: hydrated.readings,
        readingTexts: hydrated.readingTexts,
        selectedIndex: 0,
      );
    } catch (e) {
      debugPrint('Error loading current readings: $e');
      _readingSession = ReadingSession.empty();
    }
  }

  void _onReadingSelected(
    String reference,
    String content,
    LiturgicalDay? liturgicalDay, [
    DailyReading? readingData,
    List<DailyReading>? readingSet,
    int? selectedIndex,
  ]) {
    if (readingSet != null) {
      _readingSession = _readingFlow.buildSession(
        readings: readingSet,
        readingTexts: {},
        selectedIndex: selectedIndex ?? 0,
      );
      _primeReadingTexts(readingSet);
    }

    if (selectedIndex == null && readingData != null && !_readingSession.isEmpty) {
      final resolvedIndex = _readingSession.readings.indexOf(readingData);
      if (resolvedIndex >= 0) {
        _readingSession = _readingSession.copyWith(currentIndex: resolvedIndex);
      }
    }
    
    _persistLastReading(reference: reference, content: content);
    _openReading(
      reference: reference,
      content: content,
      liturgicalDay: liturgicalDay,
      readingData: readingData,
    );
  }

  Future<void> _primeReadingTexts(List<DailyReading> readings) async {
    final updatedTexts = Map<String, String>.from(_readingSession.readingTexts);
    for (final reading in readings) {
      if (updatedTexts.containsKey(reading.reading)) continue;
      try {
        final text = await _readingFlow.getReadingText(reading);
        updatedTexts[reading.reading] = text;
      } catch (_) {
        updatedTexts[reading.reading] = reading.reading;
      }
    }

    _readingSession = _readingSession.copyWith(readingTexts: updatedTexts);
  }

  void _openReading({
    required String reference,
    required String content,
    required LiturgicalDay? liturgicalDay,
    DailyReading? readingData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingScreen(
          reference: reference,
          content: content,
          liturgicalDay: liturgicalDay,
          readingData: readingData,
          hasNext: _readingSession.hasNext,
          hasPrev: _readingSession.hasPrev,
          onNextReading: _goToNextReading,
          onPrevReading: _goToPrevReading,
        ),
      ),
    );
  }

  void _goToNextReading() {
    if (_readingSession.hasNext) {
      _readingSession = _readingSession.copyWith(
        currentIndex: _readingSession.currentIndex + 1,
      );
      _openCurrentReadingFromNavigation();
    }
  }

  void _goToPrevReading() {
    if (_readingSession.hasPrev) {
      _readingSession = _readingSession.copyWith(
        currentIndex: _readingSession.currentIndex - 1,
      );
      _openCurrentReadingFromNavigation();
    }
  }

  void _openCurrentReadingFromNavigation() {
    final reading = _readingSession.currentReading;
    if (reading == null) {
      return;
    }

    final cachedText = _readingSession.textFor(reading.reading);

    if (cachedText != null && cachedText.trim().isNotEmpty) {
      _onReadingSelected(
        reading.reading,
        cachedText,
        null,
        reading,
      );
      return;
    }

    _resolveReadingTextAndOpen(reading);
  }

  Future<void> _resolveReadingTextAndOpen(DailyReading reading) async {
    String text;
    try {
      text = await _readingFlow.getReadingText(reading);
      _readingSession = _readingSession.copyWith(
        readingTexts: {
          ..._readingSession.readingTexts,
          reading.reading: text,
        },
      );
    } catch (_) {
      text = reading.reading;
    }

    if (!mounted) return;

    _onReadingSelected(
      reading.reading,
      text,
      null,
      reading,
    );
  }

  Future<void> _persistLastReading({
    required String reference,
    required String content,
  }) async {
    _lastReadingReference = reference;
    _lastReadingContent = content;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastReadingReference, reference);
    await prefs.setString(_keyLastReadingContent, content);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final navBackgroundColor = isDark
        ? Color.alphaBlend(
            colorScheme.surface.withValues(alpha: 0.88),
            colorScheme.primary.withValues(alpha: 0.10),
          )
        : null;
    final navIndicatorColor = isDark
        ? Color.alphaBlend(
            colorScheme.primary.withValues(alpha: 0.34),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          )
        : null;
    final navIconTheme = WidgetStateProperty.resolveWith<IconThemeData>((states) {
      final selected = states.contains(WidgetState.selected);
      return IconThemeData(
        color: selected
            ? (isDark ? Colors.white : colorScheme.primary)
            : (isDark ? colorScheme.onSurfaceVariant.withValues(alpha: 0.92) : null),
      );
    });
    final navLabelTextStyle = WidgetStateProperty.resolveWith<TextStyle>((states) {
      final selected = states.contains(WidgetState.selected);
      return theme.textTheme.labelMedium?.copyWith(
            color: selected
                ? (isDark ? Colors.white : colorScheme.primary)
                : (isDark ? colorScheme.onSurfaceVariant.withValues(alpha: 0.92) : colorScheme.onSurfaceVariant),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
          ) ??
          TextStyle(
            color: selected
                ? (isDark ? Colors.white : colorScheme.primary)
                : (isDark ? colorScheme.onSurfaceVariant.withValues(alpha: 0.92) : colorScheme.onSurfaceVariant),
          );
    });

    final screens = [
      PremiumBrowseScreen(onReadingSelected: _onReadingSelected),
      SearchScreen(onReadingSelected: _onReadingSelected),
      SettingsScreen(
        versions: _versions,
        themeMode: widget.themeMode,
        themeStyle: widget.themeStyle,
        onThemeModeChanged: widget.onThemeModeChanged,
        onThemeStyleChanged: widget.onThemeStyleChanged,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: navBackgroundColor,
          indicatorColor: navIndicatorColor,
          iconTheme: navIconTheme,
          labelTextStyle: navLabelTextStyle,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            _persistTab(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.book_outlined),
              selectedIcon: Icon(Icons.book),
              label: 'Daily',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _persistTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastTabIndex, index);
  }
}
