# Share extension crash on macOS (build 53) — investigation

Reported by the author: share extensions do not work on macOS and iPadOS TestFlight builds.
Crash report attached from Console (`LinkPilerShareExtensionMac` 2.0 (53), macOS 26.6.2).

## Root cause — main-actor executor check in the `@objc` notification thunk

```
Thread 4 Crashed:: Dispatch queue: com.apple.coredata.NSPersistentStoreRemoteChangeNotification…
0 _dispatch_assert_queue_fail
3 _swift_task_checkIsolatedSwift
4 swift_task_isCurrentExecutorWithFlagsImpl
5 _checkExpectedExecutor(…)                      [inlined]
6 @objc ShareViewController.processNotification(_:)   (<compiler-generated>:103)
7 __CFNOTIFICATIONCENTER_IS_CALLING_OUT_TO_AN_OBSERVER__
…
12 -[NSPersistentStoreCoordinator _postStoreRemoteChangeNotificationsForStore:andState:]
```

`EXC_BREAKPOINT` / `brk 1` — this is a Swift concurrency precondition, not a memory error.

`ShareViewController` subclasses `NSViewController` (iOS: `UIViewController`), both of which are
`@MainActor` in the SDK, so the class and every member are main-actor isolated —
including `processNotification(_:)` (`LinkPilerShareExtensionMac/ShareViewController.swift:103`,
`LinkCollectorShareExtension/ShareViewController.swift:91`). Under Swift 6 language mode the
compiler emits an `@objc` thunk that asserts it is running on the main actor before entering
the Swift body. Core Data posts `.NSPersistentStoreRemoteChange` on its own private serial
queue, so the assert fails and the extension traps.

`loadView()` / `viewDidLoad()` registers the observer with the selector-based API, which
delivers on whatever queue the poster used:

```swift
NotificationCenter.default.addObserver(self,
                                       selector: #selector(processNotification),
                                       name: .NSPersistentStoreRemoteChange,
                                       object: persistenceController.container.persistentStoreCoordinator)
```

The main app does not crash because `LinkCollectorViewModel` observes the same notification
through Combine with `.receive(on: DispatchQueue.main)`
(`LinkCollector/ViewModel/LinkCollectorViewModel.swift:68-72`).

The bug is latent in the source since the observer was written; `7404922 chore: Adopt Swift 6
language mode` turned the isolation check from a runtime warning into a fatal precondition,
which is why it surfaced now. Both share extensions have the identical pattern, so iPadOS
fails for the same reason.

### Timing — it crashes before the user can act

Launch `12:35:09.6882`, crash `12:35:09.9605`: 272 ms. `posted` is still `nil`, so the
function body would have returned immediately — the trap is in the thunk, ahead of the
`guard`. The extension dies on the first remote-change notification the store emits while
CloudKit sets itself up (thread 3 is inside `PFCloudKitSetupAssistant`), i.e. every time the
share sheet opens, regardless of what is shared.

## Secondary problem — synchronous network on the main thread

Thread 0 at the moment of the crash:

```
ShareViewController.tryDownloadHTML(from:)      (ShareViewController.swift:345)
String.init(contentsOf:encoding:)
+[NSURLConnection sendSynchronousRequest:returningResponse:error:]
_dispatch_semaphore_wait_slow
```

`tryDownloadHTML(from:)` uses `String(contentsOf:encoding:)`, a synchronous network fetch.
Because the class is `@MainActor`, the `Task { }` in `accessWebpageProperties` inherits main-actor
isolation, so `update(with:)` → `process(urlString:)` → `getURLAndHTML` → `tryDownloadHTML` all
run on the main thread and block it for the whole download — and up to twice more on the
`https://` → `http://` retry path. The same holds for `try? Data(contentsOf: faviconURL)` in
`send(_:)` / `post(_:)`. This does not cause this crash, but it freezes the share sheet and is
its own termination risk (watchdog). Should move to `URLSession.data(from:)` on a
non-main-actor path.

- macOS: `LinkPilerShareExtensionMac/ShareViewController.swift:343-349`, `:155`
- iOS: `LinkCollectorShareExtension/ShareViewController.swift:268-274`, `:328`

## Also noticed

- `longitude:` is passed `location?.coordinate.latitude` in both extensions
  (`LinkPilerShareExtensionMac/ShareViewController.swift:165`,
  `LinkCollectorShareExtension/ShareViewController.swift:338`) — every link saved from a share
  extension gets a wrong longitude.
- `processNotification` calls `context.execute(…)` on a `newBackgroundContext()` from outside
  that context's queue — a Core Data queue violation independent of the actor issue.

## Fix applied

Both extensions — `LinkPilerShareExtensionMac/ShareViewController.swift` and
`LinkCollectorShareExtension/ShareViewController.swift`:

- `processNotification(_:)` is now `@objc private nonisolated` and does nothing but hop:
  `Task { @MainActor in self.handleRemoteChange() }`. `@MainActor` classes are implicitly
  `Sendable`, so capturing `self` is legal. (`nonisolated` is a declaration modifier, so it
  has to follow the `@objc` attribute — `nonisolated @objc` does not parse.)
- The old body moved to `handleRemoteChange()`, which stays main-actor isolated. Because it
  now runs on the main actor already, the two inner `DispatchQueue.main.async` hops
  (`showAlertAndTerminate()`, `stopAnimating()` / `stopAnimation(nil)`) are gone.
- The history fetch is wrapped in `context.performAndWait { }`, so `execute()` runs on the
  background context's own queue instead of whatever queue happened to call in. The nested
  `guard let` collapsed into one expression: `try? … as? …` does not add an optional layer
  (SE-0230), so `(try? context.execute(…) as? NSPersistentHistoryResult)?.result as? […]`
  is equivalent to the original pair of bindings.

Verified: `** BUILD SUCCEEDED **` for both `-destination 'platform=macOS'` and
`-destination 'platform=iOS Simulator,name=iPhone 17'`, no new warnings. Not yet verified at
runtime — needs a share-sheet run on device.

## Still open

- Synchronous network on the main thread (`String(contentsOf:)`, `Data(contentsOf:)`) — the
  freeze described above. Untouched.
- `longitude:` receiving `coordinate.latitude` in both extensions. Untouched.

---

# Follow-up: macOS share extension saves nothing (post-fix testing)

Author's report after the crash fix: iOS works; on macOS the sheet appears and accepts a
link, but the link never shows up in the app. The crash fix itself is therefore confirmed —
the extension now lives long enough to present its UI.

## Cause — the mac extension is entitled to the wrong iCloud container

`LinkPilerShareExtensionMac/LinkPilerShareExtensionMac.entitlements` declares:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.resonance.SpendingKeeper</string>
</array>
```

That is a different app's container (copy-paste from SpendingKeeper). The code asks for
`LinkPilerConstants.containerIdentifier` = `iCloud.com.resonance.jaeseung.LinkCollector`,
which this extension has no entitlement for, so CloudKit mirroring cannot start.

Confirmed in the shipped build, not just the source:

```
$ codesign -d --entitlements - /Applications/LinkPiler.app/Contents/PlugIns/LinkPilerShareExtensionMac.appex
com.apple.developer.icloud-container-identifiers = ['iCloud.com.resonance.SpendingKeeper']

$ codesign -d --entitlements - /Applications/LinkPiler.app
com.apple.developer.icloud-container-identifiers = ['iCloud.com.resonance.jaeseung.LinkCollector']
```

The iOS extension's entitlements file has the correct container, which is why iOS works.

## Why this produces exactly this symptom

`Persistence` (package source) never touches the app group — it uses
`NSPersistentContainer.defaultDirectoryURL()`, i.e. each process's own container, and sets
`cloudKitContainerOptions` from the passed identifier. The extensions and the app therefore
share data *only* through CloudKit. So on macOS the save succeeds locally, into the
extension's private store, and then has nowhere to go: the app never sees it, and the
`.NSPersistentStoreRemoteChange` confirmation `handleRemoteChange()` waits for never arrives
(the 10s `showAlertAndTerminate()` fallback fires instead).

Note the mac extension also lacks `com.apple.security.application-groups`, but that is
harmless — the app group is only used by the widget's `contents.json`.

## Fix (not yet applied)

Change the container identifier in the mac extension's entitlements to
`iCloud.com.resonance.jaeseung.LinkCollector`. The App ID
`com.resonance.jaeseung.LinkCollector.LinkPilerShareExtensionMac` also needs that container
enabled in the developer portal; automatic signing normally handles it once the entitlements
file is right.

---

# Follow-up 2: CloudKit export fails from the mac extension's store

After the entitlement fix shipped (build installed 13:26 today, `codesign` confirms
`iCloud.com.resonance.jaeseung.LinkCollector` / Production), sharing still does not reach the
app. Console shows a `_EXSinkLoadOperator … nil expectedValueClass` fault and
`CKErrorDomain Code=2` on export.

## The two log lines

- `_EXSinkLoadOperator … nil expectedValueClass allowing {…}` — benign. `ExtensionKit` logs it
  whenever `loadItem(forTypeIdentifier:options:)` is called without an expected class, which is
  what `accessWebpageProperties` does on both platforms. Fault level, but informational.
- `CKErrorDomain Code=2` is `CKError.partialFailure` — per-record failures inside
  `CKPartialErrors`, all `<private>`. This one is the blocker.

## Evidence — the mirroring event log

`NSPersistentCloudKitContainer` persists its event history in `ANSCKEVENT` in each store
(type 0 = setup, 1 = import, 2 = export). Reading both stores (copied with their `-wal` first;
`immutable=1` alone hides recent events):

Extension store — `~/Library/Containers/…LinkPilerShareExtensionMac/Data/Library/Application
Support/LinkPilerShareExtensionMac/LinkCollector.sqlite`:

```
type ok  domain         code  started
2    0   CKErrorDomain  2     2026-09-08 13:31:14   <- after the entitlement fix
0    1                  0     2026-09-08 13:31:14   <- setup now succeeds
…
2    0   CKErrorDomain  2     2026-05-17 13:51:55   <- first failure
2    1                  0     2026-05-17 13:50:00   <- last success
```

Every export has failed since 2026-05-17 13:51. Setup succeeds; only export fails.

App store — same query, today: every setup, import and export `ok = 1`. So the iCloud account,
the container, the Production schema and the network are all fine. The failure is specific to
the extension's local store.

## Cause

That store was created in April 2025 and mirrored for ~14 months against
`iCloud.com.resonance.SpendingKeeper`, the container the extension was (wrongly) entitled to.
It holds 1056 `ZLINKENTITY` rows and 1116 `ANSCKRECORDMETADATA` rows whose encoded system
fields — record names and change tags — belong to that container's zone. Changing the
entitlement repoints the store at a different container but does not reset any of that
metadata, and there is no API that does; so every export still offers the server records it
has never seen, and comes back as a partial failure.

The 2026-05-17 inflection fits: before it, exports "succeeded" into the SpendingKeeper
container under a development build, which is why the mac extension never delivered anything
to the app even while reporting success. From the first Production/TestFlight build the
SpendingKeeper container had no `CD_LinkEntity` schema and could not create one, so exports
started failing outright.

Note the inner `CKInternalErrorDomain Code=1011` is not a documented public value, and the
useful content stays redacted; the event log is what makes the diagnosis without unmasking.

## Data stranded in that store

18 rows exist in the extension's store and not the app's — 10 distinct URLs (9 real pages from
2026-05-10 to 2026-08-08, plus today's repeated test of the same arXiv page). These are exactly
the links shared from the Mac that never got out. Listed in the conversation; they need
re-adding by hand after the reset.

## Remedy (not yet applied — destroys the extension's local store)

Quit the app and any process hosting the extension, then remove
`~/Library/Containers/com.resonance.jaeseung.LinkCollector.LinkPilerShareExtensionMac/Data/Library/Application Support/LinkPilerShareExtensionMac/`
(`LinkCollector.sqlite*`, `.LinkCollector_SUPPORT`, `LinkCollector_ckAssets`). The extension
rebuilds the store on next use, does a clean setup and import against the correct container,
and exports should then succeed.

## Worth doing in code

Neither the app nor the extensions observe
`NSPersistentCloudKitContainer.eventChangedNotification`. Logging `event.type`,
`event.succeeded` and `event.error` with `privacy: .public` would have surfaced this from the
TestFlight logs directly instead of requiring sqlite forensics.

---

# Follow-up 3: correction to the diagnosis, and how to clean up on users' Macs

## Correction

Follow-up 2 said the extension's store had been mirroring a foreign container and that its
metadata was therefore stale/bound to SpendingKeeper. Further evidence contradicts that:

```
-- ext store, last import (type 1) events:      -- ext links also present in the app's store:
1  2026-05-17 13:50:00                          2026-05-17 13:49:56  GitHub - waltheri/go-libraries
1  2026-05-17 13:49:56                          2026-05-13 19:49:02  PUG REST
1  2026-05-13 19:49:01                          2026-05-10 17:18:29  Building Effective AI Agents
```

The extension's store was importing the user's real library — links created on other devices —
right up to 2026-05-17 13:49:56. It could only have got those from
`iCloud.com.resonance.jaeseung.LinkCollector`. So the SpendingKeeper entitlement was evidently
not enforced before that date, and the store's mirroring metadata belongs to the *correct*
container.

What is established: at 2026-05-17 13:51 imports stopped and exports began failing, and the
store has been wedged ever since — 1056 records carrying four-month-old change tags, re-offered
on every export. The per-record errors stay `<private>`, so "stale change tags →
`serverRecordChanged` → the whole batch fails, new link included" is inference. What is not
inference: the failure is local to this store. The app's store on the same Mac, same account,
same container, exported and imported successfully minutes either side of the extension's
failures.

The entitlement was still genuinely wrong and worth fixing; it just was not what blocked export.

Also ruled out: the `summary` attribute. The app has 15 links with summaries and exported them
successfully today, so the Production schema has the field. And the breakage predates the
attribute by four months.

## Cleaning up on users' machines

Every macOS user upgrading into the fixed build carries the same wedged store, and cannot be
asked to delete container files. The cleanup has to run inside the extension process — the app
cannot reach the extension's container (separate sandbox, and the extensions hold no app-group
entitlement).

Near-term, version-gated one-time reset in both extensions, before `Persistence` is constructed
(`persistenceController` has to become lazy, or the reset has to run from a type-level
initialiser):

1. Salvage — open the existing store as a plain `NSPersistentContainer` with no
   `cloudKitContainerOptions`, fetch every `LinkEntity`, write id/url/title/created/note/
   locality/coordinates/summary/tag-names to JSON in the extension's Application Support.
2. Destroy — `NSPersistentStoreCoordinator.destroyPersistentStore(at:type:.sqlite)`, then remove
   `.LinkCollector_SUPPORT` and `LinkCollector_ckAssets`.
3. Rebuild — the new `Persistence` creates a fresh store and does a clean setup + import.
4. Re-insert — on this and subsequent launches, insert salvaged links whose `id` is not already
   present, then delete the salvage file. Dedupe by `id` works because CloudKit re-imports the
   same UUIDs; only the genuinely stranded links survive it. It takes more than one launch
   because the extension lives only as long as the share sheet.

Gate on `UserDefaults` in the extension's own domain (`shareExtensionStoreResetVersion`), so it
runs once per user.

**Validate before shipping.** Reset this Mac's extension store by hand first and confirm a share
exports. Everything above rests on the failure being store-local; if a fresh store fails the
same way, the migration would destroy data for nothing.

## The structural fix

Point the extensions at a store in the app group shared with the app, instead of each keeping a
private mirror. Needs `com.apple.security.application-groups` on both extensions, a `Persistence`
change to accept a store URL (`defaultDirectoryURL()` is hardcoded), and a migration of the app's
existing store into the group container. It removes the second and third mirrors entirely — no
divergence, no duplicated 17 MB, and a shared link is visible to the app immediately instead of
via a CloudKit round-trip, which would also retire the `handleRemoteChange` confirmation dance.

---

# Follow-up 4: one-time store reset on macOS (applied)

Decision by the author: discard whatever is stranded in the extension's store rather than
salvaging it. A user who notices a missing link can re-add it from the app.

Note the app group was added to *both* extensions first (`6c88ad2`), even though the reset does
not use it — it is groundwork for moving the extensions onto a shared app-group store.

Also worth recording: "delete it during installation" is not available. macOS App Store and
TestFlight installs run no hook; the bundle is simply replaced. The earliest code that can run is
the extension's own first launch, which is what this does. And nothing needs to copy records
from the app's store — the extension cannot reach it across the sandbox boundary anyway, and
`NSPersistentCloudKitContainer` re-imports the whole library from iCloud by itself once the
fresh store is created.

## The change

`LinkPilerShareExtensionMac/ShareViewController.swift`, macOS only — the iOS extension exports
fine and resetting it would cost every iOS user a full re-download for nothing.

- A file-private `ShareExtensionStoreReset` enum. `runIfNeeded()` compares a version int in the
  extension's own `UserDefaults` against `version = 1` and, when behind, removes from
  `NSPersistentContainer.defaultDirectoryURL()`: `LinkCollector.sqlite`, `-wal`, `-shm`,
  `.LinkCollector_SUPPORT`, `LinkCollector_ckAssets`, and the `LinkCollector` directory that
  holds `Persistence`'s `token.data` — a history token pointing into a destroyed store would
  break `purgeHistory()` on the next launch.
- The marker is written only if every removal succeeded. A half-deleted store is worse than a
  wedged one, so a failure retries on the next launch instead of being recorded as done.
- `persistenceController` had to become `lazy`; it was an inline stored property, and the
  deletion has to happen before Core Data opens the store. `viewContext` and `loadView()` are
  the only things that touch it, both after the lazy initialiser runs.

New installs and healthy stores run it too, since the marker is simply absent — a delete of
nothing followed by the normal first import. The unavoidable cost is that every Mac user's next
share is slow while the library downloads, and may still hit the 10s "cannot confirm" alert once.

Verified: `** BUILD SUCCEEDED **` for macOS and the iOS simulator. Not yet verified at runtime.

---

# Follow-up 5: confirmed working, and the warnings cleaned up

The author confirms the macOS share extension works after pushing the build with the store reset
through TestFlight. The whole chain — crash fix, iCloud container, store reset — is verified at
runtime on macOS; iOS was verified earlier.

Four warnings remained in both extensions, all introduced by the `performAndWait` wrapper in the
crash fix:

```
capture of 'history' with non-Sendable type '[NSPersistentHistoryTransaction]?' in a '@Sendable' closure
mutation of captured var 'history' in concurrently-executing code
capture of 'fetchHistoryRequest' with non-Sendable type 'NSPersistentHistoryChangeRequest' in a '@Sendable' closure
add '@preconcurrency' to treat 'Sendable'-related errors from module 'CoreData' as warnings
```

Two causes:

- The closure returned `Void` and assigned into an outer `var`. A Void-returning closure binds to
  the Objective-C `performBlockAndWait:`, imported as `@Sendable`, so the outer variable was
  captured and mutated across an isolation boundary. Switching to the value-returning Swift
  overload (`let history = context.performAndWait { … }`) removes the `var` entirely.
- That overload's closure is `@Sendable` too, and `NSPersistentHistoryChangeRequest` is not
  `Sendable`, so hoisting the request outside it was a capture. Building it inside the closure
  removes that; `posted` is a `Date` and crosses fine.

The `@preconcurrency` suggestion on the `import CoreData` line was a companion to those and went
away with them — taking it literally would have suppressed the real warnings instead of fixing
them.

Verified: `** BUILD SUCCEEDED **` with zero warnings for both `platform=macOS` and
`platform=iOS Simulator,name=iPhone 17`, forcing recompilation of both files first so the
warnings would actually be re-emitted.

---

# Follow-up 6: longitude

`LinkPilerShareExtensionMac/ShareViewController.swift:232` and
`LinkCollectorShareExtension/ShareViewController.swift:348` passed
`location?.coordinate.latitude` as `longitude:`. Both now pass `coordinate.longitude`.

`LinkCollectorViewModel` was already correct (`userLatitude`/`userLongitude` from the matching
coordinate members), so the app's own saves were never affected — only links added through a
share extension.

Links already saved this way keep a longitude equal to their latitude. Nothing can repair them:
the real longitude was never written anywhere, so it is not recoverable from the record.

Verified: `** BUILD SUCCEEDED **`, no warnings, for macOS and the iOS simulator.

---

# Follow-up 7: the share extensions no longer block the main thread

`tryDownloadHTML(from:)` used `String(contentsOf:encoding:)` — a synchronous network fetch. The
class is `@MainActor`, so the `Task` in `accessWebpageProperties` inherited main-actor isolation
and the whole chain (`update(with:)` → `process(urlString:)` → `getURLAndHTML` →
`tryDownloadHTML`) ran on the main thread, freezing the share sheet for the duration — up to
three times over on the `https://` → `http://` retry path. It is the thread 0 stack in the
original crash report.

## Reused the app's downloader instead of making the local copies async

`LinkCollectorDownloader` (an actor, in the app target) already does exactly what the extensions
were doing by hand: `getUrlAndHtml()` with the same scheme fallback over
`URLSession.shared.data(from:)`, plus `isValid()` and `findFavicon()`. The extensions had
duplicated all of it, synchronously.

So `update(with publicURL:)` / `update(with plainText:)` now hop to the actor and resume on the
main actor to touch the UI, and these are gone from both extensions: `process(urlString:completionHandler:)`,
`getURLAndHTML(from:)`, `tryDownloadHTML(from:)`, `isValid(urlString:)`,
`findFavicon(url:completionHandler:)` — about 110 lines each. `update(with publicURL:)` now just
forwards to the string overload; the two bodies were identical. The `import FaviconFinder` in
both files went with them, since the only use was the deleted `findFavicon`.

## Target membership

The iOS extension already had `LinkCollectorDownloader.swift` in its Sources phase — compiled but
never used. Only the mac extension needed adding: one `PBXBuildFile` entry against the existing
fileRef plus a line in phase `90DBCD7B2D93691C0059D2E2`, mirroring how `HTMLParser.swift` is
already shared across the three targets.

Worth noting for future files: the `LinkPilerShareExtensionMac` target uses a
`PBXFileSystemSynchronizedRootGroup`, so anything placed in that *directory* joins the target
automatically. Only files from elsewhere in the repo need the explicit entries CLAUDE.md
describes.

## Still synchronous

`send(_:)` / `post(_:)` still fetch `/favicon.ico` with `try? Data(contentsOf: faviconURL)` on the
main thread when the user submits, and ignore the `favicon` the download path already stored.
Left alone deliberately — out of scope for this change.

Verified: `** BUILD SUCCEEDED **` with zero warnings for macOS and the iOS simulator.

---

# Follow-up 8: the favicon fetch on submit

Not purely redundant, as it turned out — checking before deleting was worth it.

`send(_:)` / `post(_:)` declared a **local** `var favicon: Data?` that shadowed the property of
the same name, then filled it with a synchronous `try? Data(contentsOf:)` of
`<scheme>://<host>/favicon.ico`. Two consequences:

- The favicon the download path had already stored in `self.favicon` — found by `FaviconFinder`,
  which reads the page's `<link rel="icon">` and picks the largest — was never saved. Every link
  got the crude root-`/favicon.ico` guess instead.
- The fetch blocked the main thread at the moment the user submitted.

But a blind deletion would have regressed one path. Both extensions declare
`NSExtensionJavaScriptPreprocessingFile` in their Info.plist and both bundle
`LinkCollectorShareExtension.js` (verified against the Resources build phases), so the
`.propertyList` branch is live on each. That branch — `update(with results: NSDictionary)` —
takes the URL and title straight from the JavaScript results and does no network at all, so
`self.favicon` is nil there and the submit-time fetch was the only favicon source.

So: drop the local shadow and the synchronous fetch, use the property, and fall back to the
downloader actor only when it is nil.

```swift
if favicon == nil {
    favicon = await LinkCollectorDownloader(url: urlTextField.stringValue).findFavicon()
}
```

Net effect: no main-thread network on submit; one favicon request instead of two on the
`publicURL`/`plainText` paths, and a better-quality icon saved; still exactly one on the
`propertyList` path, now asynchronous and via `FaviconFinder` rather than a root-path guess.

The body of `send(_:)` / `post(_:)` moved inside a `Task`, so `posted` is now set after the
favicon resolves rather than before — it is only ever compared against the timestamps of the save
that follows it, which still happens later. The 10s `showAlertAndTerminate()` fallback likewise
now starts after the fetch instead of racing it.

Verified: `** BUILD SUCCEEDED **` with zero warnings for macOS and the iOS simulator.
