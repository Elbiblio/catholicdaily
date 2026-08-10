import '../models/saint_profile.dart';
import '../models/saint_profile_content.dart';

enum SaintProfileIssueSeverity { warning, error }

class SaintProfileIssue {
  const SaintProfileIssue({
    required this.severity,
    required this.code,
    required this.profileId,
    required this.field,
    required this.message,
  });

  final SaintProfileIssueSeverity severity;
  final String code;
  final String profileId;
  final String field;
  final String message;

  bool get isError => severity == SaintProfileIssueSeverity.error;
}

class SaintProfileValidator {
  static final RegExp _stableId = RegExp(r'^[a-z0-9]+(?:_[a-z0-9]+)*$');
  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );
  static final RegExp _danglingDate = RegExp(
    r'(?:\b(?:born|died|c\.?|ca\.?)\s*|\b\d{3,4}\s*[-\u2013\u2014]\s*)$',
    caseSensitive: false,
  );
  static final RegExp _placeholder = RegExp(
    r'(?:profile available offline|fuller curated biography|'
    r'biography (?:is |will be )?available|content coming soon|'
    r'to be (?:completed|researched|written))',
    caseSensitive: false,
  );

  List<SaintProfileIssue> validateProfile(SaintProfile profile) {
    final issues = <SaintProfileIssue>[];

    void error(String code, String field, String message) {
      issues.add(
        SaintProfileIssue(
          severity: SaintProfileIssueSeverity.error,
          code: code,
          profileId: profile.id,
          field: field,
          message: message,
        ),
      );
    }

    void requireText(String field, String value) {
      if (value.trim().isEmpty) {
        error('missing_required', field, 'A non-empty value is required.');
      }
    }

    requireText('id', profile.id);
    if (profile.id.isNotEmpty && !_stableId.hasMatch(profile.id)) {
      error(
        'malformed_text',
        'id',
        'The stable ID must use lowercase snake_case.',
      );
    }
    if (profile.celebrationIds.isEmpty) {
      error(
        'missing_required',
        'celebrationIds',
        'At least one celebration ID is required.',
      );
    }
    requireText('name', profile.name);
    if (profile.feastDates.isEmpty ||
        profile.feastDates.every((date) => date.trim().isEmpty)) {
      error(
        'missing_required',
        'feastDates',
        'At least one feast date is required.',
      );
    }

    if (profile.sources.isEmpty) {
      error(
        'missing_source',
        'sources',
        'At least one traceable source is required.',
      );
    }

    final sourceIds = <String>{};
    for (var index = 0; index < profile.sources.length; index++) {
      final source = profile.sources[index];
      final field = 'sources[$index]';
      if (source.id.trim().isEmpty ||
          source.title.trim().isEmpty ||
          source.authorOrInstitution.trim().isEmpty ||
          source.publisher.trim().isEmpty ||
          source.url == null ||
          !_isWebUri(source.url!) ||
          source.accessedDate == null ||
          source.reuseBasis.trim().isEmpty ||
          source.supports.isEmpty) {
        error(
          'missing_source',
          field,
          'Published evidence must have complete provenance and scope.',
        );
      }
      if (source.id.trim().isNotEmpty && !sourceIds.add(source.id)) {
        error('duplicate_id', '$field.id', 'Source IDs must be unique.');
      }
    }

    if (_forbidsLifeSpan(profile.kind) && profile.lifeSpan.trim().isNotEmpty) {
      error(
        'forbidden_field',
        'lifeSpan',
        'Life span is not applicable to ${profile.kind.name} profiles.',
      );
    }

    final guide = profile.guide;
    if (profile.isPublished) {
      if (profile.schemaVersion != 2) {
        error(
          'invalid_publication_state',
          'schemaVersion',
          'Only schema version 2 profiles can be published.',
        );
      }
      if (guide == null) {
        error(
          'missing_required',
          'guide',
          'A complete spiritual life guide is required for publication.',
        );
      } else {
        _validateGuide(profile, guide, sourceIds, error, requireText);
      }
      final editorial = profile.editorial;
      if (editorial.researcher.trim().isEmpty ||
          editorial.reviewer.trim().isEmpty ||
          editorial.reviewedAt == null ||
          editorial.revision < 1 ||
          editorial.warnings.isNotEmpty ||
          !profile.hasFullGuide) {
        error(
          'invalid_publication_state',
          'editorial',
          'Published profiles require a complete guide, completed review, '
              'positive revision, and no unresolved warnings.',
        );
      }
    } else if (guide != null) {
      _validateGuide(profile, guide, sourceIds, error, requireText);
    }

    final quote = guide?.quote;
    if (quote != null) {
      if (quote.text.trim().isEmpty ||
          quote.attribution.trim().isEmpty ||
          quote.sourceId.trim().isEmpty) {
        error(
          'unverified_quote',
          'quote',
          'A quotation needs exact text, attribution, and a source ID.',
        );
      } else if (!sourceIds.contains(quote.sourceId)) {
        error(
          'unknown_source_id',
          'quote.sourceId',
          'The quotation references an unknown source ID.',
        );
        error(
          'unverified_quote',
          'quote.sourceId',
          'The quotation cannot be verified from the listed sources.',
        );
      }
    }

    final image = profile.image;
    if (image != null &&
        (image.assetPath.trim().isEmpty ||
            image.creator.trim().isEmpty ||
            image.sourceUrl == null ||
            !_isWebUri(image.sourceUrl!) ||
            image.license.trim().isEmpty ||
            image.creditLine.trim().isEmpty)) {
      error(
        'missing_image_attribution',
        'image',
        'An image needs an asset, creator, source URL, license, and credit line.',
      );
    }

    for (final entry in _userFacingText(profile).entries) {
      final value = entry.value;
      if (_placeholder.hasMatch(value)) {
        error(
          'placeholder_text',
          entry.key,
          'Placeholder or migration text is not publishable.',
        );
      }
      if (value.contains('\uFFFD') ||
          value.contains('Ã') ||
          value.contains('Â')) {
        error(
          'mojibake',
          entry.key,
          'Text contains a likely character-encoding error.',
        );
      }
      if (_controlCharacters.hasMatch(value) ||
          _danglingDate.hasMatch(value.trim())) {
        error(
          'malformed_text',
          entry.key,
          'Text contains a control character or incomplete date fragment.',
        );
      }
    }

    return List.unmodifiable(issues);
  }

  List<SaintProfileIssue> validateCorpus(Iterable<SaintProfile> profiles) {
    final values = profiles.toList(growable: false);
    final issues = <SaintProfileIssue>[
      for (final profile in values) ...validateProfile(profile),
    ];
    final ids = <String, List<SaintProfile>>{};
    final celebrations = <String, Set<String>>{};

    for (final profile in values) {
      ids.putIfAbsent(profile.id, () => []).add(profile);
      for (final celebrationId in profile.celebrationIds) {
        celebrations
            .putIfAbsent(celebrationId, () => <String>{})
            .add(profile.id);
      }
    }

    for (final entry in ids.entries.where((entry) => entry.value.length > 1)) {
      issues.add(
        SaintProfileIssue(
          severity: SaintProfileIssueSeverity.error,
          code: 'duplicate_id',
          profileId: entry.key,
          field: 'id',
          message: 'Stable profile ID appears ${entry.value.length} times.',
        ),
      );
    }
    for (final entry in celebrations.entries.where(
      (entry) => entry.value.length > 1,
    )) {
      issues.add(
        SaintProfileIssue(
          severity: SaintProfileIssueSeverity.error,
          code: 'duplicate_celebration_id',
          profileId: entry.value.join(','),
          field: 'celebrationIds',
          message: 'Celebration ID "${entry.key}" maps to multiple profiles.',
        ),
      );
    }

    final contentOwners = <String, String>{};
    for (final profile in values) {
      for (final entry in _duplicateCandidates(profile).entries) {
        final normalized = _normalize(entry.value);
        if (normalized.length < 100) continue;
        final key = '${entry.key}|$normalized';
        final owner = contentOwners[key];
        if (owner == null) {
          contentOwners[key] = profile.id;
        } else if (owner != profile.id) {
          issues.add(
            SaintProfileIssue(
              severity: SaintProfileIssueSeverity.error,
              code: 'duplicate_content',
              profileId: profile.id,
              field: entry.key,
              message: 'Long-form content duplicates profile "$owner".',
            ),
          );
        }
      }
    }

    return List.unmodifiable(issues);
  }

  static void _validateGuide(
    SaintProfile profile,
    SaintSpiritualGuide guide,
    Set<String> sourceIds,
    void Function(String code, String field, String message) error,
    void Function(String field, String value) requireText,
  ) {
    requireText('whyItMatters', guide.whyItMatters);
    requireText('oneMinuteSummary', guide.oneMinuteSummary);
    requireText('life.gospelTheme', guide.gospelTheme);
    requireText('life.struggle', guide.struggle);
    requireText('life.response', guide.response);
    requireText('practice.spiritual', guide.practice.spiritual);
    requireText('practice.action', guide.practice.action);
    requireText('scripture.reference', guide.scripture.reference);
    requireText('scripture.connection', guide.scripture.connection);
    requireText('prayer', guide.prayer);

    if (guide.lifeSections.isEmpty) {
      error(
        'missing_required',
        'life.sections',
        'At least one sourced life section is required.',
      );
    }
    for (var index = 0; index < guide.lifeSections.length; index++) {
      final section = guide.lifeSections[index];
      requireText('life.sections[$index].heading', section.heading);
      requireText('life.sections[$index].body', section.body);
      _validateEvidenceLinks(
        sourceIds,
        section.sourceIds,
        'life.sections[$index].sourceIds',
        error,
      );
    }

    if (guide.virtues.isEmpty || guide.virtues.length > 3) {
      error(
        'missing_required',
        'virtues',
        'One to three evidence-based virtues are required.',
      );
    }
    for (var index = 0; index < guide.virtues.length; index++) {
      final virtue = guide.virtues[index];
      requireText('virtues[$index].name', virtue.name);
      requireText('virtues[$index].evidence', virtue.evidence);
      requireText('virtues[$index].imitation', virtue.imitation);
      _validateEvidenceLinks(
        sourceIds,
        virtue.sourceIds,
        'virtues[$index].sourceIds',
        error,
      );
    }

    if (guide.reflectionQuestions.length != 2 ||
        guide.reflectionQuestions.any((question) => question.trim().isEmpty)) {
      error(
        'missing_required',
        'reflectionQuestions',
        'Exactly two non-empty reflection questions are required.',
      );
    }
  }

  static void _validateEvidenceLinks(
    Set<String> knownSourceIds,
    List<String> linkedSourceIds,
    String field,
    void Function(String code, String field, String message) error,
  ) {
    if (linkedSourceIds.isEmpty) {
      error(
        'missing_source',
        field,
        'Evidence must link to at least one listed source.',
      );
    }
    for (final sourceId in linkedSourceIds) {
      if (!knownSourceIds.contains(sourceId)) {
        error(
          'unknown_source_id',
          field,
          'Evidence references unknown source ID "$sourceId".',
        );
      }
    }
  }

  static bool _forbidsLifeSpan(SaintProfileKind kind) => switch (kind) {
    SaintProfileKind.angelic ||
    SaintProfileKind.marian ||
    SaintProfileKind.collective ||
    SaintProfileKind.observance => true,
    _ => false,
  };

  static bool _isWebUri(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;

  static Map<String, String> _userFacingText(SaintProfile profile) {
    final values = <String, String>{
      'name': profile.name,
      'ecclesialTitle': profile.ecclesialTitle,
      'lifeSpan': profile.lifeSpan,
      'lifeLength': profile.lifeLength,
      'vocation': profile.vocation,
      'briefBio': profile.briefBio,
      for (var i = 0; i < profile.alternateNames.length; i++)
        'alternateNames[$i]': profile.alternateNames[i],
      for (var i = 0; i < profile.places.length; i++)
        'places[$i]': profile.places[i],
      for (var i = 0; i < profile.patronage.length; i++)
        'patronage[$i]': profile.patronage[i],
      for (var i = 0; i < profile.symbols.length; i++)
        'symbols[$i]': profile.symbols[i],
      for (var i = 0; i < profile.feastDates.length; i++)
        'feastDates[$i]': profile.feastDates[i],
    };
    for (var i = 0; i < profile.sources.length; i++) {
      values['sources[$i].title'] = profile.sources[i].title;
      values['sources[$i].institution'] =
          profile.sources[i].authorOrInstitution;
    }
    final guide = profile.guide;
    if (guide == null) return values;
    values.addAll({
      'whyItMatters': guide.whyItMatters,
      'oneMinuteSummary': guide.oneMinuteSummary,
      'life.gospelTheme': guide.gospelTheme,
      'life.struggle': guide.struggle,
      'life.response': guide.response,
      'practice.spiritual': guide.practice.spiritual,
      'practice.action': guide.practice.action,
      'scripture.reference': guide.scripture.reference,
      'scripture.connection': guide.scripture.connection,
      'prayer': guide.prayer,
      for (var i = 0; i < guide.reflectionQuestions.length; i++)
        'reflectionQuestions[$i]': guide.reflectionQuestions[i],
      for (var i = 0; i < guide.lifeSections.length; i++) ...{
        'life.sections[$i].heading': guide.lifeSections[i].heading,
        'life.sections[$i].body': guide.lifeSections[i].body,
      },
      for (var i = 0; i < guide.virtues.length; i++) ...{
        'virtues[$i].name': guide.virtues[i].name,
        'virtues[$i].evidence': guide.virtues[i].evidence,
        'virtues[$i].imitation': guide.virtues[i].imitation,
      },
      if (guide.quote != null) ...{
        'quote.text': guide.quote!.text,
        'quote.attribution': guide.quote!.attribution,
      },
    });
    return values;
  }

  static Map<String, String> _duplicateCandidates(SaintProfile profile) {
    final guide = profile.guide;
    if (guide == null) return const {};
    return {
      'briefBio': profile.briefBio,
      'whyItMatters': guide.whyItMatters,
      'oneMinuteSummary': guide.oneMinuteSummary,
      'life.gospelTheme': guide.gospelTheme,
      'life.struggle': guide.struggle,
      'life.response': guide.response,
      'practice.spiritual': guide.practice.spiritual,
      'practice.action': guide.practice.action,
      'scripture.connection': guide.scripture.connection,
      'prayer': guide.prayer,
      for (var i = 0; i < guide.lifeSections.length; i++)
        'life.sections[$i].body': guide.lifeSections[i].body,
      for (var i = 0; i < guide.virtues.length; i++) ...{
        'virtues[$i].evidence': guide.virtues[i].evidence,
        'virtues[$i].imitation': guide.virtues[i].imitation,
      },
    };
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
