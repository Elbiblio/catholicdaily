import 'package:flutter/material.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/psalm_resolver_service.dart';

/// Widget that displays psalm response with on-demand fetching for missing responses
class PsalmResponseWidget extends StatefulWidget {
  final DailyReading reading;
  final DateTime date;

  const PsalmResponseWidget({
    super.key,
    required this.reading,
    required this.date,
  });

  @override
  State<PsalmResponseWidget> createState() => _PsalmResponseWidgetState();
}

class _PsalmResponseWidgetState extends State<PsalmResponseWidget> {
  final PsalmResolverService _resolver = PsalmResolverService.instance;
  String? _fetchedResponse;
  bool _isFetching = false;
  bool _fetchFailed = false;

  @override
  void initState() {
    super.initState();
    if (_needsFetch) {
      _fetchResponse();
    }
  }

  bool get _needsFetch {
    final existing = widget.reading.psalmResponse?.trim();
    return existing == null || existing.isEmpty;
  }

  Future<void> _fetchResponse() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _fetchFailed = false;
    });

    try {
      final response = await _resolver.resolvePsalmResponse(
        date: widget.date,
        psalmReference: widget.reading.reading,
      );

      if (mounted) {
        setState(() {
          _fetchedResponse = response;
          _isFetching = false;
          _fetchFailed = response == null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _fetchFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = widget.reading.psalmResponse ?? _fetchedResponse;

    if (response != null && response.trim().isNotEmpty) {
      return _buildResponseCard(context, response);
    }

    if (_isFetching) {
      return _buildFetchingCard(context);
    }

    if (_fetchFailed) {
      return _buildRetryCard(context);
    }

    return const SizedBox.shrink();
  }

  Widget _buildResponseCard(BuildContext context, String response) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF42A5F5).withValues(alpha: 0.1)
            : const Color(0xFF2196F3).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF42A5F5).withValues(alpha: 0.3)
              : const Color(0xFF2196F3).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 16,
                color: isDark
                    ? const Color(0xFF42A5F5)
                    : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 8),
              Text(
                'Response',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isDark
                      ? const Color(0xFF42A5F5)
                      : const Color(0xFF2196F3),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            response,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchingCard(BuildContext context) {
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
              'Fetching psalm response...',
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
              'Response not available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: _fetchResponse,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
