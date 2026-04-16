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
import '../widgets/premium_browse/date_navigation.dart';
import '../widgets/premium_browse/liturgical_summary_row.dart';
import '../widgets/premium_browse/main_reading.dart';
import '../widgets/premium_browse/alternatives_section.dart';
import '../utils/contrast_helper.dart';
import '../utils/reading_type_colors.dart';
import '../widgets/premium_browse/daily_mass_at_a_glance_card.dart';
import '../widgets/premium_browse/todays_saint_card.dart';
import '../widgets/liturgical_calendar_view.dart';
import 'mass_flow_screen.dart';

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
  Map<String, String> _readingPreviews = {};
  bool _isLoading = true;
  LiturgicalDay? _liturgicalDay;
  OrdoYearVariables? _ordoYearVariables;
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
      _readingPreviews = {};
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

  void _showDatePicker() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                LiturgicalCalendarView(
                  selectedDate: _selectedDate,
                  onDateSelected: (date) {
                    Navigator.pop(context);
                    if (date != _selectedDate) {
                      HapticFeedback.mediumImpact();
                      setState(() => _selectedDate = date);
                      _loadReadings();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with glassmorphism effect
          _buildPremiumAppBar(theme),

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

  Widget _buildPremiumAppBar(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;
    return SliverAppBar(
      expandedHeight: isLight ? 190 : 170,
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
          DateFormat('EEEE').format(_selectedDate),
          key: ValueKey(_selectedDate),
          style: theme.textTheme.titleMedium?.copyWith(
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
              MediaQuery.of(context).padding.top + kToolbarHeight + (isLight ? 0 : 4),
              20,
              isLight ? 14 : 10,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                    // Rank badge (skip generic day names that duplicate the title)
                    if (_liturgicalDay!.rank != null &&
                        !_isGenericDayRank(_liturgicalDay!.rank!))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: headerForeground.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: headerForeground.withValues(alpha: 0.20),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _liturgicalDay!.rank!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: headerForeground.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),

                    // Main liturgical title
                    Text(
                      _buildConciseHeader(_liturgicalDay!),
                      style: (_shouldUseCanterburyFont(_liturgicalDay!)
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.titleLarge
                      )?.copyWith(
                        color: headerForeground,
                        fontFamily: _shouldUseCanterburyFont(_liturgicalDay!) ? 'Canterbury' : null,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    _buildLiturgicalSummaryRow(theme, headerForeground),

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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.95),
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

            // Daily Mass at-a-glance summary card
            DailyMassAtAGlanceCard(
              liturgicalDay: _liturgicalDay,
              readingGroups: _groupedReadings
                  .map((g) => (baseType: g.baseType, mainReading: g.mainReading))
                  .toList(),
              onBeginMass: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MassFlowScreen(date: _selectedDate),
                  ),
                );
              },
              onReadingRowTap: (baseType, reading) async {
                HapticFeedback.lightImpact();
                final readingIndex = _readings.indexOf(reading);
                if (readingIndex >= 0) {
                  await _openReadingAtIndex(readingIndex);
                }
              },
            ),

            // Today's Saint card
            if (_optionalCelebrations.isNotEmpty)
              TodaysSaintCard(
                celebrations: _optionalCelebrations,
                liturgicalDay: _liturgicalDay,
                isSuppressed: _celebrationsSuppressed,
              ),

            // Optional celebrations selector
            if (_optionalCelebrations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(top: 16),
                child: _buildOptionalCelebrationSelector(theme),
              ),

            // Grouped readings list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _liturgicalDay?.colorValue ?? theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Today\'s Readings',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    padding: EdgeInsets.zero,
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
                          readingPreviews: _readingPreviews,
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateNavigation(ThemeData theme) {
    return DateNavigation(
      selectedDate: _selectedDate,
      liturgicalColor: _liturgicalDay?.colorValue,
      onPreviousDay: _previousDay,
      onNextDay: _nextDay,
      onDateTap: _showDatePicker,
    );
  }

  String _buildConciseHeader(LiturgicalDay liturgicalDay) {
    // Sunday with special title (Palm Sunday, Easter Sunday, etc.)
    if (liturgicalDay.dayOfWeek.name == 'sunday') {
      if (liturgicalDay.title.isNotEmpty && 
          !liturgicalDay.title.toLowerCase().contains('of lent')) {
        return liturgicalDay.title;
      } else if (liturgicalDay.title.isNotEmpty && 
                 liturgicalDay.title.toLowerCase().contains('sunday')) {
        return liturgicalDay.title;
      } else {
        return '${liturgicalDay.weekNumber}${_getOrdinalSuffix(liturgicalDay.weekNumber)} Sunday of ${liturgicalDay.seasonName}';
      }
    }
    
    // Solemnities — use title case
    if (liturgicalDay.rank != null && 
        liturgicalDay.rank!.toLowerCase().contains('solemnity')) {
      if (liturgicalDay.title.isNotEmpty) {
        return _toTitleCase(liturgicalDay.title);
      }
      return 'Solemnity';
    }
    
    // Regular weekdays — compact: "2nd Week of Easter" (day name is in the date label above)
    if (liturgicalDay.weekNumber > 0) {
      return '${_ordinalFull(liturgicalDay.weekNumber)} Week of ${liturgicalDay.seasonName}';
    }

    // Fallback for edge cases (Christmas season day names, etc.)
    return liturgicalDay.title.isNotEmpty ? liturgicalDay.title : liturgicalDay.seasonName;
  }

  String _ordinalFull(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1: return '${n}st';
      case 2: return '${n}nd';
      case 3: return '${n}rd';
      default: return '${n}th';
    }
  }
  
  String _getOrdinalSuffix(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
  
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }
  
  bool _isGenericDayRank(String rank) {
    final lower = rank.toLowerCase().trim();
    const dayNames = {
      'sunday', 'monday', 'tuesday', 'wednesday',
      'thursday', 'friday', 'saturday',
    };
    return dayNames.contains(lower);
  }

  bool _shouldUseCanterburyFont(LiturgicalDay liturgicalDay) {
    // Use Canterbury font for Sundays and solemnities
    if (liturgicalDay.dayOfWeek.name == 'sunday') {
      return true;
    }
    
    if (liturgicalDay.rank != null && 
        liturgicalDay.rank!.toLowerCase().contains('solemnity')) {
      return true;
    }
    
    return false;
  }

  Widget _buildLiturgicalSummaryRow(ThemeData theme, Color foregroundColor) {
    final countdown = _buildCountdownLabel();
    
    return LiturgicalSummaryRow(
      seasonName: _liturgicalDay!.seasonName,
      weekNumber: _liturgicalDay!.weekNumber,
      sundayCycle: _ordoYearVariables?.sundayCycle,
      weekdayCycle: _ordoYearVariables?.weekdayCycle,
      foregroundColor: foregroundColor,
      liturgicalColor: _liturgicalDay?.colorValue,
      countdownLabel: countdown?.$1,
      countdownValue: countdown?.$2,
      onCountdownTap: countdown != null ? () => _jumpToDate(countdown.$3, openFirstReading: true) : null,
      onInfoTap: () => _showLiturgicalDetailsSheet(),
    );
  }

  void _showLiturgicalDetailsSheet() {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Liturgical color
                if (_liturgicalDay != null) ...[
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: _liturgicalDay!.colorValue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Liturgical Color',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: textColor.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _liturgicalDay!.color.name[0].toUpperCase() +
                            _liturgicalDay!.color.name.substring(1),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Saint of the day
                if (_optionalCelebrations.isNotEmpty) ...[
                  Text(
                    _celebrationsSuppressed ? 'Commemoration' : 'Saint of the Day',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ..._optionalCelebrations.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      c.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],

                // Ordo year variables
                if (_ordoYearVariables != null) ...[
                  Divider(height: 1, color: textColor.withValues(alpha: 0.08)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 24,
                    runSpacing: 10,
                    children: [
                      _buildSheetDetailPair(theme, 'Golden Number', '${_ordoYearVariables!.goldenNumber}'),
                      _buildSheetDetailPair(theme, 'Epact', '${_ordoYearVariables!.epact}'),
                      _buildSheetDetailPair(theme, 'Solar Cycle', '${_ordoYearVariables!.solarCycle}'),
                      _buildSheetDetailPair(theme, 'Indiction', '${_ordoYearVariables!.indiction}'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetDetailPair(ThemeData theme, String label, String value) {
    final textColor = theme.colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

  Color _resolveHeaderForeground(ThemeData theme, Color backgroundColor) {
    return ContrastHelper.getContrastColor(backgroundColor, theme);
  }

  void _applyHydratedReadings(HydratedReadingSet hydrated) {
    _readings = hydrated.readings;
    _readingTexts = hydrated.readingTexts;
    _readingPreviews = hydrated.readingPreviews;
  }

  List<ReadingGroup> get _groupedReadings {
    final groups = <String, ReadingGroup>{};
    final insertionOrder = <String>[];

    for (final reading in _readings) {
      final baseType = _getBaseReadingType(reading.position ?? 'Reading');
      final existingGroup = groups[baseType];

      if (existingGroup == null) {
        groups[baseType] = ReadingGroup(
          baseType: baseType,
          mainReading: reading,
          alternatives: [],
        );
        insertionOrder.add(baseType);
      } else {
        // Any additional reading with the same base type is an alternative.
        existingGroup.alternatives.add(reading);
      }
    }

    // Preserve natural ordering from the resolver for Easter Vigil / vigils
    // where positions like "Responsorial Psalm after Third Reading" are unique
    // per slot and must stay in sequence. Only apply the priority order for
    // standard positions so alternatives still group cleanly.
    final ordered = groups.values.toList();
    ordered.sort((a, b) {
      final orderA = _getReadingTypeOrder(a.baseType);
      final orderB = _getReadingTypeOrder(b.baseType);
      if (orderA != orderB) return orderA.compareTo(orderB);
      // Same priority bucket — fall back to insertion order.
      return insertionOrder.indexOf(a.baseType).compareTo(insertionOrder.indexOf(b.baseType));
    });
    return ordered;
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
    final lower = type.toLowerCase();
    // Easter Vigil pairs each OT reading with its psalm; preserve sequence.
    if (lower.contains('after first reading')) return 11;
    if (lower.contains('second reading') && !lower.contains('after')) return 12;
    if (lower.contains('after second reading')) return 13;
    if (lower.contains('third reading')) return 14;
    if (lower.contains('after third reading')) return 15;
    if (lower.contains('fourth reading')) return 16;
    if (lower.contains('after fourth reading')) return 17;
    if (lower.contains('fifth reading')) return 18;
    if (lower.contains('after fifth reading')) return 19;
    if (lower.contains('sixth reading')) return 20;
    if (lower.contains('after sixth reading')) return 21;
    if (lower.contains('seventh reading')) return 22;
    if (lower.contains('after seventh reading')) return 23;
    if (lower == 'epistle') return 24;
    if (lower.contains('after epistle')) return 25;
    switch (lower) {
      case 'first reading': return 10;
      case 'responsorial psalm': return 30;
      case 'alleluia psalm': return 30;
      case 'sequence': return 40;
      case 'gospel acclamation': return 50;
      case 'gospel': return 60;
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
    final isDark = theme.brightness == Brightness.dark;
    final baseBorderColor = _celebrationsSuppressed
        ? (isDark
            ? const Color(0xFFE7C27A)
            : const Color(0xFFD9A441))
        : theme.colorScheme.tertiary;
    final baseBackgroundColor = _celebrationsSuppressed
        ? (isDark
            ? const Color(0xFF2B2117)
            : const Color(0xFF3A2B1A))
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
                final isDark = theme.brightness == Brightness.dark;
                final chipForeground = _celebrationsSuppressed
                    ? (isDark
                        ? const Color(0xFFE7C27A)
                        : const Color(0xFFD9A441))
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
                      ? (isDark
                          ? const Color(0xFF8B5E1A)
                          : const Color(0xFFD9A441))
                      : theme.colorScheme.primary,
                  backgroundColor: _celebrationsSuppressed
                      ? (isDark
                          ? const Color(0xFF2B2117)
                          : const Color(0xFF3A2B1A))
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
  final Map<String, String> readingPreviews;
  final Function(DailyReading) onReadingSelected;
  
  const _PremiumReadingGroupCard({
    required this.group,
    this.liturgicalColor,
    required this.readingPreviews,
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
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    // Compute the card background first so ReadingTypeColors can ensure contrast
    final cardBackground = widget.liturgicalColor != null
        ? Color.alphaBlend(
            isLight
                ? Colors.white.withValues(alpha: 0.94)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            widget.liturgicalColor!.withValues(alpha: isLight ? 0.14 : 0.24),
          )
        : theme.colorScheme.surface;

    final color = ReadingTypeColors.forType(
      widget.group.baseType,
      context,
      liturgicalColor: widget.liturgicalColor,
      background: cardBackground,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: cardBackground,
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
            Divider(height: 1, color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            _buildAlternativesSection(theme, color, isLight),
          ],
        ],
      ),
    );
  }
  
  Widget _buildMainReading(ThemeData theme, Color color, bool isLight) {
    final group = widget.group;
    final reading = group.mainReading;
    
    return MainReading(
      reading: reading,
      baseType: group.baseType,
      alternatives: group.alternatives,
      previewText: widget.readingPreviews[reading.reading],
      color: color,
      onTap: () => widget.onReadingSelected(reading),
    );
  }
  
  Widget _buildAlternativesSection(ThemeData theme, Color color, bool isLight) {
    final group = widget.group;
    
    return AlternativesSection(
      alternatives: group.alternatives,
      readingPreviews: widget.readingPreviews,
      color: color,
      isExpanded: _isExpanded,
      expandAnimation: _expandAnimation,
      onToggleExpanded: _toggleExpanded,
      onAlternativeSelected: (reading) => widget.onReadingSelected(reading),
    );
  }
}
