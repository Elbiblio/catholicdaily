class ResponsorialPsalmTextEntry {
  final String usageId;
  final String territory;
  final String celebrationId;
  final String dateRule;
  final String sundayCycle;
  final String weekdayCycle;
  final String lectionaryNumber;
  final String readingSetKind;
  final String referenceNormalized;
  final String responseText;
  final List<String> stanzas;
  final String sourceId;
  final String sourceEdition;
  final String sourceUrl;
  final int displayPriority;

  const ResponsorialPsalmTextEntry({
    required this.usageId,
    required this.territory,
    required this.celebrationId,
    required this.dateRule,
    required this.sundayCycle,
    required this.weekdayCycle,
    required this.lectionaryNumber,
    required this.readingSetKind,
    required this.referenceNormalized,
    required this.responseText,
    required this.stanzas,
    required this.sourceId,
    required this.sourceEdition,
    required this.sourceUrl,
    required this.displayPriority,
  });

  String get formattedText {
    final response = 'R/. ${responseText.trim()}';
    final parts = <String>[response];
    for (final stanza in stanzas) {
      parts
        ..add(stanza.trim())
        ..add(response);
    }
    return parts.join('\n\n');
  }
}
