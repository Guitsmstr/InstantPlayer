# E2-S2 · Vertical feed & window — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S16 over product R7–R10, R37–R40). Branch: `feat/e2-s2-vertical-feed-window` — already
checked out; never switch branches mid-story. One task = one commit. Checkboxes are ticked during
implementation, each task's boxes in its own commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task (1–6) loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story is media reading
   (poster extraction of user files) plus SwiftUI feed rendering and paging: both pillar checklists
   apply (design §8, §9), and each task repeats the load step so it cannot be skipped.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy
   (the unavailable state's "Unavailable" included).
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source (picked up
   automatically, no flags); the SwiftLint and SwiftFormat gate steps must pass. Never edit the
   configs to make code pass.
4. **Synchronized groups / D21:** new source files land on disk under `InstantPlayer/` and
   `InstantPlayerTests/` and join their targets automatically. **Never hand-edit
   `project.pbxproj`.** This story needs **no** config change at all (design §1.1): no entitlements,
   no Info.plist keys, no build settings. If anything appears to need one, **stop and report — a
   coordinator escalation (D21), never an implementer edit.**
5. **Gate:** code tasks 1–6 run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Docs tasks 7–8 stage first, then run `./scripts/validate.sh --staged`. Task 9 runs
   the full gate with `--json` **and** the `--uitests` run (spec's UI-test mandate decision; R14 of
   E1-S2). Fix every failure before moving on; the pre-commit hook re-runs the gate on every commit.
   Never weaken the gate; `--no-verify` is forbidden.
6. **Contracts are frozen:** the design §3 seam contract (`preview(for:)` / `discardPreviews()` /
   `wiringProbe()`) and the `MediaPreview` value shape (display bytes + pixel size) are contract —
   name/signature/shape changes are design amendments: stop and report to the coordinator, never
   deviate silently. Same for any design §0 fact that no longer holds.
7. **No invented behavior:** spec non-goals hold — no playback/auto-play/loop/audio (E2-S3), no
   scrub/speed/volume (E3), no ordering (E4-S1), no live sync (E4-S2), no list view (E5-S1), no
   feed chrome (S14), no image zoom/pan, no wrap-around paging (S6), no retry affordance
   (design §7), no in-app picker, no network (D9), no bookmark store (D19).

## Sequencing & parallelism

- **Wave 1 — task 1** (Domain seam + value + stub) is first: everything consumes the protocol.
- **Wave 2 — tasks 2 and 3 `[P]`**: the Data pipeline (2) and the paging state machine (3) are
  independent of each other — 3 is developed against the stub. Both depend only on 1.
- **Wave 3 — tasks 4 and 5 `[P]`**: views (4) and App wiring (5) touch disjoint files; 4 needs 3's
  view-model surface (and 1's value), 5 needs 2's conformance and 3's factory signature. The
  window-lifecycle half of 5 is independent of the preview pipeline entirely (design §6.1).
- **Wave 4 — tasks 6, 7, 8**: mutually independent after the code lands (6 tests tasks 1–5; 7–8 are
  transcription of the approved design). Marked `[P]` where genuinely parallel: 7 and 8 are
  independent of each other and of 6; the coordinator may co-wave any of the three.
- **Task 9 is last** and depends on all others.
- Routing (D3 — coordinator's call): tasks 1–6 → `implementer` (contract-bound code; both skills
  mandatory); tasks 7–8 → `implementer-flash` candidates (approved-design transcription; task 7
  follows the E2-S1 precedent of its own docs commit); task 9 → `implementer` (evidence
  discipline).

---

## Task 1 — Feed Domain: preview seam + value + stub · design §1, §3

Deliverable (code): `InstantPlayer/Features/Feed/Domain/MediaPreviewService.swift`,
`InstantPlayer/Features/Feed/Domain/MediaPreview.swift`,
`InstantPlayer/Features/Feed/Data/StubMediaPreviewService.swift`.

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** `MediaPreviewService.swift` per design §3 — the feature-owned seam (seam-placement
  rule: one consumer, Feed Presentation; architecture §4). Members exactly the frozen contract:
  `preview(for item: MediaItem) async -> MediaPreview?` (the unified failure answer: `nil` covers
  vanished/unreadable (S12) and undecodable/mislabeled (S13); idempotent per item; concurrent
  calls coalesce; cancellation-aware; results display-sized, never full-resolution),
  `discardPreviews() async` (drops cached previews and in-flight work — called on replace-in-place
  (S9) and on welcome), `wiringProbe() async -> String` (house pattern). `Sendable`, async/await
  only, Domain stays Foundation-only (R10 — the `Data`-value decision, design §1.1).
- [x] **1.3** `MediaPreview.swift` per design §3: `imageData: Data` (display-ready encoded image
  bytes) + `pixelWidth` / `pixelHeight: Int` (intrinsic size — the sole input to aspect-fit
  letterboxing, S2). Foundation-only, `Sendable`.
- [x] **1.4** `StubMediaPreviewService.swift` **in this same commit** (a protocol requirement
  without a conformer fails the build): canned `MediaPreview` from constants, zero-I/O — no
  FileManager, no AVFoundation, no ImageIO.
- [x] **1.5** Full gate `./scripts/validate.sh` — the new types must compile (that is what proves
  target membership). Fix, tick this task's boxes, commit:
  `feat(e2-s2): task 1 — preview seam and value types`.

## Task 2 — Feed Data: `AVMediaPreviewService` extraction pipeline · design §4, §5.4

Deliverable (code): `InstantPlayer/Features/Feed/Data/AVMediaPreviewService.swift`.

- [x] **2.1** Load `swift-security` + `swift-performance` before editing (this task reads user
  media bytes — both pillars are directly in play).
- [x] **2.2** The `actor` conforming to `MediaPreviewService` (the second D8 actor, design §1.1 —
  cache + coalescing are mutable state shared across isolation domains). Video (`.video`) per
  design §4.2: `AVAssetImageGenerator` with `appliesPreferredTrackTransform = true`, frame at
  `CMTime.zero` with zero tolerance (the first frame, honestly — S3), the modern async API used
  natively (async/await rule, no callback bridge), cancellation-aware. Exact-frame failure → `nil`
  (S13) — no silent nearby-frame fallback, no generic icon.
- [x] **2.3** Image (`.image`) per design §4.2: `CGImageSourceCreateThumbnailAtIndex` with
  `kCGImageSourceCreateThumbnailFromImageAlways` and max-pixel-size bound **2× the screen's larger
  axis in pixels** (the viewport never exceeds the screen; screen scale included — the design §4.2
  display bound, computed inside the Data conformance so the seam signature stays frozen).
  Aspect-preserving; both paths end in one ImageIO encode to display bytes + intrinsic size.
- [x] **2.4** Fail-`nil` unified contract per design §4.3: vanished/unreadable file (S12) and
  corrupt/mislabeled content (S13 — `fake.mp4` holding text) both answer `nil`; display-time only —
  **no pre-check, no re-scan, no retry** (design §4.3). File content is decode-only: never executed,
  never parsed by name (design §9).
- [x] **2.5** Cache + concurrency per design §5.4: `NSCache` keyed by the item's resolved URL with
  an object box (NSCache requires objects), **cost limit 64 MB** (cost = `imageData` byte count),
  **count limit 32**, automatic eviction; request coalescing per item; **≤ 2 concurrent
  extractions**; superseded/cancelled tasks are dropped, never completed; `discardPreviews()`
  empties cache and in-flight work.
- [x] **2.6** Off-main always (design §8(2)): extraction, decode, downsample, encode run on the
  actor's executor (the project defaults to MainActor isolation — the actor is the explicit
  boundary); the `@MainActor` view model receives only the finished value. No synchronous file I/O
  in any view, view model, or `App` code (skill §1). **No `start/stopAccessingSecurityScopedResource`
  here** — reads happen inside the session D19 already holds (design §9); no logging of paths or
  names.
- [x] **2.7** Full gate; fix; tick; commit:
  `feat(e2-s2): task 2 — preview extraction pipeline`.

## Task 3 — Paging & display state machine in `FeedViewModel` · design §5.2, §5.5, §6.2, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (extended;
existing tests updated to compile in the same commit if signatures move).

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** Paging state per design §5.1–§5.2: the current item (index/id over
  `collection.items` — the snapshot order, S1) held in the view model (D8 — the only presentation-
  state holder); the `scrollPosition` binding surface is a projection calling view-model methods,
  never view state. `pageForward()` / `pageBackward()` move exactly one item (S5), clamped at both
  ends with **no wrap** (S6).
- [x] **3.3** Gesture guard per design §5.2 as **pure, unit-testable logic**: record `gestureStart`
  at scroll onset; at settle compute the net direction from the index delta and require the final
  index to be exactly `gestureStart ± 1` (direction sign), clamped at the ends; correct any other
  landing (multi-page momentum, snap-back); zero-net gesture at an end does not page (S4, S6).
  Expose the correction as a pure function the tests can drive without scroll hardware.
- [x] **3.4** Display states per design §7: per-item states (`.loading` / `.preview(MediaPreview)` /
  `.unavailable`) keyed by item id; `preview(for:)` success → `.preview` (S3), `nil` → `.unavailable`
  **sticky, no auto-retry** (S12, S13). The current item loads first (§5.5).
- [x] **3.5** Prefetch window per design §5.5 (RNF-02): request previews only for **current ± 1**;
  slide the window on page changes — new edge items load, dropped-edge in-flight work is cancelled
  (≤ 2 concurrent extraction calls across the window). Nothing beyond the window is ever requested.
- [x] **3.6** Replace-in-place per design §6.2 (S9): on every transition to `folderOpen`, set the
  current item to `collection.startIndex` (the inherited E2-S1 contract) and call
  `discardPreviews()`; a generation counter (the E2-S1 last-wins pattern) drops late results for
  the superseded collection — a stale preview never paints. The welcome transition discards display
  state too (S16 — no paging state in welcome).
- [x] **3.7** Full gate (update any existing `FeedViewModelTests` compile breaks in this same
  commit — minimal fixes; the full suites are task 6). Fix, tick; commit:
  `feat(e2-s2): task 3 — paging and display state machine`.

## Task 4 — Views: paging feed + item cell · design §2, §5.1, §5.3, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (folderOpen branch
rewritten), `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (new).

- [x] **4.1** Load `swift-security` + `swift-performance` before editing (SwiftUI views + image
  display — skill §2 applies directly).
- [x] **4.2** Paging surface per design §5.1: `ScrollView(.vertical)` + `LazyVStack` (lazy — a 
  1,000-item folder instantiates only near-viewport cells) inside `.scrollTargetLayout()`; each
  page `.containerRelativeFrame([.horizontal, .vertical])` (the page **is** the viewport — which is
  the whole resize/fullscreen story, S2/S10/S11); `.scrollTargetBehavior(.paging)` (magnetic snap —
  resting state always one full item, S4); `scrollPosition(id:)` bound two-way to the view model
  (task 3). The interim placeholder is replaced outright (S1); items render in `collection.items`
  order (S1 — never sorted).
- [x] **4.3** Input wiring per design §5.2–§5.3: `onScrollPhaseChange` reports gesture onset/settle
  to the view model's guard (S4); `.onKeyPress(.downArrow/.upArrow)` calls `pageForward()` /
  `pageBackward()` (S5). Resize and native fullscreen need **no code** — do not add any (S10, S11).
- [x] **4.4** `FeedItemView` per design §2, §7: one page cell — aspect-fit poster built from
  `MediaPreview.imageData` + intrinsic size, centered on the window background (letterboxing, S2;
  video items show the static first-frame poster, S3 — no motion, no transport); the neutral
  unavailable state (one system symbol + "Unavailable" — **no file name**, no error codes, S12–S14);
  a neutral `.loading` presentation. The `Data` → platform image wrap is display-only — done once
  per state change, never per frame, never decoded in `body` (design §1.1, §8(2)).
- [x] **4.5** Clean viewport (S14): `.scrollIndicators(.hidden)`; **no** file-name overlay,
  position counter, scrollbar, or any other chrome anywhere in the feed. The welcome branch is
  untouched (S16) — keep its accessibility identifier so the launch UI tests stay green.
- [x] **4.6** Full gate. Fix, tick; commit:
  `feat(e2-s2): task 4 — vertical feed views`.

## Task 5 — App: composition + close-quits lifecycle · design §1, §6.1

Deliverable (code): `InstantPlayer/App/AppDelegate.swift` (new),
`InstantPlayer/App/InstantPlayerApp.swift` (adaptor registration),
`InstantPlayer/App/AppDependencies.swift` (preview binding + factory). `RootView.swift` unchanged.

- [x] **5.1** Load `swift-security` + `swift-performance` before editing.
- [x] **5.2** Close-quits per design §6.1 (S8): `AppDelegate` implementing
  `applicationShouldTerminateAfterLastWindowClosed` → `true`, registered via
  `NSApplicationDelegateAdaptor` in `InstantPlayerApp` — App-owned scene/lifecycle policy (D10),
  the canonical three-line hook. The `Window` scene itself is unchanged (D18, S7). **Do not build
  D18's entry-routing fallback** — the adaptor here is the termination policy only; a divergence is
  a coordinator escalation, not an implementer improvisation.
- [x] **5.3** Composition per design §1: `AppDependencies` binds `AVMediaPreviewService` as the
  `MediaPreviewService` seam (default parameter alongside the two existing seams — tests inject
  conformances through the same initializer); `makeFeedViewModel()` passes all three seams. `init`
  stays **allocation-only** (R13 of E1-S3, design §8(5)) — one more binding allocation, nothing
  scheduled, no media touched at launch.
- [x] **5.4** D21 audit point (design §1.1, §9): confirm this task introduces **no** change under
  `InstantPlayer.xcodeproj/` or `InstantPlayer/Config/` — no entitlements, no plist keys, no build
  settings. Any apparent need → stop and report.
- [x] **5.5** Full gate. Fix, tick; commit:
  `feat(e2-s2): task 5 — composition and close-quits lifecycle`.

## Task 6 — Unit suites: paging/display machine + preview seam + perf `[P]` · design §8(1), §10.1, §10.2

Deliverable (code): `InstantPlayerTests/` — extended `FeedViewModelTests`, preview-seam suite,
fixture helper additions, the §8(1) performance test.

- [ ] **6.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **6.2** Frameworks per house pattern: Swift Testing (`@testable import InstantPlayer`,
  `@Test` + `#expect`) for the suites; the design §8(1) performance test uses XCTest `measure`
  exactly as the design names it — the one deliberate exception.
- [ ] **6.3** Paging & display state machine per design §10.1 (injected `MediaFolderRepository` +
  `MediaPreviewService` doubles — no UI, no scroll hardware, no running app), row by row:
  folder-open → current = `collection.startIndex` (S1, S9); `pageForward`/`pageBackward` → ±1 (S5);
  clamping at both ends, no wrap, both mechanisms (S6); **gesture guard**: multi-page landing →
  corrected to `gestureStart ± 1` in the net direction, snap-back → `gestureStart + direction`,
  zero-net at an end → no page (S4 — pure-logic tests); replace-in-place → new `startIndex`,
  `discardPreviews()` invoked, late result for the old collection never paints (S9); preview
  success → `.preview` (S3); `nil` → `.unavailable` sticky, no auto-retry (S12, S13); prefetch
  window → loads for current ± 1 only, current first, dropped-edge requests cancelled (RNF-02);
  welcome → no paging/display state (S16).
- [ ] **6.4** Preview seam per design §10.2 (Feed Data suite + fixtures): a throwaway-folder helper
  (E2-S1 §9.1's pattern) with a tiny **real** one-frame MP4 written by `AVAssetWriter` in setup
  (honest extraction needs real bytes), small PNG/JPEG constants of known aspect ratio, and junk
  cases. Rows: video → first-frame preview (S3); image → downsampled preview with the source's
  aspect (S2); text bytes named `fake.mp4` → `nil` (S13 — D20's honest contract, pinned);
  nonexistent URL → `nil` (S12); output pixel size bounded by the display bound (downsample proof);
  concurrent calls for one item → one extraction (coalescing); cancelled task → no completed
  extraction; `discardPreviews()` empties the cache.
- [ ] **6.5** Performance test per design §8(1): XCTest `measure` through the seam over the
  generated fixtures. Budget: page-settle → fully displayed **≤ 300 ms p95** typical (≤ 1080p
  clips, ≤ 24 MP stills) and **≤ 1 s p95** heavy media on Apple-silicon reference hardware. The
  measured numbers are recorded in task 9's evidence **from tooling, never from memory**.
- [ ] **6.6** UI tests: **none added** (design §10.3 — the feed is unreachable without host-driven
  entry; the spec's honest caveat). Verify the existing launch tests still pass unchanged
  (welcome at plain launch, S16; `testLaunchPerformance` as the launch-cost guard).
- [ ] **6.7** Full gate — the tests run and must be green. Fix, tick; commit:
  `test(e2-s2): task 6 — paging, display, and preview-seam tests`.

## Task 7 — Architecture reference updates `[P]` · design §13

Deliverable (docs): `docs/architecture.md` — the three required same-story updates (design §13).
Follows the E2-S1 precedent: the standing architecture reference is updated by its own docs commit
once the code it documents has landed (tasks 1–5).

- [ ] **7.1** Update `docs/architecture.md` exactly per design §13: (1) **§3 source tree** gains
  this story's files and re-annotations (`MediaPreviewService.swift`, `MediaPreview.swift`,
  `AVMediaPreviewService.swift`, `StubMediaPreviewService.swift`, `FeedItemView.swift`,
  `App/AppDelegate.swift`; `FeedViewModel`/`FeedView` re-annotated as the paging state machine /
  paging feed); (2) **§4 check (3)** gains the design §1.1 display-bytes refinement — display-ready
  `Data` (pre-decoded, downsampled image bytes) may travel as an opaque value like `URL`, and
  Presentation may wrap display bytes into platform image types (a wrap, not processing); (3)
  **§8's actor note** names `AVMediaPreviewService` as the second D8 actor (preview cache +
  coalescing state).
- [ ] **7.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [ ] **7.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e2-s2): task 7 — architecture reference updates`.

## Task 8 — ADR batch D22–D24 `[P]` · design §11

Deliverable (docs): `docs/decisions.md` — append D22–D24.

- [ ] **8.1** Append three ADRs continuing the numbering (the log currently ends at D21), house
  heading `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each with context,
  decision, alternatives, consequences. Titles and one-line decisions exactly per design §11:
  **D22 — Feed paging: SwiftUI paging `ScrollView` with a view-model-owned index** (→ S1, S2,
  S4–S6, S10, S11, S14) · **D23 — Media previews behind a Feed-owned `MediaPreviewService`;
  `Data`-valued display bytes** (→ S3, S12, S13) · **D24 — Close-quits via
  `applicationShouldTerminateAfterLastWindowClosed`** (→ S8).
- [ ] **8.2** Pull each entry's alternatives from the matching design §12 rows —
  D22: `TabView` + `.tabViewStyle(.page)`, custom drag gesture with manual offsets,
  `NSScrollView`/AppKit paging, trusting `.paging` alone for S4's exact contract; D23: extending
  `MediaPlayerService` with `firstFrame(for:)`, per-item `AVPlayer` frame grabs,
  `QLThumbnailGenerator`, full-resolution decode scaled in the view, the cache in the view model or
  `Core/`, file pre-checks; D24: `RootView.onDisappear` termination, `NSWindowDelegate`
  `windowWillClose`, `exit(0)`.
- [ ] **8.3** Status `accepted`. Each entry cites its implementing task commits (tasks 2–5) in its
  consequences; D23 carries the honest cache policy (in-memory only, discarded with the session) and
  D22 the honest guard rationale (S4 rests on our logic, not momentum behavior).
- [ ] **8.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; tick; commit:
  `docs(e2-s2): task 8 — ADRs D22–D24 — paging, previews, and window lifecycle`.

## Task 9 — Verification & evidence · spec acceptance criteria, design §8, §10

Deliverable (docs): `docs/specs/e2-s2-vertical-feed-window/evidence.md` (new) +
acceptance-criteria ticks in this file.

- [ ] **9.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **9.2** Traceability walk: **S1–S16 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product R-map**
  of the spec's acceptance table (product R7–R10, R37–R40 → story outcome → verified by), plus the
  S15/R16 cross-cutting note. Record both tables in evidence.md.
- [ ] **9.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/e2-s2-gate.json` (`<tmp>` = session temp dir outside the
  repo; the JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every
  step name and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [ ] **9.4** **UI-test mandate (spec Story context; R14 of E1-S2):** run
  `./scripts/validate.sh --uitests --json <tmp>/e2-s2-uitests-gate.json` and quote it **verbatim**
  (design §10.3). The run is additive and fail-closed: a failing UI test fails it; the flag never
  skips or weakens a step ([docs/development.md](../../development.md) §3).
- [ ] **9.5** Record from tooling, never from memory: the design §8(1) performance measurement
  (the `measure` run's numbers against the 300 ms / 1 s budgets, from task 6.5) and the **D21
  audit** (design §1.1, §9): the `codesign -d --entitlements` output showing the four D19 keys
  **unchanged**, and the `git diff main...HEAD` stat restricted to
  `InstantPlayer.xcodeproj/ InstantPlayer/Config/` showing **no changes** (empty output quoted).
- [ ] **9.6** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, UI copy, budgets) with its impact, marked for coordinator ratification — silently
  deviating is forbidden (standing rule 6).
- [ ] **9.7** Tick AC1–AC8 below and mirror them in evidence.md; leave the converge-owned AC9–AC11
  unticked.
- [ ] **9.8** Commit (docs-only): `docs(e2-s2): task 9 — evidence and acceptance`.

---

## Acceptance criteria

Ticked by task 9, each backed by quoted tooling evidence:

- [ ] **AC1 · R7, R8 / S1–S3** — one combined vertical feed in snapshot order (never sorted);
  current item letterboxed, filling the viewport; video items honestly show a static first-frame
  poster (unit tests + stakeholder functional review).
- [ ] **AC2 · R9, R10 / S4–S6** — paging semantics covered by unit tests on the state machine (one
  item per gesture via the guard's pure logic — including multi-page and snap-back corrections;
  ↓/↑ move one item; clamping with no wrap at both ends, both mechanisms) and functional review
  (magnetic snap, always a full item).
- [ ] **AC3 · R37–R40 / S7–S11** — single resizable window showing the feed; closing it quits the
  app; a new open replaces the collection in place at its starting item (generation-guarded);
  resize and native fullscreen keep the current item filling the view — functional review.
- [ ] **AC4 · S12, S13** — fail-safe display unit-tested and reviewed: vanished/unreadable item and
  mislabeled video (`fake.mp4`) both show the neutral unavailable state — no file name, sticky, no
  retry — and the feed stays navigable.
- [ ] **AC5 · S14–S16, RNF-02** — chrome-free viewport (no name overlay, counter, scrollbar);
  responsiveness budgets (design §8(1): 300 ms / 1 s) measured and recorded from tooling; zero
  added launch cost — `testLaunchPerformance` intact and green; welcome state unchanged (launch
  assertion green).
- [ ] **AC6 · RNF-04** — media reads only inside the open session (D19); derived data in memory
  only, discarded with the session (S9); names display-only; **no entitlement/plist/pbxproj diff**
  (D21 audit: empty diff + unchanged `codesign` output recorded); design §9.1 review table walked.
- [ ] **AC7 · R14 (E1-S2)** — the `--uitests` converge-mandate run is green and quoted verbatim
  (design §10.3: no new UI tests — feed presentation is host-driven-entry territory).
- [ ] **AC8 · evidence & coverage** — full gate `--json` quoted verbatim (lint/format `pass`); the
  S1–S16 + product R-map walk recorded; D22–D24 in `docs/decisions.md` house format; the design §13
  architecture updates done; all deviations listed honestly.

Converge-owned — the coordinator ticks these; task 9 never does:

- [ ] **AC9 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — the design §10.4 list: mixed feed with letterboxing, static video
  poster, scroll paging one item per gesture, arrow paging, stops at both ends, resize, native
  fullscreen, replace-in-place at the starting item, close quits, unavailable states (vanished
  file + mislabeled video); explicit approval required.
- [ ] **AC10 · validator review** — adversarial PASS over spec S1–S16 and the product R-map,
  design §9.1's review table, and both pillar-skill checklists.
- [ ] **AC11 · story closure** — backlog E2-S2 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e2-s2-vertical-feed-window`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review of the feed in the running app
   (`./scripts/app.sh run`): the AC9 list (design §10.4).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S16 / product R-map
   and design §10's test tables + §9.1's review table.
3. **Converge run** — `./scripts/validate.sh --uitests` (the UI-test mandate's final run) alongside
   the functional review; its output is the story's final gate record.
4. **Closure** — tick AC9–AC11, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §13: **E2-S3** adds the `.player` display state under the current item
(`MediaPlayerService` grows real members) and keeps `MediaPreviewService` for neighbors — it must
not re-scan the folder (E2-S1 §6) or re-derive the session (D19); **E3** places controls into the
chrome-free viewport; **E4-S2** supersedes S12's stale-item fail-safe with live removal semantics.

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D21; task 8 appends D22–D24)
- [docs/spec.md](../../spec.md) — product source of truth (product R7–R10, R37–R40; R16; RNF-02,
  RNF-04)
- [docs/architecture.md](../../architecture.md) — seam placement, layering; task 7 applies design
  §13
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S2) and the E2–E5 coverage note
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
