# Comprehensive Readings Audit

This directory stores reproducible evidence from the Catholic Daily readings audit. The audit is meant to make future-date and regional resolver behavior inspectable without mixing generated logs into production source changes.

## Run the Audit

From any directory, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\catholicdaily-flutter\scripts\active\run_comprehensive_readings_audit.ps1
```

If PowerShell 7 is available, this also works:

```powershell
pwsh -NoProfile -File C:\dev\catholicdaily-flutter\scripts\active\run_comprehensive_readings_audit.ps1
```

The script resolves the repository root relative to its own location, creates this directory if needed, runs:

```powershell
flutter test test/data/services/comprehensive_resolver_audit_test.dart
flutter test test/data/services/displayed_readings_source_sample_test.dart
flutter test test/demo_launch_config_test.dart
flutter test test/widgets/mass_flow_region_header_test.dart
```

and writes timestamped logs such as `resolver-20260712-143000.log`, `displayed-samples-20260712-143000.log`, `demo-config-20260712-143000.log`, and `mass-flow-region-20260712-143000.log`.

## Run a Demo Launch

To open the app directly to a dated Mass/readings screen, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\catholicdaily-flutter\scripts\active\run_readings_demo.ps1 -Date 2026-10-01 -Region NG -BibleVersion rsvce
```

The script passes these dart defines to Flutter:

- `CATHOLIC_DAILY_DEMO_SCREEN=mass`
- `CATHOLIC_DAILY_DEMO_DATE=YYYY-MM-DD`
- `CATHOLIC_DAILY_DEMO_REGION=NG`, `US`, `US_ASC_THU`, `GB_EW`, or `general`
- `CATHOLIC_DAILY_DEMO_BIBLE_VERSION=rsvce` or `nabre`

## Run Exact Text Audit

The normal audit verifies resolved references and that display text is available.
To verify word-for-word displayed reading content against source extract text, run:

```powershell
powershell -ExecutionPolicy Bypass -File C:\dev\catholicdaily-flutter\scripts\active\run_exact_text_readings_audit.ps1
```

This runs:

```powershell
flutter test --dart-define=RUN_EXACT_TEXT_AUDIT=true test/data/services/displayed_readings_exact_text_audit_test.dart
```

The fixture file is:

```text
verification/exact-reading-fixtures/local_extract_exact_text_samples.json
```

The latest mismatch report is written to:

```text
verification/comprehensive-readings-audit/exact-text-local-extract-report.json
```

This audit is intentionally opt-in because it is expected to fail whenever the
app displays a different Bible text backend from the source extract translation.
For example, an RSVCE-rendered app reading should not be expected to match a
local extract with ESV/JB/NRSV-style wording. Those failures are classified as
real `text-version` work, not as resolver failures.

## Current Coverage

The resolver audit currently verifies:

- 75 deterministic future dates across configured audit regions.
- Required regions: General Roman, United States, United States with Ascension Thursday, England/Wales, and Nigeria.
- Regional sentinels for Nigeria on October 1 and United States Ascension transfer behavior.
- Resolver output shape: non-empty readings, first reading, responsorial psalm, gospel, and well-formed references.
- Displayed/hydrated reading samples for US/NABRE, England-Wales/RSVCE, and Nigeria/RSVCE, including Bible text availability for the references the UI would render.
- Mass Flow regional display: the Nigeria demo date must render `Solemnity: Our Lady, Queen of Nigeria` as the primary Mass header.
- Opt-in exact-text fixtures compare full displayed content against local extract ranges for selected England-Wales weekday and solemnity samples.
- Bible backend source switching is covered separately by the Bible text backend/version tests.

## Manual Online Comparison

The online comparison adapter is not implemented yet. Until it exists, compare online readings manually by recording:

- date and region;
- source URL and retrieval date;
- celebration title;
- ordered reading references;
- psalm response and gospel acclamation when available;
- any mismatch classification, such as `calendar`, `reference`, `region`, `cycle`, `psalm-response`, or `text-missing`.

Future evidence can be added here as log files, short Markdown notes, UI Automator XML dumps, or screenshots. Use filenames that include the date, region, version, and source, for example:

- `online-2026-10-01-nigeria-universalis.md`
- `emulator-2026-10-01-nigeria-rsvce.xml`
- `emulator-2026-10-01-nigeria-rsvce.png`

## Legal Note

Only add downloadable or licensed source texts when there is clear permission to use them in this project. Do not assume that a downloadable Bible, missal, or lectionary file is unrestricted or redistributable. When permission is uncertain, keep the source external-only or user-provided.

## Limitations

- Online comparison adapter is not yet implemented.
- External source ingestion is still pending.
- This folder is for audit evidence and documentation; it is not an authoritative source-text store.
