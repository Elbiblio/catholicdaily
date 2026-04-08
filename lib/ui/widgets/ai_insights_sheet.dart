import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/services/bible_cache_service.dart';
import '../../core/constants.dart';

/// AI Insights bottom sheet widget for displaying Bible verse insights
/// 
/// This widget fetches and displays AI-generated insights for Bible passages
/// including core meaning, universal connection, historical context, and
/// reflection questions.
class AiInsightsSheet extends StatefulWidget {
  final String reference;
  final String content;

  const AiInsightsSheet({
    super.key,
    required this.reference,
    required this.content,
  });

  @override
  State<AiInsightsSheet> createState() => _AiInsightsSheetState();
}

class _AiInsightsSheetState extends State<AiInsightsSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _insight;

  @override
  void initState() {
    super.initState();
    _fetchInsight();
  }

  Future<void> _fetchInsight() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final verseId = Uri.encodeComponent(widget.reference);
      final text = widget.content.length > ReadingConstants.maxInsightTextLength
          ? '${widget.content.substring(0, ReadingConstants.maxInsightTextLength)}...'
          : widget.content;

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.apiVersion}/bible/verses/$verseId/explain'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'reference': widget.reference,
          'text': text,
        }),
      ).timeout(const Duration(seconds: ApiConstants.defaultTimeoutSeconds));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = (body['data'] ?? body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _insight = payload;
            _isLoading = false;
          });
          final meaning = _coreMeaning;
          if (meaning.isNotEmpty) {
            BibleCacheService().cacheInsight(
              reference: widget.reference,
              title: meaning,
              content: meaning,
            );
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Could not load insights (${response.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ErrorMessages.loadingError;
          _isLoading = false;
        });
      }
    }
  }

  String get _coreMeaning {
    final qi = _insight?['quick_insight'];
    if (qi is Map) return qi['core_meaning']?.toString() ?? '';
    return '';
  }

  List<String> get _reflectionQuestions {
    final rq = _insight?['reflection_questions'];
    if (rq is Map) {
      final qs = rq['questions'];
      if (qs is List) return qs.map((q) => q.toString()).take(3).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(LayoutConstants.radiusSm / 2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Insights — ${widget.reference}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Generating insights...'),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline,
                                    color: theme.colorScheme.error, size: 48),
                                const SizedBox(height: 12),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _fetchInsight,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildInsightSection(
                              theme,
                              icon: Icons.lightbulb_outline,
                              title: 'Core Meaning',
                              body: _coreMeaning,
                            ),
                            if (_insight?['quick_insight']?['universal_connection'] != null)
                              _buildInsightSection(
                                theme,
                                icon: Icons.connect_without_contact,
                                title: 'Universal Connection',
                                body: _insight!['quick_insight']['universal_connection'].toString(),
                              ),
                            if (_insight?['deeper_exploration']?['historical_context'] != null)
                              _buildInsightSection(
                                theme,
                                icon: Icons.history_edu,
                                title: 'Historical Context',
                                body: _insight!['deeper_exploration']['historical_context'].toString(),
                              ),
                            if (_insight?['reflection_questions'] != null)
                              _buildReflectionQuestions(theme),
                            const SizedBox(height: 16),
                          ],
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsightSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildReflectionQuestions(ThemeData theme) {
    final questionList = _reflectionQuestions;
    if (questionList.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Reflection Questions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...questionList.map((q) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: theme.textTheme.bodyMedium),
                    Expanded(child: Text(q, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
