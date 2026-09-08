# Readings and calendar repair

Goal: restore complete daily readings, prevent missing psalm text from blanking a day, and expose the requested observances with accurate liturgical status.

Approach: retain the existing calendar and reading selection rules. Audit their actual output across six years and all supported regions; repair text coverage at the source and handle unavailable text per reading. World observances appear alongside the day's liturgy. They do not create Mass reading options or change precedence. Add John Henry Newman's October 9 optional memorial using the existing memorial catalog and selection service.

Validation:
- Reproduce September 8 through the reading-set hydration path before changing production code.
- Audit actual calendar psalm references, including alternative sets, rather than only existing pack rows.
- Check source attribution and full psalm content for the Nativity; preserve the selected response.
- Verify per-reading failure isolation and a visible retry state for a failed day load.
- Verify observance dates and UI visibility, Newman selection, and unchanged primary readings.
- Run focused service/widget tests, the existing psalm and calendar suites, and static analysis.

Sources:
- https://bible.usccb.org/bible/readings/090826.cfm
- https://www.vatican.va/content/leo-xiv/en/messages/peace/documents/20251208-messaggio-pace.html
- https://www.vaticanobservatory.org/event/international-earth-day/2025-04-22/
- https://www.vatican.va/content/francesco/en/messages/cura-creato/documents/papa-francesco_20150806_lettera-giornata-cura-creato.html
- https://www.vatican.va/content/romancuria/en/dicasteri/dicastero-culto-divino-e-disciplina-sacramenti/documenti/20260203-commento-decreto-iscrizione-newman.html

The current catalog already contains Teresa of Calcutta, Faustina Kowalska, Gregory of Narek, Paul VI, Hildegard of Bingen, and Our Lady of Loreto.

Completed. Findings, corrected source data, verification results, and reproduction commands are recorded in [the repair report](../../readings-calendar-repair-2026-09-08.md). The existing whole-day retry state remains available; the new per-psalm isolation prevents the reported failure from reaching that state.
