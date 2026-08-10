import 'dart:convert';
import 'dart:io';

import 'package:catholic_daily/data/models/saint_profile.dart';
import 'package:catholic_daily/data/services/saint_profile_validator.dart';

class IndexedSaintProfile {
  const IndexedSaintProfile({required this.id, required this.state});

  final String id;
  final String state;
}

class SaintResearchQueueResult {
  const SaintResearchQueueResult({
    required this.published,
    required this.inProgress,
    required this.remaining,
    required this.duplicateIndexedIds,
    required this.unknownIndexedIds,
  });

  final List<String> published;
  final List<String> inProgress;
  final List<String> remaining;
  final List<String> duplicateIndexedIds;
  final List<String> unknownIndexedIds;

  bool get isComplete =>
      inProgress.isEmpty &&
      remaining.isEmpty &&
      duplicateIndexedIds.isEmpty &&
      unknownIndexedIds.isEmpty;
}

class SaintResearchQueue {
  const SaintResearchQueue._();

  static SaintResearchQueueResult compute({
    required List<String> legacyIds,
    required List<IndexedSaintProfile> indexedProfiles,
  }) {
    final legacySet = legacyIds.toSet();
    final counts = <String, int>{};
    final states = <String, Set<String>>{};
    for (final profile in indexedProfiles) {
      counts.update(profile.id, (count) => count + 1, ifAbsent: () => 1);
      states.putIfAbsent(profile.id, () => <String>{}).add(profile.state);
    }

    final published = <String>[];
    final inProgress = <String>[];
    final remaining = <String>[];
    for (final id in legacyIds) {
      final profileStates = states[id];
      if (profileStates == null) {
        remaining.add(id);
      } else if (profileStates.contains('published')) {
        published.add(id);
      } else {
        inProgress.add(id);
      }
    }

    return SaintResearchQueueResult(
      published: List.unmodifiable(published),
      inProgress: List.unmodifiable(inProgress),
      remaining: List.unmodifiable(remaining),
      duplicateIndexedIds: List.unmodifiable(
        counts.entries
            .where((entry) => entry.value > 1)
            .map((entry) => entry.key)
            .toList(growable: false),
      ),
      unknownIndexedIds: List.unmodifiable(
        states.keys
            .where((id) => !legacySet.contains(id))
            .toList(growable: false),
      ),
    );
  }
}

Future<void> main(List<String> arguments) async {
  try {
    final options = _Options.parse(arguments);
    final legacyIds = await _loadLegacyIds();
    final batches = await _loadAndValidateBatches(legacyIds);
    final loaded = await _loadIndexedProfiles();
    final queue = SaintResearchQueue.compute(
      legacyIds: legacyIds,
      indexedProfiles: loaded.profiles
          .map(
            (profile) => IndexedSaintProfile(
              id: profile.id,
              state: profile.editorial.state.name,
            ),
          )
          .toList(growable: false),
    );

    stdout.writeln(
      'Saint research queue: ${queue.published.length}/158 published, '
      '${queue.inProgress.length} in progress, '
      '${queue.remaining.length} remaining.',
    );
    _printList('Duplicate indexed IDs', queue.duplicateIndexedIds);
    _printList('Unknown indexed IDs', queue.unknownIndexedIds);

    final requested = options.batch == null
        ? options.ids
        : batches[options.batch.toString()]!;
    if (requested.isEmpty) {
      if (queue.duplicateIndexedIds.isNotEmpty ||
          queue.unknownIndexedIds.isNotEmpty ||
          loaded.duplicatePaths.isNotEmpty) {
        exitCode = 1;
      }
      return;
    }

    final legacySet = legacyIds.toSet();
    final byId = <String, List<SaintProfile>>{};
    for (final profile in loaded.profiles) {
      byId.putIfAbsent(profile.id, () => []).add(profile);
    }
    final failures = <String>[];
    for (final id in requested) {
      if (!legacySet.contains(id)) {
        failures.add('$id: unknown legacy ID');
        continue;
      }
      final matches = byId[id] ?? const <SaintProfile>[];
      if (matches.isEmpty) {
        failures.add('$id: researched JSON is not indexed');
        continue;
      }
      if (matches.length != 1) {
        failures.add('$id: indexed more than once');
        continue;
      }
      final profile = matches.single;
      if (!profile.isPublished) {
        failures.add('$id: editorial state is ${profile.editorial.state.name}');
      }
      final dossier = File('docs/research/saints/dossiers/$id.md');
      if (!await dossier.exists()) {
        failures.add('$id: research dossier is missing');
      } else if (!_validDossier(await dossier.readAsString())) {
        failures.add('$id: research dossier is incomplete');
      }
      final errors = SaintProfileValidator()
          .validateProfile(profile)
          .where((issue) => issue.isError)
          .toList(growable: false);
      if (errors.isNotEmpty) {
        failures.add(
          '$id: validation failed (${errors.map((issue) => issue.code).toSet().join(', ')})',
        );
      }
    }

    if (failures.isNotEmpty || loaded.duplicatePaths.isNotEmpty) {
      for (final failure in failures) {
        stderr.writeln('FAIL $failure');
      }
      _printList('Duplicate index paths', loaded.duplicatePaths, sink: stderr);
      exitCode = 1;
      return;
    }

    stdout.writeln(
      'Research gate PASS: ${queue.published.length}/158 published; '
      'requested batch valid.',
    );
  } on Object catch (error) {
    stderr.writeln('Saint research gate could not run: $error');
    exitCode = 1;
  }
}

Future<List<String>> _loadLegacyIds() async {
  final decoded = jsonDecode(
    await File('assets/data/saints_profiles.json').readAsString(),
  );
  if (decoded is! List ||
      decoded.any((item) => item is! Map<String, dynamic>)) {
    throw const FormatException('Legacy profiles must be a JSON object array.');
  }
  final ids = decoded
      .cast<Map<String, dynamic>>()
      .map((profile) => profile['id'])
      .whereType<String>()
      .toList(growable: false);
  if (ids.length != decoded.length || ids.toSet().length != ids.length) {
    throw const FormatException(
      'Legacy profile IDs must be present and unique.',
    );
  }
  return ids;
}

Future<Map<String, List<String>>> _loadAndValidateBatches(
  List<String> legacyIds,
) async {
  final decoded = jsonDecode(
    await File('docs/research/saints/batches.json').readAsString(),
  );
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
    throw const FormatException('Research batches must use schema version 1.');
  }
  final rawBatches = decoded['batches'];
  if (rawBatches is! Map<String, dynamic>) {
    throw const FormatException('Research batches map is missing.');
  }
  final batches = <String, List<String>>{};
  for (final entry in rawBatches.entries) {
    final value = entry.value;
    if (value is! List || value.any((id) => id is! String)) {
      throw FormatException('Batch ${entry.key} must contain string IDs.');
    }
    batches[entry.key] = value.cast<String>();
  }
  if (batches.keys.toSet().difference({
        for (var batch = 1; batch <= 14; batch++) '$batch',
      }).isNotEmpty ||
      batches.length != 14) {
    throw const FormatException('Research batches 1 through 14 are required.');
  }
  final flattened = batches.values.expand((ids) => ids).toList(growable: false);
  if (legacyIds.length != 158 ||
      flattened.length != 158 ||
      flattened.toSet().length != 158 ||
      !flattened.toSet().containsAll(legacyIds) ||
      !legacyIds.toSet().containsAll(flattened)) {
    throw const FormatException(
      'Batch manifest must contain every one of the 158 legacy IDs exactly once.',
    );
  }
  return batches;
}

Future<_LoadedProfiles> _loadIndexedProfiles() async {
  final decoded = jsonDecode(
    await File('assets/data/saints/index.json').readAsString(),
  );
  if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 2) {
    throw const FormatException('Saint index must use schema version 2.');
  }
  final rawPaths = decoded['profiles'];
  if (rawPaths is! List || rawPaths.any((path) => path is! String)) {
    throw const FormatException('Saint index profiles must be string paths.');
  }
  final paths = rawPaths.cast<String>();
  final counts = <String, int>{};
  for (final path in paths) {
    counts.update(path, (count) => count + 1, ifAbsent: () => 1);
  }
  final profiles = <SaintProfile>[];
  for (final path in paths) {
    final profileJson = jsonDecode(await File(path).readAsString());
    if (profileJson is! Map<String, dynamic> ||
        profileJson['schemaVersion'] != 2) {
      throw FormatException('$path must contain one schema version 2 object.');
    }
    profiles.add(SaintProfile.fromJson(profileJson));
  }
  return _LoadedProfiles(
    profiles: profiles,
    duplicatePaths: counts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList(growable: false),
  );
}

bool _validDossier(String text) {
  const headings = [
    '## Identity resolution',
    '## Source ledger',
    '## Claim ledger',
    '## Copyright and media decision',
    '## Content review',
    '## Theological review',
    '## Final validation',
  ];
  if (text.length < 800 || headings.any((heading) => !text.contains(heading))) {
    return false;
  }
  const identityFields = [
    '- Stable ID:',
    '- Profile kind:',
    '- Celebration IDs:',
    '- Canonical name and aliases:',
    '- Feast date and calendar scope:',
    '- Identity conflicts resolved:',
  ];
  const sourceLedgerHeader =
      '| ID | Tier | Author/institution | Title | Publisher | URL | Accessed | Reuse basis |';
  const claimLedgerHeader =
      '| Profile field | Claim or editorial conclusion | Source IDs | Certainty | Reconciliation note |';
  if (identityFields.any((field) => !text.contains(field)) ||
      !text.contains(sourceLedgerHeader) ||
      !text.contains(claimLedgerHeader)) {
    return false;
  }
  return !RegExp(r'\b(?:TBD|TODO)\b', caseSensitive: false).hasMatch(text);
}

void _printList(String label, List<String> values, {IOSink? sink}) {
  if (values.isEmpty) return;
  (sink ?? stdout).writeln('$label: ${values.join(', ')}');
}

class _LoadedProfiles {
  const _LoadedProfiles({required this.profiles, required this.duplicatePaths});

  final List<SaintProfile> profiles;
  final List<String> duplicatePaths;
}

class _Options {
  const _Options({required this.ids, required this.batch});

  final List<String> ids;
  final int? batch;

  static _Options parse(List<String> arguments) {
    List<String> ids = const [];
    int? batch;
    for (var index = 0; index < arguments.length; index++) {
      final argument = arguments[index];
      if (argument == '--ids' && index + 1 < arguments.length) {
        ids = arguments[++index]
            .split(',')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      } else if (argument == '--batch' && index + 1 < arguments.length) {
        batch = int.tryParse(arguments[++index]);
        if (batch == null || batch < 1 || batch > 14) {
          throw const FormatException('Batch must be between 1 and 14.');
        }
      } else {
        throw FormatException('Unknown or incomplete argument: $argument');
      }
    }
    if (ids.isNotEmpty && batch != null) {
      throw const FormatException('Use either --ids or --batch, not both.');
    }
    if (ids.toSet().length != ids.length) {
      throw const FormatException('Requested IDs must be unique.');
    }
    return _Options(ids: ids, batch: batch);
  }
}
