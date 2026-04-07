import 'hymn_rich_content.dart';

class Hymn {
  final int id;
  final String title;
  final String category;
  final List<String> lyrics;
  final String? midiFile;
  final String? audioFile;
  final String? pdfFile;
  final String? author;
  final String? composer;
  final int? hymnNumber;
  final List<String> tags;
  final String? firstLine;
  final String? oldNumber;
  final DateTime? lastAccessed;
  final int? bpm;
  final String? timeSignature;
  final String? keySignature;
  final String? tempoNotes;
  final int? yearComposed;
  final String? liturgicalSeason;
  final String? themes;
  final int? originalId;
  final int openCount;
  final bool isFavorite;
  final RichContentModel? content;
  final String? meter;
  final String? copyrightStatus;
  final Map<String, dynamic>? primaryTune;
  final List<Map<String, dynamic>>? alternateTunes;
  final List<String>? sourceAttribution;
  final String? slug;

  Hymn({
    required this.id,
    required this.title,
    required this.category,
    required this.lyrics,
    this.author,
    this.composer,
    this.hymnNumber,
    this.tags = const [],
    this.midiFile,
    this.audioFile,
    this.pdfFile,
    this.isFavorite = false,
    this.firstLine,
    this.oldNumber,
    this.lastAccessed,
    this.bpm,
    this.timeSignature,
    this.keySignature,
    this.tempoNotes,
    this.yearComposed,
    this.liturgicalSeason,
    this.themes,
    this.originalId,
    this.openCount = 0,
    this.content,
    this.meter,
    this.copyrightStatus,
    this.primaryTune,
    this.alternateTunes,
    this.sourceAttribution,
    this.slug,
  });

  List<String> get displayLyrics {
    final richContent = content;
    if (richContent != null && richContent.hasBlocks) {
      return richContent.toPlainLyrics();
    }
    return lyrics;
  }

  String get previewText {
    final previewLines = displayLyrics.where((line) => line.trim().isNotEmpty).take(3);
    return previewLines.join('\n');
  }

  Hymn copyWith({
    int? id,
    String? title,
    String? category,
    List<String>? lyrics,
    String? midiFile,
    String? audioFile,
    String? pdfFile,
    String? author,
    String? composer,
    int? hymnNumber,
    List<String>? tags,
    bool? isFavorite,
    String? firstLine,
    String? oldNumber,
    DateTime? lastAccessed,
    int? bpm,
    String? timeSignature,
    String? keySignature,
    String? tempoNotes,
    int? yearComposed,
    String? liturgicalSeason,
    String? themes,
    int? originalId,
    int? openCount,
    RichContentModel? content,
    String? meter,
    String? copyrightStatus,
    Map<String, dynamic>? primaryTune,
    List<Map<String, dynamic>>? alternateTunes,
    List<String>? sourceAttribution,
    String? slug,
  }) {
    return Hymn(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      lyrics: lyrics ?? this.lyrics,
      midiFile: midiFile ?? this.midiFile,
      audioFile: audioFile ?? this.audioFile,
      pdfFile: pdfFile ?? this.pdfFile,
      author: author ?? this.author,
      composer: composer ?? this.composer,
      hymnNumber: hymnNumber ?? this.hymnNumber,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      firstLine: firstLine ?? this.firstLine,
      oldNumber: oldNumber ?? this.oldNumber,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      keySignature: keySignature ?? this.keySignature,
      tempoNotes: tempoNotes ?? this.tempoNotes,
      yearComposed: yearComposed ?? this.yearComposed,
      liturgicalSeason: liturgicalSeason ?? this.liturgicalSeason,
      themes: themes ?? this.themes,
      originalId: originalId ?? this.originalId,
      openCount: openCount ?? this.openCount,
      content: content ?? this.content,
      meter: meter ?? this.meter,
      copyrightStatus: copyrightStatus ?? this.copyrightStatus,
      primaryTune: primaryTune ?? this.primaryTune,
      alternateTunes: alternateTunes ?? this.alternateTunes,
      sourceAttribution: sourceAttribution ?? this.sourceAttribution,
      slug: slug ?? this.slug,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'lyrics': lyrics,
      'midiFile': midiFile,
      'audioFile': audioFile,
      'pdfFile': pdfFile,
      'author': author,
      'composer': composer,
      'hymnNumber': hymnNumber,
      'tags': tags,
      'isFavorite': isFavorite,
      'firstLine': firstLine,
      'oldNumber': oldNumber,
      'lastAccessed': lastAccessed?.toIso8601String(),
      'bpm': bpm,
      'timeSignature': timeSignature,
      'keySignature': keySignature,
      'tempoNotes': tempoNotes,
      'yearComposed': yearComposed,
      'liturgicalSeason': liturgicalSeason,
      'themes': themes,
      'originalId': originalId,
      'openCount': openCount,
      'meter': meter,
      'copyrightStatus': copyrightStatus,
      'primaryTune': primaryTune,
      'alternateTunes': alternateTunes,
      'sourceAttribution': sourceAttribution,
      'slug': slug,
      'content': content == null
          ? null
          : {
              'source_format': content!.sourceFormat,
              'blocks': content!.blocks
                  .map(
                    (block) => {
                      'kind': block.kind,
                      'label': block.label,
                      'number': block.number,
                      'lines': block.lines
                          .map(
                            (line) => {
                              'text': line.text,
                              'spans': line.spans
                                  .map(
                                    (span) => {
                                      'text': span.text,
                                      'bold': span.bold,
                                      'italic': span.italic,
                                      'underline': span.underline,
                                    },
                                  )
                                  .toList(),
                            },
                          )
                          .toList(),
                    },
                  )
                  .toList(),
            },
    };
  }

  factory Hymn.fromMap(Map<String, dynamic> map) {
    final lastAcc = map['lastAccessed'] ?? map['last_accessed'];
    final richMap = map['content'];
    return Hymn(
      id: map['id']?.toInt() ?? 0,
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      lyrics: List<String>.from(map['lyrics'] ?? []),
      midiFile: map['midiFile'] ?? map['midi_file'],
      audioFile: map['audioFile'] ?? map['mp3_file'],
      pdfFile: map['pdfFile'] ?? map['pdf_file'],
      author: map['author'],
      composer: map['composer'],
      hymnNumber: (map['hymnNumber'] ?? map['hymn_number'])?.toInt(),
      tags: List<String>.from(map['tags'] ?? []),
      isFavorite: map['isFavorite'] ?? map['is_favorite'] ?? false,
      firstLine: map['firstLine'] ?? map['first_line'],
      oldNumber: map['oldNumber'] ?? map['old_number'],
      lastAccessed: lastAcc != null ? DateTime.tryParse(lastAcc.toString()) : null,
      bpm: map['bpm']?.toInt(),
      timeSignature: map['time_signature'],
      keySignature: map['key_signature'],
      tempoNotes: map['tempo_notes'],
      yearComposed: map['year_composed']?.toInt(),
      liturgicalSeason: map['liturgical_season'],
      themes: map['themes'],
      originalId: map['original_id']?.toInt(),
      openCount: (map['openCount'] ?? map['open_count'])?.toInt() ?? 0,
      content: richMap is Map ? RichContentModel.fromMap(Map<String, dynamic>.from(richMap)) : null,
      meter: map['meter'],
      copyrightStatus: map['copyright_status'],
      primaryTune: map['primary_tune'] is Map ? Map<String, dynamic>.from(map['primary_tune']) : null,
      alternateTunes: (map['alternate_tunes'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList(),
      sourceAttribution: (map['source_attribution'] as List?)?.cast<String>(),
      slug: map['slug'],
    );
  }
}
