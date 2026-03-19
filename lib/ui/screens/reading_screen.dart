import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../widgets/parchment_background.dart';
import '../widgets/psalm_response_widget.dart';
import '../widgets/gospel_acclamation_widget.dart';
import '../widgets/bible_version_switcher.dart';
import '../utils/reading_title_formatter.dart';

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
  });

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  double _textScale = 1.0;
  bool _showLiturgicalInfo = false;
  final ScrollController _scrollController = ScrollController();
  String _currentContent = '';
  bool _isReloading = false;
  bool _isBookmarked = false;
  bool _isNavigating = false;

  String get _readingLabel {
    final position = widget.readingData?.position?.trim();
    if (position != null && position.isNotEmpty) {
      return position;
    }

    final reference = widget.reference.toLowerCase();
    if (reference.startsWith('ps ') || reference.startsWith('psalm ')) {
      return 'Psalm';
    } else if (reference.contains('gospel') || reference.contains('mk') || 
               reference.contains('mt') || reference.contains('lk') || reference.contains('jn')) {
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

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
    _loadBookmarkStatus();
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

  void _selectVariant(DailyReading reading) async {
    if (_isNavigating) return; // Prevent multiple simultaneous selections
    
    final index = widget.sessionReadings.indexOf(reading);
    if (index < 0 || index == widget.currentReadingIndex) {
      return;
    }

    setState(() {
      _isNavigating = true;
    });

    try {
      // Add a small delay for better UX feedback
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
    final onOrdoColor = ThemeData.estimateBrightnessForColor(ordoColor) == Brightness.dark
        ? Colors.white
        : isLight 
            ? colorScheme.onSurface.withValues(alpha: 0.87)
            : colorScheme.onSurface;

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
                (isLight ? Colors.white : colorScheme.surface).withValues(alpha: isLight ? 0.94 : 0.84),
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
                          colorScheme.surface.withValues(alpha: isLight ? 0.42 : 0.3),
                          widget.liturgicalDay!.colorValue.withValues(alpha: isLight ? 0.96 : 1),
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
                  icon: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border),
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
                    }
                  },
                  itemBuilder: (context) => [
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
            if (widget.sessionReadings.length > 1)
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
      // Floating liturgical info button
      floatingActionButton: widget.liturgicalDay != null
          ? FloatingActionButton.small(
              backgroundColor: widget.liturgicalDay!.colorValue,
              foregroundColor: widget.liturgicalDay!.textColor,
              onPressed: () =>
                  setState(() => _showLiturgicalInfo = !_showLiturgicalInfo),
              child: Icon(_showLiturgicalInfo ? Icons.info : Icons.church),
            )
          : null,
    );
  }

  Widget _buildNavigation(ThemeData theme) {
    // Always show navigation when there are multiple readings in the session
    final hasMultipleReadings = widget.sessionReadings.length > 1;
    final shouldShowNavigation = hasMultipleReadings || widget.hasNext || widget.hasPrev;
    
    if (!shouldShowNavigation) return const SizedBox.shrink();
    
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final buttonForeground = ThemeData.estimateBrightnessForColor(ordoColor) == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show reading count when there are multiple readings
          if (hasMultipleReadings)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Reading ${widget.currentReadingIndex + 1} of ${widget.sessionReadings.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          // Navigation buttons
          Row(
            children: [
              if (widget.hasPrev)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isNavigating ? null : () async {
                      setState(() => _isNavigating = true);
                      try {
                        await Future.delayed(const Duration(milliseconds: 100));
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
                    label: Text(_isNavigating && widget.hasPrev && !widget.hasNext ? 'Loading...' : 'Previous'),
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
                    onPressed: _isNavigating ? null : () async {
                      setState(() => _isNavigating = true);
                      try {
                        await Future.delayed(const Duration(milliseconds: 100));
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
                    label: Text(_isNavigating && widget.hasNext && !widget.hasPrev ? 'Loading...' : 'Next'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ordoColor,
                      foregroundColor: buttonForeground,
                    ),
                  ),
                ),
              // Show disabled state when no navigation is available but there are multiple readings
              if (!widget.hasPrev && !widget.hasNext && hasMultipleReadings)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No more readings in this session',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final headerAccent = _resolveHeaderAccent(theme, ordoColor);
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
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVariantSwitcher(ThemeData theme) {
    final color = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Alternative Readings',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
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
                  color: isSelected ? color : null,
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
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurfaceVariant,
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
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
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
      final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: ordoColor,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading reading...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final verses = _parseVerses(_currentContent);
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final containerColor = Color.alphaBlend(
      (isLight ? Colors.white : theme.colorScheme.surfaceContainer).withValues(alpha: isLight ? 0.92 : 0.52),
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
              color: ordoColor,
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
                fontSize: theme.textTheme.bodyLarge!.fontSize! * _textScale,
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
          // Handle version change
        },
      ),
    );
  }

  Color _resolveHeaderAccent(ThemeData theme, Color ordoColor) {
    return theme.brightness == Brightness.light
        ? ordoColor.withValues(alpha: 0.8)
        : ordoColor.withValues(alpha: 0.9);
  }

  List<_Verse> _parseVerses(String content) {
    final verses = <_Verse>[];
    final lines = content.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Try to extract verse number at the start
      final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(line);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '');
        final text = match.group(2) ?? '';
        if (number != null) {
          verses.add(_Verse(number: number, text: text));
          continue;
        }
      }
      
      // If no verse number found, treat as continuation
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
    // TODO: Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }

  void _toggleFullScreen() {
    // TODO: Implement fullscreen functionality
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
