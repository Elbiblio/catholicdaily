import 'package:flutter/material.dart';
import '../../data/models/hymn.dart';
import '../../data/models/hymn_category.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/hymn_service.dart';
import '../../data/services/hymn_recommendation_service.dart';
import '../../data/services/readings_backend_io.dart';
import '../widgets/hymn_card.dart';
import 'hymn_detail_screen.dart';

class HymnListScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialQuery;

  const HymnListScreen({
    super.key,
    this.initialCategory,
    this.initialQuery,
  });

  @override
  State<HymnListScreen> createState() => _HymnListScreenState();
}

class _HymnListScreenState extends State<HymnListScreen> {
  final HymnService _hymnService = HymnService.instance;
  final HymnRecommendationService _recommendationService = HymnRecommendationService.instance;
  final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();
  final TextEditingController _searchController = TextEditingController();

  List<Hymn> _hymns = [];
  List<HymnCategory> _categories = [];
  List<Hymn> _filteredHymns = [];
  List<Hymn> _dailyRecommendations = [];
  String? _selectedCategory;
  bool _isLoading = true;
  bool _isLoadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final hymns = await _hymnService.getHymnsFromAssets();
      final categories = await _hymnService.getCategoriesFromAssets();

      setState(() {
        _hymns = hymns;
        _categories = categories;
        _filteredHymns = _filterHymns(hymns);
        _isLoading = false;
      });

      // Load daily recommendations after hymns are loaded
      _loadDailyRecommendations();
    } catch (e) {
      print('Error loading hymns: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailyRecommendations() async {
    setState(() => _isLoadingRecommendations = true);

    try {
      final today = DateTime.now();
      final List<DailyReading> readings = await _readingsBackend.getReadingsForDate(today);

      final recommendations = await _recommendationService.getCombinedRecommendations(
        today,
        readings,
      );

      setState(() {
        _dailyRecommendations = recommendations.take(3).toList();
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      print('Error loading daily recommendations: $e');
      setState(() => _isLoadingRecommendations = false);
    }
  }

  List<Hymn> _filterHymns(List<Hymn> hymns) {
    var filtered = hymns;

    // Filter by category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((hymn) => hymn.category == _selectedCategory).toList();
    }

    // Filter by search query
    final query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      filtered = filtered.where((hymn) =>
        hymn.title.toLowerCase().contains(query) ||
        (hymn.author?.toLowerCase().contains(query) ?? false) ||
        hymn.displayLyrics.any((line) => line.toLowerCase().contains(query)) ||
        hymn.tags.any((tag) => tag.toLowerCase().contains(query))
      ).toList();
    }

    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredHymns = _filterHymns(_hymns);
    });
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category;
      _filteredHymns = _filterHymns(_hymns);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hymns'),
        bottom: _selectedCategory != null || _searchController.text.isNotEmpty
            ? PreferredSize(
                preferredSize: const Size.fromHeight(kToolbarHeight),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (_selectedCategory != null)
                        Chip(
                          label: Text(_formatCategory(_selectedCategory!)),
                          onDeleted: () => _onCategorySelected(null),
                        ),
                      if (_searchController.text.isNotEmpty)
                        Chip(
                          label: Text('Search: ${_searchController.text}'),
                          onDeleted: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search hymns...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // Mass part quick filters
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildMassPartFilter('All', null),
                      _buildMassPartFilter('Entrance', 'entrance'),
                      _buildMassPartFilter('Offertory', 'offertory'),
                      _buildMassPartFilter('Communion', 'communion'),
                      _buildMassPartFilter('Dismissal', 'dismissal'),
                    ],
                  ),
                ),

                // Category filter
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // All categories option
                          final isSelected = _selectedCategory == null;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: const Text('All'),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) _onCategorySelected(null);
                              },
                            ),
                          );
                        }

                        final category = _categories[index - 1];
                        final isSelected = _selectedCategory == category.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(category.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              _onCategorySelected(selected ? category.id : null);
                            },
                          ),
                        );
                      },
                    ),
                  ),

                // Daily Recommendations Section
                if (_isLoadingRecommendations && _selectedCategory == null && _searchController.text.isEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Loading today\'s recommendations...',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_dailyRecommendations.isNotEmpty && _selectedCategory == null && _searchController.text.isEmpty)
                  _buildDailyRecommendationsSection(),

                // Hymn list
                Expanded(
                  child: _filteredHymns.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_note,
                                size: 64,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hymns found',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _filteredHymns.length,
                          itemBuilder: (context, index) {
                            final hymn = _filteredHymns[index];
                            return HymnCard(
                              hymn: hymn,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HymnDetailScreen(hymn: hymn),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _formatCategory(String category) {
    return category.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildDailyRecommendationsSection() {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final dateStr = '${today.month}/${today.day}/${today.year}';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header with date context
          Row(
            children: [
              Icon(
                Icons.today,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Today\'s Picks ($dateStr)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Recommended based on today\'s liturgical readings',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),

          // Recommendations list
          ..._dailyRecommendations.asMap().entries.map((entry) {
            final index = entry.key;
            final hymn = entry.value;
            final rank = index + 1;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HymnDetailScreen(hymn: hymn),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Rank badge
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? theme.colorScheme.primaryContainer
                              : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$rank',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: rank == 1
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Hymn info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hymn.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hymn.category.isNotEmpty)
                              Text(
                                _formatCategory(hymn.category),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Arrow
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // "Why these hymns?" subtle context
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Matched to today\'s liturgical themes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMassPartFilter(String label, String? massPart) {
    final isSelected = _selectedCategory == massPart;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          _onCategorySelected(selected ? massPart : null);
        },
        backgroundColor: massPart != null
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : null,
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
