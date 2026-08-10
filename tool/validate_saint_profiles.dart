import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/saint_profile.dart';
import 'package:catholic_daily/data/services/saint_profile_validator.dart';

const _legacyPath = 'assets/data/saints_profiles.json';
const _indexPath = 'assets/data/saints/index.json';

Future<void> main(List<String> arguments) async {
  final unknownArguments = arguments
      .where((argument) => argument != '--published-only')
      .toList(growable: false);
  if (unknownArguments.isNotEmpty) {
    stderr.writeln('Unknown argument(s): ${unknownArguments.join(', ')}');
    stderr.writeln(
      'Usage: dart run tool/validate_saint_profiles.dart '
      '[--published-only]',
    );
    exitCode = 64;
    return;
  }

  final publishedOnly = arguments.contains('--published-only');
  try {
    final corpus = await _loadCorpus();
    final profilesToValidate = publishedOnly
        ? corpus.profiles.where((profile) => profile.isPublished).toList()
        : corpus.profiles;
    final issues = SaintProfileValidator().validateCorpus(profilesToValidate);

    for (final issue in issues) {
      stdout.writeln(
        '${issue.severity.name} ${issue.profileId} ${issue.field} '
        '${issue.code}: ${issue.message}',
      );
    }

    final errorCount = issues.where((issue) => issue.isError).length;
    final warningCount = issues.length - errorCount;
    stdout.writeln(
      'Saint profile validation: ${corpus.profiles.length} total, '
      '${corpus.legacyCount} legacy, ${corpus.researchedCount} researched, '
      '${profilesToValidate.length} validated, $errorCount errors, '
      '$warningCount warnings.',
    );
    if (errorCount > 0) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Saint profile validation could not run: $error');
    exitCode = 1;
  }
}

Future<_Corpus> _loadCorpus() async {
  final legacyJson = jsonDecode(await File(_legacyPath).readAsString());
  if (legacyJson is! List) {
    throw const FormatException('Legacy saint profiles must be a JSON array.');
  }
  final legacyProfiles = legacyJson
      .whereType<Map<String, dynamic>>()
      .map(SaintProfile.fromJson)
      .toList(growable: false);
  if (legacyProfiles.length != legacyJson.length) {
    throw const FormatException('Every legacy profile must be a JSON object.');
  }

  final indexJson = jsonDecode(await File(_indexPath).readAsString());
  if (indexJson is! Map<String, dynamic> || indexJson['schemaVersion'] != 2) {
    throw const FormatException('Saint index must use schema version 2.');
  }
  final rawPaths = indexJson['profiles'];
  if (rawPaths is! List || rawPaths.any((path) => path is! String)) {
    throw const FormatException('Saint index profiles must be string paths.');
  }
  final paths = rawPaths.cast<String>();
  if (paths.toSet().length != paths.length) {
    throw const FormatException('Saint index contains duplicate paths.');
  }

  final researchedById = <String, SaintProfile>{};
  final researchedOrder = <String>[];
  for (final path in paths) {
    final decoded = jsonDecode(await File(path).readAsString());
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 2) {
      throw FormatException('$path must contain one schema version 2 object.');
    }
    final profile = SaintProfile.fromJson(decoded);
    if (researchedById.containsKey(profile.id)) {
      throw FormatException(
        'Duplicate researched stable ID "${profile.id}" in $path.',
      );
    }
    researchedById[profile.id] = profile;
    researchedOrder.add(profile.id);
  }

  final merged = <SaintProfile>[];
  final legacyIds = <String>{};
  for (final legacyProfile in legacyProfiles) {
    legacyIds.add(legacyProfile.id);
    merged.add(researchedById[legacyProfile.id] ?? legacyProfile);
  }
  for (final id in researchedOrder) {
    if (!legacyIds.contains(id)) merged.add(researchedById[id]!);
  }

  return _Corpus(
    profiles: List.unmodifiable(merged),
    legacyCount: legacyProfiles.length,
    researchedCount: researchedById.length,
  );
}

class _Corpus {
  const _Corpus({
    required this.profiles,
    required this.legacyCount,
    required this.researchedCount,
  });

  final List<SaintProfile> profiles;
  final int legacyCount;
  final int researchedCount;
}
