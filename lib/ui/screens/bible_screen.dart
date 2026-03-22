import 'package:flutter/material.dart';
import 'search_screen.dart';
import '../../data/services/bible_cache_service.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';
import '../../data/services/app_navigation_service.dart';
import '../../data/services/bible_version_preference.dart';

class BibleScreen extends StatefulWidget {
  final Function(String reference, String content, LiturgicalDay? liturgicalDay, {bool isBibleSearch})
  onReadingSelected;

  const BibleScreen({super.key, required this.onReadingSelected});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BibleCacheService _cacheService = BibleCacheService();
  final AppNavigationService _navigationService = AppNavigationService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _cacheService.initialize();
  }

  void _onTabChanged() {
    if (_tabController.index == 1) { // Quick Access tab
      setState(() {}); // Refresh to show updated recently opened/bookmarks
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.home), text: 'Quick Access'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SearchScreen(onReadingSelected: widget.onReadingSelected),
          _buildHomeTab(),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return FutureBuilder(
      future: _cacheService.initialize(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: 'Recently Opened',
                icon: Icons.history,
                items: _cacheService.recentlyOpened,
                emptyMessage: 'No recently opened passages',
                onTap: (item) => _openPassage(item),
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Bookmarks',
                icon: Icons.bookmark,
                items: _cacheService.bookmarked,
                emptyMessage: 'No bookmarked passages',
                onTap: (item) => _openPassage(item),
                isBookmarkSection: true,
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Recent Insights',
                icon: Icons.auto_awesome,
                items: _cacheService.recentInsights,
                emptyMessage: 'No recent insights',
                onTap: (item) => _openInsight(item),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
    required Function(Map<String, dynamic>) onTap,
    bool isBookmarkSection = false,
  }) {
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          ...items.map((item) => _buildItemCard(item, onTap, isBookmarkSection: isBookmarkSection)),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, Function(Map<String, dynamic>) onTap, {bool isBookmarkSection = false}) {
    final reference = item['reference'] as String? ?? '';
    final isBookmarked = _cacheService.isBookmarked(reference);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(item['title'] as String? ?? 'Unknown'),
        subtitle: Text(item['reference'] as String? ?? ''),
        trailing: isBookmarkSection 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => _toggleBookmark(item),
                ),
                const Icon(Icons.chevron_right),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (reference.isNotEmpty) IconButton(
                  icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
                  onPressed: () => _toggleBookmark(item),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
        onTap: () => onTap(item),
      ),
    );
  }

  void _toggleBookmark(Map<String, dynamic> item) async {
    final reference = item['reference'] as String? ?? '';
    final title = item['title'] as String? ?? reference;
    final content = item['content'] as String? ?? '';
    
    final preference = await BibleVersionPreference.getInstance();
    await _cacheService.toggleBookmark(
      reference: reference,
      title: title,
      content: content,
      version: preference.currentVersion.dbName,
    );
    
    // Refresh the UI
    setState(() {});
  }

  void _openPassage(Map<String, dynamic> item) async {
    final reference = item['reference'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final title = item['title'] as String? ?? reference;
    
    // Track Bible chapter for smart navigation
    await _navigationService.trackBibleChapter(
      reference: reference,
      content: content,
      title: title,
    );
    
    // Cache as recently opened
    final preference = await BibleVersionPreference.getInstance();
    await _cacheService.addRecentlyOpened(
      reference: reference,
      title: title,
      content: content,
      version: preference.currentVersion.dbName,
    );
    
    widget.onReadingSelected(reference, content, null, isBibleSearch: true);
  }

  void _openInsight(Map<String, dynamic> item) {
    final reference = item['reference'] as String? ?? '';
    final content = item['content'] as String? ?? '';
    final title = 'Insight: ${item['title'] as String? ?? reference}';
    
    widget.onReadingSelected(title, content, null, isBibleSearch: true);
  }
}
