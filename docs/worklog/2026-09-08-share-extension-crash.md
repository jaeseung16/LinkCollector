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
