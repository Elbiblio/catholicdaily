enum PsalmFallbackReason {
  none,
  selectedEditionMissing,
  selectedPackUnavailable,
  territoryEditionMissing,
  bibleEditionMissing,
  corruptPack,
}

class ResolvedResponsorialPsalm {
  final String text;
  final String responseText;
  final String requestedEditionId;
  final String actualEditionId;
  final String actualEditionName;
  final String referenceNormalized;
  final PsalmFallbackReason fallbackReason;
  final String sourceUrl;

  const ResolvedResponsorialPsalm({
    required this.text,
    required this.responseText,
    required this.requestedEditionId,
    required this.actualEditionId,
    required this.actualEditionName,
    required this.referenceNormalized,
    required this.fallbackReason,
    required this.sourceUrl,
  });

  bool get didFallback => fallbackReason != PsalmFallbackReason.none;
}
