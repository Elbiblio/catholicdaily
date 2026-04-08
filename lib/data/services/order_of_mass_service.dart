import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/daily_reading.dart';
import '../models/order_of_mass_item.dart';
import 'improved_liturgical_calendar_service.dart';
import 'ordo_resolver_service.dart';
import 'prebuilt_prayer_service.dart';
import 'missal_rites_service.dart';
import 'divinum_officium_loader_service.dart';
import 'prayer_of_the_faithful_service.dart';

class ResolvedOrderOfMassItem {
  final String id;
  final String title;
  final String insertionPoint;
  final int order;
  final Map<String, List<String>> contentByLanguage;
  final Map<String, List<Map<String, String>>>? dialogueStructure;
  final List<String> availableLanguages;
  final bool isOptional;
  final String? type;
  final String? source;
  final String? sourceField;
  final String? role;
  final bool isDialogue;
  final bool isResponsive;
  final String? alternativeGroup;

  const ResolvedOrderOfMassItem({
    required this.id,
    required this.title,
    required this.insertionPoint,
    required this.order,
    required this.contentByLanguage,
    this.dialogueStructure,
    required this.availableLanguages,
    required this.isOptional,
    this.type,
    this.source,
    this.sourceField,
    this.role,
    this.isDialogue = false,
    this.isResponsive = false,
    this.alternativeGroup,
  });

  List<String>? getContentForLanguage(String languageCode) {
    final content = contentByLanguage[languageCode];
    if (content == null) return null;
    return content.map(_decodeHtmlEntities).toList();
  }

  /// Decode HTML entities in text (e.g., &#230; -> æ, &#233; -> é)
  static String _decodeHtmlEntities(String text) {
    String decoded = text;

    // Decode named HTML entities
    decoded = decoded.replaceAll('&aelig;', 'æ');
    decoded = decoded.replaceAll('&AElig;', 'Æ');
    decoded = decoded.replaceAll('&oelig;', 'œ');
    decoded = decoded.replaceAll('&OElig;', 'Œ');
    decoded = decoded.replaceAll('&rsquo;', '\u2019');
    decoded = decoded.replaceAll('&lsquo;', '\u2018');
    decoded = decoded.replaceAll('&rdquo;', '\u201D');
    decoded = decoded.replaceAll('&ldquo;', '\u201C');
    decoded = decoded.replaceAll('&mdash;', '\u2014');
    decoded = decoded.replaceAll('&ndash;', '\u2013');
    decoded = decoded.replaceAll('&hellip;', '\u2026');
    decoded = decoded.replaceAll('&nbsp;', '\u00A0');
    decoded = decoded.replaceAll('&amp;', '&');
    decoded = decoded.replaceAll('&lt;', '<');
    decoded = decoded.replaceAll('&gt;', '>');
    decoded = decoded.replaceAll('&quot;', '"');
    decoded = decoded.replaceAll('&apos;', "'");

    // Decode numeric HTML entities (e.g., &#230; &#x00E6;)
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#x([0-9A-Fa-f]+);'),
      (m) {
        final codePoint = int.tryParse(m.group(1)!, radix: 16);
        return codePoint != null ? String.fromCharCode(codePoint) : m.group(0)!;
      },
    );
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        final codePoint = int.tryParse(m.group(1)!);
        return codePoint != null ? String.fromCharCode(codePoint) : m.group(0)!;
      },
    );

    return decoded;
  }

  bool hasLanguage(String languageCode) {
    return availableLanguages.contains(languageCode) &&
        (contentByLanguage[languageCode]?.isNotEmpty ?? false);
  }
}

class ResolvedOrderOfMassSection {
  final String insertionPoint;
  final String title;
  final List<ResolvedOrderOfMassItem> items;

  const ResolvedOrderOfMassSection({
    required this.insertionPoint,
    required this.title,
    required this.items,
  });
}

class OrderOfMassService {
  static final OrderOfMassService _instance = OrderOfMassService._internal();
  factory OrderOfMassService() => _instance;
  OrderOfMassService._internal();

  final PrebuiltPrayerService _prayerService = PrebuiltPrayerService.instance;
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  final MissalRitesService _missalRitesService = MissalRitesService.instance;
  final DivinumOfficiumLoaderService _divinumOfficiumLoader = DivinumOfficiumLoaderService();
  final PrayerOfTheFaithfulService _prayerOfTheFaithfulService = PrayerOfTheFaithfulService.instance;

  List<OrderOfMassItem>? _cachedConfig;

  Future<List<ResolvedOrderOfMassSection>> getSectionsForDate(
    DateTime date, {
    String languageCode = 'en',
    List<DailyReading>? lectionaryReadings,
  }) async {
        final config = await _loadConfig();
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    final dateStr = date.toIso8601String().split('T').first;

    final resolvedItems = <ResolvedOrderOfMassItem>[];
    for (final item in config) {
      if (_matchesAnyCondition(item.conditions, liturgicalDay)) {
        // Skip readings-based variable items (scripture text lives in the lectionary flow).
        // Keep items that also ship inline liturgical text (e.g. Gospel dialogue before the reading).
        if (item.type == 'variable' && item.source == 'readings') {
          if (item.hasInlineContent) {
            final inline = _resolveInlineItem(item);
            resolvedItems.add(inline);
          }
          continue;
        }

        final resolved = await _resolveItem(item, dateStr, languageCode);
        if (resolved != null) {
          resolvedItems.add(resolved);
        }
      }
    }

    resolvedItems.sort((a, b) {
      final insertionComparison = a.insertionPoint.compareTo(b.insertionPoint);
      if (insertionComparison != 0) {
        return insertionComparison;
      }
      return a.order.compareTo(b.order);
    });

    final grouped = <String, List<ResolvedOrderOfMassItem>>{};
    for (final item in resolvedItems) {
      grouped.putIfAbsent(item.insertionPoint, () => <ResolvedOrderOfMassItem>[]).add(item);
    }

    final orderedInsertionPoints = const [
      'introductory_rites',
      'before_first_reading',
      'between_readings',
      'before_gospel',
      'after_gospel',
      'offertory',
      'preface',
      'sanctus',
      'acclamation',
      'lords_prayer',
      'sign_of_peace',
      'fraction',
      'communion',
      'after_communion',
      'concluding_rites',
    ];

    final sections = orderedInsertionPoints
        .where(grouped.containsKey)
        .map(
          (insertionPoint) => ResolvedOrderOfMassSection(
            insertionPoint: insertionPoint,
            title: _sectionTitleFor(insertionPoint),
            items: grouped[insertionPoint]!,
          ),
        )
        .toList();

    return _substituteGospelDialoguePlaceholders(sections, lectionaryReadings);
  }

  List<ResolvedOrderOfMassSection> _substituteGospelDialoguePlaceholders(
    List<ResolvedOrderOfMassSection> sections,
    List<DailyReading>? readings,
  ) {
    if (readings == null || readings.isEmpty) return sections;
    final evangelist = _evangelistNameFromReadings(readings);
    if (evangelist == null) return sections;

    return sections.map((section) {
      if (section.insertionPoint != 'before_gospel') return section;
      final newItems = section.items.map((item) {
        if (item.id != 'gospel') return item;
        return _withGospelDialogueSubstituted(item, evangelist);
      }).toList();
      return ResolvedOrderOfMassSection(
        insertionPoint: section.insertionPoint,
        title: section.title,
        items: newItems,
      );
    }).toList();
  }

  static String? _evangelistNameFromReadings(List<DailyReading> readings) {
    for (final r in readings) {
      final p = r.position?.toLowerCase() ?? '';
      if (p.contains('gospel')) {
        return _evangelistFromReference(r.reading);
      }
    }
    for (final r in readings) {
      final ref = r.reading.trim().toLowerCase();
      if (ref.startsWith('matt ') ||
          ref.startsWith('mark ') ||
          ref.startsWith('luke ') ||
          ref.startsWith('john ')) {
        return _evangelistFromReference(r.reading);
      }
    }
    return null;
  }

  static String? _evangelistFromReference(String reference) {
    final book = reference.trim().split(RegExp(r'\s+')).first.toLowerCase();
    switch (book) {
      case 'matt':
        return 'Matthew';
      case 'mark':
        return 'Mark';
      case 'luke':
        return 'Luke';
      case 'john':
        return 'John';
      default:
        return null;
    }
  }

  ResolvedOrderOfMassItem _withGospelDialogueSubstituted(
    ResolvedOrderOfMassItem item,
    String evangelist,
  ) {
    final nextContent = <String, List<String>>{};
    for (final e in item.contentByLanguage.entries) {
      nextContent[e.key] =
          e.value.map((line) => line.replaceAll('[N]', evangelist)).toList();
    }
    return ResolvedOrderOfMassItem(
      id: item.id,
      title: item.title,
      insertionPoint: item.insertionPoint,
      order: item.order,
      contentByLanguage: nextContent,
      dialogueStructure: item.dialogueStructure,
      availableLanguages: List<String>.from(item.availableLanguages),
      isOptional: item.isOptional,
      type: item.type,
      source: item.source,
      sourceField: item.sourceField,
      role: item.role,
      isDialogue: item.isDialogue,
      isResponsive: item.isResponsive,
      alternativeGroup: item.alternativeGroup,
    );
  }

  Future<List<OrderOfMassItem>> _loadConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    final raw = await rootBundle.loadString('assets/data/order_of_mass.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      _cachedConfig = <OrderOfMassItem>[];
      return _cachedConfig!;
    }

    _cachedConfig = decoded
        .whereType<Map>()
        .map((item) => OrderOfMassItem.fromMap(item.map((k, v) => MapEntry('$k', v))))
        .where((item) => item.id.isNotEmpty)
        .toList();
    return _cachedConfig!;
  }

  Future<ResolvedOrderOfMassItem?> _resolveItem(
    OrderOfMassItem item,
    String dateStr,
    String languageCode,
  ) async {
    // Handle variable items - fetch from appropriate service
    if (item.type == 'variable') {
      String? content;
      
      // Check PrayerOfTheFaithfulService for prayers_of_the_faithful
      if (item.sourceField == 'prayers_of_the_faithful') {
        final date = DateTime.parse(dateStr);
        content = await _prayerOfTheFaithfulService.getPrayerOfTheFaithful(date, languageCode);
      }
      // Check DivinumOfficiumLoaderService for supported rite types
      else if (item.sourceField != null) {
        final divinumRiteTypes = ['collect', 'prayer_over_offerings', 'communion_antiphon', 'prayer_after_communion'];
        if (divinumRiteTypes.contains(item.sourceField)) {
          final date = DateTime.parse(dateStr);
          content = await _divinumOfficiumLoader.getRite(date, item.sourceField!, languageCode);
        }
      }
      
      // Fall back to MissalRitesService if other services don't have it
      if (content == null && item.sourceField != null) {
        content = await _missalRitesService.getRite(
          dateStr,
          languageCode,
          item.sourceField!,
        );
      }

      // If no content found, return null to hide this item
      if (content == null || content.isEmpty) {
        return null;
      }

      final contentByLanguage = <String, List<String>>{};
      contentByLanguage[languageCode] = content.split('\n');

      return ResolvedOrderOfMassItem(
        id: item.id,
        title: item.title,
        insertionPoint: item.insertionPoint,
        order: item.order,
        contentByLanguage: contentByLanguage,
        availableLanguages: item.availableLanguages,
        isOptional: item.isOptional,
        type: item.type,
        source: item.source,
        sourceField: item.sourceField,
        role: item.role,
        isDialogue: item.isDialogue,
        isResponsive: item.isResponsive,
        alternativeGroup: item.alternativeGroup,
      );
    }

    if (item.prayerSlug != null && item.prayerSlug!.trim().isNotEmpty) {
      // Handle prayers of faithful using date-based lookup
      if (item.prayerSlug!.contains('prayers_of_faithful')) {
        final prayer = await _prayerService.getPrayer(dateStr, languageCode);
        if (prayer == null) {
          return item.hasInlineContent ? _resolveInlineItem(item) : null;
        }
        return _resolvePrayerOfFaithfulItem(item, prayer, languageCode);
      }
      return item.hasInlineContent ? _resolveInlineItem(item) : null;
    }

    if (item.hasInlineContent) {
      return _resolveInlineItem(item);
    }

    return null;
  }

  ResolvedOrderOfMassItem _resolvePrayerOfFaithfulItem(OrderOfMassItem item, String prayerContent, String languageCode) {
    return ResolvedOrderOfMassItem(
      id: item.id,
      title: item.title,
      insertionPoint: item.insertionPoint,
      order: item.order,
      contentByLanguage: {languageCode: [prayerContent]},
      availableLanguages: [languageCode],
      isOptional: false,
      type: item.type,
      source: item.source,
      sourceField: item.sourceField,
      role: item.role,
      isDialogue: item.isDialogue,
      isResponsive: item.isResponsive,
      alternativeGroup: item.alternativeGroup,
    );
  }

  
  ResolvedOrderOfMassItem _resolveInlineItem(OrderOfMassItem item) {
    final parsedContent = <String, List<String>>{};
    final availableLanguages = <String>[];
    for (final entry in item.contentByLanguage!.entries) {
      final cleaned = entry.value.where((line) => line.trim().isNotEmpty).toList();
      if (cleaned.isEmpty) {
        continue;
      }
      parsedContent[entry.key] = cleaned;
      availableLanguages.add(entry.key);
    }

    return ResolvedOrderOfMassItem(
      id: item.id,
      title: item.title,
      insertionPoint: item.insertionPoint,
      order: item.order,
      contentByLanguage: parsedContent,
      dialogueStructure: item.dialogueStructure,
      availableLanguages: availableLanguages,
      isOptional: item.isOptional,
      type: item.type,
      source: item.source,
      sourceField: item.sourceField,
      role: item.role,
      isDialogue: item.isDialogue,
      isResponsive: item.isResponsive,
      alternativeGroup: item.alternativeGroup,
    );
  }

  bool _matchesAnyCondition(List<String> conditions, dynamic liturgicalDay) {
    if (conditions.isEmpty) {
      return true;
    }
    // ALL conditions must be true (AND logic)
    for (final condition in conditions) {
      if (!_matchesCondition(condition, liturgicalDay)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesCondition(String condition, dynamic liturgicalDay) {
    final normalized = condition.trim().toLowerCase();
    switch (normalized) {
      case 'always':
        return true;
      case 'sunday_only':
        return liturgicalDay.dayOfWeek == DayOfWeek.sunday;
      case 'solemnity':
        return (liturgicalDay.rank?.toString().toLowerCase().contains('solemnity') ?? false);
      case 'sunday_or_solemnity':
        return liturgicalDay.dayOfWeek == DayOfWeek.sunday ||
            (liturgicalDay.rank?.toString().toLowerCase().contains('solemnity') ?? false);
      case 'not_advent':
        return liturgicalDay.season != LiturgicalSeason.advent;
      case 'not_lent':
        return liturgicalDay.season != LiturgicalSeason.lent;
      case 'lent':
        return liturgicalDay.season == LiturgicalSeason.lent;
      case 'easter_vigil':
        return liturgicalDay.dayOfWeek == DayOfWeek.saturday &&
            liturgicalDay.season == LiturgicalSeason.easter &&
            liturgicalDay.title.toLowerCase().contains('easter');
      default:
        return false;
    }
  }

  String _sectionTitleFor(String insertionPoint) {
    switch (insertionPoint) {
      case 'introductory_rites':
        return 'Introductory Rites';
      case 'before_first_reading':
        return 'Liturgy of the Word';
      case 'between_readings':
        return 'Between the Readings';
      case 'before_gospel':
        return 'Before the Gospel';
      case 'after_gospel':
        return 'Liturgy of the Word (Conclusion)';
      case 'offertory':
        return 'Liturgy of the Eucharist';
      case 'preface':
        return 'Eucharistic Prayer';
      case 'sanctus':
        return 'Sanctus';
      case 'acclamation':
        return 'Eucharistic Acclamation';
      case 'lords_prayer':
        return "The Lord's Prayer";
      case 'sign_of_peace':
        return 'Sign of Peace';
      case 'fraction':
        return 'Lamb of God';
      case 'communion':
        return 'Holy Communion';
      case 'after_communion':
        return 'Prayer after Communion';
      case 'concluding_rites':
        return 'Concluding Rites';
      default:
        return 'Order of Mass';
    }
  }

  void resetCache() {
    _cachedConfig = null;
  }
}
