import 'package:flutter/material.dart';
import '../../data/models/prayer.dart';
import '../../data/services/prayer_service.dart';
import 'prayer_detail_screen.dart';
import 'rosary_screen.dart';

class PrayersScreen extends StatefulWidget {
  const PrayersScreen({super.key});

  @override
  State<PrayersScreen> createState() => _PrayersScreenState();
}

class _PrayersScreenState extends State<PrayersScreen> with SingleTickerProviderStateMixin {
  final PrayerService _prayerService = PrayerService();
  List<Prayer> _bookmarkedPrayers = [];
  List<Prayer> _recentlyUsedPrayers = [];
  List<Prayer> _searchResults = [];
  late TabController _tabController;
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadPrayers();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && mounted) { // Quick Access tab
      // Sync recently used from service in-memory state immediately
      setState(() {
        _recentlyUsedPrayers = _prayerService.recentlyUsedPrayers;
      });
      // Also refresh bookmarks (user may have bookmarked in detail screen)
      _prayerService.getBookmarkedPrayers().then((bookmarked) {
        if (mounted) setState(() => _bookmarkedPrayers = bookmarked);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrayers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _prayerService.initialize();
      final bookmarked = await _prayerService.getBookmarkedPrayers();
      final recentlyUsed = _prayerService.recentlyUsedPrayers;
      if (mounted) {
        setState(() {
          _bookmarkedPrayers = bookmarked;
          _recentlyUsedPrayers = recentlyUsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.dashboard), text: 'Quick Access'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHomeTab(),
          _buildQuickAccessTab(),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRosarySection(),
          const SizedBox(height: 24),
          _buildCategoriesSection(),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          'Type in the search box above to find prayers',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No prayers found for "$_searchQuery"',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 16,
          ),
        ),
      );
    }

    // Use Column instead of ListView.builder to avoid nested scrollable issue
    return Column(
      children: _searchResults.map((prayer) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            title: Text(prayer.title),
            subtitle: Text(
              prayer.firstLine.length > 80
                  ? '${prayer.firstLine.substring(0, 80)}...'
                  : prayer.firstLine,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openPrayer(prayer),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildQuickAccessTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Search section at the top
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (query) {
              setState(() {
                _searchQuery = query;
                _searchResults = _prayerService.searchPrayers(query);
              });
            },
            decoration: InputDecoration(
              hintText: 'Search prayers...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: 'Recently Used',
                  icon: Icons.history,
                  items: _recentlyUsedPrayers,
                  emptyMessage: 'No recently used prayers',
                  onTap: (prayer) => _openPrayer(prayer),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: 'Bookmarks',
                  icon: Icons.bookmark,
                  items: _bookmarkedPrayers,
                  emptyMessage: 'No bookmarked prayers',
                  onTap: (prayer) => _openPrayer(prayer),
                  isBookmarkSection: true,
                ),
                const SizedBox(height: 24),
                _buildSearchResults(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Prayer> items,
    required String emptyMessage,
    required Function(Prayer) onTap,
    bool isBookmarkSection = false,
  }) {
    if (items.isEmpty) {
      return _buildEmptySection(title, icon, emptyMessage);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.take(3).map((prayer) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildPrayerCard(prayer, onTap, isBookmarkSection),
        )).toList(),
        if (items.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () => _showAllItems(title, items),
              child: Text('See all ${items.length}'),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptySection(String title, IconData icon, String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerCard(Prayer prayer, Function(Prayer) onTap, bool isBookmarkSection) {
    return Card(
      elevation: 2,
      child: ListTile(
        title: Text(prayer.title),
        subtitle: Text(
          prayer.firstLine.length > 80
              ? '${prayer.firstLine.substring(0, 80)}...'
              : prayer.firstLine,
        ),
        trailing: isBookmarkSection
            ? IconButton(
                icon: const Icon(Icons.bookmark),
                onPressed: () => _removeBookmark(prayer),
              )
            : const Icon(Icons.arrow_forward_ios),
        onTap: () => onTap(prayer),
      ),
    );
  }

  Widget _buildRosarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Rosary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              child: Icon(
                Icons.menu_book,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            title: Text(
              'Complete Rosary',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            subtitle: const Text('All mysteries and prayers'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RosaryScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    final categories = _prayerService.prayersByCategory;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.category, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...categories.entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              title: Text(entry.key),
              subtitle: Text('${entry.value.length} prayers'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _showCategoryPrayers(entry.key, entry.value),
            ),
          ),
        )).toList(),
      ],
    );
  }

  void _openPrayer(Prayer prayer) async {
    await _prayerService.markPrayerAsUsed(prayer);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrayerDetailScreen(prayer: prayer),
      ),
    );
  }

  Future<void> _removeBookmark(Prayer prayer) async {
    await _prayerService.toggleBookmark(prayer);
    await _loadPrayers(); // Refresh the lists
  }

  void _showAllItems(String title, List<Prayer> items) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPrayersScreen(
          category: title,
          prayers: items,
        ),
      ),
    );
  }

  void _showCategoryPrayers(String category, List<Prayer> prayers) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryPrayersScreen(
          category: category,
          prayers: prayers,
        ),
      ),
    );
  }
}

class PrayerSearchDelegate extends SearchDelegate<String> {
  final PrayerService _prayerService;
  List<Prayer> _searchResults = [];

  PrayerSearchDelegate(this._prayerService);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildCategories();
    }

    _searchResults = _prayerService.searchPrayers(query);
    return _buildSearchResults(context);
  }

  Widget _buildCategories() {
    final categories = _prayerService.prayersByCategory;
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.keys.length + 1, // +1 for Rosary section
      itemBuilder: (context, index) {
        if (index == 0) {
          // Special Rosary section at the top
          return Card(
            elevation: 4,
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                child: Icon(
                  Icons.menu_book,
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              title: Text(
                'Rosary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              subtitle: Text('Complete Rosary with mysteries and prayers'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RosaryScreen(),
                  ),
                );
              },
            ),
          );
        }
        
        final adjustedIndex = index - 1;
        final category = categories.keys.elementAt(adjustedIndex);
        final prayers = categories[category]!;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(category),
            subtitle: Text('${prayers.length} prayers'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryPrayersScreen(
                    category: category,
                    prayers: prayers,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No prayers found for "$query"',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final prayer = _searchResults[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(prayer.title),
            subtitle: Text(
              prayer.firstLine.length > 100
                  ? '${prayer.firstLine.substring(0, 100)}...'
                  : prayer.firstLine,
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrayerDetailScreen(prayer: prayer),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class CategoryPrayersScreen extends StatelessWidget {
  final String category;
  final List<Prayer> prayers;

  const CategoryPrayersScreen({
    super.key,
    required this.category,
    required this.prayers,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: prayers.length,
        itemBuilder: (context, index) {
          final prayer = prayers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(prayer.title),
              subtitle: Text(
                prayer.firstLine.length > 100
                    ? '${prayer.firstLine.substring(0, 100)}...'
                    : prayer.firstLine,
              ),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrayerDetailScreen(prayer: prayer),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
