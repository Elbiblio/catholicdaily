import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/ordo_resolver_service.dart';
import '../../data/services/readings_backend.dart';
import '../../data/services/readings_backend_io.dart'
    if (dart.library.html) 'readings_backend_web.dart'
    as backend_factory;
import '../../data/models/daily_reading.dart';
import '../../data/services/optional_memorial_service.dart';
import '../../data/services/alternate_readings_service.dart';
import '../../data/services/reading_flow_service.dart';

/// Premium Browse Screen with modern 2026 design principles
class PremiumBrowseScreen extends StatefulWidget {
  final Function(
    String reading,
    String content,
    LiturgicalDay? liturgicalDay, [
    DailyReading? readingData,
    List<DailyReading>? readingSet,
    int? selectedIndex,
  ])
  onReadingSelected;

  const PremiumBrowseScreen({super.key, required this.onReadingSelected});

  @override
  State<PremiumBrowseScreen> createState() => _PremiumBrowseScreenState();
}

class _PremiumBrowseScreenState extends State<PremiumBrowseScreen>
    with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<DailyReading> _readings = [];
  Map<String, String> _readingTitles = {};
  Map<String, String> _readingPreviews = {};
  Map<String, String> _readingTexts = {};
  bool _isLoading = true;
  LiturgicalDay? _liturgicalDay;
  OrdoYearVariables? _ordoYearVariables;
  bool _showLiturgicalDetails = false;
  List<OptionalCelebration> _optionalCelebrations = [];
  int _selectedCelebrationIndex = -1; // -1 = ferial/default
  bool _celebrationsSuppressed = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  final ReadingsBackend _readingsBackend = backend_factory.createReadingsBackend();
  final ReadingFlowService _readingFlow = ReadingFlowService.instance;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadReadings();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadReadings() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _ordoResolver.resolveDay(_selectedDate),
        _ordoResolver.resolveYearVariables(_selectedDate),
        _readingsBackend.getReadingsForDate(_selectedDate),
      ]);
      _liturgicalDay = results[0] as LiturgicalDay;
      _ordoYearVariables = results[1] as OrdoYearVariables;
      final rawReadings = results[2] as List<DailyReading>;

      final optionalMemorialService = OptionalMemorialService.instance;

      // Always load celebrations for display, even when suppressed liturgically.
      _optionalCelebrations = optionalMemorialService.getAllCelebrationsForDate(
        _selectedDate,
      );
      _celebrationsSuppressed = optionalMemorialService.isSuppressedDate(
        _selectedDate,
      );
      _selectedCelebrationIndex = -1;
      final hydrated = await _readingFlow.hydrateReadingSet(
        date: _selectedDate,
        readings: rawReadings,
      );
      _applyHydratedReadings(hydrated);

      // Restart animations when data loads
      _restartAnimations();
    } catch (e) {
      debugPrint('Error loading readings: $e');
      _readings = [];
      _ordoYearVariables = null;
      _readingTitles = {};
      _readingPreviews = {};
      _readingTexts = {};
    }

    setState(() => _isLoading = false);
  }

  void _previousDay() {
    HapticFeedback.lightImpact();
    setState(
      () => _selectedDate = _selectedDate.subtract(const Duration(days: 1)),
    );
    _loadReadings();
  }

  void _nextDay() {
    HapticFeedback.lightImpact();
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadReadings();
  }

  void _goToToday() {
    HapticFeedback.mediumImpact();
    setState(() => _selectedDate = DateTime.now());
    _loadReadings();
  }

  void _showDatePicker() async {
    HapticFeedback.lightImpact();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
              surface: theme.colorScheme.surface,
              onSurface: theme.colorScheme.onSurface,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      HapticFeedback.mediumImpact();
      setState(() => _selectedDate = picked);
      _loadReadings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with glassmorphism effect
          _buildPremiumAppBar(theme, dateFormat),

          // Main content
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _readings.isEmpty
                ? _buildEmptyState(theme)
                : _buildReadingsList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumAppBar(ThemeData theme, DateFormat dateFormat) {
    return SliverAppBar(
      expandedHeight: _showLiturgicalDetails ? 360 : 240,
      pinned: true,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.96),
      surfaceTintColor: Colors.transparent,
      foregroundColor: theme.colorScheme.onSurface,
      flexibleSpace: FlexibleSpaceBar(
        background: _liturgicalDay != null
            ? _buildLiturgicalHeader(theme)
            : _buildDefaultHeader(theme),
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          dateFormat.format(_selectedDate),
          key: ValueKey(_selectedDate),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showDatePicker,
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Choose Date',
        ),
        IconButton(
          onPressed: _goToToday,
          icon: const Icon(Icons.today_rounded),
          tooltip: 'Go to Today',
        ),
      ],
    );
  }

  Widget _buildLiturgicalHeader(ThemeData theme) {
    final headerColor = _resolveHeaderColor(theme);
    final headerForeground = _resolveHeaderForeground(theme, headerColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  theme.colorScheme.surface.withValues(alpha: 0.28),
                  headerColor,
                ),
                Color.alphaBlend(
                  theme.colorScheme.surface.withValues(alpha: 0.46),
                  headerColor,
                ),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + kToolbarHeight + 20,
              20,
              20,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_liturgicalDay!.rank != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: headerForeground.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: headerForeground.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _liturgicalDay!.rank!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: headerForeground,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),

                    Text(
                      _liturgicalDay!.title.isNotEmpty
                          ? _liturgicalDay!.title
                          : _liturgicalDay!.seasonName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: headerForeground,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _liturgicalDay!.weekDescription,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: headerForeground.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    _buildLiturgicalSummaryRow(theme, headerForeground),

                    const SizedBox(height: 14),

                    GestureDetector(
                      onTap: () => setState(
                        () => _showLiturgicalDetails = !_showLiturgicalDetails,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showLiturgicalDetails ? 'Less' : 'More',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: headerForeground.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _showLiturgicalDetails ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.expand_more,
                              color: headerForeground.withValues(alpha: 0.82),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _showLiturgicalDetails
                          ? Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: double.infinity,
                              height: constraints.maxHeight * 0.4,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: headerForeground.withValues(alpha: 0.14),
                                ),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _getLiturgicalDetails(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultHeader(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              theme.colorScheme.surface.withValues(alpha: 0.24),
              theme.colorScheme.primary,
            ),
            Color.alphaBlend(
              theme.colorScheme.surface.withValues(alpha: 0.38),
              theme.colorScheme.primary,
            ),
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          MediaQuery.of(context).padding.top + kToolbarHeight + 20,
          20,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Daily Readings',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Offline-first daily Mass readings with clear liturgical context.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.84),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Today\'s Readings',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.menu_book_rounded,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No Readings Available',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection or try another date',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadReadings,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingsList(ThemeData theme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Date navigation with premium design
            _buildDateNavigation(theme),

            // Optional celebrations selector
            if (_optionalCelebrations.isNotEmpty)
              _buildOptionalCelebrationSelector(theme),

            // Readings list
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _readings.length,
              itemBuilder: (context, index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.easeOutCubic,
                  child: _PremiumReadingCard(
                    reading: _readings[index],
                    readingTitle: _readingTitles[_readings[index].reading],
                    previewText: _readingPreviews[_readings[index].reading],
                    liturgicalColor: _liturgicalDay?.colorValue,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final reference = _readings[index].reading;
                      final text =
                          _readingTexts[reference] ??
                          await _readingFlow.getReadingText(_readings[index]);
                      widget.onReadingSelected(
                        reference,
                        text,
                        _liturgicalDay,
                        _readings[index],
                        _readings,
                        index,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateNavigation(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Previous button
          Expanded(
            child: IconButton(
              onPressed: _previousDay,
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Date display
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                DateFormat('MMM d, yyyy').format(_selectedDate),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          // Next button
          Expanded(
            child: IconButton(
              onPressed: _nextDay,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getLiturgicalDetails() {
    if (_liturgicalDay == null) return '';

    final buffer = StringBuffer();
    if (_ordoYearVariables != null) {
      buffer.writeln('Golden Number: ${_ordoYearVariables!.goldenNumber}');
      buffer.writeln('Epact: ${_ordoYearVariables!.epact}');
      buffer.writeln('Solar Cycle: ${_ordoYearVariables!.solarCycle}');
      buffer.writeln('Indiction: ${_ordoYearVariables!.indiction}');
    }

    return buffer.toString();
  }

  Widget _buildLiturgicalSummaryRow(ThemeData theme, Color foregroundColor) {
    final countdown = _buildCountdownLabel();
    final chips = <Widget>[
      _buildDetailChip(theme, 'Season', _liturgicalDay!.seasonName, foregroundColor),
      if (_liturgicalDay!.weekNumber > 0)
        _buildDetailChip(theme, 'Week', '${_liturgicalDay!.weekNumber}', foregroundColor),
      _buildDetailChip(theme, 'Day', _liturgicalDay!.dayName, foregroundColor),
      if (_ordoYearVariables != null)
        _buildDetailChip(theme, 'Sunday', _ordoYearVariables!.sundayCycle, foregroundColor),
      if (_ordoYearVariables != null)
        _buildDetailChip(theme, 'Year', _ordoYearVariables!.weekdayCycle, foregroundColor),
      if (countdown != null)
        _buildDetailChip(theme, countdown.$1, countdown.$2, foregroundColor),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int index = 0; index < chips.length; index++) ...[
            chips[index],
            if (index < chips.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailChip(ThemeData theme, String label, String value, Color foregroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: foregroundColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (String, String)? _buildCountdownLabel() {
    final nextFeast = _nextMovableFeast();
    if (nextFeast == null) {
      return null;
    }

    final feastDate = nextFeast.$2;
    final difference = DateTime(
      feastDate.year,
      feastDate.month,
      feastDate.day,
    ).difference(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)).inDays;

    if (difference <= 0) {
      return ('Today', nextFeast.$1);
    }

    return ('To ${nextFeast.$1}', '$difference days');
  }

  (String, DateTime)? _nextMovableFeast() {
    final easter = _calculateEasterSunday(_selectedDate.year);
    final ashWednesday = easter.subtract(const Duration(days: 46));
    final palmSunday = easter.subtract(const Duration(days: 7));
    final ascension = easter.add(const Duration(days: 39));
    final pentecost = easter.add(const Duration(days: 49));
    final adventStart = _calculateAdventStart(_selectedDate.year);

    final candidates = <(String, DateTime)>[
      ('Ash Wednesday', ashWednesday),
      ('Palm Sunday', palmSunday),
      ('Easter', easter),
      ('Ascension', ascension),
      ('Pentecost', pentecost),
      ('Advent', adventStart),
    ];

    for (final candidate in candidates) {
      if (!candidate.$2.isBefore(DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day))) {
        return candidate;
      }
    }

    final nextYearEaster = _calculateEasterSunday(_selectedDate.year + 1);
    return ('Ash Wednesday', nextYearEaster.subtract(const Duration(days: 46)));
  }

  DateTime _calculateEasterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(year, month, day);
  }

  DateTime _calculateAdventStart(int year) {
    final christmas = DateTime(year, 12, 25);
    final daysToPreviousSunday = (christmas.weekday + 6) % 7;
    return christmas.subtract(Duration(days: daysToPreviousSunday + 21));
  }

  Color _resolveHeaderColor(ThemeData theme) {
    final seasonal = _liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    return Color.lerp(seasonal, theme.colorScheme.primary, 0.6) ?? theme.colorScheme.primary;
  }

  Color _resolveHeaderForeground(ThemeData theme, Color backgroundColor) {
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : theme.colorScheme.onSurface;
  }

  void _applyHydratedReadings(HydratedReadingSet hydrated) {
    _readings = hydrated.readings;
    _readingTitles = hydrated.readingTitles;
    _readingPreviews = hydrated.readingPreviews;
    _readingTexts = hydrated.readingTexts;
  }

  void _restartAnimations() {
    _fadeController.reset();
    _slideController.reset();
    _fadeController.forward();
    _slideController.forward();
  }

  Widget _buildOptionalCelebrationSelector(ThemeData theme) {
    final baseBorderColor = _celebrationsSuppressed
        ? const Color(0xFFD9A441)
        : theme.colorScheme.tertiary;
    final baseBackgroundColor = _celebrationsSuppressed
        ? const Color(0xFF3A2B1A)
        : theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: baseBorderColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: baseBorderColor),
              const SizedBox(width: 6),
              Text(
                _celebrationsSuppressed
                    ? 'Commemorated Feast / Memorial'
                    : 'Optional Celebrations',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: baseBorderColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_celebrationsSuppressed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'These commemorations may still be chosen locally. Tap a feast to view its readings.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              // Ferial/weekday chip (always first)
              ChoiceChip(
                label: Text('Weekday', style: TextStyle(fontSize: 12)),
                selected: _selectedCelebrationIndex == -1,
                onSelected: (_) {
                  if (_selectedCelebrationIndex != -1) {
                    setState(() => _selectedCelebrationIndex = -1);
                    _loadReadings();
                  }
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              // Optional celebration chips
              ..._optionalCelebrations.asMap().entries.map((entry) {
                final idx = entry.key;
                final celebration = entry.value;
                final hasProper = celebration.hasProperReadings;
                final selected = _selectedCelebrationIndex == idx;
                final chipForeground = _celebrationsSuppressed
                    ? const Color(0xFFE7C27A)
                    : (hasProper
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant);
                return ChoiceChip(
                  label: Text(
                    _shortenTitle(celebration.title),
                    style: TextStyle(
                      fontSize: 12,
                      color: selected ? theme.colorScheme.onPrimary : chipForeground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: selected,
                  selectedColor: _celebrationsSuppressed
                      ? const Color(0xFF8B5E1A)
                      : theme.colorScheme.primary,
                  backgroundColor: _celebrationsSuppressed
                      ? const Color(0xFF2B2117)
                      : theme.colorScheme.surface,
                  side: BorderSide(
                    color: selected
                        ? (_celebrationsSuppressed
                            ? const Color(0xFFE7C27A)
                            : theme.colorScheme.primary)
                        : chipForeground.withValues(alpha: 0.35),
                  ),
                  onSelected: (_) {
                    if (_selectedCelebrationIndex != idx) {
                      setState(() => _selectedCelebrationIndex = idx);
                      _loadCelebrationReadings(celebration);
                    }
                  },
                  avatar: hasProper
                      ? (_celebrationsSuppressed
                          ? Icon(
                              Icons.info_outline,
                              size: 14,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : const Color(0xFFE7C27A),
                            )
                          : null)
                      : Icon(
                          Icons.link,
                          size: 14,
                          color: selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  tooltip: _celebrationsSuppressed
                      ? (hasProper
                          ? 'Tap to view commemorated feast readings'
                          : 'Uses weekday readings unless local usage provides otherwise')
                      : hasProper
                          ? 'Tap to view proper readings'
                          : 'Uses weekday readings',
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  String _shortenTitle(String title) {
    // Remove common prefixes for chip display
    return title
        .replaceFirst(RegExp(r'^Saint '), 'St. ')
        .replaceFirst(RegExp(r'^Saints '), 'Sts. ')
        .replaceFirst(RegExp(r'^The '), '')
        .replaceFirst(RegExp(r', Priest and Doctor of the Church$'), '')
        .replaceFirst(RegExp(r', Bishop and Doctor of the Church$'), '')
        .replaceFirst(RegExp(r', Bishop and Martyr$'), ', Bp.')
        .replaceFirst(RegExp(r', Priest and Martyr$'), ', Pr.')
        .replaceFirst(RegExp(r', Virgin and Martyr$'), ', V.M.')
        .replaceFirst(RegExp(r', Deacon and Martyr$'), '')
        .replaceFirst(RegExp(r', Religious$'), '')
        .replaceFirst(RegExp(r', Priest$'), '')
        .replaceFirst(RegExp(r', Bishop$'), '')
        .replaceFirst(RegExp(r', Virgin$'), '')
        .replaceFirst(RegExp(r', Pope and Martyr$'), ', Pope')
        .replaceFirst(RegExp(r', Pope$'), '');
  }

  Future<void> _loadCelebrationReadings(OptionalCelebration celebration) async {
    setState(() => _isLoading = true);
    try {
      final readingSet = OptionalMemorialService.instance.getProperReadings(
        celebration.id,
      );
      if (readingSet != null) {
        final alternateService = AlternateReadingsService.instance;
        final sets = await alternateService.getAvailableReadingSets(_selectedDate);
        // Find the matching set
        final matching = sets.where((s) => s.celebration?.id == celebration.id);
        final matchingSet = matching.isEmpty ? null : matching.first;
        if (matchingSet != null && matchingSet.readings.isNotEmpty) {
          final hydrated = await _readingFlow.hydrateReadingSet(
            date: _selectedDate,
            readings: matchingSet.readings,
          );
          _applyHydratedReadings(hydrated);
          _restartAnimations();
        }
      }
    } catch (e) {
      debugPrint('Error loading celebration readings: $e');
    }
    setState(() => _isLoading = false);
  }
}

/// Premium Reading Card with modern design
class _PremiumReadingCard extends StatefulWidget {
  final DailyReading reading;
  final String? readingTitle;
  final String? previewText;
  final Color? liturgicalColor;
  final VoidCallback onTap;

  const _PremiumReadingCard({
    required this.reading,
    this.readingTitle,
    this.previewText,
    this.liturgicalColor,
    required this.onTap,
  });

  @override
  State<_PremiumReadingCard> createState() => _PremiumReadingCardState();
}

class _PremiumReadingCardState extends State<_PremiumReadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getReadingTypeColor(String? type, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (type?.toLowerCase()) {
      case 'gospel':
        return isDark ? const Color(0xFFEF5350) : const Color(0xFFE53935);
      case 'responsorial psalm':
        return widget.liturgicalColor ??
            (isDark ? const Color(0xFF42A5F5) : const Color(0xFF2196F3));
      case 'first reading':
        return isDark ? const Color(0xFFAB47BC) : const Color(0xFF9C27B0);
      case 'second reading':
        return isDark ? const Color(0xFF26A69A) : const Color(0xFF009688);
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getReadingTypeColor(widget.reading.position, context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _controller.forward(),
            onTapUp: (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.1),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 2),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.surface.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reading type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        widget.reading.position ?? 'Reading',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Reference
                    Text(
                      widget.reading.reading,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 8),

                    if (widget.readingTitle != null) ...[
                      Text(
                        widget.readingTitle!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (widget.previewText != null &&
                        widget.previewText!.isNotEmpty) ...[
                      Text(
                        widget.previewText!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.88,
                          ),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Direct psalm response display
                    if (widget.reading.psalmResponse != null && 
                        widget.reading.psalmResponse!.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.music_note,
                              size: 16,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Response: ${widget.reading.psalmResponse}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Direct gospel acclamation display
                    if (widget.reading.gospelAcclamation != null && 
                        widget.reading.gospelAcclamation!.trim().isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.celebration,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Acclamation: ${_truncateAcclamation(widget.reading.gospelAcclamation!)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Feast indicator
                    if (widget.reading.feast != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              widget.liturgicalColor?.withValues(alpha: 0.1) ??
                              theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.reading.feast!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                widget.liturgicalColor ??
                                theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    // Arrow indicator
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: color.withValues(alpha: 0.6),
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Truncate acclamation text for display in widgets
  String _truncateAcclamation(String text) {
    if (text.length <= 40) return text;
    return '${text.substring(0, 40).trimRight()}...';
  }
}
