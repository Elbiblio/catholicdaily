import '../models/bible_book.dart';
import '../models/daily_reading.dart';

abstract class ReadingsBackend {
  Future<List<DailyReading>> getReadingsForDate(DateTime date);
  Future<String> getReadingText(String reference, {String? psalmResponse});
  Future<List<Book>> getBooks();
  Future<String> getChapterText({
    required String bookShortName,
    required int chapter,
  });
  Future<void> close();
}
