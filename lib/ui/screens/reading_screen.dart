import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/daily_reading.dart';
import '../../data/models/navigable_item.dart';
import '../../data/models/reading_session.dart';
import '../../data/models/resolved_responsorial_psalm.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/liturgical_region_preference_service.dart';
import '../../data/services/bible_version_preference.dart';
import '../../data/services/incipit_preference_service.dart';
import '../../data/services/scroll_position_service.dart';
import '../../data/services/reading_flow_service.dart';
import '../../data/services/reading_narration_controller.dart';
import '../../data/services/reading_narration_queue_builder.dart';
import '../widgets/parchment_background.dart';
import '../widgets/psalm_response_widget.dart';
import '../widgets/gospel_acclamation_widget.dart';
import '../widgets/bible_version_switcher.dart';
import '../widgets/responsorial_psalm_edition_selector.dart';
import '../widgets/responsorial_psalm_source_label.dart';
import '../widgets/ai_insights_sheet.dart';
import '../widgets/read_aloud_icon.dart';
import '../widgets/reading_narration_scope.dart';
import '../utils/reading_title_formatter.dart';
import '../utils/bible_reference_helper.dart';
import '../../data/services/bible_cache_service.dart';
import 'church_locator_screen.dart';
import 'dart:async';

final RouteObserver<PageRoute<dynamic>> readingNarrationRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

typedef ReadingNarrationHydrator =
    Future<HydratedReadingSet> Function(ReadingSession session);

class ReadingScreen extends StatefulWidget {
  final String reference;
  final String content;
  final LiturgicalDay? liturgicalDay;
  final DailyReading? readingData;
  final ReadingSession? narrationSession;
  final List<DailyReading> sessionReadings;
  final int currentReadingIndex;
  final VoidCallback? onNextReading;
  final VoidCallback? onPrevReading;
  final ValueChanged<int>? onSelectReadingIndex;
  final bool hasNext;
  final bool hasPrev;
  final bool isBibleSearch;
  final List<NavigableItem> navigableItems;
  final int currentNavigableIndex;
  final VoidCallback? onRouteDisposed;
  final ResolvedResponsorialPsalm? psalmSource;
  final ReadingNarrationHydrator? narrationHydrator;
  final DisplayedGospelAcclamationResolver? gospelAcclamationResolver;

  const ReadingScreen({
    super.key,
    required this.reference,
    required this.content,
    this.liturgicalDay,
    this.readingData,
    this.narrationSession,
    this.sessionReadings = const [],
    this.currentReadingIndex = -1,
    this.onNextReading,
    this.onPrevReading,
    this.onSelectReadingIndex,
    this.hasNext = false,
    this.hasPrev = false,
    this.isBibleSearch = false,
    this.navigableItems = const [],
    this.currentNavigableIndex = 0,
    this.onRouteDisposed,
    this.psalmSource,
    this.narrationHydrator,
    this.gospelAcclamationResolver,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

// WCAG-compliant contrast helper with enhanced light color handling
Color _contrastColor(Color background, {double alpha = 1.0}) {
  // Convert sRGB channel to linear light value per WCAG 2.x spec
  double lin(double c) =>
      c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);

  final r = lin(background.r);
  final g = lin(background.g);
  final b = lin(background.b);
  final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

  // For very light backgrounds (like white/gold), always use dark text
  // regardless of the requested alpha, to ensure readability
  if (luminance > 0.85) {
    return Colors.black.withValues(alpha: alpha);
  }

  // For light backgrounds, prefer dark text
  // For dark backgrounds, prefer light text
  return luminance < 0.179
      ? Colors.white.withValues(alpha: alpha)
      : Colors.black.withValues(alpha: alpha);
}

class _ReadingScreenState extends State<ReadingScreen> with RouteAware {
  static const _verseNumbersKey = 'show_verse_numbers';

  double _textScale = 1.0;
  final ScrollController _scrollController = ScrollController();
  String _currentContent = '';
  bool _isReloading = false;
  bool _isBookmarked = false;
  bool _isNavigating = false;
  bool _hasPreviousChapter = false;
  bool _hasNextChapter = false;
  bool _isFullScreen = false;
  bool _showVerseNumbers = true;
  bool _showIncipit = true;
  ResolvedResponsorialPsalm? _currentPsalmSource;
  String? _currentGospelAcclamation;
  ReadingNarrationSession? _narration;
  bool _deliberateNarrationNavigation = false;
  bool _preserveReadAllOnNextCover = false;
  PageRoute<dynamic>? _subscribedRoute;
  int _narrationPreparationGeneration = 0;

  final ScrollPositionService _scrollPositionService = ScrollPositionService();
  Timer? _scrollDebounceTimer;

  String get _readingLabel {
    final position = widget.readingData?.position?.trim();
    if (position != null && position.isNotEmpty) {
      return position;
    }

    // Fallback to parsing from reference
    final reference = widget.reference.toLowerCase();
    if (reference.startsWith('ps ') || reference.startsWith('psalm ')) {
      return 'Psalm';
    } else if (reference.contains('gospel') ||
        reference.contains('mk ') ||
        reference.contains('mt ') ||
        reference.contains('lk ') ||
        reference.contains('jn ')) {
      return 'Gospel';
    } else if (reference.contains('reading')) {
      final parts = reference.split('reading');
      if (parts.length > 1) {
        final number = parts[1].trim();
        return 'Reading $number';
      }
      return 'Reading';
    }
    return 'Reading';
  }

  String _formatPosition(String position) {
    final match = RegExp(
      r'\(alternative(?:\s+(\d+))?\)$',
      caseSensitive: false,
    ).firstMatch(position);
    if (match == null) {
      return position;
    }
    final number = match.group(1);
    return number == null ? 'Alternative' : 'Alternative $number';
  }

  String? get _nextItemLabel {
    if (widget.navigableItems.isEmpty) return null;
    final nextIndex = widget.currentNavigableIndex + 1;
    if (nextIndex >= widget.navigableItems.length) return null;
    final nextItem = widget.navigableItems[nextIndex];
    return nextItem.isOrderOfMass
        ? nextItem.orderOfMassItem?.title
        : nextItem.reading?.position;
  }

  String? get _prevItemLabel {
    if (widget.navigableItems.isEmpty) return null;
    final prevIndex = widget.currentNavigableIndex - 1;
    if (prevIndex < 0) return null;
    final prevItem = widget.navigableItems[prevIndex];
    return prevItem.isOrderOfMass
        ? prevItem.orderOfMassItem?.title
        : prevItem.reading?.position;
  }

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
    _currentPsalmSource = widget.psalmSource;
    _loadBookmarkStatus();
    _loadVerseNumberPref();
    _loadIncipitPref();
    _scrollPositionService.initialize();
    _restoreScrollPosition();
    if (widget.isBibleSearch) {
      _checkChapterAvailability();
    }

    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _narration = ReadingNarrationScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && !identical(route, _subscribedRoute)) {
      if (_subscribedRoute != null) {
        readingNarrationRouteObserver.unsubscribe(this);
      }
      _subscribedRoute = route;
      readingNarrationRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _narrationPreparationGeneration++;
    final deliberate = _preserveReadAllOnNextCover;
    _preserveReadAllOnNextCover = false;
    final narration = _narration;
    if (narration != null) {
      unawaited(
        narration.controller.onReadingExperienceExit(
          deliberateNavigation: deliberate,
        ),
      );
    }
  }

  Future<void> _loadVerseNumberPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showVerseNumbers = prefs.getBool(_verseNumbersKey) ?? true;
      });
    }
  }

  Future<void> _loadIncipitPref() async {
    final show = await IncipitPreferenceService().getShowIncipit();
    if (mounted) {
      setState(() {
        _showIncipit = show;
      });
    }
  }

  Future<void> _toggleVerseNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_showVerseNumbers;
    await prefs.setBool(_verseNumbersKey, newValue);
    if (mounted) {
      setState(() {
        _showVerseNumbers = newValue;
      });
    }
  }

  Future<void> _checkChapterAvailability() async {
    if (!widget.isBibleSearch) return;

    final hasPrevious = await BibleReferenceHelper.hasPreviousChapter(
      widget.reference,
    );
    final hasNext = await BibleReferenceHelper.hasNextChapter(widget.reference);

    if (mounted) {
      setState(() {
        _hasPreviousChapter = hasPrevious;
        _hasNextChapter = hasNext;
      });
    }
  }

  Future<void> _restoreScrollPosition() async {
    final savedPosition = _scrollPositionService.getScrollPosition(
      widget.reference,
    );
    if (savedPosition != null && savedPosition > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            savedPosition,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  void _onScrollChanged() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_scrollController.hasClients) {
        _scrollPositionService.saveScrollPosition(
          widget.reference,
          _scrollController.offset,
        );
      }
    });
  }

  @override
  void didUpdateWidget(ReadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reference != widget.reference ||
        oldWidget.readingData?.reading != widget.readingData?.reading ||
        oldWidget.readingData?.position != widget.readingData?.position) {
      _narrationPreparationGeneration++;
    }
    if (oldWidget.content != widget.content) {
      setState(() {
        _currentContent = widget.content;
      });
    }
    if (oldWidget.psalmSource != widget.psalmSource) {
      _currentPsalmSource = widget.psalmSource;
    }
  }

  Future<void> _loadBookmarkStatus() async {
    final cacheService = BibleCacheService();
    await cacheService.initialize();
    if (mounted) {
      setState(() {
        _isBookmarked = cacheService.isBookmarked(widget.reference);
      });
    }
  }

  void _openChurchLocator() {
    _narrationPreparationGeneration++;
    _preserveReadAllOnNextCover = false;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const ChurchLocatorScreen()),
    );
  }

  Future<void> _showAiInsights() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AiInsightsSheet(
        reference: widget.reference,
        content: _currentContent,
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final cacheService = BibleCacheService();
    await cacheService.initialize();
    final preference = await BibleVersionPreference.getInstance();
    await cacheService.toggleBookmark(
      reference: widget.reference,
      title: widget.reference,
      content: _currentContent,
      version: preference.currentVersion.dbName,
    );
    if (mounted) {
      setState(() {
        _isBookmarked = cacheService.isBookmarked(widget.reference);
      });
    }
  }

  Future<void> _goToPreviousChapter() async {
    if (!widget.isBibleSearch || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      final prevChapter = await BibleReferenceHelper.getPreviousChapter(
        widget.reference,
      );
      if (prevChapter != null) {
        if (mounted) {
          _preserveReadAllOnNextCover = true;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReadingScreen(
                reference: prevChapter['reference']!,
                content: prevChapter['content']!,
                liturgicalDay: null,
                isBibleSearch: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load the previous chapter right now.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _goToNextChapter() async {
    if (!widget.isBibleSearch || _isNavigating) return;

    setState(() => _isNavigating = true);

    try {
      final nextChapter = await BibleReferenceHelper.getNextChapter(
        widget.reference,
      );
      if (nextChapter != null) {
        if (mounted) {
          _preserveReadAllOnNextCover = true;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReadingScreen(
                reference: nextChapter['reference']!,
                content: nextChapter['content']!,
                liturgicalDay: null,
                isBibleSearch: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load the next chapter right now.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  void _selectVariant(DailyReading reading) async {
    if (_isNavigating) return;

    final index = widget.sessionReadings.indexOf(reading);
    if (index < 0 || index == widget.currentReadingIndex) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    try {
      _deliberateNarrationNavigation = true;
      await _invalidateNarrationFor(reading);
      await Future.delayed(const Duration(milliseconds: 100));
      widget.onSelectReadingIndex?.call(index);
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  void _navigateToPreviousReading() {
    _narrationPreparationGeneration++;
    _deliberateNarrationNavigation = true;
    widget.onPrevReading?.call();
  }

  void _navigateToNextReading() {
    _narrationPreparationGeneration++;
    _deliberateNarrationNavigation = true;
    widget.onNextReading?.call();
  }

  DailyReading get _displayedReading =>
      widget.readingData ??
      DailyReading(
        reading: widget.reference,
        position: widget.isBibleSearch ? 'Bible Chapter' : _readingLabel,
        date: widget.liturgicalDay?.date ?? DateTime.now(),
      );

  ReadingSession _displayedNarrationSession() {
    final displayed = _displayedReading;
    final base = widget.narrationSession;
    final readings = base?.readings.isNotEmpty == true
        ? base!.readings
        : widget.sessionReadings.isNotEmpty
        ? widget.sessionReadings
        : <DailyReading>[displayed];
    var currentIndex = readings.indexWhere(
      (reading) =>
          reading.reading == displayed.reading &&
          reading.position == displayed.position,
    );
    if (currentIndex < 0) {
      currentIndex = readings.indexWhere(
        (reading) => reading.reading == displayed.reading,
      );
    }
    if (currentIndex < 0) currentIndex = 0;
    final texts = <String, String>{...?base?.readingTexts};
    texts[widget.reference] = _currentContent;
    final psalmSources = <String, ResolvedResponsorialPsalm>{
      ...?base?.psalmSources,
    };
    if (_currentPsalmSource != null) {
      psalmSources[widget.reference] = _currentPsalmSource!;
    }
    return ReadingSession(
      readings: readings,
      readingTexts: texts,
      psalmSources: psalmSources,
      currentIndex: currentIndex,
      navigableItems: base?.navigableItems ?? widget.navigableItems,
      navigableIndex: base?.navigableIndex ?? widget.currentNavigableIndex,
      liturgicalDay: widget.liturgicalDay ?? base?.liturgicalDay,
    );
  }

  List<ReadingNarrationQueueItem> _currentNarrationQueue() {
    final narration = _narration;
    if (narration == null) return const <ReadingNarrationQueueItem>[];
    if (widget.isBibleSearch) {
      return narration.queueBuilder.buildCurrentBibleChapter(
        reference: widget.reference,
        displayedText: _currentContent,
      );
    }
    return narration.queueBuilder.buildCurrent(
      _displayedNarrationSession(),
      showIncipit: _showIncipit,
      displayedGospelAcclamation: _displayedAcclamationForNarration,
    );
  }

  String? get _displayedAcclamationForNarration {
    if (widget.readingData?.gospelAcclamation == null) return null;
    return _currentGospelAcclamation ?? '';
  }

  ReadingNarrationQueueItem? get _currentNarrationItem {
    final queue = _currentNarrationQueue();
    return queue.isEmpty ? null : queue.first;
  }

  Future<NarrationContext?> _narrationContextFor(DailyReading reading) async {
    final narration = _narration;
    if (narration == null) return null;
    return narration.contextFor(
      date: reading.date,
      alternativeKey: '${reading.position ?? 'Reading'}|${reading.reading}',
    );
  }

  Future<void> _toggleCurrentNarration() async {
    final narration = _narration;
    if (narration == null) return;
    final request = ++_narrationPreparationGeneration;
    final queue = _currentNarrationQueue();
    final context = await _narrationContextFor(_displayedReading);
    if (!mounted ||
        request != _narrationPreparationGeneration ||
        context == null) {
      return;
    }
    await narration.toggle(
      queue,
      mode: NarrationPlaybackMode.currentOnly,
      context: context,
    );
  }

  Future<void> _readAllAppointedReadings() async {
    final narration = _narration;
    final base = _displayedNarrationSession();
    if (narration == null || base.readings.isEmpty) return;
    final request = ++_narrationPreparationGeneration;
    final date = base.currentReading?.date ?? _displayedReading.date;
    final Future<HydratedReadingSet> hydrationFuture;
    if (widget.narrationHydrator case final hydrator?) {
      hydrationFuture = hydrator(base);
    } else {
      hydrationFuture = ReadingFlowService.instance.hydrateReadingSet(
        date: date,
        readings: base.readings,
      );
    }
    final hydrated = await hydrationFuture;
    if (!mounted || request != _narrationPreparationGeneration) return;
    var currentIndex = hydrated.readings.indexWhere(
      (reading) =>
          reading.reading == _displayedReading.reading &&
          reading.position == _displayedReading.position,
    );
    if (currentIndex < 0) currentIndex = 0;
    final texts = <String, String>{...hydrated.readingTexts};
    texts[widget.reference] = _currentContent;
    final psalmSources = <String, ResolvedResponsorialPsalm>{
      ...hydrated.psalmSources,
    };
    if (_currentPsalmSource != null) {
      psalmSources[widget.reference] = _currentPsalmSource!;
    }
    final session = ReadingSession(
      readings: hydrated.readings,
      readingTexts: texts,
      psalmSources: psalmSources,
      currentIndex: currentIndex,
      liturgicalDay: widget.liturgicalDay,
    );
    final displayedAcclamations = <String, String>{};
    for (final reading in session.readings) {
      final raw = reading.gospelAcclamation?.trim();
      if (raw == null || raw.isEmpty) continue;
      final displayed = reading.reading == _displayedReading.reading
          ? _displayedAcclamationForNarration
          : await (widget.gospelAcclamationResolver?.call(reading, date) ??
                resolveDisplayedGospelAcclamation(reading, date));
      if (!mounted || request != _narrationPreparationGeneration) return;
      if (displayed != null && displayed.trim().isNotEmpty) {
        displayedAcclamations[reading.reading] = displayed.trim();
      } else {
        // An unresolved reference is omitted rather than narrated as UI data.
        displayedAcclamations[reading.reading] = '';
      }
    }
    final queue = narration.queueBuilder.buildReadAll(
      session,
      selectedReadings: <DailyReading>[?session.currentReading],
      showIncipit: _showIncipit,
      displayedGospelAcclamations: displayedAcclamations,
    );
    final context = await _narrationContextFor(session.currentReading!);
    if (!mounted ||
        request != _narrationPreparationGeneration ||
        context == null) {
      return;
    }
    await narration.playReadAll(queue, context: context);
  }

  Future<void> _invalidateNarrationFor(DailyReading reading) async {
    _narrationPreparationGeneration++;
    final context = await _narrationContextFor(reading);
    if (context != null) {
      await _narration?.controller.invalidateForContext(context);
    }
  }

  Future<void> _invalidateNarrationForEditionSelection({
    BibleVersionType? bibleVersion,
    String? psalmEditionId,
  }) async {
    _narrationPreparationGeneration++;
    final context = await _narrationContextFor(_displayedReading);
    if (context == null) return;
    await _narration?.controller.invalidateForContext(
      NarrationContext(
        dateKey: context.dateKey,
        regionCode: context.regionCode,
        bibleEditionId: bibleVersion?.dbName ?? context.bibleEditionId,
        psalmEditionId: psalmEditionId ?? context.psalmEditionId,
        alternativeKey: context.alternativeKey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? colorScheme.primary;

    final onOrdoColor = _contrastColor(
      Color.alphaBlend(
        colorScheme.surface.withValues(alpha: isLight ? 0.42 : 0.3),
        ordoColor.withValues(alpha: isLight ? 0.96 : 1),
      ),
    );

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: ParchmentBackground(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: widget.liturgicalDay != null ? 156 : 0,
              pinned: true,
              automaticallyImplyLeading: true,
              iconTheme: IconThemeData(
                color: isLight
                    ? colorScheme.onSurface.withValues(alpha: 0.95)
                    : onOrdoColor,
              ),
              backgroundColor: Color.alphaBlend(
                (isLight ? Colors.white : colorScheme.surface).withValues(
                  alpha: isLight ? 0.94 : 0.84,
                ),
                ordoColor.withValues(alpha: isLight ? 0.06 : 0.12),
              ),
              surfaceTintColor: Colors.transparent,
              foregroundColor: isLight
                  ? colorScheme.onSurface.withValues(alpha: 0.95)
                  : onOrdoColor,
              flexibleSpace: widget.liturgicalDay != null
                  ? FlexibleSpaceBar(
                      background: Container(
                        color: Color.alphaBlend(
                          colorScheme.surface.withValues(
                            alpha: isLight ? 0.42 : 0.3,
                          ),
                          widget.liturgicalDay!.colorValue.withValues(
                            alpha: isLight ? 0.96 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + 64,
                            16,
                            16,
                          ),
                          // Wrap in non-scrollable scroll view so collapsing
                          // SliverAppBar doesn't trigger a yellow-stripe
                          // overflow when the column's natural height exceeds
                          // the collapsed flexible-space height.
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.liturgicalDay!.fullDescription,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: onOrdoColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.liturgicalDay!.weekDescription,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: onOrdoColor.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              actions: [
                ReadAloudIcon(
                  status:
                      _narration?.statusFor(_currentNarrationItem) ??
                      NarrationStatus.idle,
                  supportsNativePause:
                      _narration?.state.supportsNativePause ?? false,
                  onPressed: _narration == null
                      ? null
                      : () => unawaited(_toggleCurrentNarration()),
                ),
                Semantics(
                  label: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    ),
                    onPressed: _toggleBookmark,
                    tooltip: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'copy':
                        _copyText();
                        break;
                      case 'share':
                        _shareText();
                        break;
                      case 'fullscreen':
                        _toggleFullScreen();
                        break;
                      case 'insights':
                        _showAiInsights();
                        break;
                      case 'verse_numbers':
                        _toggleVerseNumbers();
                        break;
                      case 'read_all':
                        unawaited(_readAllAppointedReadings());
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!widget.isBibleSearch &&
                        _displayedNarrationSession().readings.isNotEmpty)
                      const PopupMenuItem(
                        value: 'read_all',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_play_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Read all appointed readings'),
                            ),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'insights',
                      child: Row(
                        children: [
                          Icon(Icons.auto_awesome),
                          SizedBox(width: 12),
                          Text('AI Insights'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'verse_numbers',
                      child: Row(
                        children: [
                          Icon(
                            _showVerseNumbers
                                ? Icons.format_list_numbered
                                : Icons.format_list_numbered_rtl,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _showVerseNumbers
                                  ? 'Hide verse numbers'
                                  : 'Show verse numbers',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.copy),
                          SizedBox(width: 12),
                          Text('Copy text'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share),
                          SizedBox(width: 12),
                          Text('Share'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'fullscreen',
                      child: Row(
                        children: [
                          Icon(
                            _isFullScreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _isFullScreen ? 'Exit Fullscreen' : 'Fullscreen',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              title: Text(
                _readingLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isLight
                      ? colorScheme.onSurface.withValues(alpha: 0.95)
                      : onOrdoColor,
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildHeader(theme)),
            if (_hasSeparateIncipit)
              SliverToBoxAdapter(child: _buildIncipitCard(theme)),
            if (_currentVariantReadings.isNotEmpty && !widget.isBibleSearch)
              SliverToBoxAdapter(child: _buildVariantSwitcher(theme)),
            if (widget.readingData?.psalmResponse != null)
              SliverToBoxAdapter(
                child: PsalmResponseWidget(
                  reading: widget.readingData!,
                  date: widget.liturgicalDay?.date ?? DateTime.now(),
                ),
              ),
            if (widget.readingData?.gospelAcclamation != null)
              SliverToBoxAdapter(
                child: GospelAcclamationWidget(
                  reading: widget.readingData!,
                  date: widget.liturgicalDay?.date ?? DateTime.now(),
                  onDisplayedAcclamationChanged: (acclamation) {
                    if (mounted && acclamation != _currentGospelAcclamation) {
                      setState(() {
                        _currentGospelAcclamation = acclamation;
                      });
                    }
                  },
                ),
              ),
            SliverToBoxAdapter(child: _buildContent(theme)),
            SliverToBoxAdapter(child: _buildVersionFooter(theme)),
            if (widget.hasNext || widget.hasPrev)
              SliverToBoxAdapter(child: _buildNavigation(theme)),
          ],
        ),
      ),
      floatingActionButton:
          widget.liturgicalDay != null && !widget.hasNext && !widget.hasPrev
          ? Semantics(
              label: 'Open church locator',
              button: true,
              child: FloatingActionButton.small(
                backgroundColor: widget.liturgicalDay!.colorValue,
                foregroundColor: widget.liturgicalDay!.textColor,
                onPressed: _openChurchLocator,
                tooltip: 'Open church locator',
                child: const Icon(Icons.church),
              ),
            )
          : null,
    );
  }

  bool get _hasSeparateIncipit {
    if (!_showIncipit) return false;
    if (widget.isBibleSearch) return false;
    final incipit = widget.readingData?.incipit?.trim();
    if (incipit == null || incipit.isEmpty) return false;
    final position = widget.readingData?.position?.toLowerCase() ?? '';
    return !position.contains('psalm') &&
        !position.contains('acclamation') &&
        !position.contains('sequence');
  }

  Widget _buildNavigation(ThemeData theme) {
    if (widget.isBibleSearch) {
      final shouldShowNavigation = _hasPreviousChapter || _hasNextChapter;
      if (!shouldShowNavigation) return const SizedBox.shrink();

      final ordoColor = theme.colorScheme.primary;
      final buttonForeground = _contrastColor(ordoColor);

      return Container(
        margin: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_hasPreviousChapter)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isNavigating ? null : _goToPreviousChapter,
                  icon: _isNavigating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_back),
                  label: Text(
                    _isNavigating ? 'Loading...' : 'Previous Chapter',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: ordoColor,
                    foregroundColor: buttonForeground,
                  ),
                ),
              ),
            if (_hasPreviousChapter && _hasNextChapter)
              const SizedBox(width: 12),
            if (_hasNextChapter)
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isNavigating ? null : _goToNextChapter,
                  icon: _isNavigating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(_isNavigating ? 'Loading...' : 'Next Chapter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ordoColor,
                    foregroundColor: buttonForeground,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (widget.navigableItems.isNotEmpty) {
      final shouldShowNavigation = widget.hasNext || widget.hasPrev;
      if (!shouldShowNavigation) return const SizedBox.shrink();

      final ordoColor =
          widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
      final buttonForeground = _contrastColor(ordoColor);

      return Container(
        margin: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.linear_scale,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.currentNavigableIndex + 1} of ${widget.navigableItems.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (widget.hasPrev)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isNavigating
                          ? null
                          : () async {
                              setState(() => _isNavigating = true);
                              try {
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                _navigateToPreviousReading();
                              } finally {
                                if (mounted) {
                                  setState(() => _isNavigating = false);
                                }
                              }
                            },
                      icon: _isNavigating && widget.hasPrev && !widget.hasNext
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_back),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isNavigating && widget.hasPrev && !widget.hasNext
                                ? 'Loading...'
                                : 'Previous',
                          ),
                          if (_prevItemLabel != null)
                            Text(
                              _prevItemLabel!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: buttonForeground.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ordoColor,
                        foregroundColor: buttonForeground,
                      ),
                    ),
                  ),
                if (widget.hasPrev && widget.hasNext) const SizedBox(width: 12),
                if (widget.hasNext)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isNavigating
                          ? null
                          : () async {
                              setState(() => _isNavigating = true);
                              try {
                                await Future.delayed(
                                  const Duration(milliseconds: 100),
                                );
                                _navigateToNextReading();
                              } finally {
                                if (mounted) {
                                  setState(() => _isNavigating = false);
                                }
                              }
                            },
                      icon: _isNavigating && widget.hasNext && !widget.hasPrev
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isNavigating && widget.hasNext && !widget.hasPrev
                                ? 'Loading...'
                                : 'Next',
                          ),
                          if (_nextItemLabel != null)
                            Text(
                              _nextItemLabel!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                color: buttonForeground.withValues(alpha: 0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ordoColor,
                        foregroundColor: buttonForeground,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final hasMultipleReadings = widget.sessionReadings.length > 1;
    final shouldShowNavigation =
        hasMultipleReadings || widget.hasNext || widget.hasPrev;

    if (!shouldShowNavigation) return const SizedBox.shrink();

    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final buttonForeground = _contrastColor(ordoColor);

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMultipleReadings)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Reading ${widget.currentReadingIndex + 1} of ${widget.sessionReadings.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Row(
            children: [
              if (widget.hasPrev)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isNavigating
                        ? null
                        : () async {
                            setState(() => _isNavigating = true);
                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                              _navigateToPreviousReading();
                            } finally {
                              if (mounted) {
                                setState(() => _isNavigating = false);
                              }
                            }
                          },
                    icon: _isNavigating && widget.hasPrev && !widget.hasNext
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_back),
                    label: Text(
                      widget.isBibleSearch
                          ? 'Previous Chapter'
                          : (_isNavigating && widget.hasPrev && !widget.hasNext
                                ? 'Loading...'
                                : 'Previous'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ordoColor,
                      foregroundColor: buttonForeground,
                    ),
                  ),
                ),
              if (widget.hasPrev && widget.hasNext) const SizedBox(width: 12),
              if (widget.hasNext)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isNavigating
                        ? null
                        : () async {
                            setState(() => _isNavigating = true);
                            try {
                              await Future.delayed(
                                const Duration(milliseconds: 100),
                              );
                              _navigateToNextReading();
                            } finally {
                              if (mounted) {
                                setState(() => _isNavigating = false);
                              }
                            }
                          },
                    icon: _isNavigating && widget.hasNext && !widget.hasPrev
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(
                      widget.isBibleSearch
                          ? 'Next Chapter'
                          : (_isNavigating && widget.hasNext && !widget.hasPrev
                                ? 'Loading...'
                                : 'Next'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ordoColor,
                      foregroundColor: buttonForeground,
                    ),
                  ),
                ),
              if (!widget.hasPrev && !widget.hasNext && hasMultipleReadings)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No more readings in this session',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;

    final headerAccent =
        ThemeData.estimateBrightnessForColor(ordoColor) == Brightness.dark
        ? ordoColor
        : theme.colorScheme.onSurface;

    final readingTitle = ReadingTitleFormatter.build(
      reference: widget.reference,
      position: widget.readingData?.position,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            readingTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: headerAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (widget.readingData?.position != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _formatPosition(widget.readingData!.position!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIncipitCard(ThemeData theme) {
    final incipit = widget.readingData?.incipit?.trim() ?? '';
    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.surface.withValues(alpha: isLight ? 0.88 : 0.72),
          ordoColor.withValues(alpha: isLight ? 0.08 : 0.18),
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ordoColor.withValues(alpha: isLight ? 0.18 : 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote_rounded,
            color: ordoColor.withValues(alpha: 0.82),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              incipit,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantSwitcher(ThemeData theme) {
    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;

    final labelColor = theme.colorScheme.onSurface;
    final unselectedTextColor = theme.colorScheme.onSurface;
    final selectedTextColor = _contrastColor(ordoColor);
    final readings = _currentVariantReadings;
    if (readings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Alternative Readings',
            style: theme.textTheme.labelMedium?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: readings.length,
            itemBuilder: (context, index) {
              final reading = readings[index];
              final globalIndex = widget.sessionReadings.indexOf(reading);
              final isSelected = globalIndex == widget.currentReadingIndex;
              return _buildAlternativeCard(
                reading: reading,
                isSelected: isSelected,
                theme: theme,
                ordoColor: ordoColor,
                selectedTextColor: selectedTextColor,
                unselectedTextColor: unselectedTextColor,
                showTypeLabel: false,
              );
            },
          ),
        ),
      ],
    );
  }

  List<DailyReading> get _currentVariantReadings {
    final current =
        widget.readingData ??
        (widget.currentReadingIndex >= 0 &&
                widget.currentReadingIndex < widget.sessionReadings.length
            ? widget.sessionReadings[widget.currentReadingIndex]
            : null);
    if (current == null) {
      return const [];
    }

    final currentType = _getBaseReadingType(current.position ?? 'Reading');
    final variants = widget.sessionReadings
        .where(
          (reading) =>
              _getBaseReadingType(reading.position ?? 'Reading') == currentType,
        )
        .toList();

    return variants.length > 1 ? variants : const [];
  }

  String _getBaseReadingType(String position) {
    final lowerPos = position.toLowerCase();

    // Preserve unique slot labels like "Responsorial Psalm after First Reading"
    // (Easter Vigil) so they do not collapse into a single "Responsorial Psalm"
    // group with each OT psalm appearing as a spurious "alternative".
    if (lowerPos.contains(' after ')) {
      return position.split('(').first.trim();
    }

    // Extract base type from positions like "Gospel (alternative)" or "First Reading (alternative 2)"
    if (lowerPos.contains('first reading')) return 'First Reading';
    if (lowerPos.contains('second reading')) return 'Second Reading';
    if (lowerPos.contains('third reading')) return 'Third Reading';
    if (lowerPos.contains('fourth reading')) return 'Fourth Reading';
    if (lowerPos.contains('fifth reading')) return 'Fifth Reading';
    if (lowerPos.contains('sixth reading')) return 'Sixth Reading';
    if (lowerPos.contains('seventh reading')) return 'Seventh Reading';
    if (lowerPos.contains('epistle')) return 'Epistle';
    if (lowerPos.contains('responsorial psalm')) return 'Responsorial Psalm';
    if (lowerPos.contains('alleluia psalm')) return 'Alleluia Psalm';
    if (lowerPos.contains('gospel acclamation')) return 'Gospel Acclamation';
    if (lowerPos.contains('gospel')) return 'Gospel';
    if (lowerPos.contains('sequence')) return 'Sequence';

    return position.split('(').first.trim();
  }

  Widget _buildAlternativeCard({
    required DailyReading reading,
    required bool isSelected,
    required ThemeData theme,
    required Color ordoColor,
    required Color selectedTextColor,
    required Color unselectedTextColor,
    required bool showTypeLabel,
  }) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: isSelected ? ordoColor : null,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectVariant(reading),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showTypeLabel)
                      Text(
                        _getBaseReadingType(reading.position ?? 'Reading'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? selectedTextColor
                              : unselectedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      reading.reading,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isSelected
                            ? selectedTextColor.withValues(alpha: 0.82)
                            : unselectedTextColor.withValues(alpha: 0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isNavigating && isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isReloading) {
      final ordoColor =
          widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: ordoColor),
              const SizedBox(height: 16),
              Text(
                'Loading reading...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final verses = _parseVerses(_currentContent);
    final isLight = theme.brightness == Brightness.light;
    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final containerColor = Color.alphaBlend(
      (isLight ? Colors.white : theme.colorScheme.surfaceContainer).withValues(
        alpha: isLight ? 0.92 : 0.52,
      ),
      ordoColor.withValues(alpha: isLight ? 0.06 : 0.16),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ordoColor.withValues(alpha: isLight ? 0.12 : 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.reference,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.87),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...verses.map((verse) => _buildVerse(verse, theme)),
        ],
      ),
    );
  }

  Widget _buildVerse(_Verse verse, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (verse.number != null && _showVerseNumbers)
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  verse.number.toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Expanded(
            child: Text(
              verse.text,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.6,
                fontSize: theme.textTheme.bodyLarge!.fontSize! * _textScale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter(ThemeData theme) {
    if (_isResponsorialPsalm) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ResponsorialPsalmEditionSelector(
              compact: true,
              onEditionChangeStarted: (editionId) =>
                  _invalidateNarrationForEditionSelection(
                    psalmEditionId: editionId,
                  ),
              onEditionChanged: _reloadPsalmForNewEdition,
            ),
            if (_currentPsalmSource != null) ...<Widget>[
              const SizedBox(height: 8),
              ResponsorialPsalmSourceLabel(resolution: _currentPsalmSource!),
            ],
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BibleVersionSwitcher(
        onVersionChangeStarted: (version) =>
            _invalidateNarrationForEditionSelection(bibleVersion: version),
        onVersionChanged: () {
          _reloadContentForNewVersion();
        },
      ),
    );
  }

  bool get _isResponsorialPsalm =>
      (widget.readingData?.position ?? '').toLowerCase().contains(
        'responsorial psalm',
      ) ||
      widget.reference.toLowerCase().startsWith('ps ');

  Future<void> _reloadPsalmForNewEdition() async {
    if (!mounted || !_isResponsorialPsalm) return;
    setState(() => _isReloading = true);
    try {
      final region = await LiturgicalRegionPreferenceService.getInstance();
      final resolved = await ReadingsService.instance.resolveResponsorialPsalm(
        widget.reference,
        psalmResponse: widget.readingData?.psalmResponse ?? '',
        date:
            widget.readingData?.date ??
            widget.liturgicalDay?.date ??
            DateTime.now(),
        territory: region.currentRegion.code,
        celebrationId: _celebrationId(widget.readingData),
        readingSetKind: _readingSetKind(widget.readingData),
      );
      if (!mounted) return;
      setState(() {
        _currentContent = resolved.text;
        _currentPsalmSource = resolved;
        _isReloading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  static String _celebrationId(DailyReading? reading) {
    final source = reading?.source ?? '';
    final match = RegExp(r'(?:celebration|proper):([^|;]+)').firstMatch(source);
    final explicit = match?.group(1)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return (reading?.feast ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static String _readingSetKind(DailyReading? reading) {
    final position = (reading?.position ?? '').toLowerCase();
    if (position.contains('vigil')) return 'vigil';
    if ((reading?.source ?? '').contains('weekday')) return 'weekday';
    return 'celebration';
  }

  Future<void> _reloadContentForNewVersion() async {
    if (!mounted) return;
    setState(() => _isReloading = true);

    try {
      final readingsService = ReadingsService.instance;
      await readingsService.reloadForVersionChange();

      if (widget.isBibleSearch) {
        final cacheService = BibleCacheService();
        final preference = await BibleVersionPreference.getInstance();
        await cacheService.refreshContentForVersionChange(
          preference.currentVersion.dbName,
        );
      }

      String newContent;

      if (widget.isBibleSearch) {
        final parsed = BibleReferenceHelper.parseReference(widget.reference);
        if (parsed == null) {
          if (mounted) {
            setState(() => _isReloading = false);
          }
          return;
        }

        final bookName = parsed['bookName'] as String;
        final chapter = parsed['chapter'] as int;
        final shortName = await BibleReferenceHelper.getBookShortName(bookName);

        if (shortName == null) {
          if (mounted) {
            setState(() => _isReloading = false);
          }
          return;
        }

        newContent = await readingsService.getChapterText(
          bookShortName: shortName,
          chapter: chapter,
        );
      } else {
        final regionPrefs =
            await LiturgicalRegionPreferenceService.getInstance();
        newContent = await readingsService.getReadingText(
          widget.reference,
          psalmResponse: widget.readingData?.psalmResponse,
          incipit: widget.readingData?.incipit,
          readingType: widget.readingData?.position,
          date: widget.readingData?.date,
          territory: regionPrefs.currentRegion.code,
        );
      }

      if (mounted) {
        setState(() {
          _currentContent = newContent;
          _isReloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to refresh content for this Bible version.'),
          ),
        );
      }
    }
  }

  List<_Verse> _parseVerses(String content) {
    final verses = <_Verse>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final match = RegExp(r'^(\d+)\.?\s+(.+)$').firstMatch(line);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '');
        final text = match.group(2) ?? '';
        if (number != null) {
          verses.add(_Verse(number: number, text: text));
          continue;
        }
      }

      if (verses.isNotEmpty) {
        verses.last = verses.last.copyWith(
          text: verses.last.text + '\n' + line,
        );
      } else {
        verses.add(_Verse(number: null, text: line));
      }
    }

    return verses;
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _currentContent));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading copied to clipboard')),
    );
  }

  void _shareText() {
    final shareText =
        '${widget.reference}\n\n$_currentContent\n\nShared from Catholic Daily app';
    Share.share(shareText, subject: widget.reference);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  @override
  void dispose() {
    _narrationPreparationGeneration++;
    readingNarrationRouteObserver.unsubscribe(this);
    widget.onRouteDisposed?.call();
    final narration = _narration;
    if (narration != null) {
      unawaited(
        narration.controller.onReadingExperienceExit(
          deliberateNavigation: _deliberateNarrationNavigation,
        ),
      );
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _scrollDebounceTimer?.cancel();
    _scrollController.removeListener(_onScrollChanged);

    // Save final scroll position
    if (_scrollController.hasClients) {
      _scrollPositionService.saveScrollPosition(
        widget.reference,
        _scrollController.offset,
      );
    }

    _scrollController.dispose();
    super.dispose();
  }
}

class _Verse {
  final int? number;
  final String text;

  const _Verse({required this.number, required this.text});

  _Verse copyWith({int? number, String? text}) {
    return _Verse(number: number ?? this.number, text: text ?? this.text);
  }
}
