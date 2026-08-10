import 'dart:collection';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/saint_profile.dart';

typedef SaintAssetLoader = Future<String> Function(String path);

class SaintProfileRepository {
  SaintProfileRepository({
    this.legacyPath = legacyAssetPath,
    this.indexPath = indexAssetPath,
    SaintAssetLoader? loadString,
  }) : _loadString = loadString ?? rootBundle.loadString;

  static const legacyAssetPath = 'assets/data/saints_profiles.json';
  static const indexAssetPath = 'assets/data/saints/index.json';

  final String legacyPath;
  final String indexPath;
  final SaintAssetLoader _loadString;

  List<SaintProfile>? _profiles;

  Future<List<SaintProfile>> loadProfiles() async {
    final cached = _profiles;
    if (cached != null) return cached;

    final legacy = parseLegacyProfiles(await _loadString(legacyPath));
    final index = _decodeObject(await _loadString(indexPath), indexPath);
    if (index['schemaVersion'] != 2) {
      throw FormatException(
        'Unsupported saint profile index schema',
        indexPath,
      );
    }

    final rawPaths = index['profiles'];
    if (rawPaths is! List || rawPaths.any((path) => path is! String)) {
      throw FormatException(
        'Saint profile index paths must be strings',
        indexPath,
      );
    }
    final paths = rawPaths.cast<String>();
    if (paths.toSet().length != paths.length) {
      throw FormatException(
        'Saint profile index contains duplicate paths',
        indexPath,
      );
    }

    final byId = LinkedHashMap<String, SaintProfile>.fromEntries(
      legacy.map((profile) => MapEntry(profile.id, profile)),
    );
    final researchedIds = <String>{};
    final appended = <SaintProfile>[];

    for (final path in paths) {
      final json = _decodeObject(await _loadString(path), path);
      if (json['schemaVersion'] != 2) {
        throw FormatException(
          'Researched saint profile must use schema 2',
          path,
        );
      }
      final profile = SaintProfile.fromJson(json);
      if (!researchedIds.add(profile.id)) {
        throw FormatException(
          'Saint profile index contains duplicate stable id ${profile.id}',
          path,
        );
      }
      if (byId.containsKey(profile.id)) {
        byId[profile.id] = profile;
      } else {
        appended.add(profile);
      }
    }

    final result = List<SaintProfile>.unmodifiable([
      ...byId.values,
      ...appended,
    ]);
    _profiles = result;
    return result;
  }

  static List<SaintProfile> parseLegacyProfiles(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) {
      throw const FormatException('Legacy saint profile asset must be a list');
    }
    final profiles = <SaintProfile>[];
    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];
      if (value is! Map<String, dynamic>) {
        throw FormatException('Legacy saint profile $index must be an object');
      }
      profiles.add(SaintProfile.fromJson(value));
    }
    return List.unmodifiable(profiles);
  }

  static Map<String, dynamic> _decodeObject(String source, String path) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Saint profile asset must be an object', path);
    }
    return decoded;
  }
}
