import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/models/daily_reading.dart';
import '../utils/reading_title_formatter.dart';
import '../widgets/bible_version_switcher.dart';
import '../widgets/gospel_acclamation_widget.dart';
import '../widgets/psalm_response_widget.dart';
import '../../data/services/readings_backend_io.dart' as backend;
import '../widgets/parchment_background.dart';

class ReadingScreen extends StatefulWidget {
  final String reference;
  final String content;
  final LiturgicalDay? liturgicalDay;
  final DailyReading? readingData;
  final VoidCallback? onNextReading;
  final VoidCallback? onPrevReading;
  final bool hasNext;
  final bool hasPrev;

  const ReadingScreen({
    super.key,
    required this.reference,
    required this.content,
    this.liturgicalDay,
    this.readingData,
    this.onNextReading,
    this.onPrevReading,
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

  String get _readingLabel {
    final position = widget.readingData?.position?.trim();
    if (position != null && position.isNotEmpty) {
      return position;
    }

    final reference = widget.reference.toLowerCase();
    if (reference.startsWith('ps ') || reference.startsWith('psalm ')) {
      return 'Responsorial Psalm';
    }
    if (reference.startsWith('matt ') ||
        reference.startsWith('mark ') ||
        reference.startsWith('luke ') ||
        reference.startsWith('john ')) {
      return 'Gospel';
    }
    return 'Reading';
  }

  String get _insightContextLabel {
    final position = widget.readingData?.position?.trim();
    if (position != null && position.isNotEmpty) {
      return position;
    }
    return 'Reading';
  }

  @override
  void initState() {
    super.initState();
    _currentContent = widget.content;
  }

  @override
  void didUpdateWidget(ReadingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.content != oldWidget.content) {
      setState(() {
        _currentContent = widget.content;
      });
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _reloadWithNewVersion() async {
    setState(() {
      _isReloading = true;
    });

    try {
      final readingsBackend = backend.ReadingsBackendIo();
      final newContent = await readingsBackend.getReadingText(widget.reference);
      
      if (mounted) {
        setState(() {
          _currentContent = newContent;
          _isReloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reload: $e')),
        );
      }
    }
  }

  Future<void> _showVerseActions({
    _Verse? verse,
    String? selectedText,
    String? selectedLabel,
  }) async {
    final label = selectedLabel ?? (verse != null ? 'Verse ${verse.number}' : 'Selected text');
    final text = selectedText ?? verse?.text;

    if (text == null || text.trim().isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Verse Insights',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$label • ${widget.reference}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _InsightActionTile(
                  icon: Icons.auto_awesome,
                  title: 'Insight for $label',
                  subtitle: 'Explain the selected verse or highlighted line.',
                  onTap: () => Navigator.of(context).pop('selected'),
                ),
                const SizedBox(height: 8),
                _InsightActionTile(
                  icon: Icons.menu_book_rounded,
                  title: 'Insight for entire $_insightContextLabel',
                  subtitle: 'Explain the full passage you are currently viewing.',
                  onTap: () => Navigator.of(context).pop('full'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedAction == 'selected') {
      await _showInsightSheet(
        title: 'Insight for $label',
        reference: verse != null ? '${widget.reference}:${verse.number}' : widget.reference,
        highlightedText: text,
        fetchInsight: () => _fetchInsight(
          focusText: text,
          fullContextText: _currentContent,
          mode: 'selected',
          verseNumber: verse?.number,
        ),
      );
    } else if (selectedAction == 'full') {
      await _showInsightSheet(
        title: 'Insight for $_insightContextLabel',
        reference: widget.reference,
        highlightedText: _currentContent,
        fetchInsight: () => _fetchInsight(
          focusText: _currentContent,
          fullContextText: _currentContent,
          mode: 'full',
        ),
      );
    }
  }

  Future<void> _showInsightSheet({
    required String title,
    required String reference,
    required String highlightedText,
    required Future<String> Function() fetchInsight,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReadingInsightSheet(
        title: title,
        reference: reference,
        highlightedText: highlightedText,
        fetchInsight: fetchInsight,
      ),
    );
  }

  Future<String> _fetchInsight({
    required String focusText,
    required String fullContextText,
    required String mode,
    int? verseNumber,
  }) async {
    try {
      final insightReference = verseNumber != null
          ? '$widget.reference:$verseNumber'
          : widget.reference;
      final verseId = _buildInsightVerseId(insightReference, mode);
      final prompt = mode == 'full'
          ? 'Explain this passage for a Catholic reader using the provided text and reference. Return the structured JSON shape expected by the API.'
          : 'Explain this selected verse or line for a Catholic reader using the provided text and reference. Return the structured JSON shape expected by the API.';

      final response = await http.post(
        Uri.parse('https://api.elbiblio.com/api/bible/verses/$verseId/explain'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': focusText,
          'reference': insightReference,
          'version': 'rsvce',
          'prompt': prompt,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = (data['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
        final formatted = _formatInsightResponse(payload, fullContextText: fullContextText);
        if (formatted.trim().isNotEmpty) {
          return formatted;
        }
      }
    } catch (e) {
      debugPrint('Error fetching insight: $e');
    }
    // Fallback if API fails or doesn't support generic text explanation yet
    await Future.delayed(const Duration(seconds: 1));
    if (mode == 'full') {
      return "This passage is best understood as a whole unit. Read it in light of its literary setting, the surrounding verses, and the Church's living tradition. Ask how the full reading reveals God's action, what it teaches about Christ, and how it calls you to prayer and conversion.";
    }
    return "This selected verse or line can be read more fruitfully within the full passage around it. The Catholic tradition reads each verse in harmony with the whole of Scripture and the life of the Church, inviting prayerful reflection and concrete response.";
  }

  String _buildInsightVerseId(String reference, String mode) {
    final sanitizedReference = reference
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final position = widget.readingData?.position
        ?.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    return [
      'missal',
      position,
      sanitizedReference,
      mode,
    ].whereType<String>().where((value) => value.isNotEmpty).join('_');
  }

  String _formatInsightResponse(
    Map<String, dynamic> payload, {
    required String fullContextText,
  }) {
    final quickInsight = (payload['quick_insight'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final deeperExploration = (payload['deeper_exploration'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final reflectionQuestions = (payload['reflection_questions'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final livingThisOut = (payload['living_this_out'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const <Map<String, dynamic>>[];
    final theologicalNotes = (payload['theological_notes'] as List?)?.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList() ?? const <Map<String, dynamic>>[];

    final sections = <String>[];

    void addSection(String title, String? content) {
      final value = content?.trim();
      if (value == null || value.isEmpty) {
        return;
      }
      sections.add('$title\n$value');
    }

    addSection('Core meaning', quickInsight['core_meaning'] as String?);
    addSection('Universal connection', quickInsight['universal_connection'] as String?);
    addSection('Historical context', deeperExploration['historical_context'] as String?);
    addSection('Original language insight', deeperExploration['original_language_insight'] as String?);
    addSection('Biblical theme connection', deeperExploration['biblical_theme_connection'] as String?);

    if (livingThisOut.isNotEmpty) {
      final livingContent = livingThisOut.map((entry) {
        final scenario = (entry['scenario'] as String?)?.trim();
        final actions = (entry['actions'] as List?)?.whereType<String>().where((item) => item.trim().isNotEmpty).toList() ?? const <String>[];
        final lines = <String>[];
        if (scenario != null && scenario.isNotEmpty) {
          lines.add(scenario);
        }
        lines.addAll(actions.map((action) => '- $action'));
        return lines.join('\n');
      }).where((entry) => entry.trim().isNotEmpty).join('\n\n');
      addSection('Living this out', livingContent);
    }

    final questions = (reflectionQuestions['questions'] as List?)
            ?.whereType<String>()
            .where((item) => item.trim().isNotEmpty)
            .toList() ??
        const <String>[];
    if (questions.isNotEmpty) {
      addSection(
        'Reflection questions',
        questions.map((question) => '- $question').join('\n'),
      );
    }

    if (theologicalNotes.isNotEmpty) {
      final noteLines = theologicalNotes.map((entry) {
        final topic = (entry['topic'] as String?)?.trim();
        final note = (entry['note'] as String?)?.trim();
        if (topic != null && topic.isNotEmpty && note != null && note.isNotEmpty) {
          return '- $topic: $note';
        }
        return '- ${topic ?? note ?? ''}'.trim();
      }).where((item) => item.length > 2).join('\n');
      addSection('Theological notes', noteLines);
    }

    if (sections.isEmpty) {
      return fullContextText.trim().isNotEmpty
          ? 'This reading invites prayerful reflection within the whole passage. Read it slowly, note what it reveals about Christ, and ask how it calls you to faith, repentance, and charity.'
          : '';
    }

    return sections.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? colorScheme.primary;
    final onOrdoColor = ThemeData.estimateBrightnessForColor(ordoColor) == Brightness.dark
        ? Colors.white
        : colorScheme.onSurface;
    final scaffoldColor = Color.alphaBlend(
      (isLight ? Colors.white : colorScheme.surface).withValues(alpha: isLight ? 0.97 : 0.9),
      ordoColor.withValues(alpha: isLight ? 0.08 : 0.18),
    );

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: ParchmentBackground(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  (isLight ? Colors.white : colorScheme.surface).withValues(alpha: isLight ? 0.88 : 0.22),
                  ordoColor.withValues(alpha: isLight ? 0.10 : 0.18),
                ),
                scaffoldColor,
              ],
            ),
          ),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
            SliverAppBar(
              expandedHeight: widget.liturgicalDay != null ? 156 : 0,
              pinned: true,
              backgroundColor: Color.alphaBlend(
                (isLight ? Colors.white : colorScheme.surface).withValues(alpha: isLight ? 0.94 : 0.84),
                ordoColor.withValues(alpha: isLight ? 0.08 : 0.18),
              ),
              surfaceTintColor: Colors.transparent,
              foregroundColor: onOrdoColor,
              flexibleSpace: widget.liturgicalDay != null
                  ? FlexibleSpaceBar(
                      background: Container(
                        color: Color.alphaBlend(
                          colorScheme.surface.withValues(alpha: isLight ? 0.82 : 0.3),
                          widget.liturgicalDay!.colorValue.withValues(alpha: isLight ? 0.16 : 1),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + kToolbarHeight + 12,
                            16,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                widget.liturgicalDay!.fullDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: onOrdoColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.liturgicalDay!.weekDescription,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: onOrdoColor.withValues(alpha: 0.82),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : null,
              title: Text(
                _readingLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
              // Text size controls
              IconButton(
                icon: const Icon(Icons.text_decrease),
                onPressed: _textScale > 0.8
                    ? () => setState(() => _textScale -= 0.1)
                    : null,
                tooltip: 'Decrease text size',
              ),
              IconButton(
                icon: const Icon(Icons.text_increase),
                onPressed: _textScale < 2.0
                    ? () => setState(() => _textScale += 0.1)
                    : null,
                tooltip: 'Increase text size',
              ),
              // More options
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'share':
                      _shareText();
                      break;
                    case 'copy':
                      _copyText();
                      break;
                    case 'insight_full':
                      _showInsightSheet(
                        title: 'Insight for $_insightContextLabel',
                        reference: widget.reference,
                        highlightedText: _currentContent,
                        fetchInsight: () => _fetchInsight(
                          focusText: _currentContent,
                          fullContextText: _currentContent,
                          mode: 'full',
                        ),
                      );
                      break;
                    case 'fullscreen':
                      _toggleFullScreen();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 12),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 20),
                        SizedBox(width: 12),
                        Text('Copy'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'insight_full',
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome, size: 20),
                        SizedBox(width: 12),
                        Text('AI Insights (entire reading)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'fullscreen',
                    child: Row(
                      children: [
                        Icon(Icons.fullscreen, size: 20),
                        SizedBox(width: 12),
                        Text('Full screen'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reference header
                  _buildHeader(theme),
                  const SizedBox(height: 32),

                  // Psalm Response or Gospel Acclamation (before reading)
                  _buildResponseAcclamation(theme),

                  const SizedBox(height: 32),

                  // Reading content with beautiful typography
                  _buildContent(theme),

                  const SizedBox(height: 48),
                  
                  // Version switcher
                  _buildVersionFooter(theme),
                  
                  const SizedBox(height: 32),
                  
                  // Navigation
                  _buildNavigation(theme),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
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
    if (!widget.hasPrev && !widget.hasNext) return const SizedBox.shrink();
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final buttonForeground = ThemeData.estimateBrightnessForColor(ordoColor) == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onSurface;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.hasPrev)
          TextButton.icon(
            onPressed: widget.onPrevReading,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              backgroundColor: Color.alphaBlend(
                (isLight ? Colors.white : theme.colorScheme.surface).withValues(alpha: isLight ? 0.94 : 0.24),
                ordoColor.withValues(alpha: isLight ? 0.08 : 0.14),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
          
        if (widget.hasNext)
          FilledButton.icon(
            onPressed: widget.onNextReading,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Reading'),
            style: FilledButton.styleFrom(
              backgroundColor: Color.alphaBlend(
                theme.colorScheme.primary.withValues(alpha: isLight ? 0.82 : 0.7),
                ordoColor.withValues(alpha: isLight ? 0.18 : 0.24),
              ),
              foregroundColor: buttonForeground,
            ),
          )
        else
          const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme) {
    final brandColor = theme.colorScheme.primary;
    final readingTitle = ReadingTitleFormatter.build(
      reference: widget.reference,
      position: widget.readingData?.position,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _readingLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: brandColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          readingTitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.84),
            fontWeight: FontWeight.w600,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.reference,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.1,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 3,
          decoration: BoxDecoration(
            color: brandColor,
            borderRadius: BorderRadius.circular(2),
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
          child: CircularProgressIndicator(
            color: ordoColor,
          ),
        ),
      );
    }

    final isPsalm = widget.reference.toLowerCase().startsWith('ps ') ||
        widget.reference.toLowerCase().startsWith('psalm ');

    if (isPsalm) {
      return _buildPsalmContent(theme);
    }

    return _buildRegularContent(theme);
  }

  Widget _buildRegularContent(ThemeData theme) {
    // Parse verses and build styled content
    final verses = _parseVerses(_currentContent);
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final containerColor = Color.alphaBlend(
      (isLight ? Colors.white : theme.colorScheme.surfaceContainer).withValues(alpha: isLight ? 0.92 : 0.52),
      ordoColor.withValues(alpha: isLight ? 0.06 : 0.16),
    );
    final borderColor = Color.alphaBlend(
      theme.colorScheme.outlineVariant.withValues(alpha: isLight ? 0.32 : 0.28),
      ordoColor.withValues(alpha: isLight ? 0.08 : 0.16),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: verses.map((verse) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${verse.number}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: ordoColor.withValues(
                            alpha: 0.75,
                          ),
                          fontSize: 13 * _textScale,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showVerseActions(verse: verse),
                        onLongPress: () => _showVerseActions(verse: verse),
                        child: SelectableText(
                          verse.text,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.9,
                            letterSpacing: 0.15,
                            fontSize: 19 * _textScale,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface,
                          ),
                          textScaler: const TextScaler.linear(1.0),
                          contextMenuBuilder: (context, selectableTextState) {
                            final defaultItems = selectableTextState.contextMenuButtonItems;
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: selectableTextState.contextMenuAnchors,
                              buttonItems: [
                                ...defaultItems,
                                ContextMenuButtonItem(
                                  onPressed: () {
                                    Navigator.of(context).maybePop();
                                    _showVerseActions(verse: verse);
                                  },
                                  label: 'AI Insights (verse)',
                                ),
                                ContextMenuButtonItem(
                                  onPressed: () {
                                    Navigator.of(context).maybePop();
                                    _showInsightSheet(
                                      title: 'Insight for $_insightContextLabel',
                                      reference: widget.reference,
                                      highlightedText: _currentContent,
                                      fetchInsight: () => _fetchInsight(
                                        focusText: _currentContent,
                                        fullContextText: _currentContent,
                                        mode: 'full',
                                      ),
                                    );
                                  },
                                  label: 'AI Insights (reading)',
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildPsalmContent(ThemeData theme) {
    final stanzas = _currentContent
        .split(RegExp(r'\n{2,}'))
        .map((stanza) => stanza.trim())
        .where((stanza) => stanza.isNotEmpty)
        .toList();
    final response = widget.readingData?.psalmResponse?.trim();
    final isLight = theme.brightness == Brightness.light;
    final ordoColor = widget.liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final containerColor = Color.alphaBlend(
      (isLight ? Colors.white : theme.colorScheme.surfaceContainer).withValues(alpha: isLight ? 0.92 : 0.52),
      ordoColor.withValues(alpha: isLight ? 0.06 : 0.16),
    );
    final borderColor = Color.alphaBlend(
      theme.colorScheme.outlineVariant.withValues(alpha: isLight ? 0.32 : 0.28),
      ordoColor.withValues(alpha: isLight ? 0.08 : 0.16),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(stanzas.length, (index) {
                final stanza = stanzas[index];
                final lines = stanza
                    .split('\n')
                    .map((line) => line.trim())
                    .where((line) => line.isNotEmpty)
                    .toList();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${index + 1}.',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: ordoColor.withValues(alpha: 0.75),
                                fontSize: 16 * _textScale,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: lines.map((line) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showVerseActions(
                                      selectedText: line,
                                      selectedLabel: 'Psalm line ${index + 1}',
                                    ),
                                    onLongPress: () => _showVerseActions(
                                      selectedText: line,
                                      selectedLabel: 'Psalm line ${index + 1}',
                                    ),
                                    child: SelectableText(
                                      line,
                                      style: theme.textTheme.bodyLarge?.copyWith(
                                        height: 1.8,
                                        letterSpacing: 0.1,
                                        fontSize: 18 * _textScale,
                                        fontWeight: FontWeight.w500,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      contextMenuBuilder: (context, selectableTextState) {
                                        final defaultItems = selectableTextState.contextMenuButtonItems;
                                        return AdaptiveTextSelectionToolbar.buttonItems(
                                          anchors: selectableTextState.contextMenuAnchors,
                                          buttonItems: [
                                            ...defaultItems,
                                            ContextMenuButtonItem(
                                              onPressed: () {
                                                Navigator.of(context).maybePop();
                                                _showVerseActions(
                                                  selectedText: line,
                                                  selectedLabel: 'Psalm line ${index + 1}',
                                                );
                                              },
                                              label: 'AI Insights (line)',
                                            ),
                                            ContextMenuButtonItem(
                                              onPressed: () {
                                                Navigator.of(context).maybePop();
                                                _showInsightSheet(
                                                  title: 'Insight for $_insightContextLabel',
                                                  reference: widget.reference,
                                                  highlightedText: _currentContent,
                                                  fetchInsight: () => _fetchInsight(
                                                    focusText: _currentContent,
                                                    fullContextText: _currentContent,
                                                    mode: 'full',
                                                  ),
                                                );
                                              },
                                              label: 'AI Insights (reading)',
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          response != null && response.isNotEmpty
                              ? 'R/. ${response.trim()}'
                              : 'R/.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            color: ordoColor.withValues(alpha: 0.82),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponseAcclamation(ThemeData theme) {
    if (widget.readingData == null) return const SizedBox.shrink();
    
    final reading = widget.readingData!;
    final position = (reading.position ?? '').toLowerCase();

    if (position.contains('psalm')) {
      return PsalmResponseWidget(
        reading: reading,
        date: reading.date,
      );
    }

    if (position.contains('gospel')) {
      return GospelAcclamationWidget(
        reading: reading,
        date: reading.date,
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildVersionFooter(ThemeData theme) {
    return BibleVersionSwitcher(
      onVersionChanged: _reloadWithNewVersion,
    );
  }

  List<_Verse> _parseVerses(String content) {
    final verses = <_Verse>[];
    final lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Try to parse verse number at start
      final match = RegExp(r'^(\d+)[.\s]+(.*)').firstMatch(line);
      if (match != null) {
        verses.add(
          _Verse(
            number: int.tryParse(match.group(1) ?? '0') ?? i + 1,
            text: match.group(2) ?? line,
          ),
        );
      } else {
        verses.add(_Verse(number: i + 1, text: line));
      }
    }

    return verses;
  }

  void _shareText() {
    final text = '${widget.reference}\n\n$_currentContent';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading copied to clipboard')),
    );
  }

  void _copyText() {
    final text = '${widget.reference}\n\n$_currentContent';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reading copied to clipboard')),
    );
  }

  void _toggleFullScreen() {
    // Toggle fullscreen mode
    if (MediaQuery.of(context).size.width > 600) {
      // Already reading-focused layout on large screens
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reading mode enabled')));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

class _Verse {
  final int number;
  final String text;

  _Verse({required this.number, required this.text});
}

class _InsightActionTile extends StatelessWidget {
  const _InsightActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingInsightSheet extends StatefulWidget {
  const _ReadingInsightSheet({
    required this.title,
    required this.reference,
    required this.highlightedText,
    required this.fetchInsight,
  });

  final String title;
  final String reference;
  final String highlightedText;
  final Future<String> Function() fetchInsight;

  @override
  State<_ReadingInsightSheet> createState() => _ReadingInsightSheetState();
}

class _ReadingInsightSheetState extends State<_ReadingInsightSheet> {
  late final Future<String> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetchInsight();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 48,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FutureBuilder<String>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Unable to load insight. Please try again.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView(
                        children: [
                          Text(
                            widget.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.reference,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              widget.highlightedText,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            snapshot.data ?? 'No insight available.',
                            style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
