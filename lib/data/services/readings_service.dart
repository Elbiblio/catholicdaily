import 'package:flutter/foundation.dart';
import '../models/bible_book.dart';
import '../models/daily_reading.dart';
import '../models/resolved_responsorial_psalm.dart';
import 'base_service.dart';
import 'readings_backend.dart';
import 'readings_backend_io.dart'
    if (dart.library.html) 'readings_backend_web.dart'
    as backend_factory;
import 'responsorial_psalm_text_catalog_service.dart';
import 'bible_version_preference.dart';
import 'responsorial_psalm_edition_registry.dart';
import 'responsorial_psalm_fallback_service.dart';
import 'responsorial_psalm_preference.dart';
import 'responsorial_psalm_source_pack_service.dart';

/// Canonical service for readings + Bible text across all supported platforms.
class ReadingsService extends BaseService<ReadingsService> {
  static ReadingsService get instance =>
      BaseService.init(() => ReadingsService._());

  /// Factory constructor for backward compatibility
  factory ReadingsService() => instance;

  ReadingsService._();

  final ReadingsBackend _backend = backend_factory.createReadingsBackend();
  final ResponsorialPsalmTextCatalogService _psalmTexts =
      ResponsorialPsalmTextCatalogService.instance;
  Future<ResponsorialPsalmFallbackService>? _psalmFallback;

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
    String? readingType,
    DateTime? date,
    String? territory,
    String celebrationId = '',
    String readingSetKind = '',
    String lectionaryNumber = '',
  }) async {
    try {
      final isResponsorial = (readingType ?? '').toLowerCase().contains(
        'responsorial psalm',
      );
      if (isResponsorial && date != null && territory != null) {
        final resolved = await resolveResponsorialPsalm(
          reference,
          psalmResponse: psalmResponse ?? '',
          date: date,
          territory: territory,
          celebrationId: celebrationId,
          readingSetKind: readingSetKind,
          lectionaryNumber: lectionaryNumber,
        );
        return resolved.text;
      }
      return await _backend.getReadingText(
        reference,
        psalmResponse: psalmResponse,
        incipit: incipit,
        readingType: readingType,
      );
    } catch (e) {
      debugPrint('Error getting reading text: $e');
      return 'Reading text unavailable for $reference.';
    }
  }

  Future<ResolvedResponsorialPsalm> resolveResponsorialPsalm(
    String reference, {
    required String psalmResponse,
    required DateTime date,
    required String territory,
    String celebrationId = '',
    String readingSetKind = '',
    String lectionaryNumber = '',
    String sundayCycle = '',
    String weekdayCycle = '',
  }) async {
    final psalmPreference = await ResponsorialPsalmPreference.getInstance();
    final requestedEditionId = psalmPreference.currentEditionId;

    if (requestedEditionId == ResponsorialPsalmPreference.defaultEditionId) {
      final reviewed = await _psalmTexts.lookup(
        date: date,
        territory: territory,
        reference: reference,
        response: psalmResponse,
        celebrationId: celebrationId,
        readingSetKind: readingSetKind,
        lectionaryNumber: lectionaryNumber,
      );
      if (reviewed != null) {
        return ResolvedResponsorialPsalm(
          text: reviewed.formattedText,
          responseText: reviewed.responseText,
          requestedEditionId: requestedEditionId,
          actualEditionId: reviewed.sourceId,
          actualEditionName: reviewed.sourceEdition,
          referenceNormalized: reviewed.referenceNormalized,
          fallbackReason: PsalmFallbackReason.none,
          sourceUrl: reviewed.sourceUrl,
        );
      }
    }

    final biblePreference = await BibleVersionPreference.getInstance();
    final resolver = await (_psalmFallback ??= _createPsalmFallback());
    return resolver.resolve(
      request: ResponsorialPsalmRequest(
        selectedEditionId: requestedEditionId,
        reference: reference,
        responseText: psalmResponse,
        date: date,
        territory: territory,
        celebrationId: celebrationId,
        readingSetKind: readingSetKind,
        lectionaryNumber: lectionaryNumber,
        sundayCycle: sundayCycle,
        weekdayCycle: weekdayCycle,
      ),
      territoryEditionId: _territoryEdition(territory),
      bibleEditionId: _bibleEdition(biblePreference.currentDbName),
    );
  }

  Future<ResponsorialPsalmFallbackService> _createPsalmFallback() async {
    final registry = await ResponsorialPsalmEditionRegistry.load();
    return ResponsorialPsalmFallbackService(
      registry: registry,
      packs: ResponsorialPsalmSourcePackService(registry: registry),
    );
  }

  static String _territoryEdition(String territory) {
    final normalized = territory.trim().toUpperCase();
    if (normalized.startsWith('NG')) return 'nigeria_365_firestore';
    if (normalized.startsWith('US')) return 'modern_psalter_us';
    return '';
  }

  static String _bibleEdition(String bibleId) {
    return switch (bibleId) {
      'nabre' => 'local_nabre',
      'douay_rheims' => 'douay_rheims',
      _ => 'local_rsvce',
    };
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
