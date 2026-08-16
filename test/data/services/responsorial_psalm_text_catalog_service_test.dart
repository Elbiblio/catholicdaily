import 'package:catholic_daily/data/models/responsorial_psalm_text_entry.dart';
import 'package:catholic_daily/data/services/responsorial_psalm_text_catalog_service.dart';
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

  test('parses catalog rows and ranks exact territory and celebration', () {
    const header =
        'usage_id,territory,celebration_id,date_rule,sunday_cycle,'
        'weekday_cycle,lectionary_number,reading_set_kind,'
        'reference_normalized,response_text,stanzas_text,source_id,'
        'source_edition,source_url,display_priority';
    const generic =
        'world:ps45,WORLD,,08-15,A/B/C,I/II,,celebration,'
        '"ps45:10,11,12,16",Generic response,Generic stanza,'
        'open_source,Open edition,https://example.invalid/open,20';
    const nigeria =
        'ng:assumption:ps45,NG,the_assumption_of_the_blessed_virgin_mary,'
        '08-15,A/B/C,I/II,,celebration,"ps45:10,11,12,16",'
        'Nigerian response,First line\\nsecond line\\n\\nNext stanza,'
        'licensed_source,Licensed edition,https://example.invalid/licensed,1';
    final entries = ResponsorialPsalmTextCatalogService.parseCsv(
      '$header\n$generic\n$nigeria\n',
    );

    final match = ResponsorialPsalmTextCatalogService.lookupFromEntries(
      entries,
      date: DateTime(2026, 8, 15),
      territory: 'NG',
      celebrationId: 'the_assumption_of_the_blessed_virgin_mary',
      readingSetKind: 'celebration',
      reference: 'Ps 45:10, 11, 12, 16',
    );

    expect(match?.usageId, 'ng:assumption:ps45');
    expect(match?.stanzas, <String>['First line\nsecond line', 'Next stanza']);
  });
}
