# Opening Catalog Extractor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reproducible audit/dev extractor for first-100/first-200-character lectionary openings, starting with local source-marker fixtures.

**Architecture:** Add a focused Python extractor that reads source-location fixtures, extracts opening text from local source files, normalizes fingerprints, and writes JSONL under `verification/opening-catalog/`. Keep this as audit-only data so production code does not ship broad copyrighted excerpts. Later web adapters for Universalis and other reachable sources can emit the same JSONL schema.

**Tech Stack:** Python standard library, JSONL, existing local extract fixture JSON, Flutter/Dart app remains unchanged for this slice.

---

### Task 1: Local Opening Catalog Extractor

**Files:**
- Create: `scripts/active/extract_opening_catalog.py`
- Create: `test/scripts/opening_catalog_extractor_test.py`
- Output: `verification/opening-catalog/local-extract-openings.jsonl`

- [x] **Step 1: Write the failing test**

Create `test/scripts/opening_catalog_extractor_test.py` with tests that import the extractor, write tiny temporary source files and fixture JSON, run extraction, and assert JSONL output includes `opening100`, `opening200`, `normalizedFingerprint`, `sha256`, and `copyrightMode: audit_only`.

- [x] **Step 2: Run test to verify it fails**

Run: `python test/scripts/opening_catalog_extractor_test.py`

Expected: fail because `scripts/active/extract_opening_catalog.py` does not exist yet.

- [x] **Step 3: Implement the extractor**

Create `scripts/active/extract_opening_catalog.py` with:
- `extract_source_text(source_root, fixture)`;
- `normalize_fingerprint(text)`;
- `build_catalog_entries(fixture_path, source_root)`;
- CLI args `--fixtures`, `--repo-root`, `--output`;
- JSONL writer.

- [x] **Step 4: Run tests**

Run: `python test/scripts/opening_catalog_extractor_test.py`

Expected: all tests pass.

- [x] **Step 5: Generate local opening catalog**

Run:

```powershell
python scripts/active/extract_opening_catalog.py --fixtures verification/exact-reading-fixtures/local_extract_exact_text_samples.json --repo-root . --output verification/opening-catalog/local-extract-openings.jsonl
```

Expected: JSONL file with six local extract entries.

- [ ] **Step 6: Commit**

Stage only:
- `docs/superpowers/plans/2026-07-13-opening-catalog-extractor.md`
- `scripts/active/extract_opening_catalog.py`
- `test/scripts/opening_catalog_extractor_test.py`
- `verification/opening-catalog/local-extract-openings.jsonl`

Commit: `feat: add opening catalog extractor`
