import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/responsorial_psalm_edition.dart';

class ResponsorialPsalmEditionRegistry {
  static const manifestAsset = 'assets/data/psalm_editions/manifest.json';

  static const territoryLectionary = ResponsorialPsalmEdition(
    id: 'territory_lectionary',
    displayName: 'Territory lectionary (recommended)',
    abbreviation: 'Local lectionary',
    sourceKind: ResponsorialPsalmSourceKind.lectionary,
    territories: <String>['WORLD'],
    coverageStatus: 'automatic',
    packAsset: '',
    isInstalled: true,
    isDownloadable: false,
    sourceUrl: '',
    fallbackRole: 'territory_lectionary',
  );

  final List<ResponsorialPsalmEdition> _editions;

  ResponsorialPsalmEditionRegistry._(this._editions);

  factory ResponsorialPsalmEditionRegistry.fromJson(Map<String, dynamic> json) {
    final editions = (json['editions'] as List<dynamic>? ?? const [])
        .map(
          (value) => ResponsorialPsalmEdition.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    return ResponsorialPsalmEditionRegistry._(<ResponsorialPsalmEdition>[
      territoryLectionary,
      ...editions,
    ]);
  }

  static Future<ResponsorialPsalmEditionRegistry> load({
    AssetBundle? bundle,
  }) async {
    final raw = await (bundle ?? rootBundle).loadString(manifestAsset);
    return ResponsorialPsalmEditionRegistry.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  List<ResponsorialPsalmEdition> get all => List.unmodifiable(_editions);

  List<ResponsorialPsalmEdition> get selectable =>
      _editions.where((edition) => edition.isInstalled).toList(growable: false);

  ResponsorialPsalmEdition? byId(String id) {
    for (final edition in _editions) {
      if (edition.id == id) return edition;
    }
    return null;
  }

  ResponsorialPsalmEdition requireById(String id) {
    final edition = byId(id);
    if (edition == null) {
      throw ArgumentError.value(id, 'id', 'Unknown responsorial psalm edition');
    }
    return edition;
  }
}
