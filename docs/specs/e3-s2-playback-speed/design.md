# E3-S2 · Playback speed — Design

How the current video's playback rate is chosen and kept: a five-preset ladder (S2) selected from
a speed menu on the ratified overlay control bar (S1, S3, S4) and stepped with `[`/`]` (S5–S7),
owned as app-session state that carries until changed (S8) and resets only at relaunch (S9),
applied immediately while playing and remembered while paused (S10, S11), present from the first
frame of every start and restart (S12), preserved across every seek and the loop (S13, S14),
pitch-corrected in audio (S15), guarded to the settled current video (S16), read-only and
write-free (S17), and instant under every input (S18). Story spec: [spec.md](spec.md) (S1–S18 over
product R14; R16 via S18, R17 via S17). Structure follows [docs/architecture.md](../../architecture.md)
(D7–D10); this story lands exactly on the surface E3-S1 handed over — §13 of
[the E3-S1 design](../e3-s1-scrub-seek/design.md): rate members grow on the same handle, the bar
strip may grow, the keyboard table has room for rows. Pillars: RNF-02 and RNF-04 — mandatory
sections below (§8, §9); the design was written against the `swift-performance` and `swift-security`
skills (`.opencode/skills/swift-performance`, `.opencode/skills/swift-security`), and every
implementer and the validator load them before touching this code (D5).

Scope reminder: this story ends at "the user can set playback speed from the bar and the keyboard,
it sticks for the session, and nothing is written". No volume/mute or any persistence (E3-S3),
no speeds outside the ladder, no extra speed keys, no bar contents beyond the speed control and
speed badge (spec non-goals), no seek/position/play-pause/loop semantics changes beyond the two
contract evolutions the spec states plainly (Story context; S13, S14). **No project-config work of
any kind** (D21 note, §1.1, §9). No clarification markers exist in this design — every decision
below is made and traceable to S-/product-R numbers; the three readings a stakeholder may still
veto are recorded inline as **flagged readings** with recommended answers (the approved spec's own
pattern), and are listed in §13 for the design gate.

**Requirements map (S1–S18 → sections):**

| Req | Served by | Req | Served by |
|---|---|---|---|
| S1 menu applies | §2 (seam), §4 (menu), §5 (entry points) | S10 immediate while playing | §2 (rate mapping), §8 budget 1 |
| S2 five presets | §2 (`MediaPlaybackSpeed`), §5 (stepping) | S11 remembered while paused | §2 (paused case), §5 (mid-drag row) |
| S3 bar contents + control/badge | §4 (surface), §13 (contract evolution) | S12 start-at-speed | §2 (start parameter), §3 (ordering), §8 budget 2 |
| S4 badge iff ≠ 1× | §4 (badge rule), §5 (model) | S13 seek preserves speed | §5 (seek paths untouched) |
| S5 keyboard step | §6 (router rows), §5 (step policy) | S14 loop preserves speed | §2 (`restart()` mapping), §5 |
| S6 hold-to-repeat | §6 (repeat parity), §8 budget 3 | S15 pitch-corrected audio | §2 (pitch algorithm), §10.2 |
| S7 clamping at ladder ends | §5 (pure step function) | S16 guard matrix | §5 (the matrix table), §6 |
| S8 carry until changed | §3 (state ownership), §5 | S17 read-only | §9 (Security, RNF-04) |
| S9 relaunch at 1× | §3 (no persistence), §9 | S18 responsiveness | §8 (Performance, RNF-02) |

## 0 · Platform and toolchain facts this design is built on

1. **`AVPlayer` rate is the playback-speed mechanism, and `play()` is a rate-1.0 write.** Setting
   `player.rate` to a nonzero value starts (or re-paces) playback at that rate **preserving the
   position** — the S10 shape; `player.pause()` is a rate-0 write (the paused case: the frozen
   frame); `play()` is documented as beginning playback at rate 1.0 — so calling it for
   `resume()`/`restart()` would silently reset a 2× session to 1× (the trap this design closes in
   §2). `playImmediately(atRate:)` is the start call: it begins at the given rate *and* pins
   `automaticallyWaitsToMinimizeStalling = false` (already E2-S3's start policy for local files),
   after which plain rate writes bite immediately. A pending seek lands before the following rate
   applies (E3-S1 fact 1 carries) — so seek-then-rate ordering in `restart()` is safe without
   completion plumbing.
2. **Pitch behavior under rate change is an explicit per-item setting (verified against Apple
   documentation, this story).** `AVPlayerItem.audioTimePitchAlgorithm` selects one of
   `AVAudioTimePitchAlgorithm`'s four constants: `.varispeed` is "a high-quality time pitch
   algorithm that **doesn't perform pitch correction**" — the chipmunk/slowed distortion S15
   forbids; `.spectral` is "a highest-quality time pitch algorithm that's suitable for music";
   `.timeDomain` is "a modest quality … suitable for voice"; `.lowQualityZeroLatency` is
   deprecated. The property's default is not relied on (S15 is a visible contract, and an OS
   default is not a contract): the conformance sets it explicitly at item creation (§2).
3. **Key codes (verified against HIToolbox `Events.h` in the pinned SDK, this story):**
   `kVK_ANSI_LeftBracket = 0x21` (**33** = `[`), `kVK_ANSI_RightBracket = 0x1E` (**30** = `]`) —
   the same raw-key-code discipline as 123/124/125/126/49 (test-pinned). `isARepeat` identifies
   auto-repeat; the carried parity (D22, D34) is "a held key equals repeated presses" — S6 demands
   exactly that for the step keys. On a US layout ⇧33/⇧30 type braces; ⇧ alone is not a command
   modifier (frozen-table policy), so ⇧[` steps down like `[.
4. **The frozen router's discipline (D28, D34) is binding:** one pure table over NSEvent-derived
   values; with an open feed, routed keys are **always consumed** (the guard matrix no-ops quietly
   on ineligible states — passing through re-exposes keys to the unhandled-key beep); ⌘/⌥/⌃
   combinations pass through; the table is unit-pinned as the frozen contract and each addition is
   a recorded contract change for the codes it claims.
5. **Menu presentation is a separate-window tracking loop (macOS).** A SwiftUI `Menu` opens an
   AppKit popup whose hover and clicks do not reach the page's `NSTrackingArea` — relevant to the
   idle-hide policy (§4). Taps on controls are the proven SwiftUI input class (E3-S1 fact 4), and
   the strip's hit-test carve-out is the proven way to keep child interactions from the whole-page
   toggle (E3-S1 §4). No hover or menu-open callback is treated as proven here; §4 records a
   fallback instead.

## 1 · Architecture mapping & component inventory

All changes land per the D7 walkthrough: Presentation → Domain ← Data, framework types behind
seams, composition wired only in `App/`. The D25 handle grows additively — no new seam, no new
actor (§13). Files (names + responsibilities; member names are contract-level):

| File | Layer | Change | Requirements |
|---|---|---|---|
| `InstantPlayer/Features/Feed/Domain/MediaPlaybackSpeed.swift` (new) | Feed Domain | The five-preset ladder value (§2) — Foundation-only | S2, S5–S7 |
| `InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (exists) | Feed Domain | The handle grows `setPlaybackSpeed(_:)`; `seek`/`resume`/`restart` doc evolution (§2) | S10–S14 |
| `InstantPlayer/Features/Feed/Domain/MediaPlayerService.swift` (exists) | Feed Domain | `startPlayback(for:)` → `startPlayback(for:at:)` (§2, §3) | S12 |
| `InstantPlayer/Features/Feed/Domain/MediaPlaybackEvent.swift` (exists) | Feed Domain | **Untouched** | — |
| `InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (exists) | Feed Data | Per-session selected speed + the rate mapping (§2): start/resume/restart/setSpeed → `AVPlayer.rate`; paused case | S10–S14 |
| `InstantPlayer/Features/Feed/Data/AVMediaPlayerService.swift` (exists) | Feed Data | Item creation pins `audioTimePitchAlgorithm` (S15); `playImmediately(atRate:)` takes the start speed (§2, §3) | S12, S15 |
| `InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (exists) | Feed Data | Stub grows the new members/parameter (house pattern; wiring tests) | — |
| `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (exists) | Feed Presentation | All speed policy: `selectedSpeed` session state (§3), selection + step entries, the guard matrix (§5), preservation across seeks/loop (§5), install re-apply (§3), `PlaybackControlBarModel.speed` | S1–S18 policy |
| `InstantPlayer/Features/Feed/Presentation/PlaybackControlBarView.swift` (exists) | Feed Presentation | The strip grows the speed `Menu` + the ≠1× badge + the cluster's consumed drag island (§4) | S1, S3, S4 |
| `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (exists) | Feed Presentation | `FeedPageActions` grows the speed closure; strip carve-out carries (§4) | S1, S3 |
| `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (exists) | Feed Presentation | Drills the per-page speed closure (the tap-closure pattern) | S1 |
| `InstantPlayer/App/FeedKeyCommand.swift` (exists) | App | The frozen route table gains `.speedDown`/`.speedUp` (33/30) | S5, S6 |
| `InstantPlayer/App/AppDelegate.swift` (exists) | App | Monitor switch gains the two speed cases | S5 |
| `InstantPlayer/App/AppDependencies.swift`, `App/RootView.swift`, `App/InstantPlayerApp.swift`, `FeedState.swift`, `PlayerSurfaceView.swift`, `WelcomeView.swift`, `SeekScheduler.swift` | — | **Untouched** — no new wiring, no new mechanism (§7) | — |

### 1.1 Placement justifications (architecture reviewer checks)

- **Rate rides the existing opaque handle (D25, D27; E3-S1 §13's explicit handoff), not a new seam
  or a player type:** Domain stays Foundation-only — `MediaPlaybackSpeed` is a Domain-owned value
  with `Float` raw values (the `URL`/`Data`/`MediaSeekTolerance` value precedents; architecture §4
  check 3 unchanged, §13). No `AVPlayer`, no `AVAudioTimePitchAlgorithm`, no `CMTime` appears in
  any Domain signature.
- **Policy in `FeedViewModel`, mechanism in the Data conformance (D8, D26's split):** the ladder
  stepping, the guard matrix, the carry scope, and the preservation rules are presentation
  semantics — pure and unit-testable without hardware. The mapping to `AVPlayer.rate`, the
  per-session remembered speed, and the pitch setting are AVFoundation mechanism — they never
  surface above the seam.
- **The ladder is structural (S2):** a typed five-case enum on the seam means no value outside the
  ladder can ever reach AVFoundation — the type system carries the spec's "nothing outside that
  ladder is selectable", and input validation (skill §4) is free.
- **Project config: explicitly nothing.** No entitlements, no Info.plist keys, no build settings,
  no pbxproj diff — speed is a read of an already-open file plus in-memory session state (§9); the
  one new source file joins the target through synchronized groups (D21). **Any apparent need for
  project-config change is a coordinator escalation, not a task** (D21 note).

## 2 · The rate seam (Domain contract + the Data mapping)

**The ladder value (new Feed Domain file, Foundation-only):**

```swift
/// The five selectable speeds (S2) — the ladder as a type: nothing
/// outside these cases exists to select. Declaration order is ladder
/// order (CaseIterable) — stepping walks it (S5–S7).
nonisolated enum MediaPlaybackSpeed: Float, CaseIterable, Sendable {
    case quarter = 0.25
    case half = 0.5
    case normal = 1.0
    case oneAndHalf = 1.5
    case double = 2.0
}
```

**Handle additions (`MediaPlayback`, `@MainActor` — unchanged isolation):**

```swift
func setPlaybackSpeed(_ speed: MediaPlaybackSpeed)   // synchronous command (D25's pattern)
```

Contract on `setPlaybackSpeed` (the S10/S11 split made structural):

- **Playing session (rate ≠ 0):** the playback rate changes **in this same main-actor turn** — a
  rate change only: no restart, no position change (S10), no seek, no play/pause change (a speed
  input is state-neutral on the play/pause axis).
- **Paused session (rate 0 — including the frozen frame, the gesture-scoped scrub pause, and a
  frame parked at either end):** the selection is **remembered** and the session plays at that
  speed when playback next resumes (S11). The frozen frame is untouched (E2-S3 S8 stands).
- **State it carries:** the session's selected speed is what `resume()` and `restart()` use — so
  the loop (S14), the resume after a scrub drag or a seek (S11), and the toggle resume all play at
  the selection without re-application.
- **State it never touches:** position (a rate write preserves it), play/pause state, seek
  behavior (`seek` stays "never changes the *selected* speed" — S13's evolved phrasing), and
  nothing crosses the seam back (no rate read: the frozen seam carries no state-query members —
  the E3-S1 `seekDispatchCount` precedent; §5's note on observed rate).

**Service addition (`MediaPlayerService`):**

```swift
func startPlayback(for item: MediaItem, at speed: MediaPlaybackSpeed) async -> MediaPlayback?
```

Everything of D25's contract is unchanged (supersedes and tears down the previous session; async
only for the asset load; unified `nil` failure answer; audio unmuted) plus one clause: **the
session starts playing at `speed`** — the initial play call *is* at that rate (§3's ordering
guarantee). This is a recorded evolution of the seam signature — flagged below for the design gate
because E3-S1 §13's phrasing ("grows rate members on the same handle") named only the handle.

**Conformance mapping (`AVMediaPlayback` + `AVMediaPlayerService`) — mechanism only:**

- The session holds one field: `private var selectedSpeed: MediaPlaybackSpeed`, seeded from
  `startPlayback(for:at:)` and updated only by `setPlaybackSpeed`. It dies with the session (a
  fresh session is seeded again — §3).
- **Start (S12):** `AVMediaPlayerService.startPlayback` creates the item, pins the pitch
  algorithm, builds the session with the seeded speed, and calls
  `player.playImmediately(atRate: speed.rawValue)` — replacing today's `playImmediately(atRate: 1)`.
  The rate is part of "ready to play", not a follow-up adjustment: no 1× beat exists to observe.
- **`setPlaybackSpeed(s)` (S10, S11):** `selectedSpeed = s`; if `player.rate != 0` (playing) also
  `player.rate = s.rawValue` — one O(1) write, position preserved; if `player.rate == 0`
  (paused — the conformance reads the player's own state; no view-model pause flag crosses the
  seam) the write is skipped and the frozen frame stands. `player.rate != 0` ⇔ playing is exact
  here: the ladder's slowest preset is 0.25 (fact 1).
- **`resume()` and `restart()` (S11, S12, S14):** both become "play at `selectedSpeed`" —
  `player.rate = selectedSpeed.rawValue` (for `restart()`: `player.seek(to: .zero)` first, then
  the rate write; fact 1's seek-then-rate ordering). **`player.play()` is never called again** —
  it is a rate-1.0 write (fact 1) and would break S12/S14 structurally.
- **`pause()` and `seek(to:tolerance:)` are untouched** — pause stays the rate-0 write (the paused
  case), and the seek path never touches rate (S13's evolution: it never changes the *selected*
  speed; a playing video keeps its pace across a seek).
- **Pitch (S15):** `AVMediaPlayerService.startPlayback` sets
  `playerItem.audioTimePitchAlgorithm = .spectral` at item creation, before any audio renders —
  voices and music keep their pitch at 0.25× and 2× alike (the observable contract).
  **Why `.spectral` (an explicit choice, not a default — fact 2):** S15 names both voice and
  music and the ladder reaches both extremes; `.spectral` is Apple's highest-quality
  pitch-preserving algorithm. `.timeDomain` (modest quality, cheaper) and `.varispeed` (no pitch
  correction — the forbidden chipmunk effect) are considered in §12.

**Observed rate: deliberately none.** The single source of truth for "what speed is selected" is
the view model's `selectedSpeed` (§3) — it survives sessions, which the handle state cannot (S8).
The bar's badge and menu read the view model; the handle carries only the command. This keeps the
frozen seam minimal and matches E3-S1's "policy above, mechanism below" split.

## 3 · Selected-speed state & start-at-speed ordering (S8, S9, S12)

**Ownership (S8, S9):** `FeedViewModel` holds `private(set) var selectedSpeed:
MediaPlaybackSpeed = .normal` — **app-session state**, not per-video and not per-collection state.
It is written only by user input (menu selection, key step) and read by every start, the badge,
and the menu. It is **not** cleared by `stopPlayback`, `adopt` (a newly opened folder), or the
welcome transition — it carries across paging, revisits, and newly opened folders within the
session until changed (S8). It resets only when the app relaunches: `RootView`'s `@State` owns the
one `FeedViewModel` per run (D18's single state machine), and nothing is persisted (S9, §9) —
"reset by relaunch" falls out of object lifetime, by construction. This is the deliberate
asymmetry with positions (E3-S1 S15: position restarts; speed carries).

**Two copies, two lifetimes:** the view model's selection (app session) is seeded into each fresh
handle (playback session) via `startPlayback(for:at:)`; `setPlaybackSpeed` keeps the live handle's
copy in step. A stale handle dies with its session — no cross-session leakage (D25's braces).

**Ordering guarantees (S12 — "from its first frame, no 1× flash, no additional wait"):**

1. **Auto-play start / revisit restart (E2-S3 S1/S10):** the rate is chosen *with* the play call —
   `playImmediately(atRate: selectedSpeed.rawValue)` is the first and only start call of the
   session (fact 1). Ordering vs `.readyForDisplay`: the rate write precedes the first presented
   video frame by construction (the poster — frame 0 — shows until `.readyForDisplay`, D27), so no
   frame is ever displayed at another rate, and audio begins at the selected pace. The parameter
   adds zero work to the asset-load path — R11's no-perceptible-wait promise is untouched (budget
   2, §8).
2. **Install re-apply (covers a selection made while the next video's asset is still loading):**
   `install` calls `handle.setPlaybackSpeed(selectedSpeed)` as one synchronous statement before
   the event/clock loops attach — so a mid-load selection governs the session it landed on (S8
   applies "to every subsequently viewed video"). *Honesty limit, recorded:* between
   `startPlayback`'s play call and the install re-apply there is one executor hop (the awaiting
   `Task` resumes on the main actor); a selection landing in that window can leave ≤ that hop of
   **audio** at the previous selection — imperceptible, and video frames are unaffected (the
   poster covers until `.readyForDisplay`). Flagged reading F2 below covers the eligibility of
   mid-start input itself.
3. **Loop restart (S14, D26):** `.reachedEnd` → `handle.restart()` → seek-to-zero then the rate
   write at `selectedSpeed` (§2) — a batch reviewed at 2× loops at 2× with no re-selection. D26's
   honest restart (not a gapless cycle — the last frame may hold for a frame or two) carries
   unchanged; only its rate is now specified.
4. **End handover (E3-S1 S14):** the paused branch (`seek(to: 0, .exact)`) and the playing branch
   (`restart()`) both leave `selectedSpeed` alone — S13's "no seek resets it" covers the handover's
   seek; the playing branch restarts at speed per (3).
5. **Revisit (E2-S3 S10) / paging (E2-S3 S9):** paging away stops the session (speed state is not
   in the session — it survives), and a revisit starts a fresh session seeded with the current
   selection — position restarts, speed carries (the settled asymmetry).

**Flagged reading F2 — speed input while the current video is still starting (stakeholder
attention at the design gate).** The S16 guard lists non-current pages, mid-gesture pages, image
pages, and unavailable items — a *starting* video is none of those, and S5/S8 speak of "the
settled current item is a video". **Recommended reading: accept the input** — the selection
updates session state and reaches the session through the install re-apply (above); treating it
as a quiet no-op (the seek guard's "no live session" shape) would drop a keystroke on the very
first second of a clip and make the carry semantics stutter. The stakeholder can veto this reading
at the design gate.

## 4 · The bar surface (speed control + badge; every E3-S1 invariant carried)

**Surface (S3 — the plainly-stated amendment of E3-S1's bar-contents contract).**
`PlaybackControlBarView` keeps its four named elements and gains exactly two — the speed control
and the speed badge. The strip's layout is pinned: the track row is unchanged (full-width thin
line + thumb); the label row becomes
`HStack { elapsed … Spacer … [badge] … speed-menu … duration }` — elapsed stays leading, duration
stays trailing (E3-S1's visual contract), and the badge and menu form one trailing cluster beside
the duration. Everything else about the bar carries unchanged: demand-driven visibility on mouse
movement (D33), the 3 s idle-hide, structural absence on image pages/unavailable/non-current/
mid-gesture (`controlBarModel == nil`), and the strip's carve-out from the whole-page toggle (S3).

**Speed control (S1) — pinned form: a SwiftUI `Menu` in the strip.** Label:
`Label("Speed", systemImage: "speedometer")` (constant copy — at 1× the closed control shows no
number, honoring US5's chrome minimality; the state is visible in the badge when ≠ 1× and in the
menu's checkmark when open). Contents: a `Picker` over `MediaPlaybackSpeed.allCases` with
`.pickerStyle(.menu)` — the native mutually-exclusive menu with a checkmark on the selected preset
— rows rendered by the one pure formatter below (`0.25× … 2×`). The selection binding is
write-through: its setter forwards to the drilled `onSpeedSelected` closure (the binder owns no
state — D8). `PlaybackControlBarModel` grows `speed: MediaPlaybackSpeed` so the binder renders the
checkmark and badge from the model alone.

**Speed badge (S4) — pinned form:** rendered **iff `model.speed != .normal`** (the rule cuts both
ways: nothing at 1×, the identity at every other preset), text from the same formatter (`2×`,
`1.5×`, …), styled `\.caption.monospacedDigit()` in a small `Capsule().fill(.quaternary)` —
monospaced so the strip does not twitch as digits change. The formatter is
`nonisolated static func speedText(_:) -> String` on the bar view (the `mmss` precedent), pinning
the exact five display strings unit-testably. Badge copy/styling are UI detail the spec delegates
here; the pinned values above are the decision.

**Tap-vs-drag interplay (S3's carve-out, mechanically).** The badge/menu cluster is a hit-test
island inside the strip: its own `contentShape`; taps on the badge fall to the strip's existing
consumed no-op (a badge is not a control), taps on the menu are claimed by the `Menu` itself (the
proven tap-on-control input — fact 5), and a **drag** starting anywhere on the cluster is consumed
by the cluster's own `highPriorityGesture(DragGesture(minimumDistance: 3))` no-op — so speed
surface interactions **never toggle playback** (the strip is a sibling above the tap surface,
E3-S1 §4), **never start a scrub** (the track gesture is the track's own), and **never start
paging** (the consumed drag beats the scroll surface — the same `highPriorityGesture` reasoning
E3-S1 used). A click on the speed control cannot pause, per S11/S10's click semantics.

**Visibility interplay (S3/D33 carried + F1).**

- The bar model stays non-`nil` exactly under E3-S1's rule (settled current video's live player
  page); the menu and badge ride that rule and are structurally absent everywhere else (S3, S16).
- **Flagged reading F1 — keyboard speed steps never show the bar (stakeholder attention at the
  design gate).** E3-S1 S3(b)'s recorded reading ("keyboard seek never shows the bar") carries to
  speed: chrome is demand-driven on mouse movement, and the spec's Story context says the
  visibility contract "carries unchanged". **Recommended reading: steps leave the bar as found** —
  the badge appears at the next mouse movement; a step is not mouse demand. The alternative
  (steps flash the bar as feedback) is an unrequested change to the carried bar contract and is
  not adopted. The stakeholder can veto this reading at the design gate.
- **Menu-open vs the idle-hide (recorded honestly).** An open `Menu` lives in a separate window
  whose hover never reaches the page's tracking area (fact 5), so a user reading an open menu for
  > 3 s without moving the mouse will hit the idle-hide with the menu open. Pinned mitigation: a
  menu **selection** counts as activity — `selectSpeed` refreshes the bar visible and restarts the
  3 s countdown (the `scrubEnded` precedent). **Recorded fallback (the E2-S3-fallback pattern,
  ratified as a deviation if taken):** if functional review shows the hide actually disturbing the
  open menu, the menu label's press suspends the idle policy (the drag-suspend pattern of
  S3(a)) and the next selection or mouse movement re-arms it.

## 5 · Speed policy in `FeedViewModel` (the one decision surface)

Pure state, no hardware, no AVFoundation (D8). Two entry points converge on one selection method:

- `selectSpeed(_ speed: MediaPlaybackSpeed, itemID: MediaItem.ID)` — the menu route (drilled per
  page as `FeedPageActions.speedSelected`, item id captured at the `FeedView` drill site).
- `stepSpeedDownByKeyboard()` / `stepSpeedUpByKeyboard()` — the `[`/`]` routes (no item id: the
  route is app-level and resolves to `currentItemID`, exactly like `stepSeek`).
- Shared core: run the guard (matrix below); then `selectedSpeed = speed`; if a live handle
  exists, `handle.setPlaybackSpeed(speed)` (§2); refresh the bar model (preserving its current
  visibility — a keyboard step never shows the bar, F1; a menu selection re-arms the idle
  countdown per §4). **Never** touches `isPlaybackPaused`, position, or the index (S10's state
  neutrality; a speed step can never toggle play/pause).

**Stepping (S5–S7) — one pure function:**

```swift
nonisolated static func stepped(_ speed: MediaPlaybackSpeed, up: Bool) -> MediaPlaybackSpeed
```

It walks `MediaPlaybackSpeed.allCases` (declaration order = ladder order) by one and **clamps at
the ends** — 0.25× and 2× are ladder ends and the ladder never wraps (S7's approved reading). The
keyboard routes compute `stepped(selectedSpeed, up:)` and hand the result to the shared core;
auto-repeat arrives as repeated calls (§6) and clamps idempotently at the ends.

**The guard matrix (S16 + recorded derivations) — one unit-tested decision surface.** The
eligibility premise is E3-S1's (speed is a property of the settled current video), but the rows
deliberately differ from the seek matrix where the approved spec says so:

| Input situation | Result | Source |
|---|---|---|
| Menu selection / `[`/`]` on the settled current video, playing | selection changes; rate applied in the same turn | S1, S5, S10 |
| Menu selection / `[`/`]` on the settled current video, paused (frozen frame, parked at an end) | remembered; applies on resume | S11 |
| Speed input while a scrub drag is in flight (gesture-scoped pause) | **remembered** (S11's paused path) — takes effect at the drag's `resume()`/next resume | S10's approved composition note (unlike seek, which consumes mid-drag) |
| Speed input while the current video is still starting (no live session yet) | **accepted** as session state; applied at install (§3) | flagged reading F2 (S8, S16's list) |
| Speed input on a non-current page | no-op (consumed) | S16 |
| Speed input while a paging gesture is in flight | no-op (consumed) | S16 |
| Current item is an image | no-op (consumed) — no bar exists, no playback semantics | S16 |
| Current item in the neutral unavailable state (incl. sticky playback failure) | no-op (consumed) — no bar exists | S16 |
| No open feed (welcome) | keys pass through (route level) | D28 unchanged |

Guarded inputs do nothing quietly — no sound, no visual change, no error, never beep (S16, D28's
input-policy principle). The guard needs **no duration and no live handle** (unlike `seekGuard`):
speed is selection state, not a position operation.

**Preservation (S13, S14):** the seek paths (`scrubChanged`/`scrubEnded`/`seekFromTrackClick`/
`stepSeek`/`commitExactSeek`/`endHandover`) never call `setPlaybackSpeed` and never write
`selectedSpeed` — so no scrub, track click, keyboard seek, or end handover can reset the speed
(S13). `.reachedEnd` → `restart()` preserves it structurally (§2). The spec's evolution of E3-S1
S10/D32 is honored in documentation too: `MediaPlayback.seek`'s contract reads "never changes the
*selected* speed" (§13's check item).

**Badge rule (S4):** `refreshControlBar` carries `speed: selectedSpeed` into
`PlaybackControlBarModel`; the binder's `speed != .normal` comparison is the whole rule (§4) —
asserted at the model level in policy tests.

## 6 · Input delivery (keyboard routing + bar gestures)

**Keyboard (S5–S7) — the D28 App-owned key monitor is the single key path; only the frozen table
grows.** `FeedKeyCommand` gains two cases and two rows:

| Key (keyCode) | Open feed | No open feed | Auto-repeat | Modifiers ⌘/⌥/⌃ |
|---|---|---|---|---|
| `[` (33) | `.speedDown` | `.passThrough` | repeated steps (S6) | `.passThrough` |
| `]` (30) | `.speedUp` | `.passThrough` | repeated steps (S6) | `.passThrough` |
| ←/→ (123/124), ↓/↑ (125/126), space (49) | unchanged (D28, D34) | unchanged | unchanged | unchanged |

`AppDelegate`'s monitor switch routes the two new cases to `stepSpeedDownByKeyboard()` /
`stepSpeedUpByKeyboard()`. With an open feed the two keys are **always consumed** — routed to the
guard matrix, which no-ops quietly on ineligible states (S16) — because passing through would
re-expose them to the system's unhandled-key path (the D28 beep lesson). Auto-repeat = repeated
steps (S6 — the D22/D34 parity: the route ignores `isRepeat`, one step per keyDown). ⇧ alone does
not modify (⇧[` steps like `[; consistent with ⇧↓/⇧← and the approved S5 modifier policy).
This is a deliberate contract change: 33/30 previously fell to `passThrough`'s default row — the
frozen table's discipline means the change is recorded (§11) and pinned by new tests; existing
pins (`nonArrowKeysPassThrough` uses key code 0; the paging/space/modifier rows) are unaffected
and stay green. The table stays pure and unit-tested as the frozen contract.

**Bar gestures (S1, S3, S4)** are SwiftUI on the strip (§4): the `Menu` selection and the badge
are drilled per page as `FeedPageActions.speedSelected` (the `togglePlaybackFromTap(itemID:)`
precedent) into `selectSpeed(_:itemID:)`. No App-level mouse monitor, no focus handling, no new
delivery mechanism anywhere (D28's rejected alternatives stand).

## 7 · Composition & wiring

- **Current-item representation unchanged:** `FeedItemDisplayState.player(MediaPlayback)` stays as
  E2-S3/E3-S1 built it. The bar model gains `speed` (§5) and stays non-`nil` only for the settled
  current video's live player page.
- **`FeedItemView`:** the strip overlay gains the speed cluster inside the existing bar sibling
  (the carve-out is structural — one strip layer above the tap surface); `FeedPageActions` gains
  `speedSelected: (MediaPlaybackSpeed) -> Void`.
- **`FeedView`:** drills the closure per page capturing the item id (the tap-closure pattern).
- **Composition root:** `AppDependencies`, `RootView`, `InstantPlayerApp` are **untouched** — no
  new seam, no new binding (rate rides the already-bound `MediaPlayback` handle; D25). The one
  `FeedViewModel` (RootView's `@State`, D18) is what makes S8's session scope structural (§3).
  `AppDelegate` gains only the two monitor-switch cases (§6). The stub handle/service grow the new
  members and the `at:` parameter for wiring tests (house pattern).
- **Nothing new outlives the session:** the per-session speed copy dies with the handle; the
  app-session selection is the only survivor (S8), and it survives as plain in-memory state (S9,
  S17).

## 8 · Performance (RNF-02) — mandatory

Loaded skill: `swift-performance`. The performance-relevant surfaces are the rate change itself
(S10, S18), the start path (S12 — the story's "no added wait" promise), rapid stepping (S6, S18),
and the grown bar's body cost (skill §2). Per-story budgets (the E2-S1–E3-S1 measured-evidence
precedent):

1. **Rate-change latency (S10, S18):** menu selection / key press → policy decided and
   `setPlaybackSpeed` **issued in the same main-actor turn** (O(1) work; ≤ 16 ms — one display
   frame); the conformance's `AVPlayer.rate` write completes before the call returns (D25's
   synchronous bite). Pace-change observability budget: audible/visible change **≤ 100 ms p95**
   after input (one audio render quantum + the next display refresh). Position unchanged and
   play/pause unchanged by construction (unit-asserted at the spy handle). *Verified by:* spy-handle
   policy tests (the call is in the input method's turn); a conformance `XCTest` `measure` of
   command → rate write (the run-loop-pumped, `nonisolated` D25 test pattern — a semaphore bridge
   would deadlock the `@MainActor` seam); functional review (each preset applies immediately on a
   playing clip).
2. **Start-at-speed adds zero wait (S12):** the speed is one argument on the existing
   `playImmediately(atRate:)` call — **no added work** on the asset-load-to-first-frame path;
   R11's start budget is unchanged and not re-claimed. No 1× frame (poster until
   `.readyForDisplay`) and no 1× audio beat (rate set with the play call) exists by construction.
   *Verified by:* unit tests (the service receives the selected speed at start; the install
   re-apply lands); the existing start-latency measure re-run in the seam suite (must not regress);
   functional review (every clip starts already at speed — the spec's AC line).
3. **Rapid stepping stays stall-free (S6, S18):** each step is one O(1) ladder-index move + one
   O(1) observable write + one synchronous rate write — key press → applied **≤ 16 ms** (same
   main-actor turn); a held key (auto-repeat, typically 10–30 keyDown/s) builds **no backlog**:
   no queue, no allocation beyond the enum value, and the clamp makes end-of-ladder repeats
   idempotent O(1). The route table adds two O(1) switch cases (D34's parity). *Verified by:*
   repeated-step policy tests (N steps deterministic, clamped); a step-path `measure`; functional
   review (hold-to-repeat at both ladder ends stays fluid).
4. **Bar body cost (skill §2):** the strip grows by two constant views (badge + a `Menu` label);
   the menu's rows are built on presentation, not per body pass; the badge string is the tiny pure
   formatter (like `mmss`). The 10 Hz tick rebuild (E3-S1 §8(3)) is unchanged in shape — one O(1)
   observable write per tick while visible, zero view work while hidden — now invalidating a
   six-element strip instead of four. *Verified by:* body-cost review; Instruments if review
   disagrees (skill §6 escalation).
5. **Idle/menu machinery — zero launch cost:** no `Timer`, no `CADisplayLink`, no run-loop source;
   the menu-selection re-arm reuses the existing generation-guarded `Task.sleep` (E3-S1 §8(4)'s
   bound carries — ≤ 4 re-arms/s); tracking areas and menu content exist only with a visible bar.
   `testLaunchPerformance` remains the guard. *Verified by:* the launch test; code review of the
   machinery diff (it is one re-arm call site).
6. **Main-thread discipline (skill §1):** `setPlaybackSpeed`/`resume`/`restart` are synchronous
   O(1) `AVPlayer` writes on the `@MainActor` conformance — no executor hop on the command path;
   pitch processing runs on AVFoundation's audio render thread (never ours); nothing on any speed
   path touches disk (speed is in-memory state — §9). *Verified by:* review; the D25 isolation
   pattern is untouched (§13).
7. **Memory (skill §4):** no caches, no per-step allocations, no new long-lived objects — one
   enum field per session; the one-live-player bound (E2-S3 §8(3)) carries. *Verified by:* review;
   Instruments on any suspicion.

## 9 · Security (RNF-04) — mandatory

Loaded skill: `swift-security`. Speed is a **read** of the already-open security-scoped session
(D19) plus in-memory state — the posture is inherited, not extended; product R17 (S17) is the
inherited no-regression contract and S9 fixes the no-persistence scope:

- **Read-only reads inside the open session (D19, S17):** the rate mechanism operates on the
  `AVPlayer` already playing the file of the open collection. No
  `start/stopAccessingSecurityScopedResource`, no session re-derivation, no new access path of any
  kind. **D21 audit expectation, verified against this design: zero project-config diff** — no
  entitlement, no Info.plist key, no build setting, no pbxproj change is needed or permitted; D19's
  four read-only keys stand unchanged (any apparent need is a coordinator escalation).
- **Nothing is ever written or persisted (S17, S9 — R17):** playback/rate APIs only — **no
  `AVAssetExportSession`, no `AVAssetReader`/`AVAssetWriter`, no `write(to:)`**; no sidecar or
  derived file; and **no speed preference anywhere** — no `UserDefaults`, no files in `tmp`/
  `Caches`/`Application Support`. This is S9's contract, not just caution: v1's first persisted
  preference is E3-S3's volume/mute (product R20) — speed deliberately joins nothing at rest.
- **Untrusted input (skill §4):** this story's inputs are key codes and menu selections. Menu
  values are one of five enum cases by construction — **no raw float can ever reach AVFoundation**
  (the ladder type *is* the validation); key codes are `NSEvent` values routed through the frozen
  pure table. Media bytes remain play-only (never executed — E2-S3 §9 carries: mislabeled/corrupt
  → the neutral unavailable state, D20).
- **Logging:** none planned. If diagnostics are added, `os.Logger` with `privacy: .private`, never
  paths or names of user media (skill §5).
- **Dependencies:** none added — AVFoundation/AppKit are system frameworks (skill §6); no SPM
  package enters this story. ATS/network untouched (no networking in v1, D9).
- **Privacy manifest / permissions:** no required-reason API is added (no `UserDefaults`, no
  file-timestamp APIs) and no TCC-prompting capability is touched — **no `PrivacyInfo.xcprivacy`
  change, no purpose strings**, consistent with E2-S1–E3-S1.

### 9.1 Sandbox/media-read review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements | Unchanged — D19's four read-only keys; no new grant (§9) |
| User files access pattern | Reads only inside the already-open scoped session, via the already-live player; no start/stop (D19) |
| Writes to disk | None, anywhere — playback/rate APIs only; no export/reader/writer, no sidecars, no disk caches (S17) |
| Persistence | None — no speed preference at rest (S9, S17); no `UserDefaults` in this story (E3-S3 owns the first one) |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19) |
| Untrusted input | Enum ladder + frozen key table — no raw value reaches AVFoundation (S2 doubles as validation) |
| File names | Display-only; absent from logs and from any speed surface (D20) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason | No triggering API used (§9) |
| Dependencies | None added |

## 10 · Testing strategy

The UI-test mandate is settled in the spec and carried, not re-decided: launch flows are untouched
and the story's surface is unreachable without host-driven entry, so the converge run keeps the
**default gate scope, no `--uitests` obligation** ([docs/development.md](../../development.md) §3).
Recorded in the predecessors' honest form: even a `--uitests` run could not exercise speed
selection (no media is open in the launch tests) — behavior is verified by the unit tests below
plus stakeholder functional review.

### 10.1 Policy (unit, `InstantPlayerTests` — the spec's AC)

`FeedViewModelTests` with injected seam doubles (the E2-S3 §10.1 pattern: spy `MediaPlayerService`
+ scripted handle) — no UI, no window, no AVFoundation:

| Case (requirements) | Expected |
|---|---|
| Preset ladder (S2) | `MediaPlaybackSpeed` has exactly the five cases at 0.25/0.5/1/1.5/2 — nothing else exists to select |
| Stepping + clamping (S5–S7) | up/down walks the ladder; at 2× an up-step stays 2×, at 0.25× a down-step stays 0.25× — never wraps; pure `stepped(_:up:)` pinned directly |
| Hold-to-repeat (S6) | repeated route calls = repeated steps (the auto-repeat parity test, `seekAutoRepeatStillSteps`' sibling), clamping idempotently at the ends |
| Guard matrix (S16) | the §5 table as tests — non-current, mid-gesture, image, unavailable, welcome all consumed no-ops (spy records nothing, `selectedSpeed` unchanged) |
| Mid-drag input (S10's note) | speed input during a scrub drag is remembered (state changes, handle command issued) and plays at the drag's `resume()` — the opposite of the seek matrix's consume row, asserted side by side |
| Mid-start input (F2) | a selection while `startPlayback` is in flight updates session state and is re-applied at install (the scripted handle records `setPlaybackSpeed` in `install`) |
| Start-at-speed ordering (S12) | `startPlayback` receives the current `selectedSpeed` on auto-play and on revisit; install re-applies; a fresh session at 2× has no intermediate state where 1× is requested (spy's call log) |
| Carry semantics (S8, S9) | speed survives `stopPlayback`, paging, revisit, and a newly opened folder (`handle(entryAction:)` → `adopt`) and the welcome round-trip; a brand-new `FeedViewModel` starts at `.normal` (S9 — the relaunch boundary) |
| Seek preservation (S13) | scrub/track click/±5 s/`commitExactSeek`/`endHandover` never call `setPlaybackSpeed` and never change `selectedSpeed` |
| Loop preservation (S14) | `.reachedEnd` → `restart()` path leaves `selectedSpeed` untouched; the scripted handle's restart is at the selection |
| Badge rule (S4) | `controlBarModel.speed` tracks `selectedSpeed`; the ≠ 1× rule is the binder's single comparison (pinned via `speedText` + model assertions) |
| State neutrality (S10) | every speed input leaves `isPlaybackPaused`, `displayedPosition`, and the index observable-unchanged |
| Idle/menu interplay (§4) | a menu selection refreshes the bar visible and restarts the 3 s countdown (the `scrubEnded`-style policy test with injected `now`) |

`FeedKeyCommandTests` (the frozen table): 33 → `.speedDown`, 30 → `.speedUp` with auto-repeat
parity (`arrowAutoRepeatStillPages`/`seekAutoRepeatStillSteps`' sibling); ⌘/⌥/⌃-modified pass
through; ⇧ alone steps; welcome passes through; **no existing pin changes** (33/30 previously hit
the default row — the recorded consequence is new rows plus new pins, §6).

### 10.2 Playback seam (unit, Feed Data — the real conformance)

Fixtures per E2-S3 §10.2's pattern (`MediaFixture` short multi-frame MP4 with an audio track,
throwaway temp folders): `startPlayback(for:at: .double)` begins with `player.rate == 2` (the
§3 ordering pin — via `@testable` internals, the unmuted-start precedent of D25); `setPlaybackSpeed`
while playing changes `player.rate` in-turn and leaves `currentTime` unmoved (S10); while paused
leaves rate 0 and a later `resume()` starts at the selection (S11); `restart()` plays at the
selection (S14); a `seek` leaves the selection untouched (S13); `playerItem.audioTimePitchAlgorithm
== .spectral` at creation (S15 — the explicit pin, never the default); `stop()` leaves no rate
work pending (E2-S3 §10.2 patterns carry). Stub: `StubMediaPlayerService`/stub handle record the
`at:` parameter and `setPlaybackSpeed` calls for wiring tests (house pattern). Perf cases: the §8(1)
command→rate-write `measure` and the §8(3) step-path `measure` (run-loop-pumped, `nonisolated` —
the D25 test-infrastructure pattern).

### 10.3 Functional review (stakeholder — the spec AC list)

`./scripts/app.sh run` covers the spec's AC checklist verbatim: selecting each preset from the bar's
speed menu and seeing it applied immediately on a playing video; selecting while paused and seeing
it applied on resume; the badge appearing whenever the speed differs from 1× and vanishing at 1×;
`[`/`]` stepping through the ladder with hold-to-repeat and clamping at 0.25× and 2×; the speed
carrying to the next clip and across revisits and newly opened folders until changed; a relaunch
starting at 1×; every clip starting already at the selected speed with no 1× flash and no extra
wait; scrubs, track clicks, keyboard seeks, and loop restarts all keeping the selected speed; audio
sounding natural at 0.25× and at 2×; speed keys doing nothing — and changing nothing — on an image
page, a non-current page, and mid-paging-gesture; clicks on the speed control never toggling
play/pause; rapid speed changes staying stall-free; and the media files byte-identical on disk
after all of the above (this is a UI story — functional review is part of the done gate). Gate
evidence is recorded from tooling per conventions (`./scripts/validate.sh --json <tmp>/gate.json`).

## 11 · ADR plan (continuing after D35)

Three ADRs, cut along independent review axes — rate seam, speed surface, keyboard input —
recorded in [docs/decisions.md](../../decisions.md) by the implementing tasks (proposed titles +
kern; numbered D36–D38 unless the log has moved — renumbering at converge is the E3-S1 precedent,
its planned D30–D32 landed as D32–D34; the coordinator appends them at converge):

- **D36 — Playback-speed rate seam: typed five-preset ladder, `startPlayback(for:at:)` seeds the
  play call, `setPlaybackSpeed` maps to `AVPlayer.rate` (rate 0 while paused, selection
  remembered; pitch pinned `.spectral`).** `MediaPlaybackSpeed` (five cases — S2 structural, no
  raw value reaches AVFoundation); one synchronous command on the `MediaPlayback` handle; the
  conformance owns the per-session remembered speed and uses it for `resume()`/`restart()`
  (`play()` retired — it is a rate-1.0 write); the view model owns the app-session selection (S8)
  and re-applies it at install (the F2 window). → S2, S10–S15, S12's start ordering.
- **D37 — Speed surface & badge: `Menu` preset picker + ≠1× monospaced badge on the overlay bar
  strip (bar contents: four → six elements).** The plain amendment of E3-S1's bar contract (S3):
  constant-copy `Speed` menu (native checkmark via a menu-style `Picker`), badge iff ≠ 1× rendered
  as monospaced caption in a capsule; the cluster is a hit-test island (consumed drag, menu-owned
  taps) so speed interactions never toggle, scrub, or page; keyboard steps never show the bar
  (F1's recommended reading); the open-menu/idle edge and its ratified fallback recorded. → S1,
  S3, S4.
- **D38 — Keyboard speed rows on the feed-key router: `[`/`]` (33/30) = one-preset steps with
  paging's repeat parity and ladder-end clamps.** `FeedKeyCommand` gains `.speedDown`/`.speedUp`
  (raw codes 33/30 — verified against `Events.h`); auto-repeat = repeated steps (S6), always
  consumed with an open feed (quiet no-ops per D28), `.passThrough` with no feed, ⌘/⌥/⌃ pass
  through, ⇧ alone does not modify; no new delivery mechanism. The recorded consequence: 33/30 no
  longer pass through. → S5–S7, S16.

## 12 · Alternatives considered

- **Continuous slider / custom values / finer steps** — foreclosed by S2 (settled answer 2: exactly
  five presets; the ladder type makes "nothing outside" structural). **Per-video speed memory** —
  rejected twice: S8/S9 fix the scope as session-wide, and per-video memory would need a keyed
  store that outlives sessions (a persistence-shaped object for a non-persistence product) and
  contradicts the settled "carries until changed" contract.
- **Popover with explicit `isPresented`** — rejected for the settled surface name "speed menu" and
  for adding presentation-state plumbing where a native `Menu` is the control; its one advantage
  (observable open state for the idle policy) is covered by §4's recorded fallback.
  **Cycling button (click = next preset)** — rejected: five presets cycle slowly in one direction,
  gives no overview, and a stray click silently changes speed; the menu is explicit and shows the
  whole ladder with the current selection checked. **Badge merged into the menu label** (label
  shows the current speed) — rejected: S3 demands a control *and* a badge, and a numeric label at
  1× would break US5's chrome minimality.
- **Bare `Float` rate on the seam** — rejected: it externalizes the ladder as caller discipline and
  lets a future caller pass 3.7; the enum carries S2 in the type system (input validation, skill
  §4). **Stepping policy on the enum** — rejected: D8 puts product policy in the view model; the
  enum stays a plain value (like `MediaSeekTolerance`).
- **`player.play()` for resume/restart** (the status quo) — rejected: `play()` is a rate-1.0 write
  (fact 1) and would silently reset a 2× session on every resume and every loop (S12/S14 defect).
  **`playImmediately(atRate:)` for every rate change** — rejected: it is a start-style call; the
  rate write is the minimal position-preserving mechanism (S10) and `automaticallyWaitsTo-
  MinimizeStalling` is already false from the start call. **Setting `rate` before the play call in
  `startPlayback` and never passing a parameter** (handle-only shape) — rejected: `startPlayback`
  must begin playback (E2-S3 S1's contract), so a handle-only shape plays at some rate before the
  view model can set the real one — a stale-rate audio window on *every* start, not just the F2
  window; the parameter makes the no-flash guarantee structural. **New `MediaPlaybackRate`
  seam/handle** — rejected by E3-S1 §13's handoff and D26's consequence (the handle grows
  additively; a parallel seam fragments the one session).
- **Pitch choices:** `.varispeed` — rejected: no pitch correction, the exact chipmunk distortion
  S15 forbids. `.timeDomain` — modest quality, cheaper; rejected because S15 names music as well
  as voice and the ladder runs 0.25×–2× (`.spectral` is Apple's highest-quality choice), with
  CPU cost borne by AVFoundation's audio thread (§8(6)). `.lowQualityZeroLatency` — deprecated.
  **Relying on the `AVPlayerItem` default** — rejected: S15 is a visible contract and an OS
  default is not a contract (fact 2); the setting is explicit and test-pinned.
- **Mid-drag speed input consumed (like mid-drag keyboard seek)** — not adopted: the approved
  composition note — D34's rationale ("the release lands on the scrubber's point regardless") does
  not transfer to speed, which the release does not overwrite. **Resetting speed on folder open** —
  rejected: S8 says until changed, S9 says relaunch is the only reset.
- **`.stepSpeed(Int)` as one payload route case** — rejected: the frozen table is discrete-case
  switch style (D28/D34); two cases keep it mechanical and test-pinnable. **Repeat-ignored `[`/`]`
  like space** — rejected: S6 explicitly demands the paging/seek repeat parity. **Passing the keys
  through on ineligible states** — rejected: the unhandled-key beep (D28's lesson) and S16's
  silent-no-op rule. **Speed keys showing the bar as feedback** — rejected under F1 (the carried
  visibility contract); flagged for the stakeholder.
- **Badge always visible** — rejected: S4 (settled answer 4) and US5. **Speed menu on the tap
  surface / floating over the video** — rejected: D27's chrome-free viewport and E3-S1 §13's
  ratified home is the bar strip. **Persisting the speed** — foreclosed by S9/S17 (E3-S3's
  territory, product R20).

## 13 · Consequences & required follow-ups

- **`docs/architecture.md` updates are required in this story** (its §1 rule) — **not committed
  with this design: writing that file is outside this author's permissions (reported to the
  coordinator rather than bypassed, the E2-S2/E2-S3/E3-S1 §13 precedent).** The exact updates, to
  be applied by an agent with write access in this story's task phase:
  1. **§3 tree:** re-annotate `Features/Feed/Domain/MediaPlayback.swift` (gains
     `setPlaybackSpeed(_:)`; seek/resume/restart doc evolution), `Domain/MediaPlayerService.swift`
     (`startPlayback(for:at:)`), `Data/AVMediaPlayback.swift` (per-session speed + rate mapping),
     `Data/AVMediaPlayerService.swift` (pitch pin + `playImmediately(atRate:)`), `Data/
     StubMediaPlayerService.swift`, `Presentation/FeedViewModel.swift` (speed policy + guard rows
     + `PlaybackControlBarModel.speed`), `Presentation/PlaybackControlBarView.swift` (speed menu +
     badge + cluster island), `Presentation/FeedItemView.swift` (`FeedPageActions.speedSelected`),
     `Presentation/FeedView.swift` (drill), `App/FeedKeyCommand.swift` (speed rows),
     `App/AppDelegate.swift` (speed cases); add `Features/Feed/Domain/MediaPlaybackSpeed.swift`.
  2. **§4 check (3): explicitly no wording change — verdict recorded so the check does not look
     overlooked.** The rate seam moves no new kind across the boundary (`MediaPlaybackSpeed` is a
     Domain-owned Foundation-only value with `Float` raw values — the `MediaSeekTolerance`/
     `URL`/`Data` precedents; no `AVPlayer`, `AVAudioTimePitchAlgorithm`, or `CMTime` in any Domain
     signature). The two contract evolutions the spec states plainly — the bar-contents amendment
     (S3: four → six elements) and the seek-contract evolution (S13: "a seek never changes the
     *selected* speed"; S14: the loop preserves it) — are documentation-level evolutions of E3-S1
     contracts, recorded in §2/§4/§5 here and carried into the tree annotations; nothing else in
     either contract changes.
  3. **§8 evolution note:** no new actor — D8's trigger is unmet again (the per-session speed is
     one field on the existing `@MainActor` `AVMediaPlayback` conformance; nothing crosses
     isolation); the `@MainActor`-seam pattern of D25 carries unchanged.
- **D21 audit expectation:** zero project-config diff — no pbxproj, entitlements, Info.plist, or
  build-setting change anywhere in this story's commits (§9's verification).
- **E3-S3 handoff:** volume & mute grow members on the same handle (the `setPlaybackSpeed` shape is
  the template: synchronous command, remembered state, applied through `AVPlayer.rate`/`volume`) —
  note that `MediaPlayerService`'s "the conformance never touches `isMuted`/`volume`" comment
  evolves there. The strip gains volume controls as **its own spec decision** (the D37 pattern:
  each addition amends the bar contract explicitly — the bar is now four E3-S1 elements + speed
  control + speed badge). E3-S3 lands v1's **first persisted preference** (product R20): the
  data-at-rest decision lives in its design (the `swift-security` skill's line — `UserDefaults` is
  acceptable for non-secret preferences; Keychain is for secrets), and S9/S17 here guarantee speed
  leaves no persistence debt behind. The keyboard table has room for more rows (D28's frozen
  pattern; D38 is the third addition). A persisted speed, if ever wanted, belongs with that story.
- **Flagged readings for the design gate (each with its recommended answer, all vetoable):**
  **F1** — keyboard speed steps never show the bar (recommended: carry E3-S1 S3(b); the badge
  appears at the next mouse movement); **F2** — speed input while the current video is still
  starting is accepted and applied at install (recommended: accept, per S8's carry semantics);
  **F3** — `startPlayback` grows an `at speed:` parameter beyond E3-S1 §13's "rate members on the
  same handle" phrasing (recommended: accept — the only structure that makes S12's no-1×-flash
  guarantee structural; §12 records the handle-only alternative's stale-rate window).
- **Accepted sharp edges, recorded honestly:** an open speed menu with a motionless pointer can
  outlast the 3 s idle-hide (§4 — mitigated on selection, ratified fallback recorded); a speed
  change landing in the one-executor-hop window of a starting session can leave that hop of audio
  at the previous selection (§3 — frames never show the wrong rate); with the bar hidden (F1), a
  keyboard step gives no visible feedback until the next mouse movement; the ladder clamps at both
  ends and never wraps (S7's approved reading); ⇧[` / ⇧] step the speed on layouts where they
  would type braces (the frozen table's ⇧ policy — v1 has no text input); a drag starting on the
  speed cluster is a consumed no-op by design (no paging, no scrub); a speed selection mid-scrub-
  drag is inaudible until the drag ends (the approved composition note); E2-S3's zero-net-gesture
  restart sharp edge carries unchanged and restarts at the selected speed.
