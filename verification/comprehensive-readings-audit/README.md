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
```

and writes a timestamped log such as `resolver-20260712-143000.log`.

## Current Coverage

The resolver audit currently verifies:

- 75 deterministic future and past dates across configured audit regions.
- Required regions: General Roman, United States, United States with Ascension Thursday, England/Wales, and Nigeria.
- Regional sentinels for Nigeria on October 1 and United States Ascension transfer behavior.
- Resolver output shape: non-empty readings, first reading, responsorial psalm, gospel, and well-formed references.
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
