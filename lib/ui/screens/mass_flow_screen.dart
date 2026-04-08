import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/order_of_mass_service.dart';
import '../../data/services/order_of_mass_preference_service.dart';
import '../../data/services/language_preference_service.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/readings_backend_io.dart';
import '../../data/services/reading_flow_service.dart';
import '../widgets/parchment_background.dart';
import '../utils/contrast_helper.dart';

class MassFlowScreen extends StatefulWidget {
  final DateTime? date;

  const MassFlowScreen({
    super.key,
    this.date,
  });

  @override
  State<MassFlowScreen> createState() => _MassFlowScreenState();
}

class _MassFlowScreenState extends State<MassFlowScreen> {
  final OrderOfMassService _orderOfMassService = OrderOfMassService();
  final OrderOfMassPreferenceService _orderOfMassPreference = OrderOfMassPreferenceService();
  final LanguagePreferenceService _languageService = LanguagePreferenceService();
  final ImprovedLiturgicalCalendarService _calendarService = ImprovedLiturgicalCalendarService.instance;
    final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();

  late DateTime _selectedDate;
  String _primaryLanguage = 'en';
  String _secondaryLanguage = 'en';
  List<ResolvedOrderOfMassSection>? _sections;
  List<DailyReading>? _readings;
  LiturgicalDay? _liturgicalDay;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
    _initialize();
  }

  Future<void> _initialize() async {
    final primaryLang = await _languageService.getPreferredLanguage();
    final secondaryLang = await _orderOfMassPreference.getPreferredLanguage();

    if (mounted) {
      setState(() {
        _primaryLanguage = primaryLang;
        _secondaryLanguage = secondaryLang;
      });
    }

    await _loadMassForDate(_selectedDate);
  }

  Future<void> _loadMassForDate(DateTime date) async {
    setState(() => _isLoading = true);

    try {
      final liturgicalDay = await _calendarService.getLiturgicalDay(date);
      final lectionaryReadings =
          await ReadingsService.instance.getReadingsForDate(date);
      final sections = await _orderOfMassService.getSectionsForDate(
        date,
        languageCode: _secondaryLanguage,
        lectionaryReadings: lectionaryReadings,
      );
      final readings = await _readingsBackend.getReadingsForDate(date);

      if (mounted) {
        setState(() {
          _selectedDate = date;
          _liturgicalDay = liturgicalDay;
          _sections = sections;
          _readings = readings;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading mass: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      await _loadMassForDate(picked);
    }
  }

  Future<void> _onPrimaryLanguageChanged(String language) async {
    await _languageService.setPreferredLanguage(language);
    if (mounted) {
      setState(() => _primaryLanguage = language);
    }
  }

  Future<void> _onSecondaryLanguageChanged(String language) async {
    await _orderOfMassPreference.setPreferredLanguage(language);
    if (mounted) {
      setState(() => _secondaryLanguage = language);
    }
    await _loadMassForDate(_selectedDate);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Order of Mass'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.translate, color: theme.colorScheme.onSurface),
            tooltip: 'Language',
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'Mass Prayers',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._orderOfMassPreference.availableLanguages.map((lang) {
                final displayName = _orderOfMassPreference.getLanguageDisplayName(lang);
                return PopupMenuItem(
                  value: lang,
                  onTap: () => _onSecondaryLanguageChanged(lang),
                  child: Row(
                    children: [
                      Icon(
                        lang == _secondaryLanguage ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(displayName),
                    ],
                  ),
                );
              }),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Text(
                  'App Language',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._languageService.availableLanguages.map((lang) {
                final displayName = _languageService.getLanguageDisplayName(lang);
                return PopupMenuItem(
                  value: lang,
                  onTap: () => _onPrimaryLanguageChanged(lang),
                  child: Row(
                    children: [
                      Icon(
                        lang == _primaryLanguage ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(displayName),
                    ],
                  ),
                );
              }),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: 'Select Date',
          ),
        ],
      ),
      body: ParchmentBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sections == null || _sections!.isEmpty
                ? _buildEmptyState()
                : _buildMassContent(theme),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No mass content available',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different date',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMassContent(ThemeData theme) {
    final bool isLight = theme.brightness == Brightness.light;
    final Color sectionColor = _liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    // Ensure good contrast in light mode
    final Color readableColor = isLight
        ? sectionColor.withValues(alpha: 0.95)
        : sectionColor;

    return CustomScrollView(
      slivers: [
        if (_liturgicalDay != null) _buildLiturgicalHeader(theme, readableColor),
        // Introductory Rites
        ..._getSectionsForInsertionPoint('introductory_rites'),
        // Liturgy of the Word
        ..._getSectionsForInsertionPoint('before_first_reading'),
        if (_readings != null && _readings!.isNotEmpty)
          _buildReadingsSection(theme, readableColor),
        ..._getSectionsForInsertionPoint('between_readings'),
        ..._getSectionsForInsertionPoint('before_gospel'),
        ..._getSectionsForInsertionPoint('after_gospel'),
        // Liturgy of the Eucharist
        ..._getSectionsForInsertionPoint('offertory'),
        ..._getSectionsForInsertionPoint('preface'),
        ..._getSectionsForInsertionPoint('sanctus'),
        ..._getSectionsForInsertionPoint('acclamation'),
        ..._getSectionsForInsertionPoint('lords_prayer'),
        ..._getSectionsForInsertionPoint('sign_of_peace'),
        ..._getSectionsForInsertionPoint('fraction'),
        ..._getSectionsForInsertionPoint('communion'),
        ..._getSectionsForInsertionPoint('after_communion'),
        ..._getSectionsForInsertionPoint('concluding_rites'),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  List<Widget> _getSectionsForInsertionPoint(String insertionPoint) {
    if (_sections == null) return [];
    return _sections!
        .where((s) => s.insertionPoint == insertionPoint)
        .map((section) => _buildSection(section))
        .toList();
  }

  Widget _buildLiturgicalHeader(ThemeData theme, Color readableColor) {
    final ordoColor = _liturgicalDay!.colorValue;
    final bool isLight = theme.brightness == Brightness.light;
    // Use higher alpha for better contrast in light mode
    final bgAlpha = isLight ? 0.35 : 0.15;

    return SliverToBoxAdapter(
      child: Container(
        color: ordoColor.withValues(alpha: bgAlpha),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat.yMMMMd().format(_selectedDate),
              style: theme.textTheme.labelLarge?.copyWith(
                color: readableColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _liturgicalDay!.fullDescription,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: readableColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _liturgicalDay!.weekDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ContrastHelper.getSecondaryContrastColor(ordoColor.withValues(alpha: bgAlpha), theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsSection(ThemeData theme, Color sectionColor) {
    if (_readings == null || _readings!.isEmpty) return const SliverToBoxAdapter();

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _ReadingsSectionWidget(
          readings: _readings!,
          liturgicalColor: sectionColor,
        ),
      ),
    );
  }

  
  Widget _buildSection(ResolvedOrderOfMassSection section) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _MassFlowSectionWidget(
          section: section,
          language: _secondaryLanguage,
          liturgicalColor: _liturgicalDay?.colorValue,
        ),
      ),
    );
  }
}

class _MassFlowSectionWidget extends StatefulWidget {
  final ResolvedOrderOfMassSection section;
  final String language;
  final Color? liturgicalColor;

  const _MassFlowSectionWidget({
    required this.section,
    required this.language,
    this.liturgicalColor,
  });

  @override
  State<_MassFlowSectionWidget> createState() => _MassFlowSectionWidgetState();
}

class _MassFlowSectionWidgetState extends State<_MassFlowSectionWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionColor = widget.liturgicalColor ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.section.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ContrastHelper.getContrastColor(
                              sectionColor.withValues(alpha: 0.18),
                              theme,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.section.items.length} part${widget.section.items.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ContrastHelper.getSecondaryContrastColor(sectionColor.withValues(alpha: 0.18), theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: ContrastHelper.getContrastColor(
                      sectionColor.withValues(alpha: 0.18),
                      theme,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Section items
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: widget.section.items.map((item) {
                  return _MassFlowItemCard(
                    item: item,
                    language: widget.language,
                    sectionColor: sectionColor,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _MassFlowItemCard extends StatelessWidget {
  final ResolvedOrderOfMassItem item;
  final String language;
  final Color sectionColor;

  const _MassFlowItemCard({
    required this.item,
    required this.language,
    required this.sectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = item.getContentForLanguage(language) ?? const <String>[];
    
    if (content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: ContrastHelper.getContrastColor(theme.colorScheme.surface, theme),
                  ),
                ),
              ),
              if (item.isOptional)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Optional',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                          if (item.role != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    // Higher contrast for light mode
                    color: sectionColor.withValues(alpha: theme.brightness == Brightness.light ? 0.35 : 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatRole(item.role!, item.isDialogue, item.isResponsive),
                    style: theme.textTheme.labelSmall?.copyWith(
                      // Ensure readable contrast in light mode
                      color: theme.brightness == Brightness.light
                          ? sectionColor.withValues(alpha: 1.0)
                          : sectionColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
                  const SizedBox(height: 12),
          ...content.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final line = entry.value;
              // Prefix lines with V or R markers for dialogue/responsive prayers
              final String prefix = _getLinePrefix(item, index, line);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    children: [
                      if (prefix.isNotEmpty)
                        TextSpan(
                          text: prefix,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            color: ContrastHelper.getContrastColor(theme.colorScheme.surface, theme),
                          ),
                        ),
                      TextSpan(
                        text: line,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatRole(String role, bool isDialogue, bool isResponsive) {
    // Return V/R markers based on role and dialogue/responsive flags
    final roleLower = role.toLowerCase();
    if (roleLower == 'priest' || roleLower == 'deacon' || roleLower == 'deacon_or_priest') {
      return 'V.';
    }
    if (roleLower == 'all' || isResponsive) {
      return 'R.';
    }
    // For other roles, show role name with appropriate marker
    switch (roleLower) {
      case 'lector':
        return 'V. Lector';
      case 'cantor':
        return 'V. Cantor';
      case 'choir':
        return 'R. Choir';
      default:
        return isDialogue ? 'V. $role' : role;
    }
  }

  String _getLinePrefix(ResolvedOrderOfMassItem item, int lineIndex, String line) {
    if (!item.isDialogue && !item.isResponsive) return '';

    // Use structured dialogue data if available
    if (item.dialogueStructure != null && item.dialogueStructure!.isNotEmpty) {
      // Get the current language (fallback to English if not available)
      final language = this.language;
      
      final dialogueLines = item.dialogueStructure![language];
      if (dialogueLines != null && lineIndex < dialogueLines.length) {
        final dialogueLine = dialogueLines[lineIndex];
        final prefix = dialogueLine['prefix'];
        if (prefix != null && (prefix == 'V' || prefix == 'R')) {
          return '$prefix. ';
        }
      }
    }

    // Fallback to original logic for non-structured dialogues
    final role = item.role?.toLowerCase() ?? '';
    final lineLower = line.trim().toLowerCase();

    // Priest/Deacon lines get V
    if (role == 'priest' || role == 'deacon' || role == 'deacon_or_priest' || role == 'lector') {
      return 'V. ';
    }

    // All/People responses get R
    if (role == 'all' || item.isResponsive) {
      return 'R. ';
    }

    // For mixed dialogue, alternate based on common patterns
    if (item.isDialogue) {
      // If it's the first line and it's a greeting/invitation, it's typically the Priest (V)
      if (lineIndex == 0) {
        return 'V. ';
      }
      // Check for common response patterns
      if (lineLower.startsWith('and with your spirit') ||
          lineLower.startsWith('amen') ||
          lineLower.startsWith('we lift them up') ||
          lineLower.startsWith('it is right and just') ||
          lineLower.startsWith('holy, holy') ||
          lineLower.startsWith('lord, i am not worthy') ||
          lineLower.startsWith('blessed is he who comes') ||
          lineLower.startsWith('have mercy on us') ||
          lineLower.startsWith('grant us peace') ||
          lineLower.startsWith('lamb of god')) {
        return 'R. ';
      }
    }

    return '';
  }
}

// Widget to display readings in the mass flow
class _ReadingsSectionWidget extends StatefulWidget {
  final List<DailyReading> readings;
  final Color liturgicalColor;

  const _ReadingsSectionWidget({
    required this.readings,
    required this.liturgicalColor,
  });

  @override
  State<_ReadingsSectionWidget> createState() => _ReadingsSectionWidgetState();
}

class _ReadingsSectionWidgetState extends State<_ReadingsSectionWidget> {
  bool _isExpanded = true;
  final Set<int> _expandedReadings = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLight = theme.brightness == Brightness.light;
    // Ensure good contrast
    final Color sectionColor = isLight
        ? widget.liturgicalColor.withValues(alpha: 0.9)
        : widget.liturgicalColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionColor.withValues(alpha: isLight ? 0.15 : 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Liturgy of the Word',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ContrastHelper.getContrastColor(
                      sectionColor.withValues(alpha: 0.18),
                      theme,
                    ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.readings.length} reading${widget.readings.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ContrastHelper.getSecondaryContrastColor(sectionColor.withValues(alpha: 0.15), theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: ContrastHelper.getContrastColor(
                      sectionColor.withValues(alpha: 0.18),
                      theme,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Readings list
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: widget.readings.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reading = entry.value;
                  return _ReadingCard(
                    reading: reading,
                    index: index,
                    isExpanded: _expandedReadings.contains(index),
                    onToggle: () => setState(() {
                      if (_expandedReadings.contains(index)) {
                        _expandedReadings.remove(index);
                      } else {
                        _expandedReadings.add(index);
                      }
                    }),
                    sectionColor: sectionColor,
                  );
                }).toList(),
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatefulWidget {
  final DailyReading reading;
  final int index;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Color sectionColor;

  const _ReadingCard({
    required this.reading,
    required this.index,
    required this.isExpanded,
    required this.onToggle,
    required this.sectionColor,
  });

  @override
  State<_ReadingCard> createState() => _ReadingCardState();
}

class _ReadingCardState extends State<_ReadingCard> {
  final ReadingFlowService _readingFlow = ReadingFlowService.instance;
  String? _fullReadingText;
  bool _isLoadingText = false;

  String get _readingLabel {
    final position = widget.reading.position?.toLowerCase() ?? '';
    
    // Handle Gospel Acclamation - this appears before the Gospel
    if (widget.reading.gospelAcclamation != null && 
        widget.reading.gospelAcclamation!.trim().isNotEmpty) {
      // Check if this reading has a gospel acclamation but isn't the gospel itself
      final isGospel = position.contains('gospel');
      if (!isGospel) {
        // This is the Gospel Acclamation as a separate item
        return 'Gospel Acclamation';
      }
    }
    
    if (position.contains('gospel')) return 'Gospel';
    if (position.contains('first')) return 'First Reading';
    if (position.contains('second')) return 'Second Reading';
    if (position.contains('psalm')) return 'Responsorial Psalm';
    return 'Reading ${widget.index + 1}';
  }

  @override
  void didUpdateWidget(_ReadingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fetch reading text when expanded and not already loaded
    if (widget.isExpanded && !oldWidget.isExpanded && _fullReadingText == null) {
      _fetchReadingText();
    }
  }

  Future<void> _fetchReadingText() async {
    if (_fullReadingText != null) return;
    
    setState(() => _isLoadingText = true);
    
    try {
      final text = await _readingFlow.getReadingText(widget.reading);
      if (mounted) {
        setState(() {
          _fullReadingText = text;
          _isLoadingText = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching reading text: $e');
      if (mounted) {
        setState(() => _isLoadingText = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.sectionColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Reading header
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _readingLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ContrastHelper.getContrastColor(
                              theme.colorScheme.surface,
                              theme,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.reading.reading,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: ContrastHelper.getSecondaryContrastColor(widget.sectionColor.withValues(alpha: 0.3), theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: ContrastHelper.getContrastColor(
                      theme.colorScheme.surface,
                      theme,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            if (_isLoadingText)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.sectionColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading reading...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ContrastHelper.getSecondaryContrastColor(widget.sectionColor.withValues(alpha: 0.3), theme),
                      ),
                    ),
                  ],
                ),
              )
            else if (_fullReadingText != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  _fullReadingText!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ContrastHelper.getSecondaryContrastColor(widget.sectionColor.withValues(alpha: 0.3), theme),
                    height: 1.5,
                  ),
                ),
              )
            else if (widget.reading.incipit != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  widget.reading.incipit!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: ContrastHelper.getSecondaryContrastColor(widget.sectionColor.withValues(alpha: 0.3), theme),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
