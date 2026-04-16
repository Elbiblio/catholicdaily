import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/reading_catalog_service.dart';

/// A month-view liturgical calendar showing liturgical colors and feast days.
/// Used as a date picker replacement in the PremiumBrowseScreen.
class LiturgicalCalendarView extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const LiturgicalCalendarView({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<LiturgicalCalendarView> createState() => _LiturgicalCalendarViewState();
}

class _LiturgicalCalendarViewState extends State<LiturgicalCalendarView> {
  late DateTime _displayedMonth;
  late PageController _pageController;
  final _calendarService = ImprovedLiturgicalCalendarService.instance;

  // Cache liturgical days per month to avoid recomputation
  final Map<String, List<LiturgicalDay>> _cache = {};

  // memorial_feasts.csv data keyed by "month-day" -> shortest title for display
  Map<String, String>? _feastByMonthDay;

  static const _minDate = 2020;
  static const _maxDate = 2038;
  // Total months from Jan 2020 to Dec 2038
  static const _totalMonths = ((_maxDate - _minDate) + 1) * 12;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    final initialPage = _monthToIndex(_displayedMonth);
    _pageController = PageController(initialPage: initialPage);
    _loadFeastData();
  }

  Future<void> _loadFeastData() async {
    try {
      final entries = await ReadingCatalogService.instance.loadMemorialEntries();
      final map = <String, String>{};
      for (final e in entries) {
        if (e.month.isEmpty || e.day.isEmpty || e.title.isEmpty) continue;
        final key = '${e.month}-${e.day}';
        // Keep the first (highest-rank) entry; prefer shorter label
        if (!map.containsKey(key) || e.title.length < map[key]!.length) {
          map[key] = e.title;
        }
      }
      if (mounted) {
        setState(() => _feastByMonthDay = map);
      }
    } catch (_) {
      if (mounted) setState(() => _feastByMonthDay = {});
    }
  }

  String? _getFeastLabel(int month, int day) {
    if (_feastByMonthDay == null) return null;
    return _feastByMonthDay!['$month-$day'];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _monthToIndex(DateTime month) {
    return (month.year - _minDate) * 12 + (month.month - 1);
  }

  DateTime _indexToMonth(int index) {
    final year = _minDate + index ~/ 12;
    final month = (index % 12) + 1;
    return DateTime(year, month);
  }

  List<LiturgicalDay> _getLiturgicalDaysForMonth(DateTime month) {
    final key = '${month.year}-${month.month}';
    if (_cache.containsKey(key)) return _cache[key]!;

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final days = <LiturgicalDay>[];
    for (int d = 1; d <= daysInMonth; d++) {
      days.add(_calendarService.getLiturgicalDay(DateTime(month.year, month.month, d)));
    }
    _cache[key] = days;
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month/year header with navigation
        _buildMonthHeader(theme, isDark),
        // Weekday labels
        _buildWeekdayLabels(theme),
        // Calendar grid via PageView
        SizedBox(
          height: 380,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _totalMonths,
            onPageChanged: (index) {
              setState(() => _displayedMonth = _indexToMonth(index));
            },
            itemBuilder: (context, index) {
              final month = _indexToMonth(index);
              return _buildMonthGrid(theme, isDark, month);
            },
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        _buildLegend(theme, isDark),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMonthHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.chevron_left_rounded),
            iconSize: 24,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _showYearPicker,
              child: Text(
                DateFormat('MMMM yyyy').format(_displayedMonth),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            icon: const Icon(Icons.chevron_right_rounded),
            iconSize: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels(ThemeData theme) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: days.map((d) {
          return Expanded(
            child: Center(
              child: Text(
                d,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(ThemeData theme, bool isDark, DateTime month) {
    final liturgicalDays = _getLiturgicalDaysForMonth(month);
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = liturgicalDays.length;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateTime.now();
    final isToday = (DateTime d) =>
        d.year == today.year && d.month == today.month && d.day == today.day;
    final isSelected = (DateTime d) =>
        d.year == widget.selectedDate.year &&
        d.month == widget.selectedDate.month &&
        d.day == widget.selectedDate.day;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: List.generate(rows, (row) {
          return Expanded(
            child: Row(
              children: List.generate(7, (col) {
                final cellIndex = row * 7 + col;
                final dayIndex = cellIndex - startWeekday;

                if (dayIndex < 0 || dayIndex >= daysInMonth) {
                  return const Expanded(child: SizedBox.shrink());
                }

                final litDay = liturgicalDays[dayIndex];
                final date = litDay.date;
                final selected = isSelected(date);
                final todayMark = isToday(date);
                final litColor = litDay.colorValue;
                final hasFeast = litDay.title.isNotEmpty;
                final isHighRank = litDay.rank == 'Solemnity' ||
                    litDay.rank == 'Feast' ||
                    litDay.rank == 'Sunday';
                final isSunday = date.weekday == DateTime.sunday;
                final feastLabel = _getFeastLabel(date.month, date.day) ??
                    (hasFeast && isHighRank ? litDay.title : null);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      widget.onDateSelected(date);
                    },
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primary
                            : todayMark
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Day number — red for Sundays
                          Text(
                            '${dayIndex + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: isHighRank || selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? theme.colorScheme.onPrimary
                                  : isSunday
                                      ? const Color(0xFFB22222)
                                      : theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Liturgical color dot
                          Container(
                            width: hasFeast ? 8 : 5,
                            height: hasFeast ? 8 : 5,
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.onPrimary.withValues(alpha: 0.8)
                                  : _resolveCalendarDotColor(litColor, isDark),
                              shape: BoxShape.circle,
                              border: litDay.color == LiturgicalColor.white && !selected
                                  ? Border.all(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                      width: 0.5,
                                    )
                                  : null,
                            ),
                          ),
                          // Feast / memorial label
                          if (feastLabel != null) ...[  
                            const SizedBox(height: 2),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Text(
                                feastLabel,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 7,
                                  height: 1.1,
                                  fontWeight: isHighRank ? FontWeight.w600 : FontWeight.w400,
                                  color: selected
                                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme, bool isDark) {
    final items = [
      ('Green', const Color(0xFF228B22)),
      ('Purple', const Color(0xFF6B3FA0)),
      ('Red', const Color(0xFFB22222)),
      ('White', const Color(0xFFF5F5F5)),
      ('Pink', const Color(0xFFFF69B4)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _resolveCalendarDotColor(item.$2, isDark),
                    shape: BoxShape.circle,
                    border: item.$1 == 'White'
                        ? Border.all(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            width: 0.5,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  item.$1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _resolveCalendarDotColor(Color litColor, bool isDark) {
    // For white liturgical color, use a visible substitute
    if (litColor == const Color(0xFFF5F5F5)) {
      return isDark ? const Color(0xFFE0E0E0) : const Color(0xFFBDBDBD);
    }
    return isDark ? Color.lerp(litColor, Colors.white, 0.15)! : litColor;
  }

  void _showYearPicker() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Year'),
          content: SizedBox(
            width: 200,
            height: 300,
            child: ListView.builder(
              itemCount: _maxDate - _minDate + 1,
              itemBuilder: (context, index) {
                final year = _minDate + index;
                final isCurrent = year == _displayedMonth.year;
                return ListTile(
                  title: Text(
                    '$year',
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  selected: isCurrent,
                  onTap: () {
                    Navigator.pop(context);
                    final newMonth = DateTime(year, _displayedMonth.month);
                    final targetIndex = _monthToIndex(newMonth);
                    _pageController.jumpToPage(targetIndex);
                    setState(() => _displayedMonth = newMonth);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
