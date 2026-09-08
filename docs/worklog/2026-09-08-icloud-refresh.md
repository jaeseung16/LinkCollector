# 2026-09-08 — Views not refreshed on iCloud remote changes

## Problem

An edit made on iPad/iOS is not reflected in the running macOS app. Restarting the
macOS app shows it. The opposite direction (macOS → iOS) appears to work.

## Investigation

Traced the path from the CloudKit import to the view.

1. **The remote-change handler never invalidates any view.**
   `LinkCollectorViewModel.swift:71-74` subscribes to `.NSPersistentStoreRemoteChange`
   and calls `fetchUpdates(_:)` (`LinkCollectorViewModel.swift:516`). That merges
   persistent history into `viewContext` (inside `HistoryRequestHandler.fetchUpdates()`
   in PersistenceSwift 0.2.18) and re-indexes Spotlight — and stops there. It never
   calls `fetchAll()`, never reassigns `links`/`tags`, never sends `objectWillChange`.
   Nothing in SwiftUI is invalidated by a remote change.
   `@Published var changedPeristentContext` (`LinkCollectorViewModel.swift:33`) is dead
   code — nothing subscribes to it.

2. **The only refresh triggers are user-driven.**
   - `ContentView.swift:53-56` — `onChange(of: scenePhase)` → `.active` → `fetchAll()`
   - `LinkListView.swift:111` — `.refreshable { viewModel.fetchAll() }`

   Confirmed by the author: on macOS, deactivating and reactivating the window does
   fire `.active` and the iPad edit then appears. So the refresh *mechanism* works on
   both platforms; only the *trigger* is missing while the window stays frontmost.
   `.refreshable` renders no affordance in an AppKit `List`, so macOS has no manual
   refresh at all — hence "restart the app".

   The macOS → iOS direction only looks better because iOS suspends, backgrounds and
   cold-relaunches the app constantly, so `.active` fires many times a day.

3. **`LinkDetailView` has its own staleness, independent of the above.**
   `fetchAll()` re-renders `ContentView`, which recreates `LinkDetailView` and re-reads
   `entity.title` / `entity.note`. But:
   - `entity` (`LinkDetailView.swift:22`) is a plain stored property, not
     `@ObservedObject`, so property-level changes on the managed object invalidate
     nothing on their own.
   - `summary` is `@State` seeded only in `.onAppear` (`LinkDetailView.swift:86-88`),
     and `.id(selectedLink)` (`ContentView.swift:44`) keeps that state alive across
     re-renders — a remotely-changed summary stays stale until the link is re-selected.
   - `tags` is computed once at `ContentView.swift:42` and passed in.

4. **Not the cause (ruled out).** Neither `viewContext.automaticallyMergesChangesFromParent`
   nor `shouldRefreshRefetchedObjects` is set anywhere (app or package). Since
   `fetchAll()` alone surfaces the iPad edit, the history merge is working and the
   objects are being faulted correctly, so these are optional hardening at most — and
   `automaticallyMergesChangesFromParent` would require a PersistenceSwift change.

5. **Unverified:** `fetchAll()` sets `searchString = ""` (`LinkCollectorViewModel.swift:385`)
   and the `$searchString` sink (`:94-99`) has no `removeDuplicates()`, so in principle
   `fetchAll()` → `searchString = ""` → debounce → `searchLink()` → `fetchAll()` is a
   self-sustaining 0.3s loop. The author's observation argues it is *not* firing (if it
   were, no window switch would be needed), most likely because the sink is only
   installed when `searchHelper.isReady()` is true. Hardened defensively, not treated
   as a known bug.

## Plan

1. **Wire the remote-change notification to a UI refresh.** In `fetchUpdates(_:)`,
   after `persistence.fetchUpdates()` returns a non-empty `objectIDs`, re-publish
   `links`/`tags`. Add a `refresh()` that re-fetches without touching `searchString`
   (re-running `searchLink()` instead when a search is active) and call that. Also drop
   the unused `changedPeristentContext` publisher.
2. **Give macOS a real manual refresh.** Add a toolbar `Button` calling
   `viewModel.fetchAll()` with `.keyboardShortcut("r")` in `LinkListView`; keep
   `.refreshable` for iOS pull-to-refresh.
3. **Fix `LinkDetailView` staleness.** Make `entity` an `@ObservedObject`, read
   `entity.summary` directly (local state only for the in-flight summarize), and derive
   `tags` in-view from `entity.getTagList()` instead of passing it in.
4. **`searchString` hygiene (defensive).** Guard the reset in `fetchAll()` and add
   `.removeDuplicates()` to the `$searchString` sink; log whether the sink is installed.

Dropped: `shouldRefreshRefetchedObjects` / `automaticallyMergesChangesFromParent`.

## Step 1 — done: wire the remote-change notification to a UI refresh

`LinkCollector/ViewModel/LinkCollectorViewModel.swift`

- Added `refresh()` next to `fetchAll()`. It re-publishes `links`/`tags` from the view
  context but, unlike `fetchAll()`, leaves `searchString` untouched — a refresh triggered
  by an iCloud change must not wipe out what the user is searching for. When a search is
  active it re-runs `searchLinks()` instead of `fetchLinks()` so the visible result set
  stays consistent with the search.
- `fetchUpdates(_:)` now returns early on an empty `objectIDs` and, after re-indexing
  Spotlight, calls `refresh()`. `persistence.fetchUpdates()` merges the persistent history
  into the view context but publishes nothing, so this is the missing link between an
  iCloud import and a SwiftUI redraw. Added an `os.Logger` line reporting how many remote
  changes triggered the refresh.
- Removed the unused `@Published var changedPeristentContext` — nothing subscribed to it.

Verified: `** BUILD SUCCEEDED **` for both `-destination 'platform=macOS'` and
`-destination 'platform=iOS Simulator,name=iPhone 17'`.

Not yet verified at runtime — the real check is editing a link on iPad and watching the
macOS window update without deactivating it.

## Step 2 — done: a macOS-usable manual refresh

`LinkCollector/Views/LinkListView.swift`

- Added a "Refresh" toolbar button (`arrow.clockwise`) with `.keyboardShortcut("r")` — ⌘R —
  guarded by `#if canImport(AppKit)`. `.refreshable` draws no affordance in an AppKit
  `List`, so before this macOS had no manual refresh at all; iOS keeps pull-to-refresh and
  its toolbar stays uncrowded.
- Changed both the button and `.refreshable` to call `refresh()` rather than `fetchAll()`.
  This deviates from the plan, which said `fetchAll()`: `fetchAll()` clears `searchString`,
  so refreshing mid-search would silently drop the user's search. Neither function merges
  history, so there is no behavioural difference beyond preserving the search.

Verified: `** BUILD SUCCEEDED **` for both `-destination 'platform=macOS'` and
`-destination 'platform=iOS Simulator,name=iPhone 17'`.

Not verified at runtime — ⌘R and the toolbar button still need a click in the real app.
