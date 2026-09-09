# 2026-09-04 — Body-text extraction in `HTMLParser`

First step of `2026.md` §3 (Apple Intelligence — summarize the content of the link): the app had no
way to get at a page's *body* text. `HTMLParser` only ever populated `title` and `ogTitle`, so there
was nothing to feed a summarizer. This adds the extraction path; no model call and no schema change
yet — those are the later bullets of §3.

## What was added

`LinkCollector/ViewModel/HTMLParser.swift`:

- `parseBodyText(url:html:) -> String?` — the public entry point, alongside the existing
  `parse(url:html:)`. Returns `nil` rather than an empty string when nothing readable is found.
- `populateBodyText(document:)` — the heuristic, and a `bodyText` stored property matching the
  existing `title`/`ogTitle` shape.
- Three selector constants: `noiseSelector`, `contentSelector`, `minimumContentLength`.

The heuristic, as planned in `2026.md`:

1. Strip the noise: `script, style, noscript, template, nav, aside, form, iframe, svg`, plus the
   ARIA landmark roles `[role=navigation]`, `[role=banner]`, `[role=complementary]`,
   `[role=contentinfo]`, `[role=search]`.
2. Select `article, main, [role=main]` and take the candidate with the *most* text — index pages
   often hold several short `<article>` teasers, and the longest one is the real content when a page
   genuinely has one.
3. If the best candidate is under 200 characters, treat it as boilerplate and fall back to the whole
   `<body>` text.

Two deliberate choices worth recording:

- **The bare `header` and `footer` tags are not stripped**, only their landmark-role equivalents
  (`[role=banner]` / `[role=contentinfo]`). Inside an `<article>`, `<header>` is usually where the
  headline lives, and dropping it would lose the single most useful line for a summarizer. The
  landmark roles reach the *site* chrome without touching the article's own header.
- **`parseBodyText` re-parses the html** instead of reusing a document left over from
  `parse(url:html:)`. Stripping noise mutates the document in place, so sharing one would make the
  result depend on call order. Each `HTMLParser` instance is already created per call site, so the
  cost is one extra parse only if both methods are called on the same instance.

Existing callers are untouched: `LinkCollectorViewModel.process(urlString:)` and both share
extensions still call `parse(url:html:)` and get a title. Per the plan, summarization runs in-app on
demand, not in the share extensions.

## Verification

Both targets build clean:

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' build
```

There are no test targets in this repo, so the heuristic itself was checked by running the same
logic against the same SwiftSoup checkout in a throwaway SwiftPM harness:

- synthetic fixtures — an `<article>` page, an index page of short teasers, a page with no
  `article`/`main` at all, a page with two `<article>`s of different lengths, and a `[role=main]`
  page. All five picked the intended text, and none leaked nav/script/style/aside content. Empty
  html yields `nil`.
- real pages — MDN's HTTP caching article (43k chars of raw body text → 33k extracted, starting
  exactly at the headline) and the English Wikipedia article on Swift (63k → 59k).

Known limit, accepted for now: Wikipedia's language switcher and category footer are plain `div`s
with no nav tag and no landmark role, so they survive. Site-specific rules would be needed to reach
them, which is out of proportion to the payoff — the article text dominates what gets extracted, and
a summarizer tolerates the residue.

## Next in §3

- Decide between this SwiftSoup path and pulling `innerText` from the `WKWebView` in
  `LinkDetailView` (handles JS-rendered pages this can't).
- Add the `og:description` fallback for when the on-device model is unavailable — `HTMLParser`
  already reads the same meta tags for `ogTitle`.
- Confirm the Foundation Models context-window limit and pick truncation vs. chunk-then-combine.
- Schema: optional `summary: String?` on `LinkEntity` in `LinkCollector 2.xcdatamodel`.
- UI: an on-demand summarize button in `LinkDetailView`, gated on `SystemLanguageModel.availability`.
