import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/order_of_mass_item.dart';
import '../models/prayer.dart';
import 'improved_liturgical_calendar_service.dart';
import 'ordo_resolver_service.dart';
import 'prayer_service.dart';
import 'missal_rites_service.dart';
import 'divinum_officium_loader_service.dart';
import 'prayer_of_the_faithful_service.dart';

class ResolvedOrderOfMassItem {
  final String id;
  final String title;
  final String insertionPoint;
  final int order;
  final Map<String, List<String>> contentByLanguage;
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
    return contentByLanguage[languageCode];
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

  final PrayerService _prayerService = PrayerService();
  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;
  final MissalRitesService _missalRitesService = MissalRitesService.instance;
  final DivinumOfficiumLoaderService _divinumOfficiumLoader = DivinumOfficiumLoaderService();
  final PrayerOfTheFaithfulService _prayerOfTheFaithfulService = PrayerOfTheFaithfulService.instance;

  List<OrderOfMassItem>? _cachedConfig;

  Future<List<ResolvedOrderOfMassSection>> getSectionsForDate(
    DateTime date, {
    String languageCode = 'en',
  }) async {
    await _prayerService.initialize();
    final config = await _loadConfig();
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    final dateStr = date.toIso8601String().split('T').first;

    final resolvedItems = <ResolvedOrderOfMassItem>[];
    for (final item in config) {
      if (_matchesAnyCondition(item.conditions, liturgicalDay)) {
        // Skip readings-based variable items - they belong in reading flow, not mass flow
        if (item.type == 'variable' && item.source == 'readings') {
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

    return orderedInsertionPoints
        .where(grouped.containsKey)
        .map(
          (insertionPoint) => ResolvedOrderOfMassSection(
            insertionPoint: insertionPoint,
            title: _sectionTitleFor(insertionPoint),
            items: grouped[insertionPoint]!,
          ),
        )
        .toList();
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
      final prayer = _prayerService.findPrayerBySlug(item.prayerSlug!.trim());
      if (prayer == null) {
        return item.hasInlineContent ? _resolveInlineItem(item) : null;
      }
      return _resolvePrayerItem(item, prayer);
    }

    if (item.hasInlineContent) {
      return _resolveInlineItem(item);
    }

    return null;
  }

  ResolvedOrderOfMassItem _resolvePrayerItem(OrderOfMassItem item, Prayer prayer) {
    final parsedContent = <String, List<String>>{};
    final availableLanguages = <String>[];

    // Load all available languages - UI will select based on user preference
    // This allows language switching without reloading prayers

    final sourceContent = prayer.contentByLanguage;
    if (sourceContent != null && sourceContent.isNotEmpty) {
      for (final entry in sourceContent.entries) {
        final cleaned = entry.value.where((line) => line.trim().isNotEmpty).toList();
        if (cleaned.isEmpty) {
          continue;
        }
        parsedContent[entry.key] = cleaned;
        availableLanguages.add(entry.key);
      }
    }

    if (parsedContent.isEmpty && prayer.text.isNotEmpty) {
      final cleaned = prayer.text.where((line) => line.trim().isNotEmpty).toList();
      if (cleaned.isNotEmpty) {
        parsedContent['en'] = cleaned;
        availableLanguages.add('en');
      }
    }

    return ResolvedOrderOfMassItem(
      id: item.id,
      title: item.title,
      insertionPoint: item.insertionPoint,
      order: item.order,
      contentByLanguage: parsedContent,
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
        return 'Gospel';
      case 'after_gospel':
        return 'After the Gospel';
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
        return 'Fraction of the Bread';
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
