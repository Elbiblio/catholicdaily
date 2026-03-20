import '../../data/services/readings_service.dart';
import '../../data/models/bible_book.dart';

/// Helper class for parsing and navigating Bible references
class BibleReferenceHelper {
  static final ReadingsService _readingsService = ReadingsService.instance;

  /// Parse a Bible reference to extract book short name and current chapter
  static Map<String, dynamic>? parseReference(String reference) {
    // Handle formats like "Genesis 1", "John 3", "Psalm 23", etc.
    final match = RegExp(r'^(.+?)\s+(\d+)$', caseSensitive: false).firstMatch(reference.trim());
    if (match == null) return null;

    final bookName = match.group(1)!.trim();
    final chapter = int.tryParse(match.group(2)!);
    if (chapter == null) return null;

    return {
      'bookName': bookName,
      'chapter': chapter,
    };
  }

  /// Get the short name for a book from its full name
  static Future<String?> getBookShortName(String bookName) async {
    try {
      final books = await _readingsService.getBooks();
      final book = books.firstWhere(
        (book) => book.name.toLowerCase() == bookName.toLowerCase(),
        orElse: () => books.firstWhere(
          (book) => book.shortName.toLowerCase() == bookName.toLowerCase(),
          orElse: () => books.firstWhere(
            (book) => book.name.toLowerCase().contains(bookName.toLowerCase()),
            orElse: () => Book(id: 0, name: '', shortName: '', chapterCount: 0),
          ),
        ),
      );
      return book.shortName.isNotEmpty ? book.shortName : null;
    } catch (e) {
      return null;
    }
  }

  /// Check if a previous chapter exists
  static Future<bool> hasPreviousChapter(String reference) async {
    final parsed = parseReference(reference);
    if (parsed == null) return false;

    final chapter = parsed['chapter'] as int;
    return chapter > 1;
  }

  /// Check if a next chapter exists
  static Future<bool> hasNextChapter(String reference) async {
    final parsed = parseReference(reference);
    if (parsed == null) return false;

    final bookName = parsed['bookName'] as String;
    final chapter = parsed['chapter'] as int;
    final shortName = await getBookShortName(bookName);
    
    if (shortName == null) return false;

    try {
      final books = await _readingsService.getBooks();
      final book = books.firstWhere(
        (book) => book.shortName.toLowerCase() == shortName.toLowerCase(),
      );
      return chapter < book.chapterCount;
    } catch (e) {
      return false;
    }
  }

  /// Get the previous chapter reference and content
  static Future<Map<String, String>?> getPreviousChapter(String reference) async {
    final parsed = parseReference(reference);
    if (parsed == null) return null;

    final bookName = parsed['bookName'] as String;
    final chapter = parsed['chapter'] as int;
    
    if (chapter <= 1) return null;

    final previousChapter = chapter - 1;
    final shortName = await getBookShortName(bookName);
    if (shortName == null) return null;

    try {
      final content = await _readingsService.getChapterText(
        bookShortName: shortName,
        chapter: previousChapter,
      );
      
      return {
        'reference': '$bookName $previousChapter',
        'content': content,
      };
    } catch (e) {
      return null;
    }
  }

  /// Get the next chapter reference and content
  static Future<Map<String, String>?> getNextChapter(String reference) async {
    final parsed = parseReference(reference);
    if (parsed == null) return null;

    final bookName = parsed['bookName'] as String;
    final chapter = parsed['chapter'] as int;
    final shortName = await getBookShortName(bookName);
    if (shortName == null) return null;

    try {
      final books = await _readingsService.getBooks();
      final book = books.firstWhere(
        (book) => book.shortName.toLowerCase() == shortName.toLowerCase(),
      );
      
      if (chapter >= book.chapterCount) return null;

      final nextChapter = chapter + 1;
      final content = await _readingsService.getChapterText(
        bookShortName: shortName,
        chapter: nextChapter,
      );
      
      return {
        'reference': '$bookName $nextChapter',
        'content': content,
      };
    } catch (e) {
      return null;
    }
  }
}
