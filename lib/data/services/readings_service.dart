import 'package:flutter/foundation.dart';
import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import 'base_service.dart';
import 'readings_backend.dart';
import 'readings_backend_io.dart'
    if (dart.library.html) 'readings_backend_web.dart'
    as backend_factory;

/// Canonical service for readings + Bible text across all supported platforms.
class ReadingsService extends BaseService<ReadingsService> {
  static ReadingsService get instance => BaseService.init(() => ReadingsService._());
  
  /// Factory constructor for backward compatibility
  factory ReadingsService() => instance;
  
  ReadingsService._();

  final ReadingsBackend _backend = backend_factory.createReadingsBackend();

  Future<List<DailyReading>> getReadingsForDate(DateTime date) async {
    try {
      return await _backend.getReadingsForDate(date);
    } catch (e) {
      debugPrint('Error getting readings: $e');
      return [];
    }
  }

  Future<String> getReadingText(
    String reference, {
    String? psalmResponse,
    String? incipit,
  }) async {
    try {
      return await _backend.getReadingText(
        reference,
        psalmResponse: psalmResponse,
        incipit: incipit,
      );
    } catch (e) {
      debugPrint('Error getting reading text: $e');
      return 'Reading text unavailable for $reference.';
    }
  }

  Future<List<Book>> getBooks() async {
    try {
      return await _backend.getBooks();
    } catch (e) {
      debugPrint('Error loading books: $e');
      return [];
    }
  }

  Future<String> getChapterText({
    required String bookShortName,
    required int chapter,
  }) async {
    try {
      return await _backend.getChapterText(
        bookShortName: bookShortName,
        chapter: chapter,
      );
    } catch (e) {
      debugPrint('Error getting chapter text: $e');
      return 'Chapter text unavailable for $bookShortName $chapter.';
    }
  }

  Future<void> close() async {
    try {
      await _backend.close();
    } catch (e) {
      debugPrint('Error closing readings backend: $e');
    }
  }

  Future<void> reloadForVersionChange() async {
    try {
      await _backend.reloadForVersionChange();
    } catch (e) {
      debugPrint('Error reloading for version change: $e');
    }
  }
}
