import 'package:flutter/material.dart';
import '../../data/models/hymn.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/robust_hymn_recommendation_service.dart';
import '../widgets/hymn_card.dart';
import '../screens/hymn_detail_screen.dart';
import '../screens/hymn_list_screen.dart';

class HymnRecommendationsWidget extends StatefulWidget {
  final DateTime date;
  final List<DailyReading> readings;

  const HymnRecommendationsWidget({
    super.key,
    required this.date,
    required this.readings,
  });

  @override
  State<HymnRecommendationsWidget> createState() => _HymnRecommendationsWidgetState();
}

class _HymnRecommendationsWidgetState extends State<HymnRecommendationsWidget> {
  final RobustHymnRecommendationService _recommendationService = RobustHymnRecommendationService.instance;

  Map<String, List<Hymn>> _recommendations = {};
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _isLoading = true);

    try {
      final recommendations = await _recommendationService.getMassPartRecommendations(
        widget.date,
        widget.readings,
      );

      setState(() {
        _recommendations = recommendations;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading hymn recommendations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Card(
        margin: const EdgeInsets.all(16),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Loading hymn recommendations...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Check if we have any recommendations
    final hasRecommendations = _recommendations.values.any((list) => list.isNotEmpty);
    if (!hasRecommendations) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.music_note, color: Theme.of(context).colorScheme.primary),
            title: Text(
              'Recommended Hymns for Mass',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            trailing: IconButton(
              icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
              },
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            _buildMassPartSection('Entrance', 'entrance'),
            _buildMassPartSection('Offertory', 'offertory'),
            _buildMassPartSection('Communion', 'communion'),
            _buildMassPartSection('Dismissal', 'dismissal'),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HymnListScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.library_music),
                  label: const Text('Browse All Hymns'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMassPartSection(String title, String key) {
    final hymns = _recommendations[key] ?? [];
    if (hymns.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ...hymns.take(2).map((hymn) {
          return HymnCard(
            hymn: hymn,
            showPreview: false,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HymnDetailScreen(hymn: hymn),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
