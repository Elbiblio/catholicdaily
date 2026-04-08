import 'package:flutter/material.dart';
import '../../data/models/hymn.dart';
import '../../data/models/hymn_category.dart';
import '../../data/models/daily_reading.dart';
import '../../data/services/hymn_service.dart';
import '../../data/services/robust_hymn_recommendation_service.dart';
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

class _HymnListScreenState extends State<HymnListScreen> with SingleTickerProviderStateMixin {
  final HymnService _hymnService = HymnService.instance;
  final RobustHymnRecommendationService _recommendationService = RobustHymnRecommendationService.instance;
  final ReadingsBackendIo _readingsBackend = ReadingsBackendIo();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  int _currentTabIndex = 0;

  List<Hymn> _hymns = [];
  List<HymnCategory> _categories = [];
  List<Hymn> _filteredHymns = [];
  Map<String, List<Hymn>> _massPartRecommendations = {};
  List<Hymn> _favorites = [];
  String? _selectedCategory;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _selectedCategory = widget.initialCategory;
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _loadData();
    _loadFavorites();
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
    try {
      final today = DateTime.now();
      final List<DailyReading> readings = await _readingsBackend.getReadingsForDate(today);

      // Get mass part recommendations (ensures only entrance, offertory, communion, dismissal)
      final massPartRecommendations = await _recommendationService.getMassPartRecommendations(
        today,
        readings,
      );

      setState(() {
        _massPartRecommendations = massPartRecommendations;
      });
    } catch (e) {
      debugPrint('Error loading daily recommendations: $e');
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'All Hymns'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Show subtitle on Today tab, search bar on others
          if (_currentTabIndex == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surface,
              child: Text(
                'Recommended hymns for today\'s readings',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surface,
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
          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRecommendationsTab(),
                      _buildAllHymnsTab(),
                      _buildFavoritesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsTab() {
    if (_massPartRecommendations.isEmpty) {
      return const Center(
        child: Text('No recommendations available'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildMassPartGrid(),
    );
  }

  Widget _buildAllHymnsTab() {
    return Column(
      children: [
        // Category filters
        if (_categories.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
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

        // Results count
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_filteredHymns.length} hymn${_filteredHymns.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (_selectedCategory != null || _searchController.text.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _onCategorySelected(null);
                  },
                  child: const Text('Clear filters'),
                ),
            ],
          ),
        ),

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
    );
  }

  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64),
            SizedBox(height: 16),
            Text('No favorites yet'),
            SizedBox(height: 8),
            Text('Tap the heart icon on hymns to add them here'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final hymn = _favorites[index];
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
    );
  }

  /// Responsive grid showing 2 hymns per mass part (8 total: 2 entrance, 2 offertory, 2 communion, 2 dismissal)
  Widget _buildMassPartGrid() {
    final theme = Theme.of(context);
    final parts = [
      {'key': 'entrance', 'label': 'Entrance', 'icon': Icons.church},
      {'key': 'offertory', 'label': 'Offertory', 'icon': Icons.wine_bar},
      {'key': 'communion', 'label': 'Communion', 'icon': Icons.set_meal},
      {'key': 'dismissal', 'label': 'Dismissal', 'icon': Icons.exit_to_app},
    ];

    // Responsive layout: use grid for larger screens, column for smaller
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth > 600;

    return useGrid ? _buildGridLayout(parts, theme) : _buildColumnLayout(parts, theme);
  }

  Widget _buildGridLayout(List<Map<String, dynamic>> parts, ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: parts.map((part) {
        final key = part['key'] as String;
        final label = part['label'] as String;
        final icon = part['icon'] as IconData;
        final hymns = _massPartRecommendations[key] ?? [];
        final topHymns = hymns.take(2).toList();

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${topHymns.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Hymns
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: topHymns.asMap().entries.map((entry) {
                      final index = entry.key;
                      final hymn = entry.value;
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => HymnDetailScreen(hymn: hymn),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surfaceContainerHigh,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: index == 0
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hymn.title,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColumnLayout(List<Map<String, dynamic>> parts, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parts.map((part) {
        final key = part['key'] as String;
        final label = part['label'] as String;
        final icon = part['icon'] as IconData;
        final hymns = _massPartRecommendations[key] ?? [];
        final topHymns = hymns.take(2).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(icon, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${topHymns.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Hymns
                ...topHymns.asMap().entries.map((entry) {
                  final index = entry.key;
                  final hymn = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HymnDetailScreen(hymn: hymn),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? theme.colorScheme.primaryContainer
                                    : theme.colorScheme.surfaceContainerHigh,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: index == 0
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                hymn.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    // TODO: Load favorites from storage
    setState(() {
      _favorites = [];
    });
  }
}
