# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Link Piler** — a SwiftUI app for collecting/organizing web links, shipping on the App Store for iOS, iPadOS, and macOS from one codebase (native AppKit, *not* Mac Catalyst). Data syncs across devices through CloudKit.

Naming is inconsistent for historical reasons: the product/scheme is **LinkPiler**, but the source directory, bundle identifier (`com.resonance.jaeseung.LinkCollector`), Core Data model, and many type names are still **LinkCollector**. Both names refer to the same thing.

## Build & Run

The live project is `LinkPiler.xcodeproj` (`LinkCollector.xcodeproj` is a dead stub with no `project.pbxproj`). Requires Xcode 26.x; deployment targets are iOS 26.0 / macOS 26.0.

```bash
# Build for macOS
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build

# Build for the iOS simulator
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Available schemes: LinkPiler, LinkPilerShareExtension, LinkPilerShareExtensionMac, LinkPilerWidgetExtension
xcodebuild -project LinkPiler.xcodeproj -list
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -showdestinations
```

There are **no test targets** and no lint configuration in this repo — there is nothing to run for tests. Verification means building, and running the app.

Dependencies are Swift Package Manager, resolved by Xcode: [PersistenceSwift](https://github.com/jaeseung16/PersistenceSwift) (the author's own Core Data/CloudKit wrapper, imported as `Persistence`), SwiftSoup (HTML parsing), FaviconFinder.

## Targets and source layout

| Target | Source dir | Platform |
|---|---|---|
| `LinkPiler` (app) | `LinkCollector/` | iOS + macOS |
| `LinkPilerShareExtension` | `LinkCollectorShareExtension/` | iOS (UIKit + storyboard) |
| `LinkPilerShareExtensionMac` | `LinkPilerShareExtensionMac/` | macOS (AppKit + XIB) |
| `LinkPilerWidgetExtension` | `LinkPilerWidget/` | iOS + macOS |

`ShareExtension/`, `LinkCollectorExtension/`, `LinkCollectorSafariExtension/`, `LinkPiler2/`, root `Base.lproj/`, and `LinkCollector.xcodeproj` are leftovers from earlier layouts and are **not** referenced by the live project — ignore them.

There is no shared framework. Code used by more than one target is given multiple target memberships in `project.pbxproj` (`LinkPilerConstants.swift`, `HTMLParser.swift`, `LinkeEntity+Extension.swift`). When adding a file that an extension needs, its target membership must be added explicitly.

## Architecture

**Single view model, injected from the app delegate.** `AppDelegate` owns `Persistence` and `LinkCollectorViewModel` and hands the view model to SwiftUI as an `@EnvironmentObject` (`LinkPilerApp.swift`). Views never touch Core Data directly; they read `viewModel.links` / `viewModel.tags` (both `@Published` arrays refreshed by `fetchAll()`) and filter in-memory. `@FetchRequest` is not used anywhere.

**Persistence stack:** `Persistence` (external package, `NSPersistentCloudKitContainer`) → `PersistenceHelper` (thin fetch/save/find wrapper over `viewContext`) → `LinkCollectorViewModel`. Model: `LinkCollector.xcdatamodeld`, current version **`LinkCollector 2.xcdatamodel`**; entities `LinkEntity` and `TagEntity` in a many-to-many relationship, `codeGenerationType="class"` — so the entity classes are generated at build time and have no source files here, only `+Extension.swift` files.

**Search goes through Spotlight, not Core Data.** `SearchHelper` (an `actor`) indexes links via `LinkSpotlightDelegate` (`NSCoreDataCoreSpotlightDelegate`) and runs `CSSearchQuery` against the title. Results come back as unique identifiers that are the managed object ID URIs, which `PersistenceHelper.find(for:)` maps back to `LinkEntity` objects. `searchString` is debounced 0.3s in the view model. Two `@AppStorage` flags (`spotlightLinkIndexing`, `oldIndexDeleted`) gate one-time index rebuilds at launch — flipping them forces a reindex.

**Cross-process data sharing.** The share extensions do *not* use the view model; each constructs its own `Persistence` and writes to the same CloudKit-backed store. The widget cannot read Core Data at all: the app serializes up to 6 random `WidgetEntry` values to `contents.json` in the app group container (`writeWidgetEntries()`, called when the scene leaves `.active`), and `Provider` decodes that file. Tapping a widget opens `widget-linkpiler://` and `onOpenURL` sets the view model's `searchString`/`selected`. All identifiers live in `LinkPilerConstants.swift` (app group, iCloud container, Spotlight domain/index names, URL scheme).

**CloudKit push notifications.** `AppDelegate` subscribes to `CD_LinkEntity` changes on the private database to post a local notification when another device adds a link. The `Subscriber.subscribe()` path is marked as not working under Swift 6.

**Platform branching** is done inline with `#if canImport(UIKit)` / `#else` (AppKit) throughout views, `AppDelegate`, `WebView`, and the widget provider — not with separate files.

**Concurrency:** all four targets are on **Swift 6 language mode** with `SWIFT_STRICT_CONCURRENCY = complete`. `LinkCollectorViewModel` and `AppDelegate` are `@MainActor`; `HTMLParser`, `LinkCollectorDownloader`, and `SearchHelper` are actors; several imports are `@preconcurrency`. Preserve these annotations when editing.

## Conventions

- Commit messages use a type prefix: `feature:`, `fix:`, `chore:`, `refactor:`, `docs:`.
- Work happens on a version-named branch (`1.6`, `2026`) and merges to `main` via PR.
- Version bumps are their own commit: `chore: Version 1.6 Build 51` (`MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`).
- Logging is `os.Logger` with explicit privacy annotations (`privacy: .public`), not `print`.
- Errors are logged and surfaced to the user by setting `viewModel.message`, whose `didSet` toggles `showAlert`.

## Work log

After completing each step or major task, append a summary of it to `docs/worklog/YYYY-MM-DD-<topic>.md` in this repo (create the file if it does not exist), in addition to reporting the summary in the conversation.

## Notes

- `2026.md` (on the `2026` branch) is the working plan for the 2.0 release: Liquid Glass adoption, `NavigationSplitView` vs. adaptive `TabView`, Apple Intelligence link summarization, and an eventual SwiftData migration (its toolchain/deployment-target and Swift 6 items are done). Read it before starting work in those areas.
- `README.md` is stale (it references `LinkCollector.xcodeproj` and Xcode 12.5.1); the "How to Use" section still describes current app behavior.
