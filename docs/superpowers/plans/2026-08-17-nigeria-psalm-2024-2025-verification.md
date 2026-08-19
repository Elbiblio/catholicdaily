# Nigeria Psalm 2024–2025 Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recover and reconcile the 2024–2025 Nigeria responsorial psalms as historical verification evidence for the stable liturgical usage catalog.

**Architecture:** Add an archive importer that emits the existing source-row schema, then reconcile historical rows through the existing liturgical assignment model. Generate comparison and coverage artifacts separately from runtime assets so historical source dates cannot become resolver keys.

**Tech Stack:** Python 3 CSV/JSON tooling, Flutter/Dart services, existing Nigeria usage catalog, Flutter and Python tests.

---

### Task 1: Historical source inventory

**Files:**
- Modify: `test/scripts/responsorial_psalm_corpus_test.py`
- Create: `verification/psalm_sources/nigeria_2024_2025_source_inventory.csv`

- [ ] Add a failing test requiring explicit status for every date from 2024-01-01 through 2025-11-30.
- [ ] Run the focused Python test and confirm it fails for missing inventory.
- [ ] Probe the primary app/API and existing captured artifacts, recording recovered and unavailable dates without fabricating rows.
- [ ] Run the test and confirm every date has an evidence status.

### Task 2: Historical extraction

**Files:**
- Create: `scripts/psalm_sources/nigeria_archive.py`
- Modify: `scripts/build_responsorial_psalm_corpus.py`
- Create: `verification/psalm_sources/nigeria_2024_2025_psalms.csv`

- [ ] Add parser tests using actual captured historical record shapes.
- [ ] Confirm the tests fail before the importer exists.
- [ ] Implement extraction into the existing source-row schema with source date and provenance retained.
- [ ] Confirm extraction tests pass and report exact recovered-day/choice counts.

### Task 3: Stable-key reconciliation

**Files:**
- Modify: `scripts/psalm_sources/nigeria_assignment_rules.py`
- Modify: `scripts/psalm_sources/nigeria_usage_catalog.py`
- Create: `verification/psalm_sources/nigeria_2024_2025_usage_assignments.csv`

- [ ] Add failing tests for Sunday Cycles B/C, weekday Cycle I, proper precedence, and alternatives.
- [ ] Implement historical-row assignment through the existing semantic context model.
- [ ] Confirm no assignment uses its source date as a runtime key.

### Task 4: Full-text comparison

**Files:**
- Modify: `scripts/build_nigeria_psalm_usage_catalog.py`
- Create: `verification/psalm_sources/nigeria_2024_2025_comparison.csv`
- Create: `verification/psalm_sources/nigeria_2024_2025_coverage.json`

- [ ] Add a failing test requiring both full texts and an explicit status for each comparison.
- [ ] Generate corroborated, new-usage, conflict, and unavailable results.
- [ ] Report all four uniqueness counts before and after reconciliation.

### Task 5: Runtime and regression verification

**Files:**
- Modify: `test/data/services/nigeria_psalm_usage_service_test.dart`
- Modify: `test/data/services/nigeria_missal_audit_test.dart`

- [ ] Add failing recurrence tests proving recovered historical choices resolve in later matching liturgical contexts.
- [ ] Preserve proper-first and all-choice ordering.
- [ ] Run the Nigeria audit, source-pack tests, corpus tests, and static analyzer.
- [ ] Inspect every unresolved conflict before any commit or push.
