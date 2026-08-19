import '../models/resolved_responsorial_psalm.dart';
import '../models/responsorial_psalm_text_entry.dart';
import 'responsorial_psalm_edition_registry.dart';
import 'responsorial_psalm_source_pack_service.dart';

class ResponsorialPsalmFallbackService {
  final ResponsorialPsalmEditionRegistry registry;
  final ResponsorialPsalmSourcePackService packs;

  const ResponsorialPsalmFallbackService({
    required this.registry,
    required this.packs,
  });

  Future<ResolvedResponsorialPsalm> resolve({
    required ResponsorialPsalmRequest request,
    required String territoryEditionId,
    required String bibleEditionId,
  }) async {
    final candidates = <String>[];
    void add(String value) {
      if (value.isNotEmpty &&
          value != 'territory_lectionary' &&
          !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(request.selectedEditionId);
    add(territoryEditionId);
    add(bibleEditionId);
    add('local_rsvce');

    for (final editionId in candidates) {
      final entry = await packs.lookup(editionId: editionId, request: request);
      if (entry == null) continue;
      final edition = registry.requireById(editionId);
      final requestedResponse = request.responseText.trim();
      // The stable liturgical usage resolver has already selected the
      // response for this celebration/temporal key. Source-pack dates are
      // provenance only, so a same-reference row from another date must not
      // replace that selected response.
      final response = requestedResponse.isNotEmpty
          ? requestedResponse
          : entry.responseText.trim();
      return ResolvedResponsorialPsalm(
        text: _format(entry, response),
        responseText: response,
        requestedEditionId: request.selectedEditionId,
        actualEditionId: editionId,
        actualEditionName: edition.abbreviation,
        referenceNormalized: entry.referenceNormalized,
        fallbackReason: _reason(
          request.selectedEditionId,
          editionId,
          territoryEditionId,
        ),
        sourceUrl: entry.sourceUrl,
      );
    }
    throw StateError('No complete psalm edition contains ${request.reference}');
  }

  static PsalmFallbackReason _reason(
    String requested,
    String actual,
    String territoryEdition,
  ) {
    if (requested == actual) {
      return PsalmFallbackReason.none;
    }
    if (requested == 'territory_lectionary') {
      return actual == territoryEdition
          ? PsalmFallbackReason.none
          : PsalmFallbackReason.territoryEditionMissing;
    }
    return PsalmFallbackReason.selectedEditionMissing;
  }

  static String _format(ResponsorialPsalmTextEntry entry, String response) {
    if (response.isEmpty) return entry.stanzas.join('\n\n');
    final refrain = 'R/. $response';
    return <String>[
      refrain,
      for (final stanza in entry.stanzas) ...<String>[stanza, refrain],
    ].join('\n\n');
  }
}
