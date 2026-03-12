import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/ordo_resolver_service.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/psalm_resolver_service.dart';
import '../../data/models/daily_reading.dart';
import 'reading_detail_screen.dart';

class BrowseScreen extends StatefulWidget {
  final Function(String reading, String content, LiturgicalDay? liturgicalDay)
  onReadingSelected;

  const BrowseScreen({super.key, required this.onReadingSelected});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  DateTime _selectedDate = DateTime.now();
  List<DailyReading> _readings = [];
  bool _isLoading = true;
  LiturgicalDay? _liturgicalDay;
  OrdoYearVariables? _ordoYearVariables;
  bool _showLiturgicalDetails = false;

  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  final ReadingsService _readingsService = ReadingsService.instance;
  final PsalmResolverService _psalmResolver = PsalmResolverService.instance;

  @override
  void initState() {
    super.initState();
    _loadReadings();
    // Prefetch upcoming psalm responses in background
    _psalmResolver.prefetchUpcoming(days: 7);
  }

  Future<void> _loadReadings() async {
    setState(() => _isLoading = true);

    try {
      debugPrint('Loading readings for date: ${_selectedDate.toIso8601String()}');
      final results = await Future.wait([
        _ordoResolver.resolveDay(_selectedDate),
        _ordoResolver.resolveYearVariables(_selectedDate),
        _readingsService.getReadingsForDate(_selectedDate),
      ]);
      _liturgicalDay = results[0] as LiturgicalDay;
      _ordoYearVariables = results[1] as OrdoYearVariables;
      final rawReadings = results[2] as List<DailyReading>;
      debugPrint('Raw readings count: ${rawReadings.length}');
      for (final reading in rawReadings) {
        debugPrint('Reading: ${reading.position} - ${reading.reading} - Psalm: ${reading.psalmResponse} - Acclamation: ${reading.gospelAcclamation}');
      }
      _readings = await _psalmResolver.enrichReadingsForDisplay(
        date: _selectedDate,
        readings: rawReadings,
      );
      debugPrint('Enriched readings count: ${_readings.length}');
      for (final reading in _readings) {
        debugPrint('Enriched: ${reading.position} - ${reading.reading} - Psalm: ${reading.psalmResponse} - Acclamation: ${reading.gospelAcclamation}');
      }
    } catch (e) {
      debugPrint('Error loading readings: $e');
      _readings = [];
      _ordoYearVariables = null;
    }

    setState(() => _isLoading = false);
  }

  void _previousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
    });
    _loadReadings();
  }

  void _nextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
    });
    _loadReadings();
  }

  void _goToToday() {
    setState(() {
      _selectedDate = DateTime.now();
    });
    _loadReadings();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with liturgical day
          SliverAppBar(
            expandedHeight: _liturgicalDay != null ? 140 : 0,
            pinned: true,
            backgroundColor: _liturgicalDay?.colorValue ?? theme.primaryColor,
            foregroundColor: _liturgicalDay?.textColor ?? Colors.white,
            flexibleSpace: _liturgicalDay != null
                ? FlexibleSpaceBar(
                    background: Container(
                      color: _liturgicalDay!.colorValue,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Rank badge
                              if (_liturgicalDay!.rank != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  decoration: BoxDecoration(
                                    color: _liturgicalDay!.textColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _liturgicalDay!.rank!.toUpperCase(),
                                    style: TextStyle(
                                      color: _liturgicalDay!.textColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              // Title with overflow protection
                              Flexible(
                                child: Text(
                                  _liturgicalDay!.title.isNotEmpty
                                      ? _liturgicalDay!.title
                                      : _liturgicalDay!.seasonName,
                                  style: TextStyle(
                                    color: _liturgicalDay!.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Week description with overflow protection
                              Flexible(
                                child: Text(
                                  _liturgicalDay!.weekDescription,
                                  style: TextStyle(
                                    color: _liturgicalDay!.textColor.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Expand indicator
                              GestureDetector(
                                onTap: () => setState(
                                  () => _showLiturgicalDetails =
                                      !_showLiturgicalDetails,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _showLiturgicalDetails ? 'Hide' : 'More',
                                      style: TextStyle(
                                        color: _liturgicalDay!.textColor
                                            .withValues(alpha: 0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Icon(
                                      _showLiturgicalDetails
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: _liturgicalDay!.textColor
                                          .withValues(alpha: 0.7),
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                              // Additional details with size constraint
                              if (_showLiturgicalDetails) ...[
                                const SizedBox(height: 6),
                                SizedBox(
                                  height: 30,
                                  child: SingleChildScrollView(
                                    child: Text(
                                      _getLiturgicalDetails(),
                                      style: TextStyle(
                                        color: _liturgicalDay!.textColor
                                            .withValues(alpha: 0.8),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : null,
            title: Text(dateFormat.format(_selectedDate)),
            actions: [
              IconButton(
                icon: const Icon(Icons.today),
                onPressed: _goToToday,
                tooltip: 'Go to today',
              ),
            ],
          ),

          // Date navigation (smaller, below app bar)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.primaryColor.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _previousDay,
                  ),
                  TextButton(onPressed: _goToToday, child: const Text('Today')),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _nextDay,
                  ),
                ],
              ),
            ),
          ),

          // Readings list
          SliverFillRemaining(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _readings.isEmpty
                ? const Center(child: Text('No readings available'))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: _readings.length,
                    itemBuilder: (context, index) {
                      final reading = _readings[index];
                      return _ReadingCard(
                        reading: reading,
                        liturgicalColor: _liturgicalDay?.colorValue,
                        onTap: () async {
                          final text = await _readingsService.getReadingText(
                            reading.reading,
                          );
                          // Navigate to detail screen with psalm support
                          if (context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReadingDetailScreen(
                                  reading: reading,
                                  readingText: text,
                                  date: _selectedDate,
                                  liturgicalDay: _liturgicalDay,
                                ),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getLiturgicalDetails() {
    if (_liturgicalDay == null) return '';

    final buffer = StringBuffer();
    buffer.writeln('Season: ${_liturgicalDay!.seasonName}');
    if (_liturgicalDay!.weekNumber > 0) {
      buffer.writeln('Week: ${_liturgicalDay!.weekNumber}');
    }
    buffer.writeln('Day: ${_liturgicalDay!.dayName}');
    if (_ordoYearVariables != null) {
      buffer.writeln('Sunday Cycle: ${_ordoYearVariables!.sundayCycle}');
      buffer.writeln('Weekday Cycle: ${_ordoYearVariables!.weekdayCycle}');
      buffer.writeln('Golden Number: ${_ordoYearVariables!.goldenNumber}');
      buffer.writeln('Epact: ${_ordoYearVariables!.epact}');
    }

    return buffer.toString();
  }
}

class _ReadingCard extends StatelessWidget {
  final DailyReading reading;
  final Color? liturgicalColor;
  final VoidCallback onTap;

  const _ReadingCard({
    required this.reading,
    this.liturgicalColor,
    required this.onTap,
  });

  Color _getTypeColor(String? type, BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (type?.toLowerCase()) {
      case 'gospel':
        return isDark ? const Color(0xFFE57373) : Colors.red;
      case 'responsorial psalm':
        return liturgicalColor ??
            (isDark ? const Color(0xFF64B5F6) : Colors.blue);
      case 'first reading':
        return isDark ? const Color(0xFFBA68C8) : Colors.purple;
      case 'second reading':
        return isDark ? const Color(0xFF4DB6AC) : Colors.teal;
      default:
        return isDark ? Colors.grey.shade400 : Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _getTypeColor(reading.position, context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: theme.brightness == Brightness.dark ? 2 : 1,
      color: theme.brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainer
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: color.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.2,
          ),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Reading type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.2 : 0.15,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: color.withValues(
                          alpha: theme.brightness == Brightness.dark
                              ? 0.4
                              : 0.3,
                        ),
                      ),
                    ),
                    child: Text(
                      reading.position ?? 'Reading',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey.shade400
                        : Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Reference
              Text(
                reading.reading,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface
                      : null,
                ),
              ),
              const SizedBox(height: 8),

              // Psalm Response or Gospel Acclamation preview
              if (reading.psalmResponse != null && reading.psalmResponse!.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Response: ${reading.psalmResponse}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (reading.gospelAcclamation != null && reading.gospelAcclamation!.trim().isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.celebration,
                        size: 14,
                        color: Colors.red.shade700,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Acclamation: ${reading.gospelAcclamation}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Feast indicator
              if (reading.feast != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        liturgicalColor?.withValues(alpha: 0.1) ??
                        (theme.brightness == Brightness.dark
                            ? Colors.grey.withValues(alpha: 0.2)
                            : Colors.grey.withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    reading.feast!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          liturgicalColor ??
                          (theme.brightness == Brightness.dark
                              ? Colors.grey.shade300
                              : Colors.grey),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
