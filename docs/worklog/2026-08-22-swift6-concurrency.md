# 2026-08-22 — Swift 6 concurrency cleanup (2026.md step 4)

Step 4's language-mode flip had already landed in `7404922`. Verified the starting state before
touching anything: all five build config groups — `LinkPiler`, `LinkPilerShareExtension`,
`LinkPilerShareExtensionMac`, `LinkPilerWidgetExtension`, and the project-level default — are on
`SWIFT_VERSION = 6.0` with `SWIFT_STRICT_CONCURRENCY = complete`, so the
`LinkPilerShareExtensionMac` gap the plan flagged is closed too. What remained was the "concrete
cleanup once compiling under Swift 6" list.

## Dead code in `HTMLParser`

The plan listed two dead APIs; there were actually three. Grepped all four targets to confirm no
callers before deleting:

- `parse(url:html:completionHandler:)` — the completion-handler variant the plan named.
- `findYouTubeTitle(_:completionHandler:)` — its private helper.
- `parseTitle(url:html:)` — **not in the plan**; it appeared after the plan was written and is a
  byte-identical duplicate of the live `parse(url:html:)`. Also uncalled.

`parse(url:html:)` (3 callers: the view model and both share extensions) and
`findTitle(youTubeUrl:)` are the live implementations and are untouched. The file goes from 190 to
121 lines.

Also removed a `private let htmlParser = HTMLParser()` stored property from **both**
`ShareViewController`s. Neither is used — both call sites shadow it with a local `HTMLParser()`
inside the parsing function.

## Redundant main-queue hops

`LinkCollectorViewModel` is `@MainActor`, so its four `DispatchQueue.main` hops were dispatching
from the main actor to the main queue. Checked every caller first — all are event handlers
(`onOpenURL`, delete/save actions), none run during SwiftUI view-body evaluation, so making the
mutations synchronous cannot trip "publishing changes from within view updates".

- `getLinkEntity(id:)` / `getTagEntity(with:)`: the `self.message = …` assignments are now direct.
- `set(searchString:selected:)`: the reset is now direct. The 0.5s gap before re-setting is
  **deliberate** — it is what makes SwiftUI observe a change when the same link is opened twice
  from a widget tap — so it is kept, as `Task { try? await Task.sleep(for: .seconds(0.5)) }` per
  the plan.

The three remaining `DispatchQueue.main` references are Combine schedulers
(`.receive(on:)` / `.debounce`), which the plan explicitly defers to the `@Observable` work in
step 5. Left alone.

## `@preconcurrency` bridges — tested, not stripped speculatively

The plan asked whether the iOS 26 SDK and current `PersistenceSwift` have picked up `Sendable`
annotations. Rather than guess, removed **all ten** `@preconcurrency` occurrences, then built both
platforms and put back only the ones the compiler demanded.

Result — all six *imports* are no longer needed and are gone:

| Dropped | File |
|---|---|
| `import UserNotifications` | `AppDelegate.swift` |
| `import Persistence` | `PersistenceHelper.swift` |
| `import UIKit`, `import FaviconFinder` | `LinkCollectorShareExtension/ShareViewController.swift` |
| `import Cocoa`, `import FaviconFinder` | `LinkPilerShareExtensionMac/ShareViewController.swift` |

Dropping `@preconcurrency import Persistence` answers step 3 of the plan's sequence: PersistenceSwift
0.2.15 is clean under Swift 6 caller-side checking, so no package-level fix is needed.

All four protocol *conformances* are still load-bearing and were restored, with the exact errors
they produce:

- `AppDelegate: @preconcurrency UNUserNotificationCenterDelegate` — "non-Sendable parameter type
  'UNNotification'/'UNUserNotificationCenter' cannot be sent from caller of protocol requirement
  into main actor-isolated implementation".
- `LinkCollectorViewModel: @preconcurrency CLLocationManagerDelegate`, and the same on both
  `ShareViewController`s — "conformance … to protocol 'CLLocationManagerDelegate' crosses into
  main actor-isolated code and can cause data races".

So `CLLocationManagerDelegate` and `UNUserNotificationCenterDelegate` have *not* been annotated in
the iOS 26 / macOS 26 SDKs. These stay until Apple annotates them.

## `TimelineProvider` — evaluated, deliberately not changed

The plan asked whether `AppIntentTimelineProvider` is worth adopting for `LinkPilerWidget/Provider.swift`,
the one remaining non-dead completion-handler surface. It is not: `AppIntentTimelineProvider` takes
a configuration intent and requires switching the widget from `StaticConfiguration` (what
`LinkPilerWidget.swift:18` uses) to `AppIntentConfiguration` — that makes the widget
user-configurable, which is a product decision, not a concurrency cleanup. WidgetKit still offers
no async variant for static widgets. The existing `Provider` is a `Sendable` struct with no shared
mutable state and its completion handlers are called synchronously, so there is no concurrency
problem to solve here. Left as-is.

## Verification

Clean builds on both platforms, **zero warnings and zero errors**:

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' clean build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' clean build
```

The clean builds matter here specifically because a `@preconcurrency import` suppresses *warnings*
as well as errors — an incremental build that merely succeeds would not have proven the imports
were safe to drop.

No test targets exist, and the app has not been run. The behavioral surface touched is small but
non-zero: the widget-tap → search-and-select path in `set(searchString:selected:)` is worth
exercising by hand.

## Follow-up found, not fixed

`LinkCollectorViewModel.save()` is declared `throws` but performs its work inside a detached
`Task`, so it can never throw. All five call sites wrap it in `do`/`catch` — including
`LinkListView.removeLink` and `TagListView.removeTag`, whose catch blocks set the "Failed to
delete the selected link/tag" user message — meaning save failures are silently swallowed today.
The fix is to make it `async throws` and `await` it at the call sites. Not done here: it is a
behavior change (currently-dead error paths start firing) and deserves its own commit rather than
riding along in a cleanup pass. Recorded in `2026.md` under section 4.

## Plan file

Marked section 4 of `2026.md` done, recording the two deliberate carve-outs (TimelineProvider,
Combine) and the `save()` follow-up.
