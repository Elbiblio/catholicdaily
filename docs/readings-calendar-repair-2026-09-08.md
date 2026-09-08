# Readings and calendar repair — 8 September 2026

## Findings and changes

- **Missing psalms:** 23 standard lectionary rows had empty responsorial fields. Twenty were canticles omitted during extraction; three were Sunday psalms. Restored the references and responses from the bundled weekday source texts and Sunday catalog. The catalog extractor now recognizes `RESPONSORIAL CANTICLE` as well as `RESPONSORIAL PSALM`.
- **Wrong date keys:** Three weekdays after Ash Wednesday and dated Advent entries carried ordinary week numbers. Corrected those keys so the resolver uses the complete standard readings. Explicitly preserve Advent Sunday precedence. The initial six-year audit found 448 date/region combinations without a psalm; the final audit found none.
- **September 8 failure:** The Nativity override requests `Ps 13:6ab,6c`, which had no complete matching source-pack entry outside the Nigerian alias path. Added a verified alias containing both the trust/salvation and singing stanzas. An unavailable psalm previously rejected the whole asynchronous reading load; it now leaves an unavailable-text notice for that reading while preserving the other readings.
- **Text coverage and numbering:** Filled missing Bible fallback selections, corrected the Good Friday selection, and fixed canticle aliases and mixed-chapter punctuation. Corrected RSVCE Daniel's Greek addition numbering and NABRE Jonah numbering. The generator excludes verified incomplete NABRE selections and allows a labelled RSVCE fallback. Whole-verse Bible fallback text may include material beyond a cited subverse; the new Tobit selections include verse 6 once instead of repeating it for every lettered segment.
- **Loading work:** Cache the most recent date's special-day classification instead of recomputing Easter-related dates for every catalog row. The cache is bounded and retains the existing selection order.
- **Calendar additions:** Show World Day of Peace (January 1), Earth Day (April 22), and World Day of Prayer for the Care of Creation (September 1) alongside the appointed liturgy. Add John Henry Newman, Priest and Doctor of the Church, as an October 9 optional memorial with its proper readings. The catalog already included Teresa of Calcutta, Faustina, Paul VI, Gregory of Narek, Hildegard, and Our Lady of Loreto.

## Verification

- **7 new service/coverage tests pass:** primary psalms for every day from 2025 through 2030 in all seven regions (**15,337 date/region combinations**), named memorial and feast choices, complete Nativity text, failure isolation, Sunday precedence, and correctly labelled fallback content.
- **44 service and widget regression tests pass:** includes the actual September 8 browse screen, observance cards, reading choices, existing psalm packs, special days, randomized dates, and the 2026–2027 reading audit. The latter reports zero missing reading sets, first readings, Gospels, or malformed references.
- **80 Python tests pass:** extraction, text corpus, source-pack integrity, and one-pass/idempotent December 22 restoration.
- Static analysis of changed Dart files reports **no issues**. `git diff --check` passes. Independent code review findings were addressed and rechecked.

These checks establish coverage and the specific corrected content; they are not a verse-by-verse certification of every pre-existing Bible database row.

## Release follow-up: 1.6.23+48

The full pre-release suite caught two integration omissions: Newman's new memorial needed an offline profile for saint-detail and reminder deep links, and the Nigerian Nativity text alias incorrectly retained a date rule that made it look like another appointed reading. Added the sourced profile and cleared the alias's calendar date while preserving its text and provenance. Updated the catalog snapshots for the additional memorial/profile.

The final local CI-equivalent selection passes **645 Flutter tests**, with **2 existing opt-in audits skipped** (exact source-text comparison and live Bible downloads). All **105 Python tests**, **7 iOS provisioning tests**, and the **iOS notification-extension validation checks** pass. Full-library analysis reports no issues. Independent review checked the integration fixes and their sources. Version `1.6.23+48` is prepared for the existing Mobile CI workflow, triggered by the release commit on `main`: Google Play production-track draft, TestFlight upload, and Windows GitHub release.

## Reproduction

```powershell
python -m scripts.restore_lectionary_canticles
flutter test test/data/services/calendar_psalm_coverage_test.dart --dart-define=PSALM_COVERAGE_OUTPUT=verification/calendar-psalm-references.json --reporter expanded
python -m scripts.complete_calendar_psalm_packs --references verification/calendar-psalm-references.json
```

The restoration script fills only identified gaps and repairs their date keys. The pack completion script preserves reviewed text, repairs the identified numbering cases, records honest fallback availability, and updates manifest counts. Run coverage again after generating packs. Its exported reference list covers primary readings; the test also exercises named celebration choices.

## Sources

- [USCCB: Nativity of the Blessed Virgin Mary, September 8, 2026](https://bible.usccb.org/bible/readings/090826.cfm)
- [Vatican: World Day of Peace](https://www.vatican.va/content/leo-xiv/en/messages/peace/documents/20251208-messaggio-pace.html)
- [Vatican Observatory: Earth Day](https://www.vaticanobservatory.org/event/international-earth-day/2025-04-22/)
- [Vatican: establishment of the World Day of Prayer for the Care of Creation](https://www.vatican.va/content/francesco/en/messages/cura-creato/documents/papa-francesco_20150806_lettera-giornata-cura-creato.html)
- [Vatican: Newman in the General Roman Calendar](https://www.vatican.va/content/romancuria/en/dicasteri/dicastero-culto-divino-e-disciplina-sacramenti/documenti/20260203-commento-decreto-iscrizione-newman.html)
- [Vatican: Newman's proper readings](https://www.vatican.va/content/romancuria/it/dicasteri/dicastero-culto-divino-e-disciplina-sacramenti/documenti/20251109-annesso-decreto-iscrizione-newman-la.html)
- Bundled source texts: `scripts/weekday_a_full.txt`, `scripts/weekday_b_full.txt`, and `scripts/sunday_readings_columns.txt`. Exact restoration source locations are recorded in `scripts/restore_lectionary_canticles.py`.
