import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models/daily_reading.dart';
import '../../data/models/navigable_item.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/bible_version_preference.dart';
import '../widgets/parchment_background.dart';
import '../widgets/psalm_response_widget.dart';
import '../widgets/gospel_acclamation_widget.dart';
import '../widgets/bible_version_switcher.dart';
import '../widgets/ai_insights_sheet.dart';
import '../utils/reading_title_formatter.dart';
import '../utils/bible_reference_helper.dart';
import '../../data/services/bible_cache_service.dart';
import 'church_locator_screen.dart';

class ReadingScreen extends StatefulWidget {
  final String reference;
  final String content;
  final LiturgicalDay? liturgicalDay;
  final DailyReading? readingData;
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

  const ReadingScreen({
    super.key,
    required this.reference,
    required this.content,
    this.liturgicalDay,
    this.readingData,
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

class _ReadingScreenState extends State<ReadingScreen> {
  double _textScale = 1.0;
  final ScrollController _scrollController = ScrollController();
  String _currentContent = '';
  bool _isReloading = false;
  bool _isBookmarked = false;
  bool _isNavigating = false;
  bool _hasPreviousChapter = false;
  bool _hasNextChapter = false;
  bool _isFullScreen = false;

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
    final match = RegExp(r'\(alternative(?:\s+(\d+))?\)$', caseSensitive: false)
        .firstMatch(position);
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
    return nextItem.isOrderOfMass ? nextItem.orderOfMassItem?.title : nextItem.reading?.position;
  }

  String? get _prevItemLabel {
    if (widget.navigableItems.isEmpty) return null;
    final prevIndex = widget.currentNavigableIndex - 1;
    if (prevIndex < 0) return null;
    final prevItem = widget.navigableItems[prevIndex];
    return prevItem.isOrderOfMass ? prevItem.orderOfMassItem?.title : prevItem.reading?.position;
  }

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
    _loadBookmarkStatus();
    if (widget.isBibleSearch) {
      _checkChapterAvailability();
    }
  }

  Future<void> _checkChapterAvailability() async {
    if (!widget.isBibleSearch) return;
    
    final hasPrevious = await BibleReferenceHelper.hasPreviousChapter(widget.reference);
    final hasNext = await BibleReferenceHelper.hasNextChapter(widget.reference);
    
    if (mounted) {
      setState(() {
        _hasPreviousChapter = hasPrevious;
        _hasNextChapter = hasNext;
      });
    }
  }

  @override
  void didUpdateWidget(ReadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      setState(() {
        _currentContent = widget.content;
      });
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ChurchLocatorScreen(),
      ),
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
      final prevChapter = await BibleReferenceHelper.getPreviousChapter(widget.reference);
      if (prevChapter != null) {
        if (mounted) {
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
          const SnackBar(content: Text('Unable to load the previous chapter right now.')),
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
      final nextChapter = await BibleReferenceHelper.getNextChapter(widget.reference);
      if (nextChapter != null) {
        if (mounted) {
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
          const SnackBar(content: Text('Unable to load the next chapter right now.')),
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
                (isLight ? Colors.white : colorScheme.surface)
                    .withValues(alpha: isLight ? 0.94 : 0.84),
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
                          colorScheme.surface
                              .withValues(alpha: isLight ? 0.42 : 0.3),
                          widget.liturgicalDay!.colorValue
                              .withValues(alpha: isLight ? 0.96 : 1),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + 64,
                            16,
                            16,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
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
                    )
                  : null,
              actions: [
                Semantics(
                  label: _isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border),
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
                    }
                  },
                  itemBuilder: (context) => [
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
                          Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen),
                          const SizedBox(width: 12),
                          Text(_isFullScreen ? 'Exit Fullscreen' : 'Fullscreen'),
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
            SliverToBoxAdapter(
              child: _buildHeader(theme),
            ),
            if (widget.sessionReadings.length > 1 && !widget.isBibleSearch)
              SliverToBoxAdapter(
                child: _buildVariantSwitcher(theme),
              ),
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
                ),
              ),
            SliverToBoxAdapter(
              child: _buildContent(theme),
            ),
            SliverToBoxAdapter(
              child: _buildVersionFooter(theme),
            ),
            if (widget.hasNext || widget.hasPrev)
              SliverToBoxAdapter(
                child: _buildNavigation(theme),
              ),
          ],
        ),
      ),
      floatingActionButton: widget.liturgicalDay != null
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
                  label: Text(_isNavigating ? 'Loading...' : 'Previous Chapter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ordoColor,
                    foregroundColor: buttonForeground,
                  ),
                ),
              ),
            if (_hasPreviousChapter && _hasNextChapter) const SizedBox(width: 12),
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
                                    const Duration(milliseconds: 100));
                                widget.onPrevReading?.call();
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
                          Text(_isNavigating && widget.hasPrev && !widget.hasNext
                              ? 'Loading...'
                              : 'Previous'),
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
                                    const Duration(milliseconds: 100));
                                widget.onNextReading?.call();
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
                          Text(_isNavigating && widget.hasNext && !widget.hasPrev
                              ? 'Loading...'
                              : 'Next'),
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
                                  const Duration(milliseconds: 100));
                              widget.onPrevReading?.call();
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
                                : 'Previous')),
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
                                  const Duration(milliseconds: 100));
                              widget.onNextReading?.call();
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
                                : 'Next')),
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
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

    final headerAccent = ThemeData.estimateBrightnessForColor(ordoColor) ==
            Brightness.dark
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

  Widget _buildVariantSwitcher(ThemeData theme) {
    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;

    final labelColor = theme.colorScheme.onSurface;
    final unselectedTextColor = theme.colorScheme.onSurface;
    final selectedTextColor = _contrastColor(ordoColor);

    // Group alternatives by their base reading type
    final groupedReadings = _groupAlternativesByType();

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
        ...groupedReadings.entries.map((entry) {
          final typeLabel = entry.key;
          final readings = entry.value;
          final hasMultipleAlternatives = readings.length > 1;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasMultipleAlternatives)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    typeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              SizedBox(
                height: hasMultipleAlternatives ? 80 : 0,
                child: hasMultipleAlternatives
                    ? ListView.builder(
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
                            showTypeLabel: !hasMultipleAlternatives,
                          );
                        },
                      )
                    : null,
              ),
            ],
          );
        }),
      ],
    );
  }

  Map<String, List<DailyReading>> _groupAlternativesByType() {
    final grouped = <String, List<DailyReading>>{};

    for (final reading in widget.sessionReadings) {
      final position = reading.position ?? 'Reading';
      final baseType = _getBaseReadingType(position);

      if (!grouped.containsKey(baseType)) {
        grouped[baseType] = [];
      }
      grouped[baseType]!.add(reading);
    }

    // Sort by reading type order
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _getReadingTypeOrder(a).compareTo(_getReadingTypeOrder(b)));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  String _getBaseReadingType(String position) {
    final lowerPos = position.toLowerCase();

    // Extract base type from positions like "Gospel (alternative)" or "First Reading (alternative 2)"
    if (lowerPos.contains('first reading')) return 'First Reading';
    if (lowerPos.contains('second reading')) return 'Second Reading';
    if (lowerPos.contains('responsorial psalm')) return 'Responsorial Psalm';
    if (lowerPos.contains('alleluia psalm')) return 'Alleluia Psalm';
    if (lowerPos.contains('gospel acclamation')) return 'Gospel Acclamation';
    if (lowerPos.contains('gospel')) return 'Gospel';

    return position.split('(').first.trim();
  }

  int _getReadingTypeOrder(String type) {
    switch (type.toLowerCase()) {
      case 'first reading':
        return 1;
      case 'responsorial psalm':
      case 'alleluia psalm':
        return 2;
      case 'second reading':
        return 3;
      case 'gospel acclamation':
        return 4;
      case 'gospel':
        return 5;
      default:
        return 999;
    }
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
      (isLight ? Colors.white : theme.colorScheme.surfaceContainer)
          .withValues(alpha: isLight ? 0.92 : 0.52),
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
          if (verse.number != null)
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
                fontSize:
                    theme.textTheme.bodyLarge!.fontSize! * _textScale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BibleVersionSwitcher(
        onVersionChanged: () {
          _reloadContentForNewVersion();
        },
      ),
    );
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
        await cacheService.refreshContentForVersionChange(preference.currentVersion.dbName);
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
        newContent = await readingsService.getReadingText(
          widget.reference,
          psalmResponse: widget.readingData?.psalmResponse,
          incipit: widget.readingData?.incipit,
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
          const SnackBar(content: Text('Unable to refresh content for this Bible version.')),
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

      final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(line);
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
    final shareText = '${widget.reference}\n\n$_currentContent\n\nShared from Catholic Daily app';
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
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    _scrollController.dispose();
    super.dispose();
  }
}

class _Verse {
  final int? number;
  final String text;

  const _Verse({
    required this.number,
    required this.text,
  });

  _Verse copyWith({
    int? number,
    String? text,
  }) {
    return _Verse(
      number: number ?? this.number,
      text: text ?? this.text,
    );
  }
}
