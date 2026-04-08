import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/readings_service.dart';
import '../../data/services/improved_liturgical_calendar_service.dart';

class SearchScreen extends StatefulWidget {
  final Function(String reference, String content, LiturgicalDay? liturgicalDay, {bool isBibleSearch})
  onReadingSelected;

  const SearchScreen({super.key, required this.onReadingSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _keyQuery = 'search_query';
  static const _keySelectedBookShortName = 'search_selected_book_short_name';
  static const _keySelectedChapter = 'search_selected_chapter';

  final TextEditingController _searchController = TextEditingController();
  final ReadingsService _readingsService = ReadingsService.instance;

  List<Map<String, dynamic>> _books = [];
  List<Map<String, dynamic>> _filteredBooks = [];
  Map<String, dynamic>? _selectedBook;
  int? _selectedChapter;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _readingsService.getBooks();
      _books = books
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'shortName': b.shortName,
              'chapters': b.chapterCount,
            },
          )
          .toList();
      _filteredBooks = _books;
      await _restoreSearchState();
    } catch (e) {
      _books = [];
      _filteredBooks = [];
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBooks = _books.where((book) {
        return book['name'].toLowerCase().contains(query) ||
            book['shortName'].toLowerCase().contains(query);
      }).toList();
    });
    _persistSearchState();
  }

  void _selectBook(Map<String, dynamic> book) {
    setState(() {
      _selectedBook = book;
      _selectedChapter = null;
    });
    _persistSearchState();
  }

  void _selectChapter(int chapter) {
    setState(() {
      _selectedChapter = chapter;
    });
    _persistSearchState();
    _loadChapter(chapter);
  }

  Future<void> _loadChapter(int chapter) async {
    if (_selectedBook == null) return;

    setState(() => _isLoading = true);

    try {
      final text = await _readingsService.getChapterText(
        bookShortName: _selectedBook!['shortName'] as String,
        chapter: chapter,
      );

      if (mounted) {
        widget.onReadingSelected(
          '${_selectedBook!['name']} $chapter',
          text,
          null,
          isBibleSearch: true,
        );
      }
    } catch (e) {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading chapter: $e')));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _goBack() {
    if (_selectedChapter != null) {
      setState(() {
        _selectedChapter = null;
      });
    } else if (_selectedBook != null) {
      setState(() {
        _selectedBook = null;
      });
    }
    _persistSearchState();
  }

  String _getCurrentTitle() {
    if (_selectedBook != null && _selectedChapter != null) {
      return '${_selectedBook!['name']} $_selectedChapter';
    } else if (_selectedBook != null) {
      return _selectedBook!['name'];
    }
    return 'Search Bible';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getCurrentTitle()),
        leading: _selectedBook != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        bottom: _selectedBook == null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search books...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Book selection
    if (_selectedBook == null) {
      return ListView.builder(
        itemCount: _filteredBooks.length,
        itemBuilder: (context, index) {
          final book = _filteredBooks[index];
          return ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '${book['chapters']}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            title: Text(book['name']),
            subtitle: Text('${book['chapters']} chapters'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectBook(book),
          );
        },
      );
    }

    // Chapter selection
    return LayoutBuilder(
      builder: (context, constraints) {
        final colorScheme = Theme.of(context).colorScheme;
        final gridWidth = constraints.maxWidth;
        final crossAxisCount = (gridWidth / 72).floor().clamp(3, 8);

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.25,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _selectedBook!['chapters'] as int,
          itemBuilder: (context, index) {
            final chapter = index + 1;
            final isSelected = chapter == _selectedChapter;

            return Semantics(
              button: true,
              label: 'Chapter $chapter',
              selected: isSelected,
              child: Material(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectChapter(chapter),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.5),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$chapter',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _restoreSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedQuery = prefs.getString(_keyQuery) ?? '';
    final savedBookShortName = prefs.getString(_keySelectedBookShortName);
    final savedChapter = prefs.getInt(_keySelectedChapter);

    if (savedQuery.isNotEmpty) {
      _searchController.text = savedQuery;
    }

    if (savedBookShortName != null) {
      for (final book in _books) {
        if (book['shortName'] == savedBookShortName) {
          _selectedBook = book;
          _selectedChapter = savedChapter;
          break;
        }
      }
    }
    _onSearchChanged();
  }

  Future<void> _persistSearchState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyQuery, _searchController.text);

    if (_selectedBook != null) {
      await prefs.setString(
        _keySelectedBookShortName,
        _selectedBook!['shortName'] as String,
      );
    } else {
      await prefs.remove(_keySelectedBookShortName);
    }

    if (_selectedChapter != null) {
      await prefs.setInt(_keySelectedChapter, _selectedChapter!);
    } else {
      await prefs.remove(_keySelectedChapter);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}
