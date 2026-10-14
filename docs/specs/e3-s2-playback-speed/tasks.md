# E3-S2 · Playback speed — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S18 over product R14; R16 via S18, R17 via S17). Branch: `feat/e3-s2-playback-speed` — already
checked out; never switch branches mid-story. One task = one commit. Checkboxes are ticked during
implementation, each task's boxes in its own commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task (1–7) loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story selects the playback
   rate of user media files (a read of already-open user data — security; S17) across the playback
   start path, the AVFoundation rate/audio path, and SwiftUI view work (start-at-speed, instant rate
   changes, rapid stepping — performance): both pillar checklists apply (design §8, §9), and each
   task repeats the load step so it cannot be skipped. The design's flagged readings **F1–F3 are
   approved with their recommended answers** (stakeholder design gate): F1 — keyboard speed steps
   never show the bar; F2 — speed input while the current video is still starting is accepted and
   re-applied at install; F3 — `startPlayback` grows the `at speed:` parameter. Implement the
   approved readings; never re-open them.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy.
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source (picked up
   automatically, no flags); the SwiftLint and SwiftFormat gate steps must pass. Never edit the
   configs to make code pass.
4. **Synchronized groups / D21:** new source files land on disk under `InstantPlayer/` and
   `InstantPlayerTests/` and join their targets automatically — the one new source file
   (`Features/Feed/Domain/MediaPlaybackSpeed.swift`) joins the target through **synchronized groups
   (D21): no manual `project.pbxproj` edit, ever.** This story needs **no** config change at all
   (design §1.1, §9): no entitlements, no Info.plist keys, no build settings — the D21 audit expects
   a **zero project-config diff** (checked in task 10). If anything appears to need one, **stop and
   report — a coordinator escalation (D21), never an implementer edit.**
5. **Gate:** code tasks 1–7 run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Docs tasks 8–9 stage first, then run `./scripts/validate.sh --staged`. Task 10 runs
   the full gate with `--json` for evidence. Fix every failure before moving on; the pre-commit hook
   re-runs the gate on every commit. Never weaken the gate; `--no-verify` is forbidden. **Default
   gate scope throughout — no `--uitests` obligation** (the spec's UI-test-mandate decision: launch
   flows are untouched and the story's surface is unreachable without host-driven entry).
6. **Contracts are frozen:** the design §2 seam additions — `nonisolated enum MediaPlaybackSpeed:
   Float, CaseIterable, Sendable` (five cases — `quarter` 0.25, `half` 0.5, `normal` 1.0,
   `oneAndHalf` 1.5, `double` 2.0; declaration order = ladder order), `func setPlaybackSpeed(_
   speed: MediaPlaybackSpeed)`, `func startPlayback(for item: MediaItem, at speed: MediaPlaybackSpeed)
   async -> MediaPlayback?` — and their semantics (playing → rate write in the same main-actor turn,
   position preserved; paused → remembered, played at the selection on the next `resume()`;
   `resume()`/`restart()` play at the session's selected speed — **`play()` retired**; `pause()` and
   `seek(to:tolerance:)` untouched); the `.spectral` pitch pin at item creation (S15 — design §2);
   the design §3 state ownership and install re-apply; the design §5 policy surface (`selectSpeed(
   _:itemID:)`, `stepSpeedDownByKeyboard()`/`stepSpeedUpByKeyboard()`, `nonisolated static func
   stepped(_:up:)`); `PlaybackControlBarModel` grows `speed: MediaPlaybackSpeed`; the design §4 bar
   form (`Menu` + menu-style `Picker`, `speedText`'s five display strings, the badge iff ≠ 1×, the
   cluster's consumed drag island); the design §6 route rows (`[` keyCode 33 → `.speedDown`, `]`
   keyCode 30 → `.speedUp`); `MediaPlaybackEvent` **untouched**; the design §8 budgets. The design §4
   idle/menu fallback (menu label's press suspends the idle policy) is design-sanctioned but becomes
   a **ratified deviation** with its own record — task 10's deviations list — if taken (the
   E2-S3-fallback pattern). Name/signature/shape changes are design amendments: stop and report to
   the coordinator, never deviate silently. Same for any design §0 fact that no longer holds.
7. **No invented behavior:** spec non-goals hold — no volume/mute (E3-S3), no speed persistence
   (S9/S17 — no `UserDefaults`, nothing in `tmp`/`Caches`/`Application Support`), no speeds outside
   the five-preset ladder (no custom values, continuous slider, finer steps, or user-defined
   presets), no extra speed keys (no reset-to-1× key, no numeric shortcuts, no J/K/L hold), no image
   speed semantics, no bar contents beyond the speed control and speed badge (no hover thumbnails,
   chapter markers, or buffered ranges — volume/mute is E3-S3's strip addition), no seek/position/
   play-pause/loop semantics changes beyond the two evolutions the spec states plainly (S13, S14),
   no auto-advance (S14 — the index is never touched by speed), no export/reader/writer paths (S17),
   no sidecar or derived files, no logging of paths or file names (D20), no networking (D9), no
   bookmarks (D19), no ordering (E4-S1), no live sync (E4-S2). Guarded speed inputs do nothing
   quietly — never beep (S16, D28).
8. **Composition is untouched (design §7):** `App/AppDependencies.swift`, `App/RootView.swift`,
   `App/InstantPlayerApp.swift`, `FeedState.swift`, `PlayerSurfaceView.swift`, `WelcomeView.swift`,
   `SeekScheduler.swift` change **nothing** — no new seam, no new binding, no new actor; speed rides
   the already-bound `MediaPlayback` handle and the one `FeedViewModel` of D18. No task in this plan
   edits them. `App/AppDelegate.swift` changes only the monitor switch (task 6).

## Sequencing & parallelism

- **Wave 1 — task 1** (Domain ladder + seam additions + stub) is first: everything consumes the new
  ladder type and the grown protocols, and the stub grows in the same commit (the composition still
  binds the stub, and the E2-S3 view model + its scripted doubles must compile from this commit on).
- **Wave 2 — tasks 2 and 3 `[P]`**: the Data rate mapping (2) and the view-model policy (3) are
  independent of each other — 3 is developed against the stub from 1. Both depend only on 1 (the
  e3-s1 wave-2 precedent).
- **Wave 3 — tasks 4, 5, 6 `[P]`**: the seam suite (4) tests task 2's files; the bar surface (5) and
  the keyboard rows (6) are Presentation vs `App/` code over task 3's policy — three disjoint file
  sets. **Test placement note:** a test commit cannot gate-green before the code it tests is
  committed, so each suite sits in the wave immediately after its code (never same-wave with it) —
  except task 6, which carries its own frozen-table pins in the same commit (the table's tests are
  its contract; the e3-s1 task-8 precedent).
- **Wave 4 — task 7** (the policy suite) alone: it tests task 3's files and pins the badge rule
  through task 5's `speedText` formatter — so it follows both.
- **Wave 5 — tasks 8 and 9 `[P]`**: the `docs/architecture.md` updates (8) and the ADR batch (9) are
  transcription of the approved design into two different docs files; both wait for all code.
- **Task 10 is last** and depends on everything else.
- Routing (D3 — coordinator's call): tasks 1–7 → `implementer` (contract-bound code; both skills
  mandatory; task 6 is small but contract-sensitive — the frozen table — still `implementer`);
  tasks 8–9 → `implementer-flash` candidates (approved-design transcription; each its own docs
  commit — **task 8 needs write access to `docs/architecture.md`, outside the spec-author's
  permissions (design §13): the coordinator assigns it to an implementation agent with docs write
  access**); task 10 → `implementer` (evidence discipline).

---

## Task 1 — Feed Domain: speed ladder + rate seam additions + stub · design §1, §2, §1.1

Deliverable (code): `InstantPlayer/Features/Feed/Domain/MediaPlaybackSpeed.swift` (new),
`InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (grown),
`InstantPlayer/Features/Feed/Domain/MediaPlayerService.swift` (grown),
`InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (grown), plus minimal test-double
compile fixes. `MediaPlaybackEvent.swift` is **untouched** (design §1).

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** `MediaPlaybackSpeed` exactly per design §2 — `nonisolated enum MediaPlaybackSpeed:
  Float, CaseIterable, Sendable` with the five cases in ladder order (0.25/0.5/1/1.5/2). The ladder
  is structural (S2): nothing outside these cases exists to select, so no raw float can ever reach
  AVFoundation. Foundation-only (R10) — no `AVPlayer`, no `AVAudioTimePitchAlgorithm`, no `CMTime`
  in any Domain signature. The file joins the target through synchronized groups (D21) — **no
  pbxproj edit**.
- [x] **1.3** `MediaPlayback` grows exactly `func setPlaybackSpeed(_ speed: MediaPlaybackSpeed)` — a
  synchronous command (D25's pattern; unchanged `@MainActor` isolation) carrying the design §2
  contract in its docs: playing → the rate changes in this same main-actor turn (rate change only —
  no restart, no position change — S10); paused → the selection is remembered and the next
  `resume()` plays at it (S11); the session's selected speed is what `resume()`/`restart()` use
  (S14); the command never touches position, play/pause state, or seek behavior; **no rate read
  crosses the seam** (the frozen seam carries no state-query members — the E3-S1 `seekDispatchCount`
  precedent). `seek`/`resume`/`restart` doc evolution per design §2/§5 — `seek` reads "never changes
  the *selected* speed" (S13's evolved phrasing).
- [x] **1.4** `MediaPlayerService` per design §2/§3: `startPlayback(for:)` becomes `startPlayback(for
  item: MediaItem, at speed: MediaPlaybackSpeed) async -> MediaPlayback?`. Every D25 contract clause
  is unchanged (supersedes and tears down the previous session; async only for the asset load;
  unified `nil` failure answer; audio unmuted) plus one clause: **the session starts playing at
  `speed`** (approved reading F3).
- [x] **1.5** Stub grows the new members/parameter in **this same commit** (house stub pattern; the
  composition still binds the stub until this story's code is complete and tests use their own
  scripted doubles): the `at:` parameter and `setPlaybackSpeed` calls are recorded for wiring tests,
  selection state is reflected into the stub's observable behavior — zero I/O, no AVFoundation.
- [x] **1.6** Existing call sites and test doubles updated minimally so everything compiles from
  this commit on (scripted handles/services in `InstantPlayerTests/Features/Feed/FeedViewModelTests.swift`
  and `InstantPlayerTests/App/AppDependenciesTests.swift` gain the new member/parameter; full suites
  are tasks 4 and 7).
- [x] **1.7** Full gate `./scripts/validate.sh` — the new type and the grown protocols and stub must
  compile (that is what proves target membership). Fix, tick this task's boxes, commit:
  `feat(e3-s2): task 1 — playback-speed ladder and rate seam additions`.

## Task 2 — Feed Data: AVFoundation rate mapping + pitch pin · design §2, §3, §8(6)

Deliverable (code): `InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (extended),
`InstantPlayer/Features/Feed/Data/AVMediaPlayerService.swift` (extended).

- [x] **2.1** Load `swift-security` + `swift-performance` before editing (rate writes on user-media
  playback + the AVFoundation audio path — both pillars directly in play).
- [x] **2.2** Per-session state per design §2: `private var selectedSpeed: MediaPlaybackSpeed` on the
  `@MainActor` conformance, seeded from `startPlayback(for:at:)` and updated only by
  `setPlaybackSpeed`. It dies with the session (a fresh session is seeded again — design §3).
- [x] **2.3** Start (S12, S15) per design §2/§3: `AVMediaPlayerService.startPlayback` creates the
  item, pins `playerItem.audioTimePitchAlgorithm = .spectral` at item creation **before any audio
  renders** (the explicit pin — never the OS default; voices and music keep their pitch at 0.25× and
  2× alike), builds the session with the seeded speed, and calls `player.playImmediately(atRate:
  speed.rawValue)` — replacing today's `playImmediately(atRate: 1)` as the session's first and only
  start call. The rate is part of "ready to play": no 1× beat exists to observe (S12).
- [x] **2.4** `setPlaybackSpeed(s)` per design §2 (S10, S11): `selectedSpeed = s`; if `player.rate
  != 0` (playing) also `player.rate = s.rawValue` — one O(1) position-preserving write; if
  `player.rate == 0` (paused — the conformance reads the player's own state; no view-model pause flag
  crosses the seam) the write is skipped and the frozen frame stands. `player.rate != 0` ⇔ playing
  is exact here: the ladder's slowest preset is 0.25 (design §0 fact 1).
- [x] **2.5** `resume()` and `restart()` per design §2 (S11, S12, S14): both become "play at
  `selectedSpeed`" — `player.rate = selectedSpeed.rawValue` (for `restart()`: `player.seek(to:
  .zero)` first, then the rate write — design §0 fact 1's seek-then-rate ordering). **`player.play()`
  is never called again** (it is a rate-1.0 write — design §0 fact 1 — and would break S12/S14
  structurally).
- [x] **2.6** `pause()` and `seek(to:tolerance:)` are **untouched** — pause stays the rate-0 write
  (the paused case), and the seek path never touches rate (S13: a seek never changes the *selected*
  speed; a playing video keeps its pace across a seek).
- [x] **2.7** Security per design §9 (S17, RNF-04): reads only inside the D19 session — no
  `start/stopAccessingSecurityScopedResource`, no session re-derivation; playback/rate APIs only —
  **no** `AVAssetExportSession`, **no** `AVAssetReader`/`AVAssetWriter`, no `write(to:)`, no sidecar,
  no disk cache, **no `UserDefaults`** (S9: no speed preference anywhere); no logging of paths or
  names (D20).
- [x] **2.8** Full gate. Fix, tick; commit:
  `feat(e3-s2): task 2 — playback-rate mapping in the AVFoundation conformance`.

## Task 3 — Speed policy in `FeedViewModel` · design §3, §5, §4 (policy), §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (extended;
existing tests updated to compile in the same commit if signatures move) — including the grown
`PlaybackControlBarModel` (`speed: MediaPlaybackSpeed` alongside the E3-S1 fields; no separate file
appears in the design §1 inventory).

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** Ownership per design §3 (S8, S9): `private(set) var selectedSpeed: MediaPlaybackSpeed =
  .normal` — **app-session state**, written only by user input (menu selection, key step), read by
  every start, the badge, and the menu. Not cleared by `stopPlayback`, `adopt` (a newly opened
  folder), or the welcome transition; it resets only at relaunch by object lifetime (RootView's one
  `FeedViewModel` per run, D18) — nothing is persisted. The deliberate asymmetry with positions
  stands: position restarts, speed carries (E3-S1 S15 ↔ S8).
- [x] **3.3** Entry points per design §5 — `selectSpeed(_ speed: MediaPlaybackSpeed, itemID:
  MediaItem.ID)` (the menu route) and `stepSpeedDownByKeyboard()` / `stepSpeedUpByKeyboard()` (the
  `[`/`]` routes: no item id — resolve to `currentItemID`, exactly like `stepSeek`) converging on one
  shared core: run the guard (3.5); then `selectedSpeed = speed`; if a live handle exists,
  `handle.setPlaybackSpeed(speed)`; refresh the bar model preserving its current visibility — a
  keyboard step **never** shows the bar (approved F1), a menu selection refreshes the bar visible and
  restarts the 3 s idle countdown (the `scrubEnded` precedent, design §4). Never touches
  `isPlaybackPaused`, `displayedPosition`, or the index (S10's state neutrality — a speed step can
  never toggle play/pause).
- [x] **3.4** Stepping per design §5 (S5–S7): `nonisolated static func stepped(_ speed:
  MediaPlaybackSpeed, up: Bool) -> MediaPlaybackSpeed` — one pure function walking
  `MediaPlaybackSpeed.allCases` by one and **clamping at the ends** (0.25× and 2× are ladder ends;
  the ladder never wraps). The keyboard routes compute `stepped(selectedSpeed, up:)` and hand the
  result to the shared core; auto-repeat arrives as repeated calls and clamps idempotently.
- [x] **3.5** Guard matrix per design §5's table (S16 + the approved readings) as one unit-tested
  decision surface — every row: settled current video playing → applied in the same turn (S10);
  settled current video paused (frozen frame, parked at an end) → remembered (S11); speed input
  while a scrub drag is in flight → **remembered** (S10's approved composition note — unlike seek,
  which consumes mid-drag), effective at the drag's `resume()`; speed input while the video is still
  starting → **accepted** as session state and applied at install (approved F2); non-current page,
  paging gesture in flight, image page, neutral unavailable state (incl. sticky playback failure) →
  **consumed no-op** (spy records nothing; no sound, no visual change, no error, never beep); no open
  feed → keys pass through at route level (D28 unchanged). The guard needs **no duration and no live
  handle** (unlike `seekGuard`); the view is never consulted.
- [x] **3.6** Preservation per design §5 (S13, S14): the seek paths (`scrubChanged`/`scrubEnded`/
  `seekFromTrackClick`/`stepSeek`/`commitExactSeek`/`endHandover`) never call `setPlaybackSpeed` and
  never write `selectedSpeed` — no scrub, track click, keyboard seek, or end handover can reset the
  speed; `.reachedEnd` → `handle.restart()` preserves it structurally (task 2's mapping).
- [x] **3.7** Start-at-speed ordering per design §3 (S12): `startPlayback(for:at: selectedSpeed)` on
  auto-play and on the revisit restart; `install` re-applies `handle.setPlaybackSpeed(selectedSpeed)`
  as one synchronous statement before the event/clock loops attach — so a mid-load selection governs
  the session it landed on (approved F2's window).
- [x] **3.8** `refreshControlBar` per design §5 (S4): carries `speed: selectedSpeed` into
  `PlaybackControlBarModel`; the model stays non-`nil` exactly under E3-S1's rule (the settled
  current video's live player page) and `speed` never affects that rule.
- [x] **3.9** Full gate (update existing `FeedViewModelTests` compile breaks in this same commit —
  minimal fixes; the full policy suite is task 7). Fix, tick; commit:
  `feat(e3-s2): task 3 — speed policy in the feed view model`.

## Task 4 — Feed Data seam suite: rate mapping + pitch + perf measures `[P]` · design §10.2, §8(1), §8(3)

Deliverable (code): `InstantPlayerTests/Features/Feed/AVMediaPlaybackSpeedTests.swift` (new, the
sibling of `AVMediaPlaybackSeekTests.swift`), `InstantPlayerTests/Features/Feed/MediaFixture.swift`
(extended if needed — design §10.2's fixture pattern: short multi-frame MP4 **with an audio track**,
throwaway temp folders), stub-wiring rows.

- [x] **4.1** Load `swift-security` + `swift-performance` before editing.
- [x] **4.2** Frameworks per house pattern: Swift Testing (`@testable import InstantPlayer`, `@Test`
  + `#expect`) for the suites; the two design §8 perf cases use XCTest `measure` exactly as the
  design names them — the one deliberate exception (the D25 run-loop-pumped, `nonisolated` test
  pattern; a semaphore bridge would deadlock the `@MainActor` seam).
- [x] **4.3** Conformance rows per design §10.2 (the real `AVMediaPlayback`/`AVMediaPlayerService`):
  `startPlayback(for:at: .double)` begins with `player.rate == 2` (the §3 ordering pin — via
  `@testable` internals, the unmuted-start precedent of D25); `setPlaybackSpeed` while playing
  changes `player.rate` in-turn and leaves `currentTime` unmoved (S10); while paused leaves rate 0
  and a later `resume()` starts at the selection (S11); `restart()` plays at the selection (S14); a
  `seek` leaves the selection untouched (S13); `playerItem.audioTimePitchAlgorithm == .spectral` at
  creation (S15 — the explicit pin, never the default); `stop()` leaves no rate work pending (E2-S3
  §10.2 patterns carry).
- [x] **4.4** Stub/wiring rows per design §10.2: `StubMediaPlayerService`/stub handle record the
  `at:` parameter and `setPlaybackSpeed` calls (house pattern) — asserted for the composition's
  wiring.
- [x] **4.5** Perf cases per design §10.2 / §8(1) / §8(3): the command→rate-write `measure` (the
  selection is issued in the same main-actor turn — ≤ 16 ms; pace-change observability ≤ 100 ms p95
  as reviewed) and the step-path `measure` (a step is one O(1) ladder move + one O(1) observable
  write + one synchronous rate write; end-of-ladder repeats clamp idempotently). Measured numbers are
  recorded in task 10 **from tooling, never from memory**.
- [x] **4.6** Full gate — the tests run and must be green. Fix, tick; commit:
  `test(e3-s2): task 4 — playback-seam speed tests`.

## Task 5 — Bar surface: speed menu + badge + cluster island + drill `[P]` · design §4, §7

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/PlaybackControlBarView.swift`,
`InstantPlayer/Features/Feed/Presentation/FeedItemView.swift`,
`InstantPlayer/Features/Feed/Presentation/FeedView.swift`.

- [ ] **5.1** Load `swift-security` + `swift-performance` before editing (SwiftUI views + hit-test
  geometry — skill §2 applies directly).
- [ ] **5.2** Strip layout per design §4 (S3 — the plain amendment of E3-S1's bar-contents contract):
  the track row is unchanged (full-width thin line + thumb); the label row becomes `HStack { elapsed
  … Spacer … [badge] … speed-menu … duration }` — elapsed stays leading, duration stays trailing
  (E3-S1's visual contract), badge and menu form one trailing cluster. Everything else about the bar
  carries unchanged: demand-driven visibility, 3 s idle-hide, structural absence everywhere the model
  is `nil`, the strip's carve-out from the whole-page toggle (a click or selection on the speed
  control never toggles play/pause).
- [ ] **5.3** Speed control per design §4 (S1) — pinned form: a SwiftUI `Menu` labeled
  `Label("Speed", systemImage: "speedometer")` (constant copy — at 1× the closed control shows no
  number, US5's chrome minimality). Contents: a `Picker` over `MediaPlaybackSpeed.allCases` with
  `.pickerStyle(.menu)` (the native mutually-exclusive menu with a checkmark), rows rendered by
  `nonisolated static func speedText(_:) -> String` on the bar view (the `mmss` precedent) — the
  exact five display strings `0.25×`, `0.5×`, `1×`, `1.5×`, `2×`. The selection binding is
  write-through to the drilled `onSpeedSelected` closure (the binder owns no state — D8); the menu
  checkmark and badge render from `model.speed` alone.
- [ ] **5.4** Speed badge per design §4 (S4) — pinned form: rendered **iff `model.speed != .normal`**
  (nothing at 1×, the identity at every other preset), text from `speedText`, styled
  `\.caption.monospacedDigit()` in a `Capsule().fill(.quaternary)` — monospaced so the strip does not
  twitch as digits change.
- [ ] **5.5** Cluster hit-test island per design §4 (S3's carve-out, mechanically): the badge/menu
  cluster gets its own `contentShape`; taps on the badge fall to the strip's existing consumed no-op
  (a badge is not a control); taps on the menu are claimed by the `Menu` itself; a **drag** starting
  anywhere on the cluster is consumed by the cluster's own `highPriorityGesture(DragGesture(
  minimumDistance: 3))` no-op — speed surface interactions never toggle playback (the strip is a
  sibling above the tap surface), never start a scrub (the track gesture is the track's own), and
  never start paging (the consumed drag beats the scroll surface).
- [ ] **5.6** Drill per design §6/§7: `FeedPageActions` gains `speedSelected: (MediaPlaybackSpeed) ->
  Void`; `FeedView` drills it per page capturing the item id (the `togglePlaybackFromTap(itemID:)`
  tap-closure precedent) into `selectSpeed(_:itemID:)`. `FeedItemDisplayState.player(MediaPlayback)`
  is unchanged; the cell still never sees the item. No App-level mouse monitor, no focus handling, no
  new delivery mechanism anywhere (D28; design §6).
- [ ] **5.7** Full gate. If functional review later shows the idle-hide disturbing an open menu, the
  design §4 recorded fallback (the menu label's press suspends the idle policy) is the sanctioned
  path — a **ratified deviation** recorded in task 10 if taken. Fix, tick; commit:
  `feat(e3-s2): task 5 — speed menu and badge on the control bar`.

## Task 6 — Keyboard speed rows `[P]` · design §6

Deliverable (code): `InstantPlayer/App/FeedKeyCommand.swift`, `InstantPlayer/App/AppDelegate.swift`
(monitor switch), `InstantPlayerTests/App/FeedKeyCommandTests.swift` (updated — the table's contract
pins land with the table, the e3-s1 task-8 precedent).

- [ ] **6.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **6.2** Route table per design §6 — the frozen table gains exactly two cases and two rows:
  `[` (keyCode **33**) → `.speedDown`, `]` (keyCode **30**) → `.speedUp` (codes verified against
  HIToolbox `Events.h`, design §0 fact 3). With an open feed both are **always consumed** and routed
  to the guard matrix (which no-ops quietly on ineligible states — S16; never beep — D28), because
  passing through would re-expose them to the unhandled-key path; no open feed → `.passThrough`;
  auto-repeat = repeated steps (S6 — the D22/D34 parity: the route ignores `isRepeat`, one step per
  keyDown); ⌘/⌥/⌃ → `.passThrough`; ⇧ alone does not modify (`⇧[` steps down like `[`). 123/124,
  125/126, space (49), and the paging/modifier rows are behavior-frozen and stay green —
  `nonArrowKeysPassThrough` (key code 0) is unaffected. **Recorded contract change:** 33/30
  previously fell to the default `passThrough` row — the frozen table's discipline means the change
  is recorded (D38) and pinned by new tests.
- [ ] **6.3** `AppDelegate` monitor switch gains the two cases → the view model's
  `stepSpeedDownByKeyboard()` / `stepSpeedUpByKeyboard()` (task 3's unchanged `@MainActor` methods;
  the guard matrix decides, so ineligible states consume and no-op quietly). Existing cases and the
  `hasOpenFeed` derivation unchanged.
- [ ] **6.4** `FeedKeyCommandTests` per design §10.1: 33 → `.speedDown`, 30 → `.speedUp` with
  auto-repeat parity (`arrowAutoRepeatStillPages`/`seekAutoRepeatStillSteps`' sibling); ⌘/⌥/⌃-modified
  pass through; ⇧ alone steps; welcome passes through; **no existing pin changes** (33/30 previously
  hit the default row — the recorded consequence is new rows plus new pins).
- [ ] **6.5** Full gate. Fix, tick; commit:
  `feat(e3-s2): task 6 — keyboard speed rows on the feed key router`.

## Task 7 — Policy suite: `FeedViewModel` speed rows · design §10.1

Deliverable (code): `InstantPlayerTests/Features/Feed/FeedViewModelTests.swift` extended with the
design §10.1 rows (injected seam doubles: spy `MediaPlayerService` + scripted handle — the E2-S3
§10.1 pattern; no UI, no window, no AVFoundation).

- [ ] **7.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **7.2** Preset ladder (S2): `MediaPlaybackSpeed` has exactly the five cases at
  0.25/0.5/1/1.5/2 — nothing else exists to select.
- [ ] **7.3** Stepping + clamping (S5–S7): up/down walks the ladder; at 2× an up-step stays 2×, at
  0.25× a down-step stays 0.25× — never wraps; the pure `stepped(_:up:)` pinned directly.
- [ ] **7.4** Hold-to-repeat (S6): repeated route calls = repeated steps (the auto-repeat parity
  test, `seekAutoRepeatStillSteps`' sibling), clamping idempotently at the ends.
- [ ] **7.5** Guard matrix (S16): the design §5 table as tests — non-current, mid-gesture, image,
  unavailable, welcome all consumed no-ops (spy records nothing, `selectedSpeed` unchanged).
- [ ] **7.6** Mid-drag input (S10's approved composition note): a speed input during a scrub drag is
  remembered (state changes, handle command issued) and plays at the drag's `resume()` — the
  opposite of the seek matrix's consume row, asserted side by side.
- [ ] **7.7** Mid-start input (approved F2): a selection while `startPlayback` is in flight updates
  session state and is re-applied at install (the scripted handle records `setPlaybackSpeed` in
  `install`).
- [ ] **7.8** Start-at-speed ordering (S12): `startPlayback` receives the current `selectedSpeed` on
  auto-play and on revisit; install re-applies; a fresh session at 2× has no intermediate state
  where 1× is requested (spy's call log).
- [ ] **7.9** Carry semantics (S8, S9): speed survives `stopPlayback`, paging, revisit, a newly
  opened folder (`handle(entryAction:)` → `adopt`) and the welcome round-trip; a brand-new
  `FeedViewModel` starts at `.normal` (S9 — the relaunch boundary).
- [ ] **7.10** Seek preservation (S13): scrub/track click/±5 s/`commitExactSeek`/`endHandover` never
  call `setPlaybackSpeed` and never change `selectedSpeed`.
- [ ] **7.11** Loop preservation (S14): `.reachedEnd` → `restart()` leaves `selectedSpeed` untouched;
  the scripted handle's restart is at the selection.
- [ ] **7.12** Badge rule (S4): `controlBarModel.speed` tracks `selectedSpeed`; the ≠ 1× rule is the
  binder's single comparison — pinned via `speedText` (task 5's formatter — the exact five strings)
  + model assertions.
- [ ] **7.13** State neutrality (S10): every speed input leaves `isPlaybackPaused`,
  `displayedPosition`, and the index observable-unchanged.
- [ ] **7.14** Idle/menu interplay (design §4): a menu selection refreshes the bar visible and
  restarts the 3 s countdown (the `scrubEnded`-style policy test with injected `now`).
- [ ] **7.15** Full gate — green. Fix, tick; commit:
  `test(e3-s2): task 7 — speed policy tests`.

## Task 8 — Architecture reference updates `[P]` · design §13

Deliverable (docs): `docs/architecture.md` — the three required same-story updates (design §13).
Follows the E2-S2/E2-S3/E3-S1 precedent: the standing architecture reference is updated by its own
docs commit once the code it documents has landed (tasks 1–7). **This task needs docs write access
outside `docs/specs/`** (the design could not write this file — its §13 records the permission
boundary and reports it to the coordinator; this task-phase deliverable is exactly that list).

- [ ] **8.1** Update `docs/architecture.md` exactly per design §13: (1) **§3 source tree** —
  re-annotate `Features/Feed/Domain/MediaPlayback.swift` (gains `setPlaybackSpeed(_:)`;
  seek/resume/restart doc evolution), `Domain/MediaPlayerService.swift` (`startPlayback(for:at:)`),
  `Data/AVMediaPlayback.swift` (per-session speed + rate mapping), `Data/AVMediaPlayerService.swift`
  (pitch pin + `playImmediately(atRate:)`), `Data/StubMediaPlayerService.swift`,
  `Presentation/FeedViewModel.swift` (speed policy + guard rows + `PlaybackControlBarModel.speed`),
  `Presentation/PlaybackControlBarView.swift` (speed menu + badge + cluster island),
  `Presentation/FeedItemView.swift` (`FeedPageActions.speedSelected`), `Presentation/FeedView.swift`
  (drill), `App/FeedKeyCommand.swift` (speed rows), `App/AppDelegate.swift` (speed cases); add
  `Features/Feed/Domain/MediaPlaybackSpeed.swift`. (2) **§4 check (3):** explicitly **no wording
  change** — record that verdict so the check does not look overlooked: the rate seam moves no new
  kind across the boundary (`MediaPlaybackSpeed` is a Domain-owned Foundation-only value with `Float`
  raw values — the `MediaSeekTolerance`/`URL`/`Data` precedents; no `AVPlayer`,
  `AVAudioTimePitchAlgorithm`, or `CMTime` in any Domain signature). The two contract evolutions the
  spec states plainly — the bar-contents amendment (S3: four → six elements) and the seek-contract
  evolution (S13: "a seek never changes the *selected* speed"; S14: the loop preserves it) — are
  documentation-level evolutions carried into the tree annotations; nothing else in either contract
  changes. (3) **§8 evolution note:** **no new actor** — D8's trigger is unmet again (the per-session
  speed is one field on the existing `@MainActor` `AVMediaPlayback` conformance; nothing crosses
  isolation); the `@MainActor`-seam pattern of D25 carries unchanged.
- [ ] **8.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [ ] **8.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e3-s2): task 8 — architecture reference updates`.

## Task 9 — ADR batch `[P]` · design §11

Deliverable (docs): `docs/decisions.md` — append the three ADRs of design §11.

- [ ] **9.1** Append three ADRs **continuing the numbering from the log's current end** (the house
  rule — AGENTS.md rule 6; the e3-s1 task-10 precedent). The design §11 plans D36–D38 and at
  authoring the log ends at **D35**, so the next free numbers are **D36, D37, D38**; if the log moves
  before this task runs, use the next free numbers and record the shift in task 10's deviations list
  for coordinator ratification (the E3-S1 renumber precedent). House heading `## D# — title · date ·
  status` (date = commit date, `YYYY-MM-DD`), each with context, decision, alternatives,
  consequences. **Titles and one-line decisions exactly per design §11:**
  **D36 — Playback-speed rate seam: typed five-preset ladder, `startPlayback(for:at:)` seeds the
  play call, `setPlaybackSpeed` maps to `AVPlayer.rate` (rate 0 while paused, selection remembered;
  pitch pinned `.spectral`)** (→ S2, S10–S15, S12's start ordering) · **D37 — Speed surface & badge:
  `Menu` preset picker + ≠1× monospaced badge on the overlay bar strip (bar contents: four → six
  elements)** (→ S1, S3, S4) · **D38 — Keyboard speed rows on the feed-key router: `[`/`]` (33/30) =
  one-preset steps with paging's repeat parity and ladder-end clamps** (→ S5–S7, S16).
- [ ] **9.2** Pull each entry's alternatives from the matching design §12 rows — D36: continuous
  slider/custom values/finer steps, per-video speed memory, bare `Float` rate on the seam, stepping
  policy on the enum, `player.play()` for resume/restart, `playImmediately(atRate:)` for every rate
  change, the handle-only rate-before-play shape, a new `MediaPlaybackRate` seam/handle, the pitch
  choices (`.varispeed`, `.timeDomain`, `.lowQualityZeroLatency`, the item default);
  D37: popover with explicit `isPresented`, cycling button, badge merged into the menu label, badge
  always visible, speed menu on the tap surface, persisting the speed;
  D38: `.stepSpeed(Int)` as one payload route case, repeat-ignored `[`/`]` like space, passing the
  keys through on ineligible states, speed keys showing the bar as feedback.
- [ ] **9.3** Status `accepted`. Each entry cites its implementing task commits (tasks 1–6) in its
  consequences. D36 carries the approved F2/F3 readings and the §3 honesty limit (a selection landing
  in the one-executor-hop window of a starting session can leave that hop of audio at the previous
  selection — frames never show the wrong rate); D37 carries the approved F1 reading (keyboard steps
  never show the bar) and the open-menu/idle sharp edge with its recorded fallback (§4); D38 carries
  the frozen-table contract change (33/30 no longer pass through).
- [ ] **9.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; tick; commit:
  `docs(e3-s2): task 9 — ADRs D36–D38 — rate seam, speed surface, and keyboard speed rows`.

## Task 10 — Verification & evidence · spec acceptance criteria, design §8, §10

Deliverable (docs): `docs/specs/e3-s2-playback-speed/evidence.md` (new) + acceptance-criteria ticks
in this file.

- [ ] **10.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **10.2** Traceability walk: **S1–S18 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product R-map**
  of the spec's acceptance table (product R14 → story outcome → verified by; product R16 via S18 and
  product R17 via S17 as the cross-cutting/inherited notes, never claimed). Record both tables in
  evidence.md.
- [ ] **10.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/gate.json` (`<tmp>` = session temp dir outside the repo; the
  JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every step name
  and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [ ] **10.4** **UI-test mandate (spec Story context; R14 of E1-S2):** record the decision — flows
  are **not** affected, the converge run keeps the **default gate scope with no `--uitests`
  obligation** ([docs/development.md](../../development.md) §3) — together with the spec's honest
  caveat (even a `--uitests` run could not exercise speed selection: no media is open in the launch
  tests) and the fact that `testLaunchPerformance` and the launch tests run green unchanged within
  the full gate of 10.3.
- [ ] **10.5** Record from tooling, never from memory: (a) the design §8 performance measurements —
  task 4.5's `measure` numbers against the §8(1) rate-change budgets (issue ≤ 16 ms in-turn; pace
  change ≤ 100 ms p95) and the §8(3) step-path bounds, with §8(2)'s zero-added-start-wait verified by
  the existing start-latency measure not regressing; (b) the **D21 audit** (design §1.1, §9, §13) —
  `git diff main...HEAD` stat restricted to `InstantPlayer.xcodeproj/ InstantPlayer/Config/` showing
  **no changes** (empty output quoted) and the `codesign -d --entitlements` output showing D19's
  four read-only keys **unchanged**; (c) the design §9.1 sandbox/media-read review table walked row
  by row (no export/reader/writer, no sidecars, no `UserDefaults`, **no speed preference anywhere** —
  S9, S17).
- [ ] **10.6** Functional-review checklist: carry the spec's AC list verbatim into evidence.md (the
  design §10.3 list — selecting each preset from the bar's speed menu and seeing it applied
  immediately on a playing video; selecting while paused and seeing it applied on resume; the badge
  appearing whenever the speed differs from 1× and vanishing at 1×; `[`/`]` stepping through the
  ladder with hold-to-repeat and clamping at 0.25× and 2×; the speed carrying to the next clip and
  across revisits and newly opened folders until changed; a relaunch starting at 1×; every clip
  starting already at the selected speed with no 1× flash and no extra wait; scrubs, track clicks,
  keyboard seeks, and loop restarts all keeping the selected speed; audio sounding natural at 0.25×
  and at 2×; speed keys doing nothing — and changing nothing — on an image page, a non-current page,
  and mid-paging-gesture; clicks on the speed control never toggling play/pause; rapid speed changes
  staying stall-free; and the media files byte-identical on disk after all of the above) as the
  checklist the stakeholder exercises in `./scripts/app.sh run` — functional evidence is recorded as
  what was exercised and observed in the running app (screenshot paths may be recorded, never read
  back into context); agent-recorded evidence is supporting material, never the approval.
- [ ] **10.7** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, budgets) with its impact, marked for coordinator ratification — silently deviating is
  forbidden (standing rule 6). Specifically watch for: the design §4 idle/menu fallback if taken (a
  ratified deviation with its own record — task 5.7); any `@testable` internals used in the
  conformance assertions (task 4.3); and the ADR numbering (D36–D38 vs the log's next free numbers
  if it moved — task 9.1).
- [ ] **10.8** Tick AC1–AC7 below and mirror them in evidence.md; leave the converge-owned AC8–AC10
  unticked. Confirm the spec's acceptance checklist is mirrored into evidence.md with its tick state
  (the four spec-side items met; the gate-evidence item backed by 10.3's quoted JSON); the
  functional-review and approval-gate boxes are coordinator-owned and stay unticked.
- [ ] **10.9** Commit (docs-only; stage first, the hook runs the gate):
  `docs(e3-s2): task 10 — evidence and acceptance`.

---

## Acceptance criteria

Ticked by task 10, each backed by quoted tooling evidence:

- [ ] **AC1 · product R14 / S1, S2, S5–S7** — both invocations land on the exact five-preset ladder:
  the bar's speed menu selects any preset, and `[`/`]` step one preset per press (hold-to-repeat)
  with clamping at 0.25× and 2× and no wrap — covered by the policy suite (ladder, `stepped` pins,
  repeat parity, boundary clamps) + functional review.
- [ ] **AC2 · S8, S9, S12** — session scope and starts: the selection carries across paging,
  revisits, and newly opened folders until changed; a relaunch starts at 1× (nothing persisted);
  every start — auto-play, revisit restart, loop — begins at the selected speed from the first frame
  with no 1× flash and no added wait (policy suite + seam suite ordering pins + functional review).
- [ ] **AC3 · S3, S4 (+ S1's carve-out)** — the bar is the four E3-S1 elements plus the speed control
  and the speed badge (badge iff ≠ 1×, identifying the selection); the cluster is a hit-test island,
  so clicks and drags on the speed surface never toggle play/pause, scrub, or page; keyboard steps
  never show the bar (approved F1) — policy/badge-rule tests + functional review.
- [ ] **AC4 · S10, S11, S13, S14, S16 (+ S10's composition note, approved F2)** — application rules:
  immediate rate change while playing (position and play/pause untouched), remembered while paused,
  mid-scrub-drag, and mid-start (applied at install); no seek or loop restart resets the speed; the
  full guard matrix is unit-tested row by row — quiet consumed no-ops, never beep.
- [ ] **AC5 · S15, S17, S9 / product R17 · RNF-04** — pitch-corrected audio pinned `.spectral` at item
  creation (seam suite); read-only speed walked: no rewrite/export/reader/writer, no sidecars or
  derived files, no speed preference at rest, no new access paths (D19 session not re-derived);
  **no entitlement/plist/pbxproj diff** (D21 audit: empty diff + unchanged `codesign` output
  quoted); design §9.1 review table walked; media files byte-identical on disk after review.
- [ ] **AC6 · S18 / product R16 share · RNF-02** — responsiveness budgets measured and recorded from
  tooling (rate change issued in the same main-actor turn ≤ 16 ms; pace change ≤ 100 ms p95; start
  path adds zero work; rapid stepping O(1) and backlog-free); zero added launch cost (no `Timer`/run-
  loop sources — the one re-arm call site; `testLaunchPerformance` intact); speed changes fluid in
  functional review.
- [ ] **AC7 · R14 (E1-S2) decision + evidence & coverage** — the UI-test-mandate decision recorded
  (default gate scope, no `--uitests` obligation, with the honest caveat); full gate `--json` quoted
  verbatim (lint/format `pass`); the S1–S18 + product R-map walk recorded; the three ADRs in
  `docs/decisions.md` house format with design §11 titles; the design §13 `docs/architecture.md`
  updates done (incl. the §4 check-3 verdict and the §8 no-new-actor note); all deviations listed
  honestly.

Converge-owned — the coordinator ticks these; task 10 never does:

- [ ] **AC8 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — the task 10.6 checklist carried from the spec's AC list. Explicit
  approval required.
- [ ] **AC9 · validator review** — adversarial PASS over spec S1–S18 and the product R-map, design
  §9.1's review table, and both pillar-skill checklists.
- [ ] **AC10 · story closure** — backlog E3-S2 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e3-s2-playback-speed`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review in the running app (`./scripts/app.sh run`): the AC8
   list (the spec's AC checklist, carried in task 10.6).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S18 / product R-map and
   design §10's test tables + §9.1's review table.
3. **Converge run** — `./scripts/validate.sh` (**default scope** — the UI-test-mandate decision:
   flows are not affected; no `--uitests` obligation for this story) alongside the functional review;
   its output is the story's final gate record.
4. **Closure** — tick AC8–AC10, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §13: **E3-S3** (volume & mute) grows volume/mute members on the same
handle (the `setPlaybackSpeed` shape is the template), adds volume controls to the strip as its own
spec decision (the D37 pattern — the bar is now four E3-S1 elements + speed control + speed badge),
and lands v1's first persisted preference (product R20); a persisted speed, if ever wanted, belongs
with that story. The keyboard table has room for more rows (D28's frozen pattern; D38 is the third
addition).

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D35; task 9 appends the next three)
- [docs/spec.md](../../spec.md) — product source of truth (product R14; R11, R13, R15, R17 context;
  R16; RNF-02, RNF-04; non-goals)
- [docs/architecture.md](../../architecture.md) — seam placement, layering; task 8 applies design
  §13
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E3-S2) and the E2–E5 coverage note
- [e3-s1 tasks](../e3-s1-scrub-seek/tasks.md) — format, evidence, and ADR-task precedent
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
