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

  Future<void> _jumpToDate(DateTime date, {bool openFirstReading = false}) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    HapticFeedback.mediumImpact();
    setState(() => _selectedDate = normalizedDate);
    await _loadReadings();

    if (!mounted || !openFirstReading || _readings.isEmpty) {
      return;
    }

    await _openReadingAtIndex(0);
  }

  Future<void> _openReadingAtIndex(int index) async {
    if (index < 0 || index >= _readings.length) {
      return;
    }

    final reading = _readings[index];
    final reference = reading.reading;
    final text =
        _readingTexts[reference] ?? await _readingFlow.getReadingText(reading);
    if (!mounted) {
      return;
    }

    widget.onReadingSelected(
      reference,
      text,
      _liturgicalDay,
      reading,
      _readings,
      index,
    );
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
    final isLight = theme.brightness == Brightness.light;
    return SliverAppBar(
      expandedHeight: _showLiturgicalDetails
          ? (isLight ? 360 : 320)
          : (isLight ? 240 : 210),
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
      titleSpacing: 0,
      actions: [
        IconButton(
          onPressed: _goToToday,
          icon: const Icon(Icons.today_rounded),
          tooltip: 'Go to Today',
        ),
        IconButton(
          onPressed: _showDatePicker,
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Choose Date',
        ),
      ],
    );
  }

  Widget _buildLiturgicalHeader(ThemeData theme) {
    final headerColor = _resolveHeaderColor(theme);
    final headerForeground = _resolveHeaderForeground(theme, headerColor);
    final isLight = theme.brightness == Brightness.light;

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
              MediaQuery.of(context).padding.top + kToolbarHeight + (isLight ? 0 : 8),
              20,
              isLight ? 20 : 14,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
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
                        fontFamily: 'Canterbury',
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
                        color: headerForeground.withValues(alpha: isLight ? 0.98 : 0.94),
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
                              height: constraints.maxHeight * (isLight ? 0.4 : 0.34),
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

            // Grouped readings list
            ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _groupedReadings.length,
              itemBuilder: (context, index) {
                final group = _groupedReadings[index];
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  curve: Curves.easeOutCubic,
                  child: _PremiumReadingGroupCard(
                    group: group,
                    liturgicalColor: _liturgicalDay?.colorValue,
                    onReadingSelected: (reading) async {
                      HapticFeedback.lightImpact();
                      final readingIndex = _readings.indexOf(reading);
                      if (readingIndex >= 0) {
                        await _openReadingAtIndex(readingIndex);
                      }
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
    final ordoColor = _liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;
    final navAccent = _resolveNavigationAccent(theme, ordoColor);
    final containerColor = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.72), navAccent.withValues(alpha: 0.42))
        : Color.alphaBlend(theme.colorScheme.surfaceContainer.withValues(alpha: 0.8), navAccent.withValues(alpha: 0.36));
    final buttonColor = isLight
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.84), navAccent.withValues(alpha: 0.34))
        : Color.alphaBlend(theme.colorScheme.surface.withValues(alpha: 0.88), navAccent.withValues(alpha: 0.28));
    final foregroundColor = _resolveHeaderForeground(theme, buttonColor);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? navAccent.withValues(alpha: 0.28)
              : navAccent.withValues(alpha: 0.24),
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
                backgroundColor: buttonColor,
                foregroundColor: foregroundColor,
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
                  color: foregroundColor,
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
                backgroundColor: buttonColor,
                foregroundColor: foregroundColor,
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
    final isLight = theme.brightness == Brightness.light;
    final chipForeground = isLight ? theme.colorScheme.onSurface : foregroundColor;
    final countdown = _buildCountdownLabel();
    final isSunday = _selectedDate.weekday == DateTime.sunday;
    final chips = <Widget>[
      _buildDetailChip(
        theme,
        'Season',
        _liturgicalDay!.seasonName,
        chipForeground,
      ),
      if (_liturgicalDay!.weekNumber > 0)
        _buildDetailChip(theme, 'Week', '${_liturgicalDay!.weekNumber}', chipForeground),
      if (_ordoYearVariables != null && isSunday)
        _buildDetailChip(theme, 'Sunday', _ordoYearVariables!.sundayCycle, chipForeground),
      if (_ordoYearVariables != null && !isSunday)
        _buildDetailChip(theme, 'Year', _ordoYearVariables!.weekdayCycle, chipForeground),
      if (countdown != null)
        _buildDetailChip(
          theme,
          countdown.$1,
          countdown.$2,
          chipForeground,
          onTap: () => _jumpToDate(countdown.$3, openFirstReading: true),
        ),
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

  Widget _buildDetailChip(
    ThemeData theme,
    String label,
    String value,
    Color foregroundColor,
    {VoidCallback? onTap}
  ) {
    final isLight = theme.brightness == Brightness.light;
    final liturgicalColor = _liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLight
            ? Color.alphaBlend(
                Colors.white.withValues(alpha: 0.94),
                liturgicalColor.withValues(alpha: 0.08),
              )
            : theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLight
              ? liturgicalColor.withValues(alpha: 0.24)
              : foregroundColor.withValues(alpha: 0.12),
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor.withValues(alpha: isLight ? 0.72 : 0.72),
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

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: chip,
      ),
    );
  }

  (String, String, DateTime)? _buildCountdownLabel() {
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
      return ('Today', nextFeast.$1, feastDate);
    }

    return ('To ${nextFeast.$1}', '$difference days', feastDate);
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
    final daysUntilSunday = (DateTime.sunday - christmas.weekday + 7) % 7;
    final sundayOnOrAfterChristmas = christmas.add(Duration(days: daysUntilSunday));
    return sundayOnOrAfterChristmas.subtract(const Duration(days: 28));
  }

  Color _resolveHeaderColor(ThemeData theme) {
    final seasonal = _liturgicalDay?.colorValue ?? theme.colorScheme.primary;
    final blendAmount = theme.brightness == Brightness.light ? 0.18 : 0.42;
    return Color.lerp(seasonal, theme.colorScheme.primary, blendAmount) ?? theme.colorScheme.primary;
  }

  Color _resolveNavigationAccent(ThemeData theme, Color ordoColor) {
    if (theme.brightness == Brightness.dark) {
      return Color.lerp(ordoColor, Colors.white, 0.12) ?? ordoColor;
    }

    return Color.lerp(ordoColor, theme.colorScheme.primary, 0.18) ?? ordoColor;
  }

  Color _resolveHeaderForeground(ThemeData theme, Color backgroundColor) {
    if (theme.brightness == Brightness.dark) {
      return Colors.white.withValues(alpha: 0.96);
    }

    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    return brightness == Brightness.dark ? Colors.white : theme.colorScheme.onSurface;
  }

  void _applyHydratedReadings(HydratedReadingSet hydrated) {
    _readings = hydrated.readings;
    _readingTexts = hydrated.readingTexts;
  }

  List<ReadingGroup> get _groupedReadings {
    final groups = <String, ReadingGroup>{};
    
    for (final reading in _readings) {
      final baseType = _getBaseReadingType(reading.position ?? 'Reading');
      final existingGroup = groups[baseType];
      
      if (existingGroup == null) {
        groups[baseType] = ReadingGroup(
          baseType: baseType,
          mainReading: reading,
          alternatives: [],
        );
      } else {
        // Check if this is an alternative
        if (reading.position?.contains('alternative') == true) {
          existingGroup.alternatives.add(reading);
        } else {
          // This shouldn't happen in normal flow, but handle it
          existingGroup.alternatives.add(reading);
        }
      }
    }
    
    return groups.values.toList()
      ..sort((a, b) => _getReadingTypeOrder(a.baseType).compareTo(_getReadingTypeOrder(b.baseType)));
  }
  
  String _getBaseReadingType(String? position) {
    if (position == null) return 'Reading';
    
    // Extract base type from positions like "Gospel (alternative)" or "First Reading (alternative 2)"
    final alternativeMatch = RegExp(r'^(.+?)\s*\(').firstMatch(position);
    if (alternativeMatch != null) {
      return alternativeMatch.group(1)!;
    }
    
    return position;
  }
  
  int _getReadingTypeOrder(String type) {
    switch (type.toLowerCase()) {
      case 'first reading': return 1;
      case 'responsorial psalm': return 2;
      case 'second reading': return 3;
      case 'gospel': return 4;
      case 'gospel at procession': return 5;
      default: return 999;
    }
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

/// Represents a group of readings of the same type (main + alternatives)
class ReadingGroup {
  final String baseType;
  final DailyReading mainReading;
  final List<DailyReading> alternatives;
  
  ReadingGroup({
    required this.baseType,
    required this.mainReading,
    required this.alternatives,
  });
  
  bool get hasAlternatives => alternatives.isNotEmpty;
  List<DailyReading> get allReadings => [mainReading, ...alternatives];
}

/// Premium Reading Group Card that shows main reading with expandable alternatives
class _PremiumReadingGroupCard extends StatefulWidget {
  final ReadingGroup group;
  final Color? liturgicalColor;
  final Function(DailyReading) onReadingSelected;
  
  const _PremiumReadingGroupCard({
    required this.group,
    this.liturgicalColor,
    required this.onReadingSelected,
  });
  
  @override
  State<_PremiumReadingGroupCard> createState() => _PremiumReadingGroupCardState();
}

class _PremiumReadingGroupCardState extends State<_PremiumReadingGroupCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }
  
  Color _getReadingTypeColor(String type, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (type.toLowerCase()) {
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
    final color = _getReadingTypeColor(widget.group.baseType, context);
    final isLight = theme.brightness == Brightness.light;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: widget.liturgicalColor != null
            ? Color.alphaBlend(
                isLight
                    ? Colors.white.withValues(alpha: 0.94)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
                widget.liturgicalColor!.withValues(alpha: isLight ? 0.14 : 0.24),
              )
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main reading
          _buildMainReading(theme, color, isLight),
          
          // Alternatives section
          if (widget.group.hasAlternatives) ...[
            const Divider(height: 1, color: Colors.grey),
            _buildAlternativesSection(theme, color, isLight),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMainReading(ThemeData theme, Color color, bool isLight) {
    final reading = widget.group.mainReading;
    final badgeBackground = isLight
        ? null
        : Color.alphaBlend(
            theme.colorScheme.surface.withValues(alpha: 0.86),
            color.withValues(alpha: 0.18),
          );
    final badgeForeground = isLight
        ? color
        : (ThemeData.estimateBrightnessForColor(badgeBackground!) == Brightness.dark
              ? Colors.white.withValues(alpha: 0.94)
              : theme.colorScheme.onSurface);

    return InkWell(
      onTap: () => widget.onReadingSelected(reading),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reading type badge with alternative indicator
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    gradient: isLight
                        ? LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.2),
                              color.withValues(alpha: 0.1),
                            ],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLight
                          ? color.withValues(alpha: 0.3)
                          : color.withValues(alpha: 0.42),
                    ),
                  ),
                  child: Text(
                    widget.group.baseType,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeForeground,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (widget.group.hasAlternatives) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '+${widget.group.alternatives.length} alt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Reference
            Text(
              reading.reading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Psalm response if applicable
            if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) ...[
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
                        'Response: ${reading.psalmResponse}',
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
              const SizedBox(height: 12),
            ],

            // Arrow indicator
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
    );
  }
  
  Widget _buildAlternativesSection(ThemeData theme, Color color, bool isLight) {
    return Column(
      children: [
        // Expand/collapse button
        InkWell(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: color.withValues(alpha: 0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isExpanded ? 'Hide Alternatives' : 'Show Alternatives',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.group.alternatives.length} available',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Alternatives list
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: widget.group.alternatives.asMap().entries.map((entry) {
                final index = entry.key;
                final alternative = entry.value;
                return _buildAlternativeItem(theme, color, alternative, index + 1);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAlternativeItem(ThemeData theme, Color color, DailyReading reading, int number) {
    return InkWell(
      onTap: () => widget.onReadingSelected(reading),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Alternative $number',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reading.reading,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Response: ${reading.psalmResponse}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
