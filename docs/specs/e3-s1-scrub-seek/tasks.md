# E3-S1 · Scrub & seek — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S17 over product R13; R16 via S17, R17 via S16). Branch: `feat/e3-s1-scrub-seek` — already
checked out; never switch branches mid-story. One task = one commit. Checkboxes are ticked during
implementation, each task's boxes in its own commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task (1–8) loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story moves the playback
   position of user media files (read-only seeks of user data — security) under pointer-rate input,
   a 10 Hz clock, and SwiftUI gesture/view work (drag fluidity, landing latency, idle machinery —
   performance): both pillar checklists apply (design §8, §9), and each task repeats the load step
   so it cannot be skipped.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy.
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source (picked up
   automatically, no flags); the SwiftLint and SwiftFormat gate steps must pass. Never edit the
   configs to make code pass.
4. **Synchronized groups / D21:** new source files land on disk under `InstantPlayer/` and
   `InstantPlayerTests/` and join their targets automatically. **Never hand-edit
   `project.pbxproj`.** This story needs **no** config change at all (design §1.1, §9): no
   entitlements, no Info.plist keys, no build settings — the D21 audit expects a **zero
   project-config diff** (checked in task 11). If anything appears to need one, **stop and report —
   a coordinator escalation (D21), never an implementer edit.**
5. **Gate:** code tasks 1–8 run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Docs tasks 9–10 stage first, then run `./scripts/validate.sh --staged`. Task 11 runs
   the full gate with `--json` for evidence. Fix every failure before moving on; the pre-commit hook
   re-runs the gate on every commit. Never weaken the gate; `--no-verify` is forbidden. **Default
   gate scope throughout — no `--uitests` obligation** (the spec's UI-test-mandate decision: launch
   flows are untouched and the story's surface is unreachable without host-driven entry).
6. **Contracts are frozen:** the design §2 seam additions — `enum MediaSeekTolerance: Sendable {
   case preview, exact }`, `var duration: TimeInterval { get }`, `var timeUpdates: AsyncStream<
   TimeInterval> { get }`, `func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance)` —
   and their semantics (`.preview` tolerant + coalesced, `.exact` zero-tolerance + immediate,
   synchronous dispatch, never changes rate); `MediaPlaybackEvent` **untouched** (rare events keep
   their never-dropped semantics); the design §5 entry points (`beginScrub`/`scrubChanged`/
   `scrubEnded`, `seekFromTrackClick`, `seekBackwardByKeyboard`/`seekForwardByKeyboard`,
   `noteMouseMoved`); the design §7 `PlaybackControlBarModel` (`elapsed`, `duration`,
   `scrubFraction`, `isVisible`); the design §4 bar surface (four named elements, `NSTrackingArea`
   mouse-move visibility, 3 s idle); the design §6 route rows (123/124 → `.seekBackward`/
   `.seekForward`, always consumed with an open feed); the design §2/§3 mechanism bounds (≤ 1 seek
   in flight, latest-wins pending, 10 Hz clock, `.bufferingNewest(1)`, 250 ms post-commit tick
   suppression). Name/signature/shape changes are design amendments: stop and report to the
   coordinator, never deviate silently. Same for any design §0 fact that no longer holds. (The
   design §4 `acceptsMouseMovedEvents` fallback is design-sanctioned but becomes a **ratified
   deviation** with its own record — task 11's deviations list — if taken.)
7. **No invented behavior:** spec non-goals hold — no playback speed (E3-S2 — never touch `rate`
   beyond play/pause), no volume/mute (E3-S3 — never set `isMuted`/`volume`), no drag-on-video
   scrubbing (foreclosed by D27), no bar contents beyond the four named elements (no hover
   thumbnails, chapter markers, or buffered ranges), no extra seek keys or variable steps (no
   Home/End, no J/K/L, no modifier steps — the step is fixed ±5 s), no double-click meaning, no
   resume or persisted positions (S15, S16 — no `UserDefaults`, nothing in `tmp`/`Caches`/
   `Application Support`), no auto-advance (S14 — the index is never touched by a seek), no
   export/reader/writer paths (S16), no sidecar or derived files, no logging of paths or file names
   (D20), no networking (D9), no bookmarks (D19), no retry affordance, no ordering (E4-S1), no live
   sync (E4-S2). Guarded seek inputs do nothing quietly — never beep (D28).
8. **Composition is untouched (design §7):** `App/AppDependencies.swift`, `App/RootView.swift`,
   `App/InstantPlayerApp.swift`, `FeedState.swift` change **nothing** — no new seam, no new binding;
   seek rides the already-bound `MediaPlayback` handle. No task in this plan edits them.

## Sequencing & parallelism

- **Wave 1 — task 1** (Domain seam additions + stub) is first: everything consumes the grown
  protocol, and the stub handle grows in the same commit (the composition still binds the stub, and
  the E2-S3 view model + its scripted doubles must compile from this commit on).
- **Wave 2 — tasks 2 and 3 `[P]`**: the Data mechanism (2) and the view-model policy (3) are
  independent of each other — 3 is developed against the stub from 1. Both depend only on 1
  (the e2-s3 wave-2 precedent).
- **Wave 3 — tasks 4, 5, 6 `[P]`**: the Feed Data suite (4) tests task 2's files, the policy suite
  (5) tests task 3's files, and the bar view + tracking area (6) is Presentation code over task 3's
  model — three disjoint file sets. **Test placement note:** a test commit cannot gate-green before
  the code it tests is committed, so each suite sits in the wave immediately after its code (never
  same-wave with it); no test work is deferred to the tail — the suites land mid-plan, next to their
  seams (design §10.1/§10.2).
- **Wave 4 — tasks 7 and 8 `[P]`**: overlay wiring (7) consumes task 6's bar view and task 3's
  model/closures; the App key rows (8) depend only on task 3's step methods. Presentation views vs
  `App/` + key-table tests — disjoint, genuinely parallel.
- **Wave 5 — tasks 9 and 10 `[P]`**: the `docs/architecture.md` updates (9) and the ADR batch (10)
  are transcription of the approved design into two different docs files; both wait for all code.
- **Task 11 is last** and depends on everything else.
- Routing (D3 — coordinator's call): tasks 1–8 → `implementer` (contract-bound code; both skills
  mandatory; task 8 is small but contract-sensitive — the frozen table — still `implementer`);
  tasks 9–10 → `implementer-flash` candidates (approved-design transcription; each its own docs
  commit, the e2-s3 precedent); task 11 → `implementer` (evidence discipline).

---

## Task 1 — Feed Domain: seek seam additions + stub · design §1, §2, §1.1

Deliverable (code): `InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (grown),
`InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (grown). `MediaPlaybackEvent.swift`
is **untouched** (design §1).

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** `MediaPlayback` grows exactly the design §2 members (Foundation-only — R10; no
  `CMTime`, no `AVPlayer`, no completion handler in any Domain signature, design §1.1): `enum
  MediaSeekTolerance: Sendable { case preview, exact }` (lives with the handle per design §1);
  `var duration: TimeInterval { get }` (known once `startPlayback` returns — design §3);
  `var timeUpdates: AsyncStream<TimeInterval> { get }` (elapsed ticks; finished by `stop()` like
  `events`); `func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance)` — synchronous
  dispatch, never changes rate (S10), seconds clamped by the caller to `[0, duration]` (S13).
- [x] **1.3** Stub handle grows the same members in **this same commit** (house stub pattern; the
  composition still binds the stub until this story's code is complete and tests use their own
  scripted doubles): canned non-zero `duration`, a `timeUpdates` stream that finishes on `stop()`,
  seeks recorded and reflected into `displayedPosition` feeds — zero I/O, no AVFoundation.
- [x] **1.4** Existing call sites and test doubles updated minimally so everything compiles from
  this commit on (scripted handles in `FeedViewModelTests` gain the three members; full suites are
  tasks 4–5). `MediaPlaybackEvent` semantics unchanged — no edit to that file.
- [x] **1.5** Full gate `./scripts/validate.sh` — the grown protocol and stub must compile (that is
  what proves target membership). Fix, tick this task's boxes, commit:
  `feat(e3-s1): task 1 — seek seam additions and stub`.

## Task 2 — Feed Data: seek scheduler + clock bridge · design §2, §3, §8(5)

Deliverable (code): `InstantPlayer/Features/Feed/Data/SeekScheduler.swift` (new),
`InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (extended).

- [x] **2.1** Load `swift-security` + `swift-performance` before editing (pointer-rate dispatch of
  seeks on user media bytes — both pillars directly in play).
- [x] **2.2** `SeekScheduler` per design §2 — the pure latest-wins seek-dispatch state machine,
  conformance-internal (one consumer; seam-placement rule, architecture §4), **no AVFoundation
  import** so it is unit-testable without hardware (task 4): at most **one** seek in flight; while
  one is in flight, newer preview targets **replace** the pending one (never queued — the entire
  pending state is one target); when the in-flight seek completes, exactly one seek to the newest
  pending target is issued; `.exact` supersedes pending and dispatches immediately; pending state is
  dropped on stop (design §8(5)'s storm bound).
- [x] **2.3** `seek(to:tolerance:)` per design §2 on the `@MainActor` conformance: `.preview` → a
  maximum-tolerance seek (`.positiveInfinity` both sides) routed through `SeekScheduler` (S1, S5,
  S6); `.exact` → `.zero`/`.zero` issued immediately, abandoning and superseding any in-flight or
  pending seek (AVPlayer's self-superseding semantics — design §0(1); S7, S11, S2/S9 commits);
  synchronous dispatch in the same main-actor turn; seconds defensively re-bounded when converted to
  `CMTime`; **rate never touched** (S10). Seek completion state stays inside the conformance — no
  completion event, no callback crosses the seam (D8, R4).
- [x] **2.4** `duration` per design §3 — the synchronous `AVPlayerItem.duration` value (known once
  the asset load `startPlayback` already awaits completes; E2-S3 §2 carries).
- [x] **2.5** Clock bridge per design §3: `addPeriodicTimeObserver(forInterval:queue:using:)` at
  **100 ms (10 Hz)** on AVFoundation's queue, marshaled to the main actor at the conformance
  boundary (D25's brace pattern); `timeUpdates` is a **separate** `AsyncStream` from `events`,
  created with **`.bufferingNewest(1)`** (a stalled main actor drops stale ticks, never replays a
  backlog); `stop()` finishes **both** streams and removes the periodic observer (design §3 braces).
  `MediaPlaybackEvent` and its unbounded, never-dropped semantics stay untouched.
- [x] **2.6** Security per design §9 (S16, RNF-04): reads only inside the D19 session — no
  `start/stopAccessingSecurityScopedResource`; playback/seek APIs only — **no**
  `AVAssetExportSession`, **no** `AVAssetReader`/`AVAssetWriter`, no `write(to:)`, no sidecar, no
  disk cache, no persistence (no `UserDefaults`); no logging of paths or names (D20).
- [x] **2.7** Full gate. Fix, tick; commit:
  `feat(e3-s1): task 2 — seek scheduler and clock bridge`.

## Task 3 — Scrub & seek policy in `FeedViewModel` · design §3, §4 (policy), §5, §6, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (extended;
existing tests updated to compile in the same commit if signatures move) — including the design §7
`PlaybackControlBarModel` (`nonisolated struct`: `elapsed`, `duration`, `scrubFraction`,
`isVisible`; no separate file appears in the design §1 inventory).

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** Drag state machine per design §5 (S5–S8), pure and unit-testable:
  `beginScrub(itemID:)` — guard first (3.4), record `wasPlayingBeforeDrag = !isPlaybackPaused`,
  `handle.pause()` **gesture-scoped** (`isPlaybackPaused` itself untouched — the user's intent is
  preserved), suspend the idle policy, enter scrubbing; `scrubChanged(itemID:fraction:)` — guard
  `isScrubbing`, `target = clamp(fraction × duration, 0, duration)`, `displayedPosition = target`
  (labels/thumb track the pointer exactly — S5), `handle.seek(to: target, .preview)` (S6);
  `scrubEnded(itemID:fraction:)` — guard `isScrubbing`, clamp, then the S14 end rule (3.5) or
  `handle.seek(to: target, .exact)` (S7) + S8 restore (`wasPlayingBeforeDrag` → `resume()`, else
  stay paused on the frozen frame at the new position), restart the idle countdown (S3(a)),
  `isScrubbing = false`.
- [x] **3.3** Commit seeks per design §5 (S2, S9–S11): `seekFromTrackClick(itemID:fraction:)` and
  `seekBackwardByKeyboard()` / `seekForwardByKeyboard()` map/clamp and issue `.exact`, leaving
  play/pause exactly as found (S10); keyboard steps compute from `displayedPosition ± 5 s` (the
  drift-proof arithmetic — two quick presses net exactly 10 s; design §2), auto-repeat = repeated
  steps (S9, paging parity).
- [x] **3.4** Guard matrix per design §5's table (S12) as one unit-tested decision surface — every
  row: settled current video → seek per S1/S2/S11; non-current page, paging gesture in flight, image
  page, neutral unavailable state (incl. sticky playback failure), keyboard seek during a scrub
  drag, `duration <= 0` session → **consumed no-op** (the spy records nothing; never beep — D28).
  No open feed passes through at route level (D28 unchanged). The view is never consulted.
- [x] **3.5** Clamping + end handover per design §5 (S13, S14): every target clamps to `[0,
  duration]`; **`target == duration` after clamping is the end rule (exact, not epsilon)** →
  playing (or `wasPlayingBeforeDrag`) → `handle.restart()` (D26's seek-zero-and-play); paused →
  `handle.seek(to: 0, .exact)` and stay paused on the frozen frame at the beginning. The index is
  **never** touched (product R15 — no auto-advance by construction); the rule is shared by
  drag-release, track click, and key steps; a seek to 0 is an ordinary clamped seek. "Plays into the
  end" remains E2-S3 S11's unchanged `.reachedEnd` → `restart()` path.
- [x] **3.6** Bar visibility + idle policy per design §4 (S3, S4): `noteMouseMoved(itemID:)` on the
  settled current video page → `controlBarModel` non-nil with `isVisible = true` and a 3 s idle
  deadline armed; movement anywhere else shows nothing (S4, S12); keyboard seek **never** shows the
  bar (S3(b)); a paging gesture in flight → the model goes `nil` and any visible bar hides at once;
  the idle machinery is **one cancellable generation-guarded `Task.sleep`** — never a `Timer`, never
  a `CADisplayLink`, never a run-loop source — created only while a bar is visible, re-arms
  throttled to ≤ 4/s, owned and cancelled on every exit path (skill §4); a scrub drag suspends the
  idle policy entirely and the deadline restarts after release (S3(a)).
- [x] **3.7** Time-display state per design §3: consume `timeUpdates` into `displayedPosition` —
  ticks **ignored during a scrub drag** (the drag target owns the display) and **suppressed for
  250 ms after any `.exact` seek** (no thumb bounce from a stale tick); `controlBarModel` is
  non-`nil` **only** for the settled current video's live player page (structural absence on image
  pages, unavailable items, non-current pages, mid-paging — S4, S12); `duration <= 0` sessions
  reject seek input. Hidden at rest the model still drives `opacity(0)` + `allowsHitTesting(false)`
  presentation semantics (the whole-page toggle stays intact).
- [x] **3.8** Nothing carried (S15): every fresh session (E2-S3 §3 lifecycle carries unchanged)
  resets the drag machine, `displayedPosition`, and the clock consumer — a seek position is stored
  nowhere (§9 keeps it so).
- [x] **3.9** Full gate (update existing `FeedViewModelTests` compile breaks in this same commit —
  minimal fixes; the full policy suite is task 5). Fix, tick; commit:
  `feat(e3-s1): task 3 — scrub and seek policy in the feed view model`.

## Task 4 — Feed Data suite: scheduler + conformance + perf `[P]` · design §10.2, §8(2), §8(8)

Deliverable (code): `InstantPlayerTests/` — `SeekSchedulerTests` (pure), the seek/clock conformance
suite (extending the E2-S3 session suite and `MediaFixture` throwaway-temp-folder pattern with the
existing one-frame + short multi-frame MP4 fixtures), the §8(2) performance case.

- [x] **4.1** Load `swift-security` + `swift-performance` before editing.
- [x] **4.2** Frameworks per house pattern: Swift Testing (`@testable import InstantPlayer`,
  `@Test` + `#expect`) for the suites; the design §8(2) performance case uses XCTest `measure`
  exactly as the design names it — the one deliberate exception (the D25 run-loop-pumped,
  nonisolated pattern; a semaphore bridge would deadlock the `@MainActor` seam).
- [x] **4.3** `SeekScheduler` rows per design §10.1 (pure, Feed Data): latest-wins pending; **≤ 1
  in flight** (the design §8(5) bound, unit-asserted); exactly one dispatch after completion to the
  newest pending target; `.exact` supersedes pending and dispatches immediately; pending dropped on
  stop.
- [x] **4.4** Conformance rows per design §10.2 (the real `AVMediaPlayback`): `seek(.exact)` lands
  `currentTime` **within one frame duration** of the target (the §2 frame-exact contract pinned);
  `seek(.preview)` lands approximate and fast; a burst of N preview seeks dispatches **far fewer**
  actual seeks (internal dispatch counter via `@testable`) and the final target lands (S6 storm
  bound + S7 authority); `.exact` during a preview storm lands immediately; `duration` correct;
  `timeUpdates` ticks at **≤ 12/s** while playing and produces nothing while paused (§3);
  `stop()` finishes **both** streams and removes the observer; a superseded session drops pending
  seeks (E2-S3 §10.2 patterns carry).
- [x] **4.5** Performance case per design §8(2): the landing-latency `measure` — release/keypress/
  click → `.exact` issued immediately and landed frame within budget: **≤ 300 ms p95 typical**
  (≤ 1080p clips), **≤ 500 ms p95 atypical heavy media**. Measured numbers are recorded in task 11
  **from tooling, never from memory**.
- [x] **4.6** Full gate — the tests run and must be green. Fix, tick; commit:
  `test(e3-s1): task 4 — seek scheduler and playback-seam tests`.

## Task 5 — Policy suite: `FeedViewModel` scrub/seek rows `[P]` · design §10.1

Deliverable (code): `InstantPlayerTests/` — `FeedViewModelTests` extended with the design §10.1
rows (injected seam doubles: spy `MediaPlayerService` + scripted handle — the E2-S3 §10.1 pattern;
no UI, no window, no AVFoundation).

- [x] **5.1** Load `swift-security` + `swift-performance` before editing.
- [x] **5.2** Drag machine (S5–S8): begin records `wasPlayingBeforeDrag` and calls `pause()`
  **without** flipping `isPlaybackPaused`; change issues `.preview` to the mapped target and moves
  `displayedPosition`; end issues `.exact` to the final target; was-playing → `resume()`, was-paused
  → stays paused; the idle countdown is suspended during the drag and re-armed after (S3(a)).
- [x] **5.3** Tolerant/precision split (S6, S7): every `scrubChanged` call is `.preview`; the
  release, the track click, and the key steps are `.exact` — asserted at the spy handle.
- [x] **5.4** Key steps (S2, S9, S10): ±5 s from `displayedPosition` (two quick presses net 10 s —
  no drift); auto-repeat = repeated steps; rate untouched in both play states.
- [x] **5.5** Track click (S11): `.exact` to the mapped target; **never** `pause()`/`resume()`;
  the play/pause state observable-unchanged.
- [x] **5.6** Guard matrix (S12): the design §5 table as tests — non-current, mid-gesture, image,
  unavailable, mid-drag keyboard, `duration <= 0` all consumed no-ops (spy records nothing).
- [x] **5.7** Clamping & end handover (S13, S14): out-of-range targets clamp; `target == duration`
  → playing (or `wasPlayingBeforeDrag`) → `restart()`, paused → `seek(to: 0, .exact)` + stays
  paused; the index never changes; click/step/drag-release all share the rule.
- [x] **5.8** Bar visibility policy (S3, S4): mouse activity on the current video page shows + arms
  3 s; idle hides (the `Task.sleep` scheduler driven with an injected `now`); movement on neighbor
  and image pages shows nothing; keyboard seek never shows (S3(b)); paging in flight drops the model
  to `nil` at once; the hidden model keeps the toggle surface intact.
- [x] **5.9** Time display (§3): ticks update `displayedPosition`; ignored during drag; suppressed
  250 ms after `.exact`; stale ticks never bounce the thumb.
- [x] **5.10** Nothing carried (S15): current-item change → new session → drag/position state reset
  (the E2-S3 lifecycle tests extend).
- [x] **5.11** Full gate — green. Fix, tick; commit:
  `test(e3-s1): task 5 — scrub and seek policy tests`.

## Task 6 — Bar view + mouse-move tracking area `[P]` · design §4, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/PlaybackControlBarView.swift` (new),
`InstantPlayer/Features/Feed/Presentation/PlayerSurfaceView.swift` (tracking area + coordinator-
held callback).

- [x] **6.1** Load `swift-security` + `swift-performance` before editing (SwiftUI views + gesture
  geometry — skill §2 applies directly).
- [x] **6.2** `PlaybackControlBarView` per design §4 — a dumb binder over `PlaybackControlBarModel`
  (D8: no policy in views): progress track (thin line, full width), scrubber thumb riding on it,
  elapsed label (leading), duration label (trailing) — **exactly the four named elements** (spec
  non-goals exclude everything else). Gesture geometry is reported as **fractions** (`0...1` along
  the track; geometry stays a view concern): `DragGesture(minimumDistance: 3)` → begin/change/end at
  gesture phase transitions (a pure click never crosses the threshold and stays a tap — so a click
  cannot pause, S11/S10); tap on the track (thumb footprint included) → the track-click seek; the
  labels and strip padding are consumed no-ops. The strip's drag is a **`highPriorityGesture`** so a
  scrub never starts a paging gesture; drags track past the strip's bounds once started (standard
  SwiftUI semantics). `mm:ss` formatting is a tiny pure helper evaluated only in the two label views
  (skill §2).
- [x] **6.3** `PlayerSurfaceView` per design §4 — AppKit-only plumbing on the Presentation side (no
  AVFoundation/AVKit import in any Presentation file; the Data display view stays interaction-free
  — D27): an `NSTrackingArea` (`.mouseMoved`, `.activeInKeyWindow`, `.inVisibleRect`) on the surface
  the wrap already vends, correct across resize and native fullscreen (`.inVisibleRect` /
  `updateTrackingAreas`); each `mouseMoved` reaches the view model through a coordinator-held
  closure (refreshed in `updateNSView` — the wrap stays once-per-session) as
  `noteMouseMoved(itemID:)`. If functional review shows `mouseMoved` gated on
  `NSWindow.acceptsMouseMovedEvents`, the surface enables it for its own window (one AppKit line) —
  a **ratified deviation** recorded in task 11 if taken (design §4's recorded fallback).
- [x] **6.4** Full gate. Fix, tick; commit:
  `feat(e3-s1): task 6 — control bar view and mouse-move tracking area`.

## Task 7 — Overlay wiring: `FeedItemView` + `FeedView` `[P]` · design §4, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift`,
`InstantPlayer/Features/Feed/Presentation/FeedView.swift`.

- [x] **7.1** Load `swift-security` + `swift-performance` before editing.
- [x] **7.2** `FeedItemView` per design §4/§7 — the `.player` case becomes a `ZStack` of two sibling
  layers: the **tap surface** (full-bleed display content with `.contentShape` + `.onTapGesture` →
  `togglePlaybackFromTap(itemID:)` — E2-S3 S6/S7 unchanged) and, above it, the **bar strip**
  (task 6's `PlaybackControlBarView`) rendered **iff the page's bar model is non-`nil`** —
  structurally absent on image pages (S4), unavailable items, non-current pages, and mid-paging
  (S12). The strip's own `contentShape` and gestures hit-test above the tap surface (S11's carve-out
  is the whole strip); clicks anywhere else on the page keep toggling exactly as E2-S3 S6/S7
  specify. Hidden = `opacity(0)` with `allowsHitTesting(false)` — a hidden bar can never swallow
  clicks, so the whole-page toggle is intact at rest. `FeedItemDisplayState.player(MediaPlayback)`
  is unchanged, and the cell still never sees the item (E2-S2 S14's structural absence holds).
- [x] **7.3** `FeedView` per design §7 — drills per-page `PlaybackControlBarModel?` **and** an
  actions value (scrub begin/change/end, track click, mouse-moved — each capturing the item id, the
  `togglePlaybackFromTap(itemID:)` tap-closure precedent of E2-S3 §6) into the §5 entry points of
  task 3. No App-level mouse monitor, no focus handling anywhere (D28; design §6).
- [x] **7.4** Full gate. Fix, tick; commit:
  `feat(e3-s1): task 7 — bar overlay wiring in the feed views`.

## Task 8 — App keyboard seek rows `[P]` · design §6

Deliverable (code): `InstantPlayer/App/FeedKeyCommand.swift`, `InstantPlayer/App/AppDelegate.swift`
(monitor switch), `InstantPlayerTests/` — `FeedKeyCommandTests` (updated).

- [x] **8.1** Load `swift-security` + `swift-performance` before editing.
- [x] **8.2** Route table per design §6 — the frozen table gains exactly two cases and two rows:
  `←` (keyCode 123) → `.seekBackward`, `→` (124) → `.seekForward`; with an open feed both are
  **always consumed** and routed to the guard matrix (which no-ops quietly on ineligible states —
  S12; never beep — D28), because passing through would re-expose them to the unhandled-key path;
  no open feed → `.passThrough`; auto-repeat = repeated steps (S9, paging's carried parity); ⌘/⌥/⌃
  → `.passThrough`; ⇧ alone does not modify; 125/126, space (49), and paging rows are behavior-
  frozen and stay green. **Recorded contract change:** 123/124 previously passed through — the
  frozen table's `nonRoutedArrowsPassThrough` test is **replaced** by the seek rows (design §6,
  §10.1).
- [x] **8.3** `AppDelegate` monitor switch gains the two cases → the view model's
  `seekBackwardByKeyboard()` / `seekForwardByKeyboard()` (task 3's unchanged `@MainActor` methods;
  the guard matrix decides, so ineligible states consume and no-op quietly). Existing cases and the
  `hasOpenFeed` derivation unchanged.
- [x] **8.4** `FeedKeyCommandTests` per design §10.1: 123 → `.seekBackward`, 124 → `.seekForward`
  with auto-repeat parity (`arrowAutoRepeatStillPages`' sibling for seeks); the replaced
  `nonRoutedArrowsPassThrough` row; modifier/welcome/space/paging rows unchanged and green.
- [x] **8.5** Full gate. Fix, tick; commit:
  `feat(e3-s1): task 8 — keyboard seek rows on the feed key router`.

## Task 9 — Architecture reference updates `[P]` · design §13

Deliverable (docs): `docs/architecture.md` — the three required same-story updates (design §13).
Follows the E2-S2/E2-S3 precedent: the standing architecture reference is updated by its own docs
commit once the code it documents has landed (tasks 1–8). (The design could not write this file —
its §13 records the permission boundary; this task-phase deliverable is exactly that list.)

- [x] **9.1** Update `docs/architecture.md` exactly per design §13: (1) **§3 source tree** —
  re-annotate `Features/Feed/Domain/MediaPlayback.swift` (gains `duration`, `timeUpdates`,
  `seek(to:tolerance:)` + `MediaSeekTolerance`), `Features/Feed/Data/AVMediaPlayback.swift` (seek
  scheduler + clock bridge), `Features/Feed/Presentation/FeedViewModel.swift` (scrub/seek/idle
  policy), `FeedItemView.swift` (tap-surface + bar overlay split), `PlayerSurfaceView.swift`
  (tracking area + mouse-move closure), `App/FeedKeyCommand.swift` (seek rows),
  `App/AppDelegate.swift` (seek cases); add `Features/Feed/Data/SeekScheduler.swift` and
  `Features/Feed/Presentation/PlaybackControlBarView.swift`. (2) **§4 check (3):** explicitly **no
  wording change** — this story moves no new kind across the seam (`TimeInterval` is Foundation; the
  tracking area rides the already-ratified wrapped view); **record that verdict** so the section
  does not look overlooked. (3) **§8 evolution note:** **no new actor** — D8's trigger is unmet
  again (the seek scheduler and clock bridge are conformance-internal state on the `@MainActor`
  conformance; the periodic observer marshals at the boundary like the existing event bridges); the
  `@MainActor`-seam pattern of D25 carries unchanged.
- [x] **9.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [x] **9.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e3-s1): task 9 — architecture reference updates`.

## Task 10 — ADR batch `[P]` · design §11

Deliverable (docs): `docs/decisions.md` — append the three ADRs of design §11.

- [ ] **10.1** Append three ADRs **continuing the numbering from the log's current end** (the house
  rule — AGENTS.md rule 6, the e2-s3 task-9 precedent "continuing the numbering"). The design §11
  labels them D30–D32 because the log ended at D29 when the design was written; harness ADRs have
  since claimed those numbers (`ac919ca`), so at authoring the next free numbers are **D32, D33,
  D34** — house heading `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each
  with context, decision, alternatives, consequences. **Titles and one-line decisions exactly per
  design §11** (only the leading number differs from the plan's stale labels — recorded in task
  11.7 for coordinator ratification):
  **D32 — Scrub & seek mechanism: tolerant coalesced preview seeks vs zero-tolerance commit seeks,
  scheduler in the conformance** (→ S1, S2, S5–S8, S11, S13, S14, S17) · **D33 — Demand-driven
  transport chrome: overlay control bar with AppKit tracking-area mouse-move visibility and
  view-model idle policy** (→ S3, S4, S11, and the E2-S3 S8 amendment) · **D34 — Keyboard seek on
  the feed-key router: ←/→ = ±5 s with paging's repeat parity** (→ S2, S9, S10).
- [ ] **10.2** Pull each entry's alternatives from the matching design §12 rows — D32: coalescing
  in the view model, trusting `AVPlayer`'s self-superseding seeks, coalescing as its own Domain
  seam, two intent-named seek members, a `.seekFinished` completion event, a paused-aware
  `restart()` overload, "at the end" as a within-one-frame epsilon; D33: clock through the `events`
  stream, `TimelineView`/`Timer`/`CADisplayLink` labels, polling `handle.currentTime` from `body`,
  a 1 Hz clock, SwiftUI `.onHover`/`.onContinuousHover`, an App-level `NSEvent` mouse monitor, the
  tracking area on the Data display view, `Timer.publish`/`asyncAfter`/`.task(id:)` for the idle
  hide, always-composed bar with opacity toggling, page-root tap with gesture-exclusion modifiers,
  thumb-only drag, thumb-follows-only-the-player position; D34: `.seek(delta:)` as one payload
  route case, repeat-ignored ←/→ like space, tolerant keyboard steps, passing ←/→ through on
  ineligible states, seeking mid-drag keyboard input through.
- [ ] **10.3** Status `accepted`. Each entry cites its implementing task commits (tasks 1–8) in its
  consequences. D32 carries the §2 honesty limits (frame-grid exactness, sub-frame rounding,
  long-GOP landing cost, rate-after-seek ordering); D33 carries the E2-S2 evidence §8 lesson
  reference (SwiftUI input delivery other than plain taps failed three rounds —
  [E2-S2 evidence §8](../e2-s2-vertical-feed-window/evidence.md) — `NSTrackingArea.mouseMoved` is
  the deterministic 1:1 mechanism) and the 3 s idle value as this story's RNF-02 output; D34
  carries the frozen-table contract change (123/124 no longer pass through).
- [ ] **10.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; tick; commit:
  `docs(e3-s1): task 10 — ADRs D32–D34 — seek mechanism, transport chrome, and keyboard seek`.

## Task 11 — Verification & evidence · spec acceptance criteria, design §8, §10

Deliverable (docs): `docs/specs/e3-s1-scrub-seek/evidence.md` (new) + acceptance-criteria ticks in
this file.

- [ ] **11.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **11.2** Traceability walk: **S1–S17 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product R-map**
  of the spec's acceptance table (product R13 → story outcome → verified by; product R16 via S17
  and product R17 via S16 as the cross-cutting/inherited notes, never claimed). Record both tables
  in evidence.md.
- [ ] **11.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/e3-s1-gate.json` (`<tmp>` = session temp dir outside the
  repo; the JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every
  step name and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [ ] **11.4** **UI-test mandate (spec Story context; R14 of E1-S2):** record the decision — flows
  are **not** affected, the converge run keeps the **default gate scope with no `--uitests`
  obligation** ([docs/development.md](../../development.md) §3) — together with the spec's honest
  caveat (even a `--uitests` run could not exercise scrub/seek: no media is open in the launch
  tests) and the fact that `testLaunchPerformance` and the launch tests run green unchanged within
  the full gate of 11.3.
- [ ] **11.5** Record from tooling, never from memory: (a) the design §8(2) performance
  measurements (task 4.5's `measure` numbers against the **300 ms / 500 ms** landing budgets and
  the design §8(1) drag-preview bound as reviewed); (b) the **D21 audit** (design §1.1, §9, §13) —
  `git diff main...HEAD` stat restricted to `InstantPlayer.xcodeproj/ InstantPlayer/Config/`
  showing **no changes** (empty output quoted) and the `codesign -d --entitlements` output showing
  D19's four read-only keys **unchanged**; (c) the design §9.1 sandbox/media-read review table
  walked row by row (no export/reader/writer, no sidecars, no `UserDefaults`, no position
  persistence anywhere — S16).
- [ ] **11.6** Functional-review checklist: carry the spec's AC list verbatim into evidence.md (the
  design §10.3 list — bar appearance on mouse movement over playing and paused video pages, idle
  hiding, never on image pages; drag → pause + fluid live frame; release → resume-vs-frozen-frame
  per prior state at the frame-exact position; track click seeking without toggling while
  elsewhere-on-page clicks still toggle; ←/→ ±5 s with hold-to-repeat in both play states without
  state change; clamping at both ends; seek-to-end restarting the same video without advancing;
  revisit restarting from the beginning; keyboard seek inert on non-current/mid-gesture/image pages;
  media files byte-identical on disk afterwards) as the checklist the stakeholder exercises in
  `./scripts/app.sh run` — agent-recorded evidence is supporting material, never the approval.
- [ ] **11.7** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, budgets) with its impact, marked for coordinator ratification — silently deviating is
  forbidden (standing rule 6). Specifically watch for: the design §4 `acceptsMouseMovedEvents`
  fallback if taken (task 6.3); any `@testable` internals used in the conformance assertions
  (task 4.4); and the ADR numbering (D32–D34 vs the design §11's stale D30–D32 labels — the log's
  continuation rule applied; task 10.1).
- [ ] **11.8** Tick AC1–AC7 below and mirror them in evidence.md; leave the converge-owned AC8–AC10
  unticked.
- [ ] **11.9** Commit (docs-only; stage first, the hook runs the gate):
  `docs(e3-s1): task 11 — evidence and acceptance`.

---

## Acceptance criteria

Ticked by task 11, each backed by quoted tooling evidence:

- [ ] **AC1 · product R13 / S1, S2** — both invocations land: drag-scrub on the bar moves the
  position to the point under the scrubber, and ←/→ step ±5 s per press with hold-to-repeat —
  covered by the policy suite (step size, drift-free arithmetic, repeat parity, tolerant/precision
  split) and the conformance suite (frame-exact landing within one frame; approximate fast
  previews) + functional review.
- [ ] **AC2 · product R13 / S5–S8** — drag semantics unit-tested and reviewed: pause for the drag
  (gesture-scoped — the user's play/pause intent preserved), fluid live frame tracking the
  scrubber, frame-exact release, and state restoration (resume iff it was playing before).
- [ ] **AC3 · S3, S4, S11 (+ the E2-S3 S8 amendment)** — demand-driven chrome: the bar shows on
  mouse movement over the current video page (playing and paused), hides after the 3 s idle, is
  never shown on image pages or on keyboard seek, and hidden — paused included — the display shows
  only the frozen frame; the track click seeks without toggling while the strip is excluded from
  the whole-page toggle target and clicks elsewhere still toggle (visibility policy unit tests +
  functional review).
- [ ] **AC4 · S12–S15** — the guard matrix is unit-tested row by row (quiet consumed no-ops, never
  beep); clamping at both ends; a seek landing at the end hands over to the loop contract — the
  same video restarts and the feed **never** auto-advances (index untouched) — with the paused →
  frozen frame at the beginning rule; nothing is carried across visits (unit tests + functional
  review).
- [ ] **AC5 · S16 / product R17 · RNF-04** — read-only seek walked: no rewrite/export/reader/
  writer, no sidecars or derived files, no persisted positions, no new access paths (D19 session
  not re-derived); **no entitlement/plist/pbxproj diff** (D21 audit: empty diff + unchanged
  `codesign` output quoted); design §9.1 review table walked; media files byte-identical on disk
  after review.
- [ ] **AC6 · S17 / product R16 share · RNF-02** — responsiveness budgets measured and recorded
  from tooling (drag-preview issuance ≤ 16 ms and frame ≤ 150 ms p95 as reviewed; exact landing
  ≤ 300 ms p95 typical / ≤ 500 ms atypical); the seek-storm bound (≤ 1 in flight, one pending
  target) and the clock cadence ceiling (≤ 12 ticks/s, 10 Hz source) unit-asserted; zero added
  launch cost (`testLaunchPerformance` intact, no `Timer`/run-loop sources); drag fluid in
  functional review.
- [ ] **AC7 · R14 (E1-S2) decision + evidence & coverage** — the UI-test-mandate decision recorded
  (default gate scope, no `--uitests` obligation, with the honest caveat); full gate `--json`
  quoted verbatim (lint/format `pass`); the S1–S17 + product R-map walk recorded; the three ADRs in
  `docs/decisions.md` house format with design §11 titles; the design §13 `docs/architecture.md`
  updates done (incl. the §4 check-3 verdict and the §8 no-new-actor note); all deviations listed
  honestly.

Converge-owned — the coordinator ticks these; task 11 never does:

- [ ] **AC8 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — the task 11.6 checklist carried from the spec's AC list. Explicit
  approval required.
- [ ] **AC9 · validator review** — adversarial PASS over spec S1–S17 and the product R-map, design
  §9.1's review table, and both pillar-skill checklists.
- [ ] **AC10 · story closure** — backlog E3-S1 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e3-s1-scrub-seek`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review in the running app (`./scripts/app.sh run`): the AC8
   list (the spec's AC checklist, carried in task 11.6).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S17 / product R-map
   and design §10's test tables + §9.1's review table.
3. **Converge run** — `./scripts/validate.sh` (**default scope** — the UI-test-mandate decision:
   flows are not affected; no `--uitests` obligation for this story) alongside the functional
   review; its output is the story's final gate record.
4. **Closure** — tick AC8–AC10, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §13: **E3-S2** (speed) grows rate members on the same handle and may
extend the bar strip; **E3-S3** (volume) grows volume/mute members and lands v1's first persisted
preference; the bar strip is the ratified home for future transport chrome (this story's four
elements are the whole contract — spec non-goals); the keyboard table has room for more rows
(D28's frozen-contract pattern); **E4-S2** supersedes E2-S3 S15's stale-item fail-safe with live
removal semantics; double-click stays meaningless (spec non-goal).

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D31; task 10 appends the next three)
- [docs/spec.md](../../spec.md) — product source of truth (product R13; R16, R17; R15, R17 context;
  RNF-02, RNF-04; non-goals)
- [docs/architecture.md](../../architecture.md) — seam placement, layering; task 9 applies design
  §13
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E3-S1) and the E2–E5 coverage note
- [E2-S2 evidence §8](../e2-s2-vertical-feed-window/evidence.md) — the input-delivery lesson (why
  the bar trigger is `NSTrackingArea`, not a SwiftUI hover primitive; D33's context)
- [e2-s3 tasks](../e2-s3-basic-playback/tasks.md) — format and evidence precedent
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
