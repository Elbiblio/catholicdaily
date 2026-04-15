import 'package:flutter/foundation.dart';
import 'bidding_prayers_service.dart';
import 'ordo_resolver_service.dart';
import 'improved_liturgical_calendar_service.dart';

/// Service for loading and serving Prayer of the Faithful (Universal Prayer) content
/// Following GIRM §70-71 and current Roman Missal (3rd Edition) standards
class PrayerOfTheFaithfulService {
  static final PrayerOfTheFaithfulService instance = PrayerOfTheFaithfulService._internal();
  factory PrayerOfTheFaithfulService() => instance;
  PrayerOfTheFaithfulService._internal();

  final OrdoResolverService _ordoResolver = OrdoResolverService.instance;

  /// Standard response following current Roman Missal
  static const String _standardResponse = 'Lord, hear our prayer.';

  /// Get Prayer of the Faithful for a specific date and language.
  ///
  /// Primary source: biddingprayers.com live content (via [BiddingPrayersService]).
  /// Fallback: static seasonal template (when network is unavailable).
  Future<String?> getPrayerOfTheFaithful(
    DateTime date,
    String languageCode,
  ) async {
    // 1. Try live content from biddingprayers.com (English only; site is English)
    try {
      final live = await BiddingPrayersService.instance.getPetitionsForDate(date);
      if (live != null && live.isNotEmpty) {
        debugPrint('PrayerOfTheFaithful: using live BiddingPrayers content for $date');
        return live;
      }
    } catch (e) {
      debugPrint('PrayerOfTheFaithful: BiddingPrayers fetch failed – $e');
    }

    // 2. Fallback: generate from seasonal template so the section is never blank
    debugPrint('PrayerOfTheFaithful: falling back to template for $date');
    final liturgicalDay = await _ordoResolver.resolveDay(date);
    return _generateFromTemplate(liturgicalDay);
  }

  /// Get season name from LiturgicalSeason enum (used by _generateFromTemplate)
  String _getSeasonName(LiturgicalSeason season) {
    switch (season) {
      case LiturgicalSeason.advent: return 'advent';
      case LiturgicalSeason.christmas: return 'christmas';
      case LiturgicalSeason.lent: return 'lent';
      case LiturgicalSeason.easter: return 'easter';
      case LiturgicalSeason.ordinaryTime: return 'ordinary time';
    }
  }

  /// Generate a GIRM-compliant prayer from template when no specific prayer exists
  String _generateFromTemplate(LiturgicalDay liturgicalDay) {
    final season = _getSeasonName(liturgicalDay.season);
    final occasion = liturgicalDay.title;
    
    final buffer = StringBuffer();
    buffer.writeln('Prayer of the Faithful');
    buffer.writeln('(Universal Prayer)');
    if (occasion.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(occasion);
    }
    buffer.writeln('');
    buffer.writeln('Response: $_standardResponse');
    buffer.writeln('');
    
    // Generate season-appropriate petitions following GIRM categories
    final petitions = _getSeasonalPetitions(season, occasion);
    for (var i = 0; i < petitions.length; i++) {
      buffer.writeln('${i + 1}. ${petitions[i]}');
      buffer.writeln('   R. $_standardResponse');
      if (i < petitions.length - 1) buffer.writeln('');
    }
    
    return buffer.toString();
  }

  /// Get season-appropriate petition templates
  List<String> _getSeasonalPetitions(String season, String? occasion) {
    final lowerSeason = season.toLowerCase();
    
    if (lowerSeason.contains('advent')) {
      return [
        'For the Church as we await the coming of Christ, that we may be prepared to welcome him with joy, we pray to the Lord.',
        'For peace among nations and for those who govern, that they may work for justice and the common good, we pray to the Lord.',
        'For those who are sick, poor, or suffering in any way, that they may find comfort and hope in Christ\'s coming, we pray to the Lord.',
        'For our parish community and our families, that this season of preparation may deepen our faith, we pray to the Lord.',
        'For our beloved dead, and for all who have died in hope of the Resurrection, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('christmas')) {
      return [
        'For the Church throughout the world, that the light of Christ may shine brightly in our hearts, we pray to the Lord.',
        'For peace on earth and goodwill among all peoples, especially in areas of conflict, we pray to the Lord.',
        'For those who are lonely, sick, or in need during this holy season, that they may experience Christ\'s love, we pray to the Lord.',
        'For our families and this worshipping community, that we may celebrate this feast with grateful hearts, we pray to the Lord.',
        'For our departed loved ones, that they may rejoice in the eternal light of Christ, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('lent')) {
      return [
        'For the Church in this holy season of renewal, that we may be faithful to our baptismal commitment, we pray to the Lord.',
        'For the grace to overcome evil and to work for justice in our world, we pray to the Lord.',
        'For those preparing to receive the sacraments of initiation, and for all seeking reconciliation, we pray to the Lord.',
        'For those who suffer and for sinners, that they may find mercy and healing, we pray to the Lord.',
        'For our own intentions and for the faithful departed, we pray to the Lord.',
      ];
    }
    
    if (lowerSeason.contains('easter')) {
      return [
        'For the Church rejoicing in the Resurrection of Christ, that we may bear witness to the Risen Lord, we pray to the Lord.',
        'For peace among nations and for those who work for justice and human dignity, we pray to the Lord.',
        'For those recently baptized and for all who have returned to the Church this Easter, we pray to the Lord.',
        'For those who are sick, troubled, or in need, that they may share in the hope of the Resurrection, we pray to the Lord.',
        'For our beloved dead, that they may rise with Christ to everlasting life, we pray to the Lord.',
      ];
    }
    
    // Ordinary Time (default)
    return [
      'For the Church throughout the world, that we may faithfully proclaim the Gospel, we pray to the Lord.',
      'For our nation and all in authority, that they may serve the common good and protect the dignity of every person, we pray to the Lord.',
      'For those who suffer from illness, poverty, or any affliction, and for all in need of our prayers, we pray to the Lord.',
      'For our parish community, that we may grow in faith, hope, and love, we pray to the Lord.',
      'For our deceased relatives and friends, and for all who have died in the peace of Christ, we pray to the Lord.',
    ];
  }

}
