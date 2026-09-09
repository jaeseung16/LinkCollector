# 2026-09-02 — Make `LinkCollectorViewModel.save()` `async throws`

Fixes the follow-up recorded in `2026.md` §4 and
`docs/worklog/2026-08-22-swift6-concurrency.md`: save failures were silently swallowed.

## The defect

`LinkCollectorViewModel.save()` was declared `throws` but performed its work inside a detached
`Task`:

```swift
func save() throws -> Void {
    Task {
        try await persistenceHelper.save()
    }
}
```

The `try await` threw inside the `Task`, where nothing observed it; the enclosing function returned
immediately and could never throw. Every one of the five call sites wrapped the call in
`do`/`catch`, so all five catch blocks were dead code — including `LinkListView.removeLink` and
`TagListView.removeTag`, whose catch blocks set the user-facing "Failed to delete the selected
link/tag" message and raise an alert. A failing save looked exactly like a successful one.

## The change

`save()` is now `async throws` and simply forwards to `PersistenceHelper.save()`, which was already
`async throws`. That propagated outward:

**`LinkCollectorViewModel`** — the four mutators that call `save()` became `async`:
`saveTag(_:)`, `saveLinkAndTags(...)`, `update(link:with:)`, and `remove(tag:from:)`. Their existing
`do`/`catch` blocks are unchanged in shape (log + set `self.message`) but are now reachable.
`remove(tag:from:)` has no caller in the app today; it was converted along with the others for
consistency rather than left as the odd sync one out.

**Views** — each call site now drives the async work from a `Task`:

| File | Call site |
|---|---|
| `ContentView.swift` | `.onChange(of: scenePhase)`, leaving `.active` |
| `LinkListView.swift` | `.onDelete` → `removeLink(indexSet:)` |
| `TagListView.swift` | `.onDelete` → `removeTag(indexSet:)` |
| `AddTagView.swift` | `.onDelete` → `removeTag(indexSet:)`, and the Save button → `save()` |
| `AddLinkView.swift` | Save button → `saveLinkAndTags()` |
| `EditLinkView.swift` | Save button → `saveEntities()` |

`onDelete(perform:)` takes a synchronous `(IndexSet) -> Void`, so the three list views changed to
the trailing-closure form wrapping a `Task`. The view model is `@MainActor`, so these unstructured
`Task`s inherit the main actor — no isolation changes were needed anywhere.

`ContentView`'s empty `// TODO:` catch now sets `viewModel.message = "Failed to save changes"`,
following the repo convention that errors surface through `message`/`showAlert`.

## Behavior changes to watch

- **Error paths that were dead now fire.** Deleting a link or tag when the save fails will now show
  the "Failed to delete…" alert instead of appearing to succeed. That is the point of the fix, but
  it is a user-visible change.
- **`saveLinkAndTags` now saves in order.** Previously the link save was deferred into a `Task`, so
  in practice the tag saves that follow it ran first and the link rode along on a later save. Now
  the link save completes before the tags are attached and saved. More round-trips through the
  context, correct ordering.
- **`ContentView` scene-phase path.** `viewModel.writeWidgetEntries()` was deliberately left
  *outside* the new `Task`, so it still runs synchronously as the scene leaves `.active` — exactly
  its previous relative ordering, since `save()` was already deferred there. Moving it inside the
  `Task` would have put it behind an `await` at the moment the app may be suspended.

## Verification

Builds succeed on both platforms with no new warnings or errors:

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' build
```

(The one warning emitted, `appintentsmetadataprocessor … No AppIntents.framework dependency found`,
is pre-existing and unrelated.)

There are no test targets. The app was not run: the save/delete/edit paths above are worth
exercising by hand, particularly the two `onDelete` flows whose error alerts are newly reachable.

## Plan file

`2026.md` §4's follow-up entry is marked fixed and points here.
