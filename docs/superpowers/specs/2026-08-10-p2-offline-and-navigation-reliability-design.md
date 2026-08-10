# P2 Offline and Navigation Reliability Design

**Date:** 2026-08-10
**Status:** Approved for implementation by the user's instruction to proceed with recommended P2 fixes

## Context

The P1 reliability work is merged. A second review found three medium-severity failure modes that can still interrupt the app's core purpose: following the correct liturgical date and reading Scripture reliably when connectivity or downloaded data changes.

1. Mass Flow commits a requested date only after its asynchronous load succeeds. If the user changes the secondary language while a new date is loading, the language reload uses the previous committed date and supersedes the user's newer date request.
2. The Bible download catalog falls back to bundled translations when its remote manifest cannot be fetched. A valid locally installed Douay-Rheims database then disappears from Data & Downloads even though it remains usable offline.
3. A saved preference can continue pointing at a downloaded database that has been removed, interrupted, or corrupted. The IO readings backend then returns unavailable content or empty Bible data instead of restoring a bundled source.

## Goals

- Preserve the newest Mass Flow date request across language reloads and delayed completions.
- Keep valid installed translations discoverable without network access.
- Guarantee that a missing or invalid downloaded source cannot prevent bundled Bible text from rendering.
- Persist fallback to RSVCE so UI labels, caches, and subsequent reads agree on the active source.
- Add deterministic regression tests for all three behaviors.

## Non-goals

- Adding new Bible translations or changing licensing/source policy.
- Adding translation deletion UI.
- Reworking the Mass Flow visual design or liturgical content resolver.
- Expanding supported deployment platforms.

## Design

### 1. Separate requested and committed Mass Flow dates

Mass Flow will track both:

- `requestedDate`: the newest date the user has asked the screen to load.
- `committedDate`: the date represented by the currently committed liturgical day, sections, and readings.

Starting a load updates `requestedDate` before the first await. Successful latest-request completion atomically commits the date and all date-scoped content. A secondary-language change reloads `requestedDate`, not stale committed content. The existing latest-request guard remains responsible for preventing older completions from committing.

A small request-state object will make the ownership rule independently testable without network or plugin dependencies.

### 2. Build an offline-aware translation catalog

When the remote manifest succeeds, the service continues filtering it through the approved registry. When the manifest is unavailable or invalid, the fallback catalog will contain:

- every bundled translation; and
- each approved downloadable source whose local normalized database validates successfully.

Unavailable, corrupt, raw, or merely advertised downloads remain hidden. Installed entries retain their registry metadata, including database filename and source URL, so the UI can represent them consistently.

### 3. Fall back from an unavailable selected database

The IO readings backend will validate the minimum normalized schema of a downloaded database when opening it. If the selected downloadable source is missing, cannot be opened, or lacks the expected `books` and `verses` tables, the backend will:

1. persist `BibleVersionType.rsvce` through `BibleVersionPreference`;
2. open the bundled RSVCE database; and
3. continue the original read operation.

Bundled-source errors are not swallowed or recursively retried. This keeps genuine packaged-data failures visible while recovering only from optional downloaded-source failures.

## Error handling

- Remote catalog failure remains non-fatal and does not expose unsupported sources.
- Invalid downloaded files remain on disk so the existing atomic downloader can replace them; they are not treated as installed.
- The fallback preference change notifies listeners so Bible-version UI converges on RSVCE.
- Mass Flow load failures keep the last committed content/date internally, while the next language retry targets the user's newest requested date.

## Testing

- Unit-test Mass Flow request state: a language reload after requesting date B targets B, while date A remains committed until success.
- Service-test offline catalog fallback with a locally validated installed translation and a failed HTTP manifest request.
- Backend-test missing and invalid selected downloaded databases; both must render from RSVCE and persist RSVCE.
- Re-run focused tests, `flutter analyze`, the complete Flutter suite, and an Android debug build.

