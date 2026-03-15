import 'package:flutter/material.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/gospel_acclamation_service.dart';
import '../../data/services/psalm_resolver_service.dart';

/// Widget that displays gospel acclamation with on-demand fetching for missing acclamations
class GospelAcclamationWidget extends StatefulWidget {
  final DailyReading reading;
  final DateTime date;

  const GospelAcclamationWidget({
    super.key,
    required this.reading,
    required this.date,
  });

  @override
  State<GospelAcclamationWidget> createState() => _GospelAcclamationWidgetState();
}

class _GospelAcclamationWidgetState extends State<GospelAcclamationWidget> {
  final PsalmResolverService _resolver = PsalmResolverService.instance;
  final GospelAcclamationService _acclamationService = GospelAcclamationService();
  String? _fetchedAcclamation;
  bool _isGenerating = false;
  bool _fetchFailed = false;

  @override
  void initState() {
    super.initState();
    if (_needsFetch) {
      _fetchAcclamation();
    }
  }

  bool get _needsFetch {
    final existing = widget.reading.gospelAcclamation?.trim();
    if (existing == null || existing.isEmpty) return true;
    if (existing.startsWith('Reading text unavailable')) return true;
    return _acclamationService.shouldResolveReference(existing);
  }

  Future<void> _fetchAcclamation() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
      _fetchFailed = false;
    });

    try {
      final existing = widget.reading.gospelAcclamation?.trim();
      String? acclamation;
      final hasProperCelebrationAcclamation =
          widget.reading.feast?.trim().isNotEmpty == true;

      if (existing != null &&
          existing.isNotEmpty &&
          _acclamationService.shouldResolveReference(existing)) {
        if (hasProperCelebrationAcclamation) {
          final decoded = await _acclamationService.getAcclamationText(existing);
          if (decoded.trim().isNotEmpty &&
              !decoded.startsWith('Reading text unavailable')) {
            acclamation = decoded;
          }
        }

        acclamation ??= await _resolver.resolveGospelAcclamation(
          date: widget.date,
          gospelReference: widget.reading.reading,
        );

        if (acclamation == null ||
            acclamation.trim().isEmpty ||
            acclamation.startsWith('Reading text unavailable')) {
          final decoded = await _acclamationService.getAcclamationText(existing);
          if (decoded.trim().isNotEmpty &&
              !decoded.startsWith('Reading text unavailable')) {
            acclamation = decoded;
          }
        }
      }

      acclamation ??= await _resolver.resolveGospelAcclamation(
        date: widget.date,
        gospelReference: widget.reading.reading,
      );

      if (mounted) {
        setState(() {
          _fetchedAcclamation = acclamation;
          _isGenerating = false;
          _fetchFailed = acclamation == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _fetchFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.reading.gospelAcclamation?.trim();
    final safeExisting = (existing == null ||
            existing.isEmpty ||
            existing.startsWith('Reading text unavailable') ||
            _acclamationService.shouldResolveReference(existing))
        ? null
        : existing;
    final acclamation = safeExisting ?? _fetchedAcclamation;

    if (acclamation != null && acclamation.trim().isNotEmpty) {
      return _buildAcclamationCard(context, acclamation);
    }

    if (_isGenerating) {
      return _buildGeneratingCard(context);
    }

    if (_fetchFailed) {
      return _buildRetryCard(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildAcclamationCard(BuildContext context, String acclamation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isLent = _isDuringLent(widget.date);
    final acclamationResponse = _buildAcclamationResponse(widget.date);
    
    // Check if this is just the intro or a complete acclamation
    final isCompleteAcclamation = _isCompleteAcclamation(acclamation);
    final isFromVerseReference = _isFromVerseReference(acclamation);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? (isLent ? const Color(0xFF8D6E63).withValues(alpha: 0.1) : const Color(0xFFE57373).withValues(alpha: 0.1))
            : (isLent ? const Color(0xFF795548).withValues(alpha: 0.05) : const Color(0xFFE53935).withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? (isLent ? const Color(0xFF8D6E63).withValues(alpha: 0.3) : const Color(0xFFE57373).withValues(alpha: 0.3))
              : (isLent ? const Color(0xFF795548).withValues(alpha: 0.2) : const Color(0xFFE53935).withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLent ? Icons.church_rounded : Icons.celebration_rounded,
                size: 16,
                color: isDark
                    ? (isLent ? const Color(0xFF8D6E63) : const Color(0xFFE57373))
                    : (isLent ? const Color(0xFF795548) : const Color(0xFFE53935)),
              ),
              const SizedBox(width: 8),
              Text(
                isLent ? 'Verse before the Gospel' : 'Gospel Acclamation',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark
                      ? (isLent ? const Color(0xFF8D6E63) : const Color(0xFFE57373))
                      : (isLent ? const Color(0xFF795548) : const Color(0xFFE53935)),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              if (isLent) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF8D6E63).withValues(alpha: 0.2)
                        : const Color(0xFF795548).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Lent',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? const Color(0xFF8D6E63) : const Color(0xFF795548),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (!isCompleteAcclamation) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Intro only',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (isFromVerseReference && isCompleteAcclamation) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'From verse',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            acclamation,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (!isCompleteAcclamation) ...[
            const SizedBox(height: 8),
            Text(
              'Full acclamation will be fetched when available',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (isFromVerseReference && isCompleteAcclamation) ...[
            const SizedBox(height: 8),
            Text(
              acclamationResponse,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.blue.shade600,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildAcclamationResponse(DateTime date) {
    if (_isDuringLent(date)) {
      return 'Glory and praise to you, Lord Jesus Christ.';
    }

    return 'Alleluia, alleluia.';
  }

  /// Check if acclamation contains the full verse text or just the intro
  bool _isCompleteAcclamation(String acclamation) {
    // Complete acclamations typically have more than just the intro
    // Intro-only: "Alleluia." or "Glory and praise to you, Lord Jesus Christ."
    // Complete: "Alleluia. God was in himself reconciling himself to man."
    
    if (acclamation.length > 50) return true; // Likely complete

    final normalized = acclamation.trim().toLowerCase();
    if (normalized == 'alleluia.' ||
        normalized == 'glory and praise to you, lord jesus christ.') {
      return false;
    }
    
    return true; // Assume complete if it doesn't match intro-only patterns
  }

  /// Check if acclamation was decoded from verse reference
  bool _isFromVerseReference(String acclamation) {
    // If it's complete but not too long, it might be from a verse reference
    if (_isCompleteAcclamation(acclamation) && acclamation.length < 200) {
      return true;
    }
    return false;
  }

  Widget _buildGeneratingCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.grey.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Preparing gospel acclamation...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Acclamation not available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchAcclamation,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  /// Check if date is during Lent (Ash Wednesday to Holy Saturday)
  bool _isDuringLent(DateTime date) {
    final year = date.year;
    
    // Calculate Easter Sunday for the given year
    final easter = _calculateEaster(year);
    
    // Ash Wednesday is 46 days before Easter Sunday
    final ashWednesday = easter.subtract(const Duration(days: 46));
    
    // Holy Saturday is the day before Easter Sunday
    final holySaturday = easter.subtract(const Duration(days: 1));
    
    // Check if date is within Lent period
    return (date.isAtSameMomentAs(ashWednesday) || date.isAfter(ashWednesday)) &&
           (date.isAtSameMomentAs(holySaturday) || date.isBefore(holySaturday));
  }

  /// Calculate Easter Sunday using computus algorithm
  DateTime _calculateEaster(int year) {
    // Anonymous Gregorian algorithm
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
}
