# Reading Text Size Design

## Problem

The Display section presents “Reading Text Size” as a disabled row and tells readers to adjust it elsewhere, but the reading view has no text-size control. Reading content therefore remains fixed at the default size and the preference cannot be saved.

## Design

Use one persisted reading-text preference with five named choices: Small (90%), Standard (100%), Comfortable (115%), Large (130%), and Extra large (150%). Named choices reduce precision work and make the result predictable. Android and iOS accessibility text scaling continues to apply on top of the chosen reading size.

The Settings row shows the active choice and opens a modal sheet. The sheet contains a short scripture preview and full-width radio rows with at least 48 dp touch height. Selecting an option updates the preview, saves immediately, and updates any open reading experience. A reset action appears only when the choice is not Standard.

The daily-reading overflow menu includes “Text size” so the control is available at the point of reading without adding another crowded app-bar icon. The same sheet is reused from Settings and reading view.

The preference scales scripture body text, separate incipits, responsorial-psalm responses, gospel-acclamation text, and expanded Order of Mass readings. References, section headings, menus, and controls remain at the system text size.

## Accessibility and resilience

- Keep native radio semantics and 48 dp minimum touch targets.
- Allow content to wrap without fixed-height containers.
- Preserve system text scaling instead of replacing it.
- Normalize unsupported stored values to Standard.
- Keep preference loading off the critical app-startup path; reading surfaces initialize it lazily.
- Use concise product copy that states the setting and current value without UI narration.

## Validation

- Preference unit tests: default, persistence, notifications, invalid-value recovery.
- Settings widget test: enabled row, current value, live preview, selection, reset.
- Reading widget test: menu access and immediate body-size change.
- Order of Mass widget test: expanded text honors the supplied scale.
- Analyze, focused tests, full test suite, release Android build, and physical-device smoke test at Standard and Extra large.
