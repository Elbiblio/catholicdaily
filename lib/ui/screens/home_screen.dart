import 'package:flutter/material.dart';
import 'premium_browse_screen.dart';
import 'reading_screen.dart';
import 'settings_screen.dart';
import 'prayers_screen.dart';
import 'bible_screen.dart';
import 'hymn_list_screen.dart';
import '../../data/models/bible_version.dart';
import '../../data/services/theme_preferences.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/models/reading_session.dart';
import '../../data/services/readings_backend_io.dart';
import '../../data/services/reading_flow_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/app_navigation_service.dart';

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

  int _currentIndex = 0;
  final AppNavigationService _navigationService = AppNavigationService();

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
    await _navigationService.initialize();
    await _navigationService.trackHomeScreen();
    
    final prefs = await SharedPreferences.getInstance();
    _currentIndex = prefs.getInt(_keyLastTabIndex) ?? 0;

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
    
    // Handle Bible chapter resume in bible reading mode only
    if (_navigationService.shouldResumeToBibleChapter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resumeToBibleChapter();
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

      final navigableItems = await _readingFlow.buildNavigableFlow(
        date: _currentDate,
        readings: hydrated.readings,
      );

      _readingSession = _readingFlow.buildSession(
        readings: hydrated.readings,
        readingTexts: hydrated.readingTexts,
        selectedIndex: 0,
        navigableItems: navigableItems,
        navigableIndex: 0,
      );
    } catch (e) {
      debugPrint('Error loading current readings: $e');
      _readingSession = ReadingSession.empty();
    }
  }

  void _resumeToBibleChapter() {
    final chapter = _navigationService.lastBibleChapter!;
    
    // Switch to Bible tab first
    setState(() {
      _currentIndex = 1; // Bible tab index
    });
    _persistTab(1); // Persist the Bible tab selection
    
    // Then open the bible chapter
    _openBibleReading(
      reference: chapter['reference'] as String,
      content: chapter['content'] as String,
      liturgicalDay: null,
    );
  }

  void _onReadingSelected(
    String reference,
    String content,
    LiturgicalDay? liturgicalDay, {
    DailyReading? readingData,
    List<DailyReading>? readingSet,
    int? selectedIndex,
    bool isBibleSearch = false,
  }) {
    // For bible search, don't build a reading session
    if (isBibleSearch) {
      _openBibleReading(reference: reference, content: content, liturgicalDay: liturgicalDay);
      return;
    }
    
    // Only build a new session if we don't already have one or if explicitly provided with a different set
    if (readingSet != null && (_readingSession.isEmpty || !_readingSetsEqual(readingSet, _readingSession.readings))) {
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
    
    _openReading(
      reference: reference,
      content: content,
      liturgicalDay: liturgicalDay,
      readingData: readingData,
    );
  }

  bool _readingSetsEqual(List<DailyReading> set1, List<DailyReading> set2) {
    if (set1.length != set2.length) return false;
    for (int i = 0; i < set1.length; i++) {
      if (set1[i].reading != set2[i].reading || set1[i].position != set2[i].position) {
        return false;
      }
    }
    return true;
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

  void _openBibleReading({
    required String reference,
    required String content,
    required LiturgicalDay? liturgicalDay,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingScreen(
          reference: reference,
          content: content,
          liturgicalDay: liturgicalDay,
          isBibleSearch: true,
          navigableItems: const [],
          currentNavigableIndex: 0,
        ),
      ),
    );
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
          sessionReadings: _readingSession.readings,
          currentReadingIndex: _readingSession.currentIndex,
          hasNext: _readingSession.hasNavigableItems ? _readingSession.hasNextNavigable : _readingSession.hasNext,
          hasPrev: _readingSession.hasNavigableItems ? _readingSession.hasPrevNavigable : _readingSession.hasPrev,
          onNextReading: _goToNextReading,
          onPrevReading: _goToPrevReading,
          onSelectReadingIndex: _goToReadingAtIndex,
          navigableItems: _readingSession.navigableItems,
          currentNavigableIndex: _readingSession.navigableIndex,
        ),
      ),
    );
  }

  void _goToReadingAtIndex(int index) {
    if (index < 0 || index >= _readingSession.readings.length) {
      return;
    }
    if (index == _readingSession.currentIndex) {
      return; // Already at this reading
    }
    
    // Find the corresponding navigable index
    final navigableIndex = _readingSession.navigableItems.indexWhere(
      (item) => item.isReading && item.reading?.reading == _readingSession.readings[index].reading,
    );
    
    _readingSession = _readingSession.copyWith(
      currentIndex: index,
      navigableIndex: navigableIndex >= 0 ? navigableIndex : index,
    );
    _openCurrentReadingFromNavigation();
  }

  void _goToNextReading() {
    if (!_readingSession.hasNavigableItems) {
      if (!_readingSession.hasNext) return;
      _readingSession = _readingSession.copyWith(
        currentIndex: _readingSession.currentIndex + 1,
      );
      _openCurrentReadingFromNavigation();
      return;
    }

    if (!_readingSession.hasNextNavigable) {
      return;
    }
    
    final nextIndex = _readingSession.navigableIndex + 1;
    _readingSession = _readingSession.copyWith(navigableIndex: nextIndex);
    
    // Update current reading index if the next item is a reading
    final nextItem = _readingSession.currentNavigableItem;
    if (nextItem?.isReading == true) {
      final readingIndex = _readingSession.readings.indexWhere(
        (r) => r.reading == nextItem!.reading!.reading,
      );
      if (readingIndex >= 0) {
        _readingSession = _readingSession.copyWith(currentIndex: readingIndex);
      }
    }
    
    _openCurrentNavigableItemFromNavigation();
  }

  void _goToPrevReading() {
    if (!_readingSession.hasNavigableItems) {
      if (!_readingSession.hasPrev) return;
      _readingSession = _readingSession.copyWith(
        currentIndex: _readingSession.currentIndex - 1,
      );
      _openCurrentReadingFromNavigation();
      return;
    }

    if (!_readingSession.hasPrevNavigable) {
      return;
    }
    
    final prevIndex = _readingSession.navigableIndex - 1;
    _readingSession = _readingSession.copyWith(navigableIndex: prevIndex);
    
    // Update current reading index if the previous item is a reading
    final prevItem = _readingSession.currentNavigableItem;
    if (prevItem?.isReading == true) {
      final readingIndex = _readingSession.readings.indexWhere(
        (r) => r.reading == prevItem!.reading!.reading,
      );
      if (readingIndex >= 0) {
        _readingSession = _readingSession.copyWith(currentIndex: readingIndex);
      }
    }
    
    _openCurrentNavigableItemFromNavigation();
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
        readingData: reading,
        readingSet: _readingSession.readings,
        selectedIndex: _readingSession.currentIndex,
      );
      return;
    }

    _resolveReadingTextAndOpen(reading);
  }

  void _openCurrentNavigableItemFromNavigation() {
    final item = _readingSession.currentNavigableItem;
    if (item == null) {
      return;
    }

    if (item.isReading) {
      _openCurrentReadingFromNavigation();
    } else if (item.isOrderOfMass) {
      // Open order of mass item - will be handled by ReadingScreen
      final reading = _readingSession.currentReading;
      if (reading != null) {
        final cachedText = _readingSession.textFor(reading.reading);
        _onReadingSelected(
          reading.reading,
          cachedText ?? reading.reading,
          null,
          readingData: reading,
          readingSet: _readingSession.readings,
          selectedIndex: _readingSession.currentIndex,
        );
      }
    }
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
      readingData: reading,
      readingSet: _readingSession.readings,
      selectedIndex: _readingSession.currentIndex,
    );
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
      PremiumBrowseScreen(onReadingSelected: (reading, content, liturgicalDay, [readingData, readingSet, selectedIndex]) {
        _onReadingSelected(
          reading,
          content,
          liturgicalDay,
          readingData: readingData,
          readingSet: readingSet,
          selectedIndex: selectedIndex,
        );
      }),
      BibleScreen(onReadingSelected: (reference, content, liturgicalDay, {isBibleSearch = false}) {
        _onReadingSelected(reference, content, liturgicalDay, isBibleSearch: isBibleSearch);
      }),
      const HymnListScreen(),
      const PrayersScreen(),
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
              label: 'Readings',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Bible',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note),
              label: 'Hymns',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline),
              selectedIcon: Icon(Icons.bookmark),
              label: 'Prayers',
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
