import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/daily_reading.dart';
import '../../data/models/navigable_item.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/bible_version_preference.dart';
import '../../data/services/order_of_mass_preference_service.dart';
import '../widgets/parchment_background.dart';
import '../widgets/psalm_response_widget.dart';
import '../widgets/gospel_acclamation_widget.dart';
import '../widgets/bible_version_switcher.dart';
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
  final VoidCallback? onOrderOfMassToggled;

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
    this.onOrderOfMassToggled,
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

// ---------------------------------------------------------------------------
// WCAG-compliant contrast helper
// Returns either Colors.white or Colors.black (with optional alpha) so that
// text placed *on top of* [background] always meets at least a 4.5:1 ratio.
// ---------------------------------------------------------------------------
Color _contrastColor(Color background, {double alpha = 1.0}) {
  // Convert sRGB channel to linear light value per WCAG 2.x spec
  double _lin(double c) =>
      c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);

  final r = _lin(background.r);
  final g = _lin(background.g);
  final b = _lin(background.b);
  final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

  // White on dark backgrounds, near-black on light ones
  return luminance < 0.179
      ? Colors.white.withValues(alpha: alpha)
      : Colors.black.withValues(alpha: alpha);
}

class _ReadingScreenState extends State<ReadingScreen> {
  double _textScale = 1.0;
  final ScrollController _scrollController = ScrollController();
  final OrderOfMassPreferenceService _orderOfMassPreferenceService =
      OrderOfMassPreferenceService();
  String _currentContent = '';
  bool _isReloading = false;
  bool _isBookmarked = false;
  bool _isNavigating = false;
  bool _hasPreviousChapter = false;
  bool _hasNextChapter = false;
  bool _showOrderOfMass = false;

  String get _readingLabel {
    final position = widget.readingData?.position?.trim();
    if (position != null && position.isNotEmpty) {
      return position;
    }

    final reference = widget.reference.toLowerCase();
    if (reference.startsWith('ps ') || reference.startsWith('psalm ')) {
      return 'Psalm';
    } else if (reference.contains('gospel') ||
        reference.contains('mk') ||
        reference.contains('mt') ||
        reference.contains('lk') ||
        reference.contains('jn')) {
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
    _loadOrderOfMassPreference();
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
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarked_readings') ?? [];
    setState(() {
      _isBookmarked = bookmarks.contains(widget.reference);
    });
  }

  Future<void> _loadOrderOfMassPreference() async {
    final showOrderOfMass = await _orderOfMassPreferenceService.getShowOrderOfMass();
    if (mounted) {
      setState(() {
        _showOrderOfMass = showOrderOfMass;
      });
    }
  }

  Future<void> _toggleOrderOfMass() async {
    final newValue = !_showOrderOfMass;
    await _orderOfMassPreferenceService.setShowOrderOfMass(newValue);
    if (mounted) {
      setState(() {
        _showOrderOfMass = newValue;
      });
    }
    // Notify parent to rebuild the flow
    widget.onOrderOfMassToggled?.call();
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
      builder: (context) => _AiInsightsSheet(
        reference: widget.reference,
        content: _currentContent,
      ),
    );
  }

  Future<void> _toggleBookmark() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bookmarked_readings') ?? [];

    if (_isBookmarked) {
      bookmarks.remove(widget.reference);
    } else {
      bookmarks.add(widget.reference);
    }

    await prefs.setStringList('bookmarked_readings', bookmarks);
    setState(() {
      _isBookmarked = !_isBookmarked;
    });
  }

  Future<void> _goToPreviousChapter() async {
  if (!widget.isBibleSearch || _isNavigating) return;
  
  setState(() => _isNavigating = true);
  
  try {
    final prevChapter = await BibleReferenceHelper.getPreviousChapter(widget.reference);
    if (prevChapter != null) {
      // Navigate to the previous chapter by replacing the current screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
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
    // Show error if navigation fails
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading previous chapter: $e')),
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
      // Navigate to the next chapter by replacing the current screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
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
    // Show error if navigation fails
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading next chapter: $e')),
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

    // onOrdoColor: text that sits ON the ordo-tinted AppBar / flexible space
    // background. Use WCAG luminance check so white ordo is always legible.
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
                IconButton(
                  icon: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: _toggleBookmark,
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
                      case 'toggle_order_of_mass':
                        _toggleOrderOfMass();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (widget.liturgicalDay != null && !widget.isBibleSearch)
                      PopupMenuItem(
                        value: 'toggle_order_of_mass',
                        child: Row(
                          children: [
                            Icon(_showOrderOfMass ? Icons.visibility_off : Icons.visibility),
                            const SizedBox(width: 12),
                            Text(_showOrderOfMass ? 'Hide Order of Mass' : 'Show Order of Mass'),
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
                    const PopupMenuItem(
                      value: 'fullscreen',
                      child: Row(
                        children: [
                          Icon(Icons.fullscreen),
                          SizedBox(width: 12),
                          Text('Fullscreen'),
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
          ? FloatingActionButton.small(
              backgroundColor: widget.liturgicalDay!.colorValue,
              foregroundColor: widget.liturgicalDay!.textColor,
              onPressed: _openChurchLocator,
              child: const Icon(Icons.church),
            )
          : null,
    );
  }

  Widget _buildNavigation(ThemeData theme) {
    // For bible search, use chapter navigation
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

    // For order of mass flow
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
            // Progress indicator with more context
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

    // For daily readings, use existing logic
    final hasMultipleReadings = widget.sessionReadings.length > 1;
    final shouldShowNavigation =
        hasMultipleReadings || widget.hasNext || widget.hasPrev;

    if (!shouldShowNavigation) return const SizedBox.shrink();

    final ordoColor =
        widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    // Button label always contrasts against the ordo-colored button background
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

    // The header sits on the page surface, NOT on the ordo color directly.
    // Use onSurface so it's always legible regardless of ordoColor value.
    // Give it a subtle ordo tint only when the background is significantly dark.
    final headerAccent = ThemeData.estimateBrightnessForColor(ordoColor) ==
            Brightness.dark
        ? ordoColor // dark ordo (e.g. purple/red) → use ordo as accent is fine
        : theme.colorScheme
            .onSurface; // light ordo (e.g. white/gold) → always use onSurface

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

    // CONTRAST FIX ─────────────────────────────────────────────────────────
    // The "Alternative Readings" label and non-selected card text sit on the
    // page surface, *not* on the ordo color.  Always use onSurface here so
    // contrast is guaranteed regardless of ordoColor (e.g. white liturgical
    // seasons were making text invisible on the light parchment background).
    //
    // Selected card text must contrast against the ordoColor chip background,
    // so we use the WCAG luminance helper there.
    // ───────────────────────────────────────────────────────────────────────
    final labelColor = theme.colorScheme.onSurface;
    final unselectedTextColor = theme.colorScheme.onSurface;
    final selectedTextColor = _contrastColor(ordoColor);

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
            itemCount: widget.sessionReadings.length,
            itemBuilder: (context, index) {
              final reading = widget.sessionReadings[index];
              final isSelected = index == widget.currentReadingIndex;
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
                              Text(
                                reading.position ?? '',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  // Selected → contrast on ordoColor chip
                                  // Unselected → contrast on surface
                                  color: isSelected
                                      ? selectedTextColor
                                      : unselectedTextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                reading.reading,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isSelected
                                      ? selectedTextColor.withValues(alpha: 0.82)
                                      : unselectedTextColor.withValues(
                                          alpha: 0.7),
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
            },
          ),
        ),
      ],
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
              // Reference sits on the lightly-tinted container; use onSurface
              // for reliable contrast across all ordo colors.
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
  setState(() => _isReloading = true);
  
  try {
    // Reload backend data for version change
    final readingsService = ReadingsService.instance;
    await readingsService.reloadForVersionChange();
    
    // Refresh cache content for version change
    if (widget.isBibleSearch) {
      final cacheService = BibleCacheService();
      final preference = await BibleVersionPreference.getInstance();
      await cacheService.refreshContentForVersionChange(preference.currentVersion.dbName);
    }
    
    String newContent;
    
    if (widget.isBibleSearch) {
      // Handle bible chapter/page content
      final parsed = BibleReferenceHelper.parseReference(widget.reference);
      if (parsed == null) return;
      
      final bookName = parsed['bookName'] as String;
      final chapter = parsed['chapter'] as int;
      final shortName = await BibleReferenceHelper.getBookShortName(bookName);
      
      if (shortName == null) return;
      
      newContent = await readingsService.getChapterText(
        bookShortName: shortName,
        chapter: chapter,
      );
    } else {
      // Handle regular liturgical readings
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
        SnackBar(content: Text('Error loading content: $e')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _toggleFullScreen() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fullscreen functionality coming soon')),
    );
  }

  @override
  void dispose() {
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

// ---------------------------------------------------------------------------
// AI Insights bottom sheet
// ---------------------------------------------------------------------------
class _AiInsightsSheet extends StatefulWidget {
  final String reference;
  final String content;

  const _AiInsightsSheet({required this.reference, required this.content});

  @override
  State<_AiInsightsSheet> createState() => _AiInsightsSheetState();
}

class _AiInsightsSheetState extends State<_AiInsightsSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _insight;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
  }

  Future<void> _fetchInsight() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // verseId is the URI-encoded reference; reference+text also sent in body
      final verseId = Uri.encodeComponent(widget.reference);
      // Truncate very long passages to avoid request size issues
      final text = widget.content.length > 3000
          ? '${widget.content.substring(0, 3000)}...'
          : widget.content;

      final response = await http.post(
        Uri.parse('https://api.elbiblio.com/api/bible/verses/$verseId/explain'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'reference': widget.reference,
          'text': text,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API wraps payload: { success, message, data: { ... } }
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = (body['data'] ?? body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _insight = payload;
            _isLoading = false;
          });
          final meaning = _coreMeaning;
          if (meaning.isNotEmpty) {
            BibleCacheService().cacheInsight(
              reference: widget.reference,
              title: meaning,
              content: meaning,
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Could not load insights (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to insights service.';
          _isLoading = false;
        });
      }
    }
  }

  String get _coreMeaning {
    final qi = _insight?['quick_insight'];
    if (qi is Map) return qi['core_meaning']?.toString() ?? '';
    return '';
  }

  // reflection_questions is a single object { category, questions: [...] }
  List<String> get _reflectionQuestions {
    final rq = _insight?['reflection_questions'];
    if (rq is Map) {
      final qs = rq['questions'];
      if (qs is List) return qs.map((q) => q.toString()).take(3).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Insights — ${widget.reference}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating insights...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    color: theme.colorScheme.error, size: 48),
                                const SizedBox(height: 12),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _fetchInsight,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildInsightSection(
                              theme,
                              icon: Icons.lightbulb_outline,
                              title: 'Core Meaning',
                              body: _coreMeaning,
                            ),
                            if (_insight?['quick_insight']?['universal_connection'] != null)
                              _buildInsightSection(
                                theme,
                                icon: Icons.connect_without_contact,
                                title: 'Universal Connection',
                                body: _insight!['quick_insight']['universal_connection'].toString(),
                              ),
                            if (_insight?['deeper_exploration']?['historical_context'] != null)
                              _buildInsightSection(
                                theme,
                                icon: Icons.history_edu,
                                title: 'Historical Context',
                                body: _insight!['deeper_exploration']['historical_context'].toString(),
                              ),
                            if (_insight?['reflection_questions'] != null)
                              _buildReflectionQuestions(theme),
                            const SizedBox(height: 16),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsightSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildReflectionQuestions(ThemeData theme) {
    final questionList = _reflectionQuestions;
    if (questionList.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Reflection Questions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...questionList.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodyMedium),
                    Expanded(child: Text(q, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
