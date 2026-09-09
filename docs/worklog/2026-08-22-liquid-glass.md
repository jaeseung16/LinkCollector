# 2026-08-22 — Liquid Glass (2026.md step 1, remainder)

Picked up step 1 of `2026.md` after the deployment-target bump (26.0 on all four targets) and the
Icon Composer app icon (`LinkCollector/AppIcon_iOS26.icon`, commit `1a19b9f`) had already landed.
Completed the remaining UI items.

## Verified the SDK-level adoption is actually on

Grepped the whole repo for `UIDesignRequiresCompatibility` — the Info.plist key that opts an app
*out* of the new look while still building against the iOS 26 SDK. It is not set anywhere, so
Liquid Glass is live for all targets. (This was the "confirm the exact key name" open item in the
plan.)

## Navigation container

`ContentView.swift` wrapped `NavigationSplitView` in a bare `VStack`, which fights edge-to-edge
layout and safe-area handling under Liquid Glass. Removed it; `NavigationSplitView` already fills
its container, so the whole body dedents by one level with no other change.

## Glass-readiness cleanup

**`LinkDetailView.swift`**
- Dropped `.shadow(color: .gray, radius: 1.0)` from the `WebView` — a hand-drawn gray drop shadow
  under a glass-layered detail pane reads as a stray artifact.
- Dropped `.foregroundColor(.blue)` from `openInBrowser`, `note`, `editLinkView`, and the popover's
  Dismiss button. `AccentColor.colorset` carries no color value, so these all resolve to the system
  accent anyway — removing them lets the system's automatic control tinting (including disabled and
  pressed states, and glass button treatment) win instead of being overpainted.
- Replaced the tags `List` with a plain `VStack(alignment: .leading)`. It was a `PlainListStyle`
  list pinned to `.frame(height: bodyTextHeight * CGFloat(tags.count))` — a nested scroll view
  inside the detail `VStack` that had to guess its own height. The content is a static read-out, so
  a stack lays it out correctly on its own with no fixed frame and no dependence on how the system
  styles list backgrounds. The now-unused `@ScaledMetric bodyTextHeight` and the unused
  `geometry:` parameter on `tagsView` went with it.

**`Views/Labels/`** — inspected all five (`LinkLabel`, `LocationLabel`, `NoteLabel`, `TagLabel`,
`TitleLabel`). No hardcoded background colors; they use only `.primary`/`.secondary`, which adapt
correctly. Nothing to change. (This was the "not yet inspected in this pass" item in the plan.)

**Beyond what the plan listed** — the same hardcoded-blue pattern turned up in five more places
that the plan's file-by-file pass hadn't reached, including one on a toolbar button, where it is
most visible under the new toolbar styling. Removed all of them for consistency:
- `LinkListView.swift` — the toolbar Add button
- `AddLinkView.swift` — Cancel, Save, Add tags
- `EditLinkView.swift` — Edit tags, Cancel
- `AddTagView.swift` — Done (both the UIKit and AppKit branches)
- `SelectTagsView.swift` — Done, Reset

Afterwards there are no `.foregroundColor(.blue)` / `.foregroundColor(Color.blue)` occurrences left
in `LinkCollector/`, `LinkPilerWidget/`, or either share extension.

## Verification

Both builds succeed with no errors or new warnings:

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' build
```

There are no test targets in this repo, so building is the available verification. The visual
result has not been checked on a running device or simulator — worth an eyeball pass, particularly
the tags read-out in `LinkDetailView` (now unstyled rows instead of list rows) and the toolbar in
`LinkListView`.

## Plan file

Marked section 1 of `2026.md` as done with a status note recording the state of each prerequisite.

## Not done / follow-ups

- Section 2 (`NavigationSplitView` vs. adaptive `TabView`) is untouched — the plan flags an open
  product question (whether Links/Tags stays a two-item set) to settle before writing code.
- The housekeeping items at the top of `2026.md` — deleting the unreferenced leftover directories
  and aligning the stale project-level `IPHONEOS_DEPLOYMENT_TARGET = 15.0` default — are still open.
