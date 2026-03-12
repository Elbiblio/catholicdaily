/// Represents a book of the Bible
class Book {
  final int id;
  final String name;
  final String shortName;
  final int chapterCount;

  Book({
    required this.id,
    required this.name,
    required this.shortName,
    required this.chapterCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shortName': shortName,
      'chapterCount': chapterCount,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int,
      name: map['name'] as String,
      shortName: map['shortName'] as String,
      chapterCount: map['chapterCount'] as int? ?? 0,
    );
  }
}

/// Represents a verse in the Bible
class Verse {
  final int id;
  final int bookId;
  final int chapterId;
  final int verseId;
  final String text;

  Verse({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.verseId,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterId': chapterId,
      'verseId': verseId,
      'text': text,
    };
  }

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] as int,
      bookId: map['bookId'] as int,
      chapterId: map['chapterId'] as int,
      verseId: map['verseId'] as int,
      text: map['text'] as String,
    );
  }
}
