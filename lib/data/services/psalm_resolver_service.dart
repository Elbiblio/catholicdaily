import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import '../models/daily_reading.dart';
import 'readings_service.dart';
import 'gospel_acclamation_service.dart';
import 'ultimate_gospel_acclamation_mapper.dart';
import 'responsorial_psalm_mapper.dart';
import 'reading_introduction_service.dart';

/// On-demand psalm response resolver that fetches from USCCB when missing
class PsalmResolverService {
  static final PsalmResolverService instance = PsalmResolverService._();
  PsalmResolverService._();

  Database? _db;
  final Map<String, String> _cache = {};
  final Set<String> _pendingFetches = {};
  final ReadingsService _readingsService = ReadingsService.instance;
  final GospelAcclamationService _gospelAcclamationService =
      GospelAcclamationService();
  final UltimateGospelAcclamationMapper _mapper = UltimateGospelAcclamationMapper.instance;
  final ResponsorialPsalmMapper _psalmMapper = ResponsorialPsalmMapper.instance;
  final ReadingIntroductionService _introductionService = ReadingIntroductionService();
  final Map<String, bool> _columnSupportCache = {};
  bool _referenceMigrationDone = false;

  Future<Database> get _database async {
    _db ??= await _openAssetDatabase('readings.db');
    return _db!;
  }

  Future<Database> _openAssetDatabase(String assetPath) async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, assetPath);
    } else {
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, assetPath);
    }
    
    // Check if the database exists
    final exists = await databaseExists(path);
    
    if (!exists) {
      // Copy from assets
      final data = await rootBundle.load('assets/$assetPath');
      final bytes = data.buffer.asUint8List();
      await File(path).writeAsBytes(bytes);
    }
    
    return await openDatabase(path);
  }

  /// Open a writable handle to the same asset DB path (for migrations/updates only)
  Future<Database> _openWritableDatabase(String assetPath) async {
    String path;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, assetPath);
    } else {
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, assetPath);
    }
    return openDatabase(path, readOnly: false);
  }

  /// Ensure reference columns exist and backfill them for existing rows.
  /// DISABLED: We now decode psalm responses at read time in ReadingsBackendIo
  Future<void> _ensureReferenceColumnsAndBackfill() async {
    _referenceMigrationDone = true;
    return;
  }

  Future<bool> _supportsColumn(Database db, String column) async {
    if (_columnSupportCache.containsKey(column)) {
      return _columnSupportCache[column]!;
    }
    final rows = await db.rawQuery('PRAGMA table_info(readings)');
    final hasColumn = rows.any((row) => row['name'] == column);
    _columnSupportCache[column] = hasColumn;
    return hasColumn;
  }

  /// Resolve psalm response for a given date and psalm reference
  /// Returns cached value if available, otherwise fetches from USCCB
  Future<String?> resolvePsalmResponse({
    required DateTime date,
    required String psalmReference,
    String? positionLabel,
  }) async {
    final cacheKey = '${date.toIso8601String().split('T')[0]}|psalm|$psalmReference';
    
    // Check memory cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Check database
    final db = await _database;
    final timestamp = DateTime.utc(date.year, date.month, date.day, 8, 0, 0)
        .millisecondsSinceEpoch ~/
        1000;

    final hasPsalmResponse = await _supportsColumn(db, 'psalm_response');
    final hasPsalmResponseRef = await _supportsColumn(db, 'psalm_response_ref');
    if (hasPsalmResponseRef) {
      final refRows = await db.rawQuery(
        'SELECT psalm_response_ref FROM readings WHERE timestamp = ? AND reading = ? ORDER BY position LIMIT 1',
        [timestamp, psalmReference],
      );
      if (refRows.isNotEmpty && refRows.first['psalm_response_ref'] != null) {
        final ref = refRows.first['psalm_response_ref'] as String;
        if (ref.trim().isNotEmpty) {
          // Decode reference to full refrain text
          final text = await _decodeAcclamationVerse(ref);
          if (text != null && text.trim().isNotEmpty) {
            _cache[cacheKey] = text;
            return text;
          }
        }
      }
    }
    if (hasPsalmResponse) {
      final rows = await db.rawQuery(
        'SELECT psalm_response FROM readings WHERE timestamp = ? AND reading = ? ORDER BY position LIMIT 1',
        [timestamp, psalmReference],
      );

      if (rows.isNotEmpty && rows.first['psalm_response'] != null) {
        final response = rows.first['psalm_response'] as String;
        if (response.trim().isNotEmpty) {
          _cache[cacheKey] = response;
          return response;
        }
      }
    }

    final offlineFallback = _resolvePsalmResponseOffline(
      date: date,
      psalmReference: psalmReference,
      positionLabel: positionLabel,
    );
    if (offlineFallback != null && offlineFallback.trim().isNotEmpty) {
      _cache[cacheKey] = offlineFallback;
      return offlineFallback;
    }

    // Fetch from USCCB if not in database and not already pending
    if (!_pendingFetches.contains(cacheKey)) {
      _pendingFetches.add(cacheKey);
      _fetchAndUpdatePsalmResponse(date, psalmReference, timestamp, cacheKey);
    }

    return null;
  }

  Future<List<DailyReading>> enrichReadingsForDisplay({
    required DateTime date,
    required List<DailyReading> readings,
  }) async {
    // One-time migration to ensure reference columns exist and are backfilled
    await _ensureReferenceColumnsAndBackfill();
    final enriched = <DailyReading>[];

    for (final reading in readings) {
      final position = (reading.position ?? '').toLowerCase();
      String? psalmResponse = reading.psalmResponse;
      String? gospelAcclamation = reading.gospelAcclamation;

      if (position.contains('psalm') && (psalmResponse == null || psalmResponse.trim().isEmpty)) {
        psalmResponse = await resolvePsalmResponse(
          date: date,
          psalmReference: reading.reading,
          positionLabel: reading.position,
        );
      }

      if (position.contains('gospel') && (gospelAcclamation == null || gospelAcclamation.trim().isEmpty)) {
        gospelAcclamation = await resolveGospelAcclamation(
          date: date,
          gospelReference: reading.reading,
          positionLabel: reading.position,
        );
      } else if (position.contains('gospel') && gospelAcclamation != null) {
        final trimmedAcclamation = gospelAcclamation.trim();
        if (trimmedAcclamation.startsWith('Reading text unavailable')) {
          gospelAcclamation = await resolveGospelAcclamation(
            date: date,
            gospelReference: reading.reading,
            positionLabel: reading.position,
          );
        } else if (_gospelAcclamationService.shouldResolveReference(
          trimmedAcclamation,
        )) {
          gospelAcclamation = await resolveGospelAcclamation(
                date: date,
                gospelReference: reading.reading,
                positionLabel: reading.position,
              ) ??
              await _gospelAcclamationService.getAcclamationText(
                trimmedAcclamation,
              );
        }
      }

      enriched.add(
        reading.copyWith(
          psalmResponse: psalmResponse,
          gospelAcclamation: gospelAcclamation,
        ),
      );
    }

    return enriched;
  }

  String? _resolvePsalmResponseOffline({
    required DateTime date,
    required String psalmReference,
    String? positionLabel,
  }) {
    // Use the responsorial psalm mapper for accurate offline coverage
    return _psalmMapper.getPsalmResponse(
      date: date,
      psalmReference: psalmReference,
    );
  }

  /// Background fetch from USCCB and cache in memory only
  Future<void> _fetchAndUpdatePsalmResponse(
    DateTime date,
    String psalmReference,
    int timestamp,
    String cacheKey,
  ) async {
    try {
      final response = await _fetchFromUSCCB(date);
      if (response != null && response.isNotEmpty) {
        // Update cache only (not database)
        _cache[cacheKey] = response;
        
        debugPrint('✓ Fetched psalm response for $date: ${response.substring(0, response.length > 50 ? 50 : response.length)}...');
      }
    } catch (e) {
      debugPrint('Error fetching psalm response for $date: $e');
    } finally {
      _pendingFetches.remove(cacheKey);
    }
  }

  /// Fetch psalm response from USCCB daily readings page
  Future<String?> _fetchFromUSCCB(DateTime date) async {
    try {
      final url = 'https://bible.usccb.org/bible/readings/${_formatDate(date)}.cfm';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; CatholicDailyApp/1.0)',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return null;
      }

      return _extractPsalmResponse(response.body);
    } catch (e) {
      debugPrint('USCCB fetch error: $e');
      return null;
    }
  }

  /// Extract psalm response from USCCB HTML
  String? _extractPsalmResponse(String html) {
    // Look for "Responsorial Psalm" section
    final psalmMatch = RegExp(
      r'Responsorial Psalm.*?(?=Reading II|Gospel|Alleluia|Verse before the Gospel|$)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (psalmMatch == null) return null;

    final psalmSection = psalmMatch.group(0) ?? '';

    // Extract response patterns: R. (...) text or R. text
    final patterns = [
      RegExp(r'R\.\s*\([^)]*\)\s*(.+?)(?=<|R\.|$)', caseSensitive: false),
      RegExp(r'R\.\s*(.+?)(?=<|R\.|$)', caseSensitive: false),
      RegExp(r'Resp?\.\s*(.+?)(?=<|$)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(psalmSection);
      if (match != null) {
        final response = _cleanHtml(match.group(1) ?? '');
        if (response.isNotEmpty && response.length > 5) {
          return response;
        }
      }
    }

    return null;
  }

  /// Clean HTML tags and entities from text
  String _cleanHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // Remove trailing punctuation
    text = text.replaceAll(RegExp(r'[;:,]+$'), '');
    
    return text;
  }

  /// Format date for USCCB URL (MMDDYY)
  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString().substring(2);
    return '$month$day$year';
  }

  /// Resolve gospel acclamation for a given date
  /// Uses mapping algorithm for 100% offline coverage
  Future<String?> resolveGospelAcclamation({
    required DateTime date,
    required String gospelReference,
    String? positionLabel,
  }) async {
    final cacheKey = '${date.toIso8601String().split('T')[0]}|acclamation|$gospelReference';
    
    // Check memory cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // Use mapping algorithm for reliable offline coverage
    final mappedAcclamation = _mapper.getAcclamation(
      date: date,
      gospelReference: gospelReference,
    );

    // Extract the text from UltimateAcclamationResult
    final completeAcclamation = await _decodeIfVerseReference(mappedAcclamation.text, date);
    
    _cache[cacheKey] = completeAcclamation;
    return completeAcclamation;
  
    // Fallback: generate seasonal intro
    final seasonalIntro = _generateSeasonalIntro(date);
    if (seasonalIntro != null) {
      _cache[cacheKey] = seasonalIntro;
      return seasonalIntro;
    }

    return null;
  }

  /// Decode verse reference if needed, otherwise return as-is
  Future<String> _decodeIfVerseReference(String acclamation, DateTime date) async {
    // Check if this is just a verse reference (short length, contains book:verse pattern)
    if (acclamation.length < 50 && RegExp(r'^[A-Za-z]+\s+\d+:\d+', caseSensitive: false).hasMatch(acclamation)) {
      try {
        // Try to decode the verse reference
        final verseText = await _decodeAcclamationVerse(acclamation);
        if (verseText != null) {
          // Format with seasonal intro
          return _formatCompleteAcclamation(date, verseText);
        }
      } catch (e) {
        debugPrint('Error decoding verse reference $acclamation: $e');
      }
    }
    
    // Check if it has "See" or "Cf." prefix
    if (acclamation.startsWith('See ') || acclamation.startsWith('Cf.') || acclamation.startsWith('cf.')) {
      try {
        final cleanReference = _cleanVerseReference(acclamation);
        final verseText = await _decodeAcclamationVerse(cleanReference);
        if (verseText != null) {
          return _formatCompleteAcclamation(date, verseText);
        }
      } catch (e) {
        debugPrint('Error decoding prefixed reference $acclamation: $e');
      }
    }
    
    // Return as-is if it's full text or decoding failed
    return acclamation;
  }

  /// Decode verse reference using the existing readings service
  Future<String?> _decodeAcclamationVerse(String verseReference) async {
    try {
      // Clean up the verse reference (remove "See", "Cf.", etc.)
      final cleanReference = _cleanVerseReference(verseReference);

      // Handle discrete verse lists like 'Ps 43:2+6' or 'Ps 43:2,6'
      final m = RegExp(r'^\s*([A-Za-z ]+\d+)\s*:(.+)\s*$').firstMatch(cleanReference);
      if (m != null) {
        final base = m.group(1)!; // e.g., 'Ps 43'
        final versesPart = m.group(2)!; // e.g., '2,6'
        // If it is a list of discrete verses (no ranges), split and fetch each
        if (versesPart.contains(',')) {
          final parts = versesPart.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final texts = <String>[];
          for (final v in parts) {
            // If any token still contains a dash (range), pass through directly once
            final ref = v.contains('-') ? '$base:$v' : '$base:$v';
            final t = await _readingsService.getReadingText(ref);
            if (t.isNotEmpty) {
              texts.add(_stripVerseNumbers(t));
            }
          }
          if (texts.isNotEmpty) {
            return texts.join(' ').trim();
          }
        }
      }

      // Use the existing readings service to get the text for the whole reference
      final verseText = await _readingsService.getReadingText(cleanReference);
      if (verseText.trim().isEmpty ||
          verseText.startsWith('Reading text unavailable')) {
        return null;
      }
      
      // Extract just the verse text (remove verse numbers)
      final cleaned = _stripVerseNumbers(verseText);
      if (cleaned.isNotEmpty &&
          !cleaned.startsWith('Reading text unavailable')) {
        return cleaned;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error decoding verse reference $verseReference: $e');
      return null;
    }
  }

  /// Clean verse reference by removing prefixes like "See", "Cf.", etc.
  String _cleanVerseReference(String reference) {
    // Normalize: remove See/Cf., convert '+' to ',' for discrete lists, collapse spaces
    var r = reference
        .replaceAll(RegExp(r'^(See|Cf\.?)\s+', caseSensitive: false), '')
        .replaceAll('+', ',')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Normalize book casing for Psalms (optional)
    r = r.replaceAll(RegExp(r'^PS(\s|$)', caseSensitive: false), 'Ps ');
    return r;
  }

  /// Helper to remove verse numbers from a multi-line scripture block
  String _stripVerseNumbers(String text) {
    final lines = text.split('\n');
    final cleanedLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !RegExp(r'^\d+\.').hasMatch(line))
        .toList();
    return cleanedLines.join(' ').trim();
  }

  /// Generate seasonal intro response (not the full acclamation)
  String? _generateSeasonalIntro(DateTime date) {
    // Check if date is during Lent (excluding Sundays)
    if (_isDuringLent(date) && !_isSunday(date)) {
      return 'Glory and praise to you, Lord Jesus Christ.';
    }
    
    // Outside Lent, use Alleluia
    return 'Alleluia.';
  }

  /// Check if date is during Lent (Ash Wednesday to Holy Saturday)
  bool _isDuringLent(DateTime date) {
    final year = date.year;
    
    // Calculate Easter Sunday for the given year
    final easter = _calculateEaster(year);
    
    // Ash Wednesday is 46 days before Easter Sunday
    final ashWednesday = easter.subtract(const Duration(days: 46));
    
    // Holy Saturday is the day before Easter Sunday
    final holySaturday = easter.subtract(const Duration(days: 1));
    
    // Check if date is within Lent period
    return (date.isAtSameMomentAs(ashWednesday) || date.isAfter(ashWednesday)) &&
           (date.isAtSameMomentAs(holySaturday) || date.isBefore(holySaturday));
  }

  /// Check if date is a Sunday
  bool _isSunday(DateTime date) {
    return date.weekday == DateTime.sunday;
  }

  /// Calculate Easter Sunday using computus algorithm
  DateTime _calculateEaster(int year) {
    // Anonymous Gregorian algorithm
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    
    return DateTime(year, month, day);
  }

  /// Format complete acclamation with seasonal intro
  String _formatCompleteAcclamation(DateTime date, String acclamationText) {
    final intro = _generateSeasonalIntro(date) ?? 'Alleluia.';
    return '$intro $acclamationText';
  }

  /// Prefetch psalm responses and gospel acclamations for upcoming days
  Future<void> prefetchUpcoming({int days = 7}) async {
    final today = DateTime.now();
    for (var i = 0; i < days; i++) {
      final date = today.add(Duration(days: i));
      final db = await _database;
      final timestamp = DateTime.utc(date.year, date.month, date.day, 8, 0, 0)
          .millisecondsSinceEpoch ~/
          1000;

      // Check psalm response
      final psalmRows = await db.rawQuery(
        '''
        SELECT reading, psalm_response 
        FROM readings 
        WHERE timestamp = ? AND position = 2
        ''',
        [timestamp],
      );

      if (psalmRows.isNotEmpty) {
        final psalmResponse = psalmRows.first['psalm_response'] as String?;
        final psalmRef = psalmRows.first['reading'] as String;
        
        if (psalmResponse == null || psalmResponse.trim().isEmpty) {
          // Fetch in background
          resolvePsalmResponse(date: date, psalmReference: psalmRef);
        }
      }

      // Check gospel acclamation
      final gospelRows = await db.rawQuery(
        '''
        SELECT reading, gospel_acclamation 
        FROM readings 
        WHERE timestamp = ? AND position = 4
        ''',
        [timestamp],
      );

      if (gospelRows.isNotEmpty) {
        final acclamation = gospelRows.first['gospel_acclamation'] as String?;
        final gospelRef = gospelRows.first['reading'] as String;
        
        if (acclamation == null || acclamation.trim().isEmpty) {
          // Generate or fetch in background
          resolveGospelAcclamation(date: date, gospelReference: gospelRef);
        }
      }
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    _cache.clear();
    _pendingFetches.clear();
  }
}
