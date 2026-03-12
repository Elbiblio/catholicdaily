/// Represents a Bible version that can be downloaded
class BibleVersion {
  final String id;
  final String name;
  final String abbreviation;
  final String? downloadUrl;
  final bool isDownloaded;
  final int size;

  BibleVersion({
    required this.id,
    required this.name,
    required this.abbreviation,
    this.downloadUrl,
    this.isDownloaded = false,
    this.size = 0,
  });

  BibleVersion copyWith({
    String? id,
    String? name,
    String? abbreviation,
    String? downloadUrl,
    bool? isDownloaded,
    int? size,
  }) {
    return BibleVersion(
      id: id ?? this.id,
      name: name ?? this.name,
      abbreviation: abbreviation ?? this.abbreviation,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'downloadUrl': downloadUrl,
      'isDownloaded': isDownloaded,
      'size': size,
    };
  }

  factory BibleVersion.fromMap(Map<String, dynamic> map) {
    return BibleVersion(
      id: map['id'] as String,
      name: map['name'] as String,
      abbreviation: map['abbreviation'] as String,
      downloadUrl: map['downloadUrl'] as String?,
      isDownloaded: map['isDownloaded'] as bool? ?? false,
      size: map['size'] as int? ?? 0,
    );
  }
}
