# 2026-09-04 — `LinkSummarizer`: the on-device Foundation Models call

Second step of `2026.md` §3, following `docs/worklog/2026-09-04-html-body-text.md`. Takes the body
text that step extracts and turns it into a summary with the on-device model. Still no schema change
and no UI — the summary isn't persisted or shown yet.

## The context window, confirmed rather than assumed

The plan said to confirm the limit before implementing. From the macOS 26.5 SDK's
`FoundationModels.swiftinterface`:

```swift
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@backDeployed(before: iOS 26.4, macOS 26.4, visionOS 26.4)
final public var contextSize: Swift.Int { get { 4096 } }
```

So **4096 tokens per session**, covering instructions, prompt and response together — and because
`contextSize` is back-deployed, it can be read at our 26.0 deployment target instead of hardcoding
the number. Printing it on this Mac returns 4096. Apple's "Managing the context window" article
gives the conversion: a token is three to four characters in Latin scripts, but about **one
character** in Chinese, Japanese, Korean and Vietnamese.

Two other API facts worth recording, both checked in the same interface file:

- `SystemLanguageModel.tokenCount(for:)` would size prompts exactly, but it is iOS/macOS **26.4+**
  and is *not* back-deployed, so it's unusable at a 26.0 target. Hence the character estimate.
- The error is `LanguageModelSession.GenerationError.exceededContextWindowSize`. (Apple's web docs
  now name a `LanguageModelError.contextSizeExceeded`; no such type exists in this SDK. The docs are
  ahead of the shipping interface — go by the interface.)

## What was added

- `LinkCollector/ViewModel/LinkSummarizer.swift` — an `actor`, matching `HTMLParser` /
  `SearchHelper` / `LinkCollectorDownloader`.
- `LinkCollector/ViewModel/LinkSummarizerError.swift` — `unavailable(UnavailableReason)`,
  `noContent`, `generationFailed(GenerationError)`, following the existing `HTMLParserError` split.

Both are members of the `LinkPiler` app target only — per the plan, summarization does not go in the
share extensions.

Design, in the order the code runs:

1. **Availability gate.** `SystemLanguageModel.default.availability`; `.unavailable(reason)` throws
   `LinkSummarizerError.unavailable(reason)` so a caller can fall back rather than guess why.
2. **Character budget.** `contextSize - responseTokenBudget(300) - overheadTokenBudget(250)`, times
   3 characters per token — or **1** when at least 20% of a 2000-character sample falls in the
   Hangul/kana/CJK ranges. Without that branch a Korean page would be budgeted at three times the
   window. This matters for this app specifically: Korean links are ordinary here, not an edge case.
3. **Chunk, don't just truncate.** Long pages are split on whitespace boundaries, each chunk is
   summarized on its own, and the section summaries are merged by a final call. Capped at **4
   chunks**, since each is a model call and the cap is what bounds how long one tap can take;
   anything past the fourth chunk is dropped.
4. **A fresh `LanguageModelSession` per call.** A session accumulates every prompt and response in
   its transcript, so reusing one across chunks would spend the 4096-token window on earlier chunks.
   This is the single easiest way to get this wrong.
5. **Recovery.** `exceededContextWindowSize` halves the prompt and retries (recursive, with a
   500-character floor). A chunk that fails for any other reason is skipped, not fatal — see below.

## What testing on the real model changed

The host runs macOS 26.6.2 with Apple Intelligence available, so `LinkSummarizer.swift` and its
error file were compiled straight into a throwaway `swiftc -swift-version 6` harness — the actual
source, not a copy — and run against the body text extracted in step 1 from MDN's HTTP caching
article (33k chars), English Wikipedia's Swift article (59k), Korean Wikipedia's (38k), and a short
paragraph. Three findings changed the code:

- **Wikipedia failed outright** with `unsupportedLanguageOrLocale`, in 0.0s. Cause: the extracted
  text opens with Wikipedia's 52-language list, and the model refuses that chunk. One refused chunk
  killed the whole summary. Chunk failures are now collected rather than propagated — the summary
  fails only if *every* chunk fails. Wikipedia summarizes fine now.
- **A "write in the same language as the text" instruction made output worse**, so it was removed.
  The control run shows the model already answers in the page's language unaided; with the clause it
  mixed languages, hallucinated the word "Swift" into "Suisseft"/"Suisse", and emitted bullet lists.
- **Format compliance was poor and cost real quality.** Responses ran 1000–1500 characters with
  preambles and bullets, long enough to hit the 300-token cap and get cut off mid-word — exactly the
  failure Apple warns about for `maximumResponseTokens`. Tightening the instructions to "Reply with
  at most three sentences and nothing else: no preamble, no heading, no bullet list, no code" was
  clean in 6/6 A/B trials against the old wording (2 of 6 messy) and cut responses to 200–450
  characters, so the cap no longer truncates.

`cleaned(_:)` is a narrow backstop for the same problem: drop a leading line ending in `:` when more
text follows, and join the rest into one paragraph.

Final state, two consecutive full runs: all four pages summarize, 11–19s for the long ones and 0.7s
for the short one, no failures.

## Verification

```
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=macOS' build
xcodebuild -project LinkPiler.xcodeproj -scheme LinkPiler -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Both succeed. There are no test targets, so the on-device harness above is the functional evidence.

## Known limits, not defects

- `unsupportedLanguageOrLocale` is **intermittent** — the same Korean input that failed one run
  succeeded the next two. Per-chunk tolerance is the reason this no longer matters much, but a
  caller must still expect `generationFailed`.
- The model sometimes mangles proper nouns on Korean pages ("Swift" → "Sprint"), and sometimes runs
  past three sentences. Model behavior, not something the code can fix.
- Which language a summary comes back in is not stable, and is now left unspecified. If it should
  always follow the device language, that is a deliberate follow-up.
- 4 chunks × ~10.6k characters covers ~42k characters of Latin text; a longer page is truncated.

## Next in §3

- Schema: optional `summary: String?` on `LinkEntity` in `LinkCollector 2.xcdatamodel`.
- The `og:description` fallback for when `availability` is `.unavailable` or the call throws.
- UI: an on-demand summarize button in `LinkDetailView`, with progress — 11–19s needs to be visible.
- Still open from step 1: whether to feed `WKWebView` `innerText` instead, for JS-rendered pages.
