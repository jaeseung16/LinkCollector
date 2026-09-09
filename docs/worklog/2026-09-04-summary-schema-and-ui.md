# 2026-09-04 — Storing and showing the summary

Third step of `2026.md` §3, after `docs/worklog/2026-09-04-html-body-text.md` (body-text
extraction) and `docs/worklog/2026-09-04-foundation-models-summarizer.md` (the model call). Those
two produced a summary that nothing stored and nothing displayed. This step closes §3: the schema
attribute, the `og:description` fallback, the view-model path that ties download → extract →
summarize → save together, and the on-demand button in `LinkDetailView`.

## Schema

`LinkCollector 2.xcdatamodel` gains one attribute on `LinkEntity`:

```xml
<attribute name="summary" optional="YES" attributeType="String"/>
```

Optional and with no default, so it is CloudKit-safe the same way `note` and `title` are, and a
lightweight migration handles it. Added to the current model version in place, as `2026.md` calls
for, rather than as a new version — the attribute is additive, and Core Data infers the mapping.

**Before this ships:** the CloudKit schema has to be re-initialized in the development environment
and deployed to production, or `summary` will not sync. Nothing in the code does this; it is a
Dashboard step at release time.

## The `og:description` fallback

`HTMLParser` gains `parseDescription(url:html:)`, alongside `parse` and `parseBodyText`. It reads
`og:description` and falls back to `<meta name="description">` — the older form of the same tag,
which plenty of pages still ship alone. Like `parseBodyText`, it re-parses the html rather than
reusing a document, so the result never depends on call order (checked in both orders).

It is only reached on the failure path, so the extra parse costs nothing in the normal case.

## The view-model path

`LinkCollectorViewModel.summarize(link:)`, in a new `// MARK: - Summary` section:

1. Downloads the page again through `LinkCollectorDownloader`. Nothing stores the page text, and a
   link saved two years ago should be summarized as it reads now.
2. `HTMLParser.parseBodyText` → `LinkSummarizer.summarize(text:)`.
3. On any failure — model unavailable on this device, or the model refusing this page — falls back
   to `parseDescription`. What the page says about itself beats showing nothing.
4. Writes `link.summary` and awaits `save()`; a save failure sets `viewModel.message` like every
   other mutator.

Two supporting members: `summarizingLinks: Set<UUID>` (published, since a run takes tens of seconds
and the view has to show progress) and `summaryModelAvailability`, which just forwards
`SystemLanguageModel.default.availability` — `SystemLanguageModel` is `Sendable` and its
`availability` is nonisolated, so the `@MainActor` view model can read it synchronously for gating.

`summarize(link:)` returns the summary rather than relying on the view observing the managed object:
`LinkDetailView` takes `entity` as a plain `var`, not an `@ObservedObject`, so a write to
`link.summary` would not redraw it.

## UI

A fourth header button in `LinkDetailView`, between `note` and `EDIT`, following the `note` popover
pattern exactly (including the AppKit `onHover` cursor branch). `Views/Labels/SummaryLabel.swift`
joins the other five label views. The popover shows, in order of state:

- a `ProgressView` and "Summarizing this page may take a while" while `viewModel.isSummarizing`;
- the stored summary in a `ScrollView`;
- "No summary added" when there is none.

Under that, when `summaryModelAvailability` is `.unavailable`, one caption line naming the reason
(`deviceNotEligible` / `appleIntelligenceNotEnabled` / `modelNotReady`) and saying the page's own
description will be used. The button stays **enabled** in that case, which is the point of having
the fallback — gating it off would leave those devices with nothing. It is disabled only while a
run is in flight or when the link has no url.

The summary is held in `@State`, seeded in `onAppear`. `ContentView` applies `.id(selectedLink)` to
the detail column, so each link gets a fresh view identity and the seed re-runs.

## Verification

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Both succeed. There are no test targets, so — as in the previous two steps — the real sources were
compiled into a throwaway SwiftPM harness on this Mac (macOS 26.6.2, Apple Intelligence available)
and run:

- `parseDescription` fixtures: og:description wins over `name="description"`; `name="description"`
  alone is used; an empty `content` falls through to the other tag; no meta tags yields `nil`;
  empty html yields `nil`. Calling `parseBodyText` and `parseDescription` on one instance gives the
  same results in either order.
- Real pages: MDN and apple.com return their descriptions; **English Wikipedia has neither meta
  tag and returns `nil`** — see below.
- The full sequence from `summarize(link:)`, minus Core Data: MDN summarized in 11.0s, Wikipedia in
  19.8s. With the model call forced to fail, MDN fell back to its description in 0.1s and Wikipedia
  produced nothing.

## Known limits

**A page with no description tag has no fallback.** Wikipedia is the example: if the on-device model
is unavailable, summarizing a Wikipedia link fails with "Cannot summarize" and nothing is stored.
A last-ditch fallback (the first few hundred characters of the extracted body text) was considered
and left out — a truncated lead paragraph presented as a summary is arguably worse than an honest
failure. Worth revisiting if it turns out to be common.

**Found while wiring up the UI — a `LinkSummarizer` behavior, not fixed here.** Multi-chunk pages
can return a summary of 1000–1600 characters instead of the 200–450 the previous step measured.
Diagnosed by instrumenting the chunk loop against Wikipedia's Swift article (4 chunks):

- chunk 0 is regularly refused with `unsupportedLanguageOrLocale` (the language-list boilerplate,
  as already documented) and skipped;
- the surviving *section* summaries vary wildly in how well they obey "at most three sentences" —
  567 and 493 characters for two of them, but 1621 for another;
- the merge step is fine: it compressed three sections to 259 characters.

The long results come from `summarize(text:)`'s `guard sectionSummaries.count > 1 else { return
firstSummary }` — when only one section survives, that section summary is returned verbatim as the
page summary, skipping the compression the merge step would have applied. Three consecutive
Wikipedia runs gave 1623, 1616 and 950 characters. The fix would be to run the single survivor
through the combine (or page) instructions anyway, at the cost of one more model call; that is a
change to step 2's verified code, so it is recorded here rather than made. The popover puts the
summary in a `ScrollView`, so a long one displays correctly meanwhile.

## §3 status

Complete, with two carry-overs: the CloudKit schema deployment above, and the question left open
since step 1 — whether to feed `WKWebView` `innerText` instead of the SwiftSoup extraction, for
JS-rendered pages. Nothing in this step forecloses that; it would replace the `parseBodyText` call
in `summarize(link:)` and leave the rest intact.
