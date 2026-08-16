import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats response before and after each lectionary stanza', () {
    const entry = ResponsorialPsalmTextEntry(
      usageId: 'ng:assumption-day:psalm:1',
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      dateRule: '08-15',
      sundayCycle: 'A/B/C',
      weekdayCycle: 'I/II',
      lectionaryNumber: '',
      readingSetKind: 'celebration',
      referenceNormalized: 'ps45:10,11,12,16',
      responseText: 'On your right stands the queen in gold of Ophir.',
      stanzas: <String>[
        'The daughters of kings are those whom you favour.\n'
            'On your right stands the queen in gold of Ophir.',
        'Listen, O daughter; pay heed and give ear;\n'
            "forget your own people and your father's house.",
      ],
      sourceId: 'reviewed_psalm_source',
      sourceEdition: 'reviewed edition',
      sourceUrl: 'https://example.invalid/reviewed-psalm-source',
      displayPriority: 1,
    );

    expect(
      entry.formattedText,
      'R/. On your right stands the queen in gold of Ophir.\n\n'
      'The daughters of kings are those whom you favour.\n'
      'On your right stands the queen in gold of Ophir.\n\n'
      'R/. On your right stands the queen in gold of Ophir.\n\n'
      'Listen, O daughter; pay heed and give ear;\n'
      "forget your own people and your father's house.\n\n"
      'R/. On your right stands the queen in gold of Ophir.',
    );
  });
}
