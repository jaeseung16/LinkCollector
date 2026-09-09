# 2026-09-09 — Refreshing the user-facing description and README

## App description review

Reviewed the "How to Use"-style feature description against changes merged since 2026-08-16
(`docs/worklog/2026-09-04-summary-schema-and-ui.md`, `docs/worklog/2026-09-08-icloud-refresh.md`).
Two user-facing additions needed reflecting; everything else since then (Swift 6 migration,
Liquid Glass restyle, new app icon) is internal or purely visual and was left out at the user's
direction:

- **Link detail view** gained a "summary" button (between "note" and "EDIT") showing an
  on-device Apple Intelligence summary of the page, generated on demand; falls back to the
  page's own meta description when the model is unavailable.
- **Refresh** is now its own affordance: pull-to-refresh on iOS/iPadOS (existing), plus a new
  refresh button / ⌘R in the macOS tool bar (new — macOS previously had no manual refresh, per
  `2026-09-08-icloud-refresh.md`).

## `README.md`

Rewrote the stale parts, verified against `CLAUDE.md` and the current source:

- Project/product name, `LinkPiler.xcodeproj` (not `LinkCollector.xcodeproj`, a dead stub),
  Xcode 26.x — the old README said `LinkCollector.xcodeproj` and Xcode 12.5.1.
- Listed the four schemes.
- "Open in Browser" corrected from "will open in Safari" to "the user's default browser" —
  confirmed no Safari-specific API in `LinkDetailView.swift`.
- Added the summary button, macOS refresh, and a "Share links" (bookmark file export) step,
  none of which were documented.
- Left `## Version History` untouched — the user is maintaining that section themselves.

Did not touch: `Requirements` item 1 (location services) and item 2 (iCloud sync), both still
accurate; `Share Extension` section, only extended to mention that summary (like note/tags) is
edited in the main app, not the extension.
