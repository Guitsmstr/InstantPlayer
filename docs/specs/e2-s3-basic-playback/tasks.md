# E2-S3 · Basic playback — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S16 over product R11, R12, R15, R17). Branch: `feat/e2-s3-basic-playback` — already
checked out; never switch branches mid-story. One task = one commit. Checkboxes are ticked during
implementation, each task's boxes in its own commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task (1–7) loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story plays user media
   files (read-only playback of user data — security) across timing, threads, and SwiftUI views
   (start latency, teardown, rendering — performance): both pillar checklists apply (design §8, §9),
   and each task repeats the load step so it cannot be skipped.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy.
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source (picked up
   automatically, no flags); the SwiftLint and SwiftFormat gate steps must pass. Never edit the
   configs to make code pass.
4. **Synchronized groups / D21:** new source files land on disk under `InstantPlayer/` and
   `InstantPlayerTests/` and join their targets automatically. **Never hand-edit
   `project.pbxproj`.** This story needs **no** config change at all (design §1.1, §9): no
   entitlements, no Info.plist keys, no build settings — the D21 audit expects a **zero
   project-config diff**. If anything appears to need one, **stop and report — a coordinator
   escalation (D21), never an implementer edit.**
5. **Gate:** code tasks 1–7 run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Docs tasks 8–9 stage first, then run `./scripts/validate.sh --staged`. Task 10 runs
   the full gate with `--json` **and** the `--uitests` run (spec's UI-test mandate decision; R14 of
   E1-S2). Fix every failure before moving on; the pre-commit hook re-runs the gate on every commit.
   Never weaken the gate; `--no-verify` is forbidden.
6. **Contracts are frozen:** the design §2 seam contract — `MediaPlayerService.startPlayback(for:)
   async -> MediaPlayback?` + `wiringProbe()`; the `MediaPlayback` handle (`events: AsyncStream<
   MediaPlaybackEvent>`, `pause()`, `resume()`, `restart()`, `stop()`, `makeDisplayView() ->
   AnyObject`); the `MediaPlaybackEvent` cases (`.readyForDisplay`, `.reachedEnd`, `.failed`) — and
   the design §6 route table (space keyCode 49 → `.togglePlayback`, repeat → `.ignore`; 125/126 →
   pages; ⌘/⌥/⌃ and everything else → `.passThrough`) are contract. Name/signature/shape changes
   are design amendments: stop and report to the coordinator, never deviate silently. Same for any
   design §0 fact that no longer holds. (Design §3's arrow-phase fallback is design-sanctioned but
   becomes a **ratified deviation** with its own record if taken.)
7. **No invented behavior:** spec non-goals hold — no scrub/seek/timeline UI and no drag-on-video
   scrubbing (E3-S1; foreclosed by spec S7's consequence), no speed (E3-S2), no volume/mute (E3-S3 —
   never set `isMuted`/`volume`), no transport chrome — no controls, progress indicator, or play
   button (S8; the frozen frame is the only pause indication), no auto-advance (S11), no resume or
   persistence of playback state (S10, S13 — no `UserDefaults`), no double-click meaning (spec
   non-goal), no retry affordance (design §7), no image playback (S4), no ordering (E4-S1), no live
   sync (E4-S2), no network (D9), no bookmark store (D19), no logging of paths or file names (D20).
   Space auto-repeat is **consumed and ignored** — never a play/pause flap.

## Sequencing & parallelism

- **Wave 1 — task 1** (Domain seam + session handle + stub) is first: everything consumes the
  protocol, and the stub lands in the same commit (a protocol without a conformer fails the build).
- **Wave 2 — tasks 2 and 3 `[P]`**: the Data conformance (2) and the view-model policy (3) are
  independent of each other — 3 is developed against the stub from 1. Both depend only on 1.
- **Wave 3 — tasks 4, 5, 6 `[P]`**: App input (4), views (5), and composition (6) touch disjoint
  files; 4 needs 3's toggle methods, 5 needs 3's display-state surface and 1's handle, 6 needs 2's
  conformance. The key-router half of 4 is independent of playback entirely (design §6).
- **Wave 4 — tasks 7, 8, 9 `[P]`**: mutually independent once the code lands (7 tests tasks 1–6;
  8–9 are transcription of the approved design; 8 follows the rename that lands with task 4, so it
  runs after wave 3). The coordinator may co-wave any of the three.
- **Task 10 is last** and depends on all others.
- Routing (D3 — coordinator's call): tasks 1–7 → `implementer` (contract-bound code; both skills
  mandatory; task 4 is small but contract-sensitive — still `implementer`); tasks 8–9 →
  `implementer-flash` candidates (approved-design transcription; task 8 follows the E2-S1/E2-S2
  precedent of its own docs commit); task 10 → `implementer` (evidence discipline).

---

## Task 1 — Feed Domain: playback seam + session handle + stub · design §1, §2

Deliverable (code): `InstantPlayer/Features/Feed/Domain/MediaPlayerService.swift` (grown),
`InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (new),
`InstantPlayer/Features/Feed/Domain/MediaPlaybackEvent.swift` (new),
`InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (extended).

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** `MediaPlayerService` per design §2 — the feature-owned seam grown to its real members
  (seam-placement rule unchanged: one consumer, Feed Presentation; architecture §4). Exactly the
  frozen contract: `@MainActor` (design §1.2's decision: D8's trigger unmet — no mutable state
  shared across isolation domains — and synchronous bite is contract), `AnyObject`;
  `startPlayback(for item: MediaItem) async -> MediaPlayback?` (supersedes and tears down any
  previous session — exactly one live player; starts playing **with audio unmuted** (S1, S3 — the
  conformance never touches `isMuted`/`volume`); returns the opaque session handle or `nil`, the
  unified failure answer for vanished (S15) and mislabeled/unplayable (S14, D20) alike);
  `wiringProbe() async -> String` (house pattern). Domain stays Foundation-only (R10).
- [x] **1.3** `MediaPlayback.swift` per design §2 — the opaque playback-session handle
  (`@MainActor protocol … : AnyObject`, Foundation-only): `var events: AsyncStream<
  MediaPlaybackEvent> { get }` (finished by `stop()`), `pause()` / `resume()` / `restart()` /
  `stop()` (all synchronous; `stop()` and `pause()` must bite before returning — design §8(2)),
  `makeDisplayView() -> AnyObject` (the display-ready platform view — the design §1.1
  architecture wording extension; Presentation wraps it, never processes it).
- [x] **1.4** `MediaPlaybackEvent.swift` per design §2: `nonisolated enum` with exactly
  `.readyForDisplay`, `.reachedEnd`, `.failed` — pure values.
- [x] **1.5** `StubMediaPlayerService.swift` extended **in this same commit** (the composition still
  binds the stub until task 6, and the E2-S3 view model must compile from this commit on):
  stub `MediaPlayerService` vending stub handles — zero-I/O, no AVFoundation, canned/never-failing
  per the house stub pattern (tests use their own scripted doubles, task 7).
- [x] **1.6** Full gate `./scripts/validate.sh` — the new types must compile (that is what proves
  target membership). Fix, tick this task's boxes, commit:
  `feat(e2-s3): task 1 — playback seam, session handle, and stub`.

## Task 2 — Feed Data: `AVMediaPlayerService` + `AVMediaPlayback` · design §1.2, §2–§5, §7

Deliverable (code): `InstantPlayer/Features/Feed/Data/AVMediaPlayerService.swift` (new),
`InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (new).

- [x] **2.1** Load `swift-security` + `swift-performance` before editing (this task plays user
  media bytes and owns the timing-critical stop/start surface — both pillars are directly in play).
- [x] **2.2** `AVMediaPlayerService` per design §1.2, §2 — `@MainActor final class` (not an actor:
  D8's trigger unmet, and `pause()`/`stop()` need synchronous bite). `startPlayback(for:)`: supersede
  and tear down any previous session first (exactly one live player — design §3, §8(3)); build
  `AVURLAsset` + `AVPlayerItem` with the modern async `load(_:)` keys (asset I/O stays inside
  AVFoundation's threads — skill §1, never main-thread); unplayable/failed load → `nil` (S14, S15);
  then start with `playImmediately(atRate: 1)` (design §0.1 — local files wait for nothing,
  `automaticallyWaitsToMinimizeStalling` is not the tool here), audio unmuted (S3).
- [x] **2.3** `AVMediaPlayback` per design §2, §5 — one session: `AVPlayer` + its item,
  `actionAtItemEnd = .none`; observation → the event stream **marshaled to the main actor at the
  boundary** (design §1.2): `didPlayToEndTime` → `.reachedEnd` (S11's trigger), `AVPlayerItem`
  `.failed` → `.failed` (S14), `AVPlayerLayer.isReadyForDisplay` → `.readyForDisplay` (the
  poster→player swap gate, design §4). `stop()` finishes the stream and removes every observer
  (design §3 brace 1).
- [x] **2.4** Commands per design §2, §8(2): `pause()` / `resume()` / `stop()` synchronous —
  `stop()` also detaches the item and releases the display view (players, decoders, observers never
  outlive the session — skill §3); `restart()` = seek to zero + play (S11's mechanism — the *policy*
  stays in the view model, task 3); `makeDisplayView()` = a layer-hosting `NSView` with
  `AVPlayerLayer`, `videoGravity = .resizeAspect` (design §4: aspect-fit letterbox inside the
  viewport-sized cell — E2-S2 S2's contract carries; resize/fullscreen need no geometry code).
- [x] **2.5** Security per design §9 (R17, S12, S13): reads only inside the session D19 already
  holds — **no** `start/stopAccessingSecurityScopedResource` here; playback APIs only
  (`AVURLAsset`/`AVPlayerItem`/`AVPlayer`/`AVPlayerLayer` — **no** export/reader/writer, no
  re-encode path); nothing written anywhere — no sidecars, no disk caches, no persistence
  (no `UserDefaults`); file content is played, never executed (skill §4); no logging of paths or
  names.
- [x] **2.6** Full gate. Fix, tick; commit:
  `feat(e2-s3): task 2 — AV player service and playback session`.

## Task 3 — Playback policy in `FeedViewModel` · design §3, §6 (guard), §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (extended;
existing tests updated to compile in the same commit if signatures move).

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** Session ownership + settle-gated auto-play per design §3 (S1, S2): the view model
  holds the current `MediaPlayback` handle (the only holder — D8); `syncPlayback()` starts playback
  **only when the feed is at rest** (no paging in flight) for the current `.video` item without
  sticky playback failure. Triggers: folder open at `startIndex`, replace-in-place at its
  `startIndex`, and paging settle — `scrollGestureDidSettle()` is the single settle signal for both
  gesture and arrow paging (design §3; the existing scroll-phase plumbing already sees arrow-page
  animations). Mid-gesture `moveTo(itemID:)` changes the index but **never** starts playback — the
  incoming item keeps its poster (S2). Images never start (S4).
- [x] **3.3** Lifecycle per design §3 (S9, S10): every current-item change `stop()`s the old
  session **synchronously in the same main-actor turn** (no audio past the page turn — design
  §8(2)); revisiting a video calls `startPlayback` again — a fresh session from the beginning, no
  resume, nothing carried across visits. `adopt`/`discardDisplayState` (replace-in-place, welcome)
  stop and drop the handle alongside the existing display-state reset.
- [x] **3.4** Toggles + guard matrix per design §6 as pure, unit-testable logic: `togglePlayback()`
  (space route) and `togglePlaybackFromTap(itemID:)`; the whole matrix — settled current video →
  pause/resume (S5, S6); non-current tap id, mid-gesture, image page, sticky-failure item → no-op
  (S7, S4). Guarded to the **settled current item**; the view is never consulted.
- [x] **3.5** Events per design §3, §5, §7: `.readyForDisplay` → the display state becomes
  `.player` (the poster — frame 0 — stays until this swap; design §4); `.reachedEnd` → `restart()`
  on the **same** handle, the index untouched (S11 — never auto-advance); `.failed` → `stop()` +
  sticky `.unavailable` (S14). **Per-axis stickiness** (design §7): poster failure does not block a
  playback attempt; once playback fails, the item is never re-attempted this session. Three braces
  against late events (design §3): stream-finish on `stop()`, handle-identity check
  (`=== current`), and the existing `latestEntryGeneration` counter (superseded sessions never
  install or paint).
- [x] **3.6** Display state per design §4: `FeedItemDisplayState` gains `case player(MediaPlayback)`
  — `Equatable` becomes hand-written (`.player` cases compare handles by `===`, other cases
  unchanged) so the wrap memo/`onChange` behavior carries. The cell still receives only the display
  state — never the item (E2-S2 S14's structural absence holds).
- [x] **3.7** Full gate (update any existing `FeedViewModelTests` compile breaks in this same
  commit — minimal fixes; the full suites are task 7). Fix, tick; commit:
  `feat(e2-s3): task 3 — playback policy in the feed view model`.

## Task 4 — App input: `FeedKeyCommand` + space toggle `[P]` · design §6

Deliverable (code): `InstantPlayer/App/FeedKeyCommand.swift` (renamed from `ArrowKeyCommand.swift`),
`InstantPlayer/App/AppDelegate.swift` (monitor switch).

- [ ] **4.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **4.2** Mechanical rename `ArrowKeyCommand` → `FeedKeyCommand` (file, type, call sites, test
  names): the table routes a feed's keys, not just arrows (design §1.1; architecture §5 naming).
  The existing arrow rows are behavior-frozen.
- [ ] **4.3** Route table per design §6 — the frozen contract, `route(keyCode:modifiers:isRepeat:
  hasOpenFeed:)` as pure, unit-testable logic: no open feed → `.passThrough`; ⌘/⌥/⌃ combinations →
  `.passThrough` (system shortcuts never robbed — ⌃⌘F fullscreen survives); **space (keyCode 49)
  first press → `.togglePlayback`; `isARepeat` → `.ignore` (consumed — a held space must not flap
  play/pause)**; 125/126 → `.pageForward`/`.pageBackward` (auto-repeat pages — carried from E2-S2);
  anything else → `.passThrough`. ⇧ is not a command modifier (⇧+space toggles, like ⇧↓ pages).
- [ ] **4.4** `AppDelegate` monitor switch gains the two cases: `.togglePlayback` →
  `dependencies.activeFeedModel?.togglePlayback()` (the unchanged `@MainActor` view-model method —
  the guard matrix of task 3 decides, so image pages and mid-gesture presses consume and no-op
  quietly, never beep — the evidence §8 lesson); `.ignore` → consume (return `nil`). Existing cases
  and the `hasOpenFeed` derivation unchanged.
- [ ] **4.5** Full gate. Fix, tick; commit:
  `feat(e2-s3): task 4 — feed key router and space toggle`.

## Task 5 — Views: `.player` cell + tap + surface wrap `[P]` · design §4, §6

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/PlayerSurfaceView.swift` (new),
`InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (extended),
`InstantPlayer/Features/Feed/Presentation/FeedView.swift` (tap closure drill-down).

- [ ] **5.1** Load `swift-security` + `swift-performance` before editing (SwiftUI views + video
  rendering — skill §2 applies directly).
- [ ] **5.2** `PlayerSurfaceView` per design §1.1, §4 — the wrap: an `NSViewRepresentable` that
  vends `makeDisplayView()` into the hierarchy (`makeNSView` once per session, `updateNSView` a
  no-op — the handle is immutable per session). **AppKit only** — no AVFoundation/AVKit import in
  any Presentation file (architecture §4 check 3); no media operations here (a wrap, not
  processing).
- [ ] **5.3** `FeedItemView` per design §4: the `.player` case renders `PlayerSurfaceView` — the
  layer's `resizeAspect` letterboxes inside the viewport-sized cell (E2-S2 S2 carries; resize and
  native fullscreen need **no code** — add none). The cell remains a pure function of the display
  state and never sees the item or its name (E2-S2 S14). Paused = the frozen frame only — **no**
  controls, progress indicator, or play button anywhere (S8); the unavailable and loading
  presentations are unchanged.
- [ ] **5.4** Tap per design §6 (S6, S7): `FeedView` drills an `onTap` closure per page that
  captures the item id and calls `viewModel.togglePlaybackFromTap(itemID:)`; the cell receives the
  closure only (the item stays structurally absent). Full-page hit target via `.contentShape` — the
  letterbox included. **No** App-level mouse monitor, **no** `onKeyPress`/focus handling anywhere
  (design §6; evidence §8's lesson is binding for keys only — taps are not focus-dependent).
- [ ] **5.5** Chrome-free viewport holds (S8; E2-S2 S14 carried): hidden scroll indicators, no
  overlays; the welcome branch untouched (its accessibility identifier keeps the launch UI tests
  green).
- [ ] **5.6** Full gate. Fix, tick; commit:
  `feat(e2-s3): task 5 — player surface and item cell wiring`.

## Task 6 — Composition: bind the real player service `[P]` · design §1

Deliverable (code): `InstantPlayer/App/AppDependencies.swift` (player binding).
`FeedState.swift`, `RootView.swift`, `InstantPlayerApp.swift` stay untouched.

- [ ] **6.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **6.2** Composition per design §1: `AppDependencies` binds `AVMediaPlayerService` as the
  `MediaPlayerService` default (replacing `StubMediaPlayerService()`; tests still inject
  conformances through the same initializer). `init` stays **allocation-only** (R13 of E1-S3,
  design §8(4)) — one binding allocation, nothing scheduled, no player created at launch (players
  exist only while a video is current). The factory's record-once `activeFeedModel` semantics are
  unchanged (the key monitor of task 4 consults it).
- [ ] **6.3** D21 audit checkpoint (design §1.1, §9): confirm this task — and the story so far —
  introduces **no** change under `InstantPlayer.xcodeproj/` or `InstantPlayer/Config/`: no
  entitlements, no plist keys, no build settings. Any apparent need → stop and report.
- [ ] **6.4** Full gate. Fix, tick; commit:
  `feat(e2-s3): task 6 — composition binding the player service`.

## Task 7 — Unit suites: playback policy + seam + perf `[P]` · design §8(1), §10.1, §10.2

Deliverable (code): `InstantPlayerTests/` — extended `FeedViewModelTests` (playback policy),
`FeedKeyCommand` route-table tests (renamed), `AVMediaPlayerServiceTests`/session suite, fixture
helper additions, the §8(1) performance test.

- [ ] **7.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **7.2** Frameworks per house pattern: Swift Testing (`@testable import InstantPlayer`,
  `@Test` + `#expect`) for the suites; the design §8(1) performance test uses XCTest `measure`
  exactly as the design names it — the one deliberate exception.
- [ ] **7.3** Playback policy per design §10.1 (injected `MediaFolderRepository` +
  `MediaPreviewService` + `MediaPlayerService` doubles — spy + scripted handle whose events the test
  drives; no UI, no window, no AVFoundation), row by row: become-current trigger set (folder open at
  `startIndex`; `pageForward`/`pageBackward` at rest; replace-in-place at its `startIndex`; images
  never started — S1, S4); **settle-only start** (mid-gesture `moveTo` never starts;
  `scrollGestureDidSettle` starts the settled item — S2); unmuted auto-play asserted at the double
  (S3); toggles via `togglePlayback()` and `togglePlaybackFromTap(itemID:)` (S5, S6); the full
  click-guard matrix (S7, S4); stop-on-away recorded synchronously with the index change (S9);
  restart-on-revisit is a fresh `startPlayback`, no resume (S10); `.reachedEnd` → `restart()` on the
  same handle with the index untouched (S11); failure rows — `startPlayback` → `nil` and `.failed`
  event → sticky `.unavailable`, never re-attempted (S14, S15; per-axis stickiness, design §7);
  late events from stopped/superseded handles never paint or sound (design §3's three braces);
  pause leaves the display state `.player` (S8); adopt/welcome teardown stops and drops (design §3).
- [ ] **7.4** Route table per design §6 (task 4's frozen contract): the key/modifier/repeat matrix —
  49 → toggle, repeat → ignore, 125/126 → pages (repeat pages), ⌘/⌥/⌃ → pass-through, no feed →
  pass-through, other keys → pass-through.
- [ ] **7.5** Playback seam per design §10.2 (Feed Data suite + fixtures): the existing
  `MediaFixture` throwaway-folder pattern plus a new tiny short multi-frame MP4 helper for end/loop
  timing. Rows: real clip → handle + `.readyForDisplay` and **unmuted** (`isMuted == false`,
  `volume` untouched — S3, via `@testable` internals; note the internals in task 10's deviations
  list if this is the only route); `pause()` freezes time; `resume()` continues; natural end of the
  short clip → `.reachedEnd`; `restart()` returns near zero and plays (S11's mechanism);
  `fake.mp4` text bytes → `nil` (S14 — D20's contract pinned); vanished URL → `nil` (S15);
  `stop()` → stream finishes, no further events, display view released; a superseded session is
  torn down by the next `startPlayback` (one live player — design §8(3)).
- [ ] **7.6** Performance test per design §8(1): XCTest `measure` through the real conformance —
  the start call to `.readyForDisplay` over the generated fixture clip. Budget: **≤ 300 ms p95**
  typical (≤ 1080p clips) and **≤ 1 s p95** heavy media on Apple-silicon reference hardware. The
  measured numbers are recorded in task 10's evidence **from tooling, never from memory**.
- [ ] **7.7** UI tests: **none added** (design §10.3 — playback is unreachable without host-driven
  entry; the spec's honest caveat). Verify the existing launch tests still pass unchanged (welcome
  at plain launch; `testLaunchPerformance` as the zero-launch-cost guard — design §8(4)).
- [ ] **7.8** Full gate — the tests run and must be green. Fix, tick; commit:
  `test(e2-s3): task 7 — playback policy and seam tests`.

## Task 8 — Architecture reference updates `[P]` · design §13

Deliverable (docs): `docs/architecture.md` — the three required same-story updates (design §13).
Follows the E2-S1/E2-S2 precedent: the standing architecture reference is updated by its own docs
commit once the code it documents has landed (tasks 1–6; the task-4 rename included).

- [ ] **8.1** Update `docs/architecture.md` exactly per design §13: (1) **§3 source tree** gains
  `Features/Feed/Domain/MediaPlayback.swift`, `MediaPlaybackEvent.swift`,
  `Features/Feed/Data/AVMediaPlayerService.swift`, `AVMediaPlayback.swift`,
  `Features/Feed/Presentation/PlayerSurfaceView.swift`; renames `App/ArrowKeyCommand.swift` →
  `App/FeedKeyCommand.swift`; re-annotates `MediaPlayerService.swift` (real members),
  `StubMediaPlayerService.swift`, `FeedViewModel`/`FeedView`/`FeedItemView`; (2) **§4 check (3)**
  gains the design §1.1 display-ready platform-view refinement — an opaque, display-ready platform
  view may travel as an opaque `AnyObject` value from a Data conformance; Presentation wraps it
  into the view hierarchy — a wrap, not processing; (3) **§8's actor note** records that no new
  actor ships in this story — the player conformance is `@MainActor` because D8's trigger is unmet
  (no cross-isolation shared state) and synchronous stop/pause bite is contract (design §1.2).
- [ ] **8.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [ ] **8.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e2-s3): task 8 — architecture reference updates`.

## Task 9 — ADR batch D25–D28 `[P]` · design §11

Deliverable (docs): `docs/decisions.md` — append D25–D28.

- [ ] **9.1** Append four ADRs continuing the numbering (the log currently ends at D24), house
  heading `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each with context,
  decision, alternatives, consequences. Titles and one-line decisions exactly per design §11:
  **D25 — Playback sessions: one `@MainActor` player service, one live player, restart-on-revisit**
  (→ S1–S3, S9, S10, S14, S15) · **D26 — Loop by seek-to-zero-and-play, policy in the view model**
  (→ S11) · **D27 — Chrome-free rendering: opaque handle + display-ready platform view wrapped by
  Presentation** (→ S4, S8) · **D28 — Playback input: the App-owned key monitor becomes a feed-key
  router; clicks are SwiftUI taps guarded in the view model** (→ S5–S7).
- [ ] **9.2** Pull each entry's alternatives from the matching design §12 rows — D25: actor
  conformance (D8 trigger unmet; the executor hop defeats S9's audio cut), all-async seam, commands
  by item id, `AVPlayer` escaping into Domain/Presentation; D26: `AVPlayerLooper`, recreate-on-end,
  looping inside the conformance; D27: SwiftUI `VideoPlayer`, `AVPlayerView` (`.none`), AVFoundation
  in Presentation, the injected view-factory closure; D28: App-level mouse monitor,
  `.onKeyPress`/focus-based space, keeping the `ArrowKeyCommand` name, auto-repeat toggling,
  starting on every `moveTo` (no settle gate), retrying failed playback on revisit, session pooling.
- [ ] **9.3** Status `accepted`. Each entry cites its implementing task commits (tasks 1–6) in its
  consequences. D25 carries the honest isolation reasoning (D8 trigger, synchronous bite) and the
  three late-event braces; D26 the honest restart — not a gapless loop; **D27 carries the §4
  check-3 wording note** (the architecture refinement of design §1.1/§13); **D28 carries the
  evidence §8 lesson reference** (SwiftUI focused-view key delivery failed three rounds —
  [E2-S2 evidence §8](../e2-s2-vertical-feed-window/evidence.md) — taps are not focus-dependent).
- [ ] **9.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; tick; commit:
  `docs(e2-s3): task 9 — ADRs D25–D28 — playback lifecycle, loop, rendering, and input`.

## Task 10 — Verification & evidence · spec acceptance criteria, design §8, §10

Deliverable (docs): `docs/specs/e2-s3-basic-playback/evidence.md` (new) +
acceptance-criteria ticks in this file.

- [ ] **10.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **10.2** Traceability walk: **S1–S16 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product R-map**
  of the spec's acceptance table (product R11, R12, R15, R17 → story outcome → verified by), plus
  the S16/R16 cross-cutting note. Record both tables in evidence.md.
- [ ] **10.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/e2-s3-gate.json` (`<tmp>` = session temp dir outside the
  repo; the JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every
  step name and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [ ] **10.4** **UI-test mandate (spec Story context; R14 of E1-S2):** run
  `./scripts/validate.sh --uitests --json <tmp>/e2-s3-uitests-gate.json` and quote it **verbatim**
  (design §10.3). The run is additive and fail-closed: a failing UI test fails it; the flag never
  skips or weakens a step ([docs/development.md](../../development.md) §3).
- [ ] **10.5** Record from tooling, never from memory: the design §8(1) performance measurement
  (the `measure` run's numbers against the **300 ms / 1 s** auto-play start budgets, from task 7.6)
  and the **D21 audit** (design §1.1, §9): the `codesign -d --entitlements` output showing the four
  D19 keys **unchanged**, and the `git diff main...HEAD` stat restricted to
  `InstantPlayer.xcodeproj/ InstantPlayer/Config/` showing **no changes** (empty output quoted).
- [ ] **10.6** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, budgets) with its impact, marked for coordinator ratification — silently deviating is
  forbidden (standing rule 6). Specifically watch for: the design §3 arrow-phase fallback if taken
  (a ratified deviation like E2-S2 round 4's), and any `@testable` internals used for the unmuted
  assertion (design §10.2).
- [ ] **10.7** Tick AC1–AC8 below and mirror them in evidence.md; leave the converge-owned AC9–AC11
  unticked.
- [ ] **10.8** Commit (docs-only): `docs(e2-s3): task 10 — evidence and acceptance`.

---

## Acceptance criteria

Ticked by task 10, each backed by quoted tooling evidence:

- [ ] **AC1 · R11 / S1–S4** — auto-play covered by unit tests on the policy machine: every
  become-current path (folder open at `startIndex`, paging settle, revisit, replace-in-place) starts
  the video; **settle-only** start (never mid-gesture — the incoming item keeps its poster); audio
  unmuted by default; images never play. Functional review: the start feels instant (budget of
  design §8(1) is the number).
- [ ] **AC2 · R12 / S5–S8** — play/pause via spacebar and via a single click anywhere on the current
  page (letterbox included); the click-guard matrix unit-tested (non-current, mid-gesture, image,
  sticky-failure → no-op); pause shows only the frozen frame — no chrome (unit tests + functional
  review).
- [ ] **AC3 · R15 / S11** — loop in place unit-tested and reviewed: the end restarts the same video
  from its beginning (`restart()` on the same handle) and the feed **never** auto-advances.
- [ ] **AC4 · S9, S10** — stop-on-away (synchronous with the page change — no audio past the page
  turn) and restart-on-revisit (fresh session from the beginning, no resume) — unit tests +
  functional review.
- [ ] **AC5 · S14, S15** — playback failure and stale file both fall back to the neutral
  unavailable state — sticky, no retry, feed navigable (unit tests with `fake.mp4` and a vanished
  URL + functional review).
- [ ] **AC6 · R17 / S12, S13 · RNF-04** — read-only playback walked: no rewrite/re-encode, no
  sidecars, no playback-state persistence; reads only inside the open D19 session; **no
  entitlement/plist/pbxproj diff** (D21 audit: empty diff + unchanged `codesign` output recorded);
  design §9.1 review table walked.
- [ ] **AC7 · S16, RNF-02** — auto-play start budget (300 ms / 1 s) measured and recorded from
  tooling; synchronous audio cut; exactly one live player (supersession teardown tested); zero added
  launch cost — `testLaunchPerformance` intact and green; paging during playback stall-free.
- [ ] **AC8 · R14 (E1-S2) + evidence & coverage** — the `--uitests` converge-mandate run is green
  and quoted verbatim (design §10.3: no new UI tests — playback is host-driven-entry territory);
  full gate `--json` quoted verbatim (lint/format `pass`); the S1–S16 + product R-map walk recorded;
  D25–D28 in `docs/decisions.md` house format; the design §13 architecture updates done; all
  deviations listed honestly.

Converge-owned — the coordinator ticks these; task 10 never does:

- [ ] **AC9 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — the design §10.4 list: auto-play on arrival and on every paging move
  starting only after settle (never mid-scroll); audible unmuted auto-play; instant-feeling start;
  seamless poster→video swap; spacebar toggle (no flap on hold, no beep on image pages); whole-page
  click toggle; guard cases doing nothing; frozen-frame-only pause; immediate silence on page-away;
  restart from the beginning on revisit; loop at end without advancing; unavailable states
  (`fake.mp4` + vanished file) with the feed navigable; letterbox under resize/native fullscreen
  with live playback; files byte-identical on disk afterwards. Explicit approval required.
- [ ] **AC10 · validator review** — adversarial PASS over spec S1–S16 and the product R-map,
  design §9.1's review table, and both pillar-skill checklists.
- [ ] **AC11 · story closure** — backlog E2-S3 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e2-s3-basic-playback`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review of playback in the running app
   (`./scripts/app.sh run`): the AC9 list (design §10.4).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S16 / product R-map
   and design §10's test tables + §9.1's review table.
3. **Converge run** — `./scripts/validate.sh --uitests` (the UI-test mandate's final run) alongside
   the functional review; its output is the story's final gate record.
4. **Closure** — tick AC9–AC11, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §13: **E3** places controls into the chrome-free viewport — E3-S1's
scrubbing must live in a hover/mouse-move overlay control bar (drag-on-video scrubbing is foreclosed
by this story's whole-page click target, spec S7's consequence); the `MediaPlayback` handle grows
seek/rate (E3-S1/E3-S2) and volume (E3-S3) members; **E4-S2** supersedes S15's stale-item fail-safe
with live removal semantics; double-click stays meaningless (spec non-goal).

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D24; task 9 appends D25–D28)
- [docs/spec.md](../../spec.md) — product source of truth (product R11, R12, R15, R17; R16; RNF-02,
  RNF-04)
- [docs/architecture.md](../../architecture.md) — seam placement, layering; task 8 applies design
  §13
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S3) and the E2–E5 coverage note
- [E2-S2 evidence §8](../e2-s2-vertical-feed-window/evidence.md) — the arrow-key saga (why key
  delivery is App-owned; D28's context)
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
