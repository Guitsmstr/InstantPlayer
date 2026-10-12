# E2-S3 · Basic playback — Design

How the feed's current item plays: auto-play on settle with no perceptible wait (S1, S2), play/pause by
spacebar or whole-page click (S5–S7), loop in place (S11), restart-on-revisit (S10), and read-only
media throughout (S12, S13). Story spec: [spec.md](spec.md) (S1–S16 over product R11, R12, R15, R17).
Structure follows [docs/architecture.md](../../architecture.md) (D7–D10); access and classification
contracts follow D19–D20 ([docs/decisions.md](../../decisions.md)); the feed/display contracts this
story extends are E2-S2's (D22–D24). Pillars: RNF-02 and RNF-04 — mandatory sections below (§8, §9);
the design was written against the `swift-performance` and `swift-security` skills
(`.opencode/skills/swift-performance`, `.opencode/skills/swift-security`), and every implementer and
the validator load them before touching this code (D5).

Scope reminder: this story ends at "the current video plays, toggles, loops, and never touches the
file". No scrub/seek/timeline UI (E3-S1 — and the spec's S7 consequence forecloses drag-on-video
scrubbing), no speed (E3-S2), no volume/mute (E3-S3), no transport chrome (the frozen frame is the
only pause indication, S8), no auto-advance (S11), no resume/persistence (S10, S13), images untouched
(S4). **No project-config work of any kind** (D21 note, §1.1, §9). No `[NEEDS CLARIFICATION]` markers
exist in this design — every decision below is made and traceable to S-/product-R numbers.

## 0 · Platform and toolchain facts this design is built on

1. **Local playback needs no stalling machinery (D9: local files only).** `AVPlayer` +
   `AVPlayerItem` over an `AVURLAsset` play files straight off disk; `automaticallyWaitsToMinimizeStalling`
   exists for networked playback and is irrelevant here; `playImmediately(atRate:)` sets rate 1
   without the player's waiting policy — the right start call for a file already on disk. Modern
   async asset loading (`load(_:)` keys) keeps asset I/O inside AVFoundation's own threads: the main
   thread never blocks (skill §1).
2. **Loop is one notification and one seek.** `AVPlayerItem.didPlayToEndTime` fires at the end;
   `actionAtItemEnd = .none` parks the item there; `seek(to: .zero)` + play restarts the *same*
   item — the literal S11 contract. `AVPlayerLooper` exists but is queue machinery for one item (§12).
3. **First-frame truth is observable:** `AVPlayerLayer.isReadyForDisplay` (KVO) flips when the layer
   has a frame to show — the canonical gate for the poster→player swap (§4). `AVPlayerItem.status`
   distinguishes `.failed` (S14) from ready.
4. **Key delivery on macOS 26 is solved App-side (evidence §8, D22's consequence):** SwiftUI
   focused-view key delivery failed three functional-review rounds; the shipped mechanism is an
   App-owned `NSEvent` local `.keyDown` monitor with a pure routing table. **Tap gestures are not
   focus-dependent** — `.onTapGesture` on a view works without key focus (the failure was key focus,
   not hit-testing). `NSEvent.keyCode` 49 = space; `event.isARepeat` identifies auto-repeat.
5. **Rendering needs one platform view.** A layer-hosting `NSView` with `AVPlayerLayer`
   (`videoGravity = .resizeAspect`) aspect-fits and letterboxes by itself at any size — resize and
   native fullscreen need no geometry code (same container-derived story as E2-S2 §5.3).
   `AVPlayerView` and SwiftUI `VideoPlayer` both carry built-in interaction machinery (§12).

## 1 · Architecture mapping & component inventory

All new code lands per the D7 walkthrough: Presentation → Domain ← Data, framework types behind
seams, composition wired only in `App/`. Files (names + responsibilities; member names are
contract-level):

| File | Layer | Responsibility | Requirements |
|---|---|---|---|
| `InstantPlayer/Features/Feed/Domain/MediaPlayerService.swift` (exists) | Feed Domain seam | Grows its real members: session vending (`startPlayback(for:)`) + `wiringProbe()` (§2) | S1–S3 (D7) |
| `InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (new) | Feed Domain | The opaque playback-session handle: commands, event stream, display-ready platform view (§2) | S1–S3, S5–S11 |
| `InstantPlayer/Features/Feed/Domain/MediaPlaybackEvent.swift` (new) | Feed Domain | Event value: `.readyForDisplay`, `.reachedEnd`, `.failed` (§2). Foundation-only | S2, S4, S11, S14 |
| `InstantPlayer/Features/Feed/Data/AVMediaPlayerService.swift` (new) | Feed Data | Real conformance, `@MainActor` (§1.2): one live AVPlayer, supersedes on re-start, failure → `nil` | S1–S3, S9, S10, S14, S15 |
| `InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (new) | Feed Data | One session: `AVPlayer` + `AVPlayerItem`, end/failure observation → event stream, loop support (`restart()`), the layer-hosting display view | S5–S11, S14 |
| `InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (exists) | Feed Data | Stub conformance grows stub handles (house pattern; wiring tests) | — |
| `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (exists) | Feed Presentation | Playback policy lives here: settle-gated auto-play (S2), toggle + click/space guards (S5–S7), stop-on-away / restart-on-revisit (S9, S10), loop policy (S11), failure → sticky `.unavailable` (S14, S15) | S1–S11, S14–S16 |
| `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (exists) | Feed Presentation | New `.player` display case (the poster it replaces); the tap target; still never sees the item (S8) | S4, S6–S8 |
| `InstantPlayer/Features/Feed/Presentation/PlayerSurfaceView.swift` (new) | Feed Presentation | ~15-line `NSViewRepresentable` wrap of the handle's display-ready view — AppKit only, a wrap not processing (§4) | S8 |
| `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (exists) | Feed Presentation | Drills the per-page tap closure; otherwise unchanged | S6, S7 |
| `InstantPlayer/App/FeedKeyCommand.swift` (renamed from `ArrowKeyCommand.swift`) | App | The routing table grows into a feed-key router: space (49, repeat-suppressed) → `.togglePlayback` (§6) | S5 |
| `InstantPlayer/App/AppDelegate.swift` (exists) | App | Monitor switch gains the toggle/ignore cases | S5 |
| `InstantPlayer/App/AppDependencies.swift` (exists) | App | Player seam binds `AVMediaPlayerService` (was stubbed); init stays allocation-only | R13 of E1-S3 |
| `InstantPlayer/Features/Feed/Presentation/FeedState.swift`, `App/RootView.swift`, `App/InstantPlayerApp.swift` | — | **Untouched** | — |

### 1.1 Placement justifications (architecture reviewer checks)

- **Commands + events through an opaque session handle (§2), not player types:** Domain stays
  Foundation-only (R10) — no `AVPlayer`, `AVPlayerItem`, `NSView` type appears in any Domain member
  signature. The seam vends a `MediaPlayback` handle (a Domain protocol — opaque, like the `URL` and
  `Data` precedents of E2-S1/E2-S2); the concrete `AVMediaPlayback` lives in Data where all
  AVFoundation operations belong (architecture §4 check 3). Handle identity (`===`) is the exact
  staleness guard for events (§3).
- **Wording extension recorded (architecture §4 check 3 — the third refinement):** alongside
  "display-ready `Data`", an **opaque, display-ready platform view** may travel as an opaque
  `AnyObject` value out of a Data conformance (`MediaPlayback.makeDisplayView()`), and Presentation
  wraps it into the view hierarchy — **a wrap, not processing** (no seeking, no rate, no item
  management, no AVFoundation import in Presentation; `PlayerSurfaceView` uses AppKit only, exactly
  like E2-S2's `NSImage` wrap). The AVKit/AVFoundation *operations* — building and configuring the
  `AVPlayerLayer` host — happen only in Data. The exact `docs/architecture.md` edits are listed in
  §13 (outside this author's write permissions).
- **Playback policy in `FeedViewModel` (D8):** the settle gate, toggles, guards, lifecycle, and loop
  policy are presentation semantics — the one holder keeps them unit-testable without a window
  (D22's precedent: spec semantics live in the view model). Views stay dumb binders.
- **`FeedKeyCommand` rename (was `ArrowKeyCommand`):** the table now routes more than arrows; the
  name follows the honest scope (architecture §5 naming). Mechanical rename + one route case.
- **Project config: explicitly nothing.** No entitlements, no Info.plist keys, no build settings, no
  pbxproj diff — playback needs no new grant (§9) and new source files join the target through
  synchronized groups automatically (D21). **Any apparent need for project-config change is a
  coordinator escalation, not a task** (D21 note).

### 1.2 Why the conformance is `@MainActor`, not an actor (D8's trigger rule, explicitly)

D8 ships an actor only when mutable state is **shared across isolation domains**. Here it is not: the
playback session has exactly one consumer — the `@MainActor` view model — and the platform player is
main-adjacent (its layer is rendered with the view tree). The event stream's sources (AVFoundation
notifications/KVO) arrive on arbitrary threads but are **marshaled to the main actor at the
conformance boundary** (§2) — no state is ever touched cross-isolation. What the story *does* need
is **synchronous bite**: S9's "nothing keeps playing off-screen" and §8(2)'s no-audio-past-the-page-
turn require `pause()`/`stop()` to take effect in the same main-actor turn as the page change — an
actor conformance would add an executor hop to exactly the calls that must be deterministic. So the
seam is `@MainActor` (isolation is now part of this contract), the conformance is a `@MainActor`
final class, and **no actor ships** — the D8 trigger is unmet. Rejected alternatives in §12.

## 2 · The playback seam contract (`Features/Feed/Domain`)

`MediaPlayerService` (grows; `@MainActor`, `AnyObject` — class semantics for mutable session state):

- `func startPlayback(for item: MediaItem) async -> MediaPlayback?` — supersedes **and tears down**
  any previous session (exactly one live player, §3), creates the session for the item, awaits the
  asset being loadable/playable (AVFoundation-internal I/O — never main-thread), and **starts playing
  with audio unmuted** (S1, S3: the conformance never sets `isMuted`/`volume` — app-level volume is
  E3-S3). Returns the opaque session handle, or **`nil`** — the unified failure answer: vanished
  file (S15), mislabeled/undecodable file (S14, D20), or unplayable asset — the same `nil` precedent
  as `MediaPreviewService`.
- `func wiringProbe() async -> String` — unchanged house pattern.

`MediaPlayback` (new, Feed Domain — one started session; `@MainActor protocol … : AnyObject`):

- `var events: AsyncStream<MediaPlaybackEvent> { get }` — `.readyForDisplay` (the layer has its
  first frame — the swap gate, §4), `.reachedEnd` (S11's trigger), `.failed` (mid-play failure,
  S14). Bridged from AVFoundation observations at the conformance boundary onto the main actor;
  the stream finishes on `stop()` (belt) — the view model's identity guard (braces) is §3.
- `func pause()` / `func resume()` — synchronous, deterministic (S5, S6).
- `func restart()` — seek to the beginning and play (S11's mechanism lives in Data; the *policy*
  — when to restart — lives in the view model).
- `func stop()` — tear down now: rate 0, item detached, observers removed, display view released.
  Synchronous bite (S9; §8(2)).
- `func makeDisplayView() -> AnyObject` — the display-ready platform view (§4): built and
  configured in Data, wrapped by Presentation. Re-called after `stop()` returns nothing usable —
  the handle dies with its session.

`MediaPlaybackEvent` (`nonisolated enum`): `.readyForDisplay`, `.reachedEnd`, `.failed` — pure
values; which handle emitted is known by *which stream* delivered it (identity by construction).

There are deliberately no seek, rate, or volume members: S12–S13 forbid nothing here, but every
extra member is surface E3 must later reshape — the minimal session is exactly this story's
contract. Async/await only (D8, R4): events are a stream, never completion handlers.

## 3 · Player lifecycle (S1, S2, S9, S10)

**Exactly one live player — the current item's (S1).** `startPlayback` supersedes any previous
session; the view model additionally stops the old session synchronously on every current-item
change. No pooling, no warm players, no kept-alive positions.

- **Auto-play trigger (S1, S2):** `syncPlayback()` runs when (a) the feed is at rest — no paging in
  flight — and (b) the current item is a video without sticky playback failure (§7's per-axis rule).
  Paths: folder open at `startIndex` (at rest → starts immediately), replace-in-place at its
  `startIndex`, and **paging settle** — the scroll surface's return to rest (`onScrollPhaseChange`
  → idle, which also covers arrow-key page animations: E2-S2's existing phase plumbing already sees
  them as onset/settle, so `scrollGestureDidSettle()` is the single settle signal for both
  mechanisms). Mid-gesture `moveTo(itemID:)` calls change the index but **never** start playback —
  the incoming item keeps its poster (S2). If functional review shows programmatic page animations
  emit no phase signals, the fallback is one line: start arrow-paged items at the (determined)
  clamped landing — recorded as a ratified deviation if taken.
- **Stop-on-away (S9):** the moment the current item changes — mid-gesture or not — the old session
  is `stop()`-ped in the same main-actor turn (§1.2). Audio cannot bleed past the page turn by
  construction (§8(2)).
- **Restart-on-revisit (S10):** returning to a video calls `startPlayback` again — a **fresh**
  session from the beginning (auto-play per S1 as a fresh start). Nothing carries across visits.
  Consequence, accepted as the honest reading of the settled semantics: a zero-net gesture
  (rubber-band snap-back) that transiently moved the index restarts the same video from its
  beginning — deterministic, and rare.
- **Late events never paint or sound (E2-S2 generation counter, three braces):** (1) `stop()`
  finishes the stream and removes observers; (2) every event handler checks `handle === current
  playback` — a torn-down session's handle can never match; (3) `startPlayback` results and event
  effects are generation-guarded (`latestEntryGeneration`, the existing last-wins counter), so a
  superseded collection's session never installs. Replace-in-place (`adopt`) and welcome
  (`discardDisplayState`) both `stop()` and drop the handle alongside the existing display-state
  reset.

## 4 · Rendering the current item (S8; the `.player` display state)

The display state (E2-S2 design §7) gains `case player(MediaPlayback)`; `Equatable` becomes
hand-written (`.player` cases compare handles by `===`; other cases unchanged) so the wrap memo and
`onChange` behavior carry over.

- **Seamless swap (the poster IS frame 0):** the poster (D23 preview) stays under the current video
  until the session emits `.readyForDisplay`; only then does the state become `.player` — the layer's
  first frame is frame 0, identical pixels to the poster. No flash, no spinner on the happy path.
- **The wrap:** `PlayerSurfaceView: NSViewRepresentable` does one thing — `makeDisplayView()` into
  the hierarchy (`makeNSView` vends it once per session; `updateNSView` is a no-op — the handle is
  immutable per session). The Data-side view is a layer-hosting `NSView` with `AVPlayerLayer`
  (`videoGravity = .resizeAspect`): aspect-fit letterbox inside the viewport-sized cell — E2-S2 S2's
  visual contract carries over unchanged (letterbox = window background). Resize and native
  fullscreen (E2-S2 S10, S11) need no code: the layer tracks its host view's bounds.
- **Paused (S8):** the layer naturally shows the frozen frame — no chrome of any kind ships in this
  story (S8; E2-S2 S14 carried). `body` stays cheap (skill §2): the wrap happens once per session,
  never per frame.
- **Images (S4):** never reach this path — `syncPlayback` and both toggles no-op for `.image`
  items; the cell renders the poster/unavailable states exactly as in E2-S2.

## 5 · Loop in place (S11)

**Mechanism: `actionAtItemEnd = .none` + the end notification + `restart()` (seek-to-zero-and-play),
policy in the view model.** On `.reachedEnd` the view model calls `handle.restart()` and **never
touches the index** — feed advancement is user-driven only (S11: no auto-advance, by construction:
the session holds exactly one item, so there is nowhere to advance to). The restart is an honest
restart of the same video from its beginning — not a seamless cycle; the last frame may hold for a
frame or two while the event round-trips (acceptable: the spec asks for restart semantics, not a
gapless loop). Edge case resolved by construction: resuming a session that is parked exactly at end
plays zero frames, emits `.reachedEnd`, and loops per S11 — no special case. Rejected alternatives
(`AVPlayerLooper`, recreate-on-end) in §12.

## 6 · Input delivery (S5–S7)

**Spacebar (S5) — extend the App-owned key monitor (D22's consequence; evidence §8's lesson is
binding: SwiftUI focused-view key delivery is unreliable on this OS build).** `ArrowKeyCommand`
becomes **`FeedKeyCommand`** (mechanical rename — the table routes a feed's keys, not just arrows)
and gains two cases: `.togglePlayback` and `.ignore` (consume, do nothing). Route table
(`route(keyCode:modifiers:isRepeat:hasOpenFeed:)`, pure and unit-tested):

- No open feed (welcome) → `.passThrough` (unchanged).
- ⌘/⌥/⌃ combinations → `.passThrough` (unchanged — ⌃⌘F fullscreen survives; system shortcuts are
  never robbed).
- **Space (keyCode 49), first press → `.togglePlayback`; auto-repeat (`isARepeat`) → `.ignore`
  (consumed).** A held space must not flap play/pause — unlike arrows, where auto-repeat = repeated
  presses is the carried, accepted behavior. Consuming space on image pages and mid-gesture (the
  toggle no-ops in the view model, S7) is deliberate: passing it through would re-expose it to the
  system's unhandled-key path — the beep that plagued evidence §8. ⇧+space toggles (⇧ is not a
  command modifier — consistent with ⇧↓ paging).
- ↓/↑ (125/126) → page (unchanged); anything else → `.passThrough`.

**Click (S6, S7) — SwiftUI tap on the page, guard in the view model.** `.onTapGesture` on each
`FeedItemView`'s full-bleed content (`.contentShape` — the whole page, letterbox included, is the
hit target). The cell still never sees the item (S8's structural absence): `FeedView` drills an
`onTap` closure per page that captures the item id and calls
`viewModel.togglePlaybackFromTap(itemID:)`. App-level mouse monitors are rejected (§12): taps are
not focus-dependent (the evidence §8 failure was key focus), and hit-testing "which page" at the App
layer would duplicate what the view tree already knows.

**The guard matrix lives entirely in the view model** (`togglePlayback()` for space — guarded to the
current session; `togglePlaybackFromTap(itemID:)`), one unit-tested decision surface:

| Input situation | Result | Source |
|---|---|---|
| Settled current video, playing | pause (S5, S6) | S5/S6 |
| Settled current video, paused | resume (S5, S6) | S5/S6 |
| Click on a non-current page | no-op (consumed) | S7 |
| Any toggle while paging is in flight | no-op (consumed) | S7 |
| Current page is an image | no-op (consumed) | S4, S7 |
| Current video with sticky playback failure | no-op | S7's guard, §7 |
| Double-click | two single clicks per S6 — **no meaning in v1** (spec non-goal) | spec |

Pause indication is the frozen frame only (S8) — the toggle changes nothing visible except motion.

## 7 · Failure path (S14, S15)

Extends E2-S2's contract on the same view-model path as preview-`nil` (the spec's S14 derivation —
the E2-S2 design §13 handoff):

- **At start:** `startPlayback` → `nil` (asset load fails, not playable, frames never produced —
  e.g. `fake.mp4` holding text under D20's honest declared-type contract; or a vanished file, S15)
  → the item's display state becomes the **same neutral `.unavailable`** — sticky for the session,
  no auto-retry, no retry affordance, feed navigable (E2-S2 S12/S13 semantics verbatim).
- **Mid-play:** a `.failed` event → `stop()` + the same sticky `.unavailable`.
- **Per-axis stickiness (settled here):** poster failure and playback failure are separate axes. A
  video whose poster failed still gets its playback attempt when it becomes current (S1 is
  unconditional; playback succeeding shows `.player` — honest recovery); once **playback** fails,
  the item is never re-attempted this session (the no-retry contract applies to the axis that
  failed). A fresh entry action resets everything (E2-S2's "way out").
- Stale items (S15) and playback failure (S14) are indistinguishable to the user by design — one
  neutral state, no error codes, no file name (E2-S2 S14). Live removal semantics stay E4-S2.

## 8 · Performance (RNF-02) — mandatory

Loaded skill: `swift-performance`. The performance-relevant surfaces are playback start (the story's
headline), the page-turn audio cut, exactly-one-player memory, and paging-during-playback
responsiveness. Per-story budgets (the E2-S1/E2-S2 measured-evidence precedent):

1. **Auto-play start budget (the "instant" contract — S1, S2, RNF-02's headline):** from paging
   **settle** (or any become-current moment) to **audibly playing with the first frame shown**
   (`.readyForDisplay` + rate 1): **≤ 300 ms p95** for typical media (≤ 1080p clips) on
   Apple-silicon reference hardware; **≤ 1 s p95** atypical heavy media (4K+). Justification for
   achievability: local files only (D9 — no network stall is possible), the work is asset init plus
   one first-frame decode; `playImmediately(atRate: 1)` skips the player's waiting policy; the
   poster-as-first-frame (§4) keeps the *visual* start seamless regardless — the measured latency
   is only the motion/sound start. Measurement: a unit performance test through the real
   conformance (XCTest `measure` over generated fixtures — settle-equivalent call to
   `.readyForDisplay`), recorded as story evidence from tooling; heavy-media numbers are functional
   review plus Instruments escalation if review disagrees (skill §6 — measurement, not vibes).
2. **Audio cut on page-away (S9, S16):** `stop()` bites **synchronously** in the same main-actor
   turn as the current-item change — no audio past the page turn, deterministic (this is why the
   seam is `@MainActor` and `stop()`/`pause()` are sync — §1.2). Testable: after the paging call
   returns, the spy's `stop` has already been recorded and the real session reports rate 0.
3. **Exactly one live player (skill §3 — create, reuse-none, tear down):** `startPlayback`
   supersedes the previous session; memory bound = one `AVPlayer` + one `AVPlayerItem` + AVFoundation
   decode buffers, plus the unchanged preview cache (64 MB / 32 entries, D23). No pooling (S10) —
   revisits allocate fresh, and every departure releases. Observers and streams die with the
   session (§3) — no leaked callbacks retaining players.
4. **Zero added launch cost (R13 of E1-S3 must survive):** no player work at launch — sessions
   exist only while a video is current; `AppDependencies` gains one binding swap (stub → real, an
   allocation) and `FeedKeyCommand` is one more O(1) switch case on the existing monitor. The
   welcome state touches no media (E2-S1/E2-S2 guarantee preserved); `testLaunchPerformance`
   remains the guard.
5. **Paging-during-playback responsiveness (S16, product R16):** event handling is O(1) state flips
   on the main actor; `body` renders a pre-wrapped surface (the E2-S2 wrap-memo pattern); pause/
   resume/stop are O(1) rate/player calls; the settle gate and guards are pure arithmetic. No
   dropped-frame regression target: the unit perf test plus the launch/UI run are the deterministic
   guards; Instruments is the escalation (skill §6).
6. **No main-thread I/O (skill §1):** asset loading uses AVFoundation's async load APIs (I/O on
   AVFoundation threads, awaited); no synchronous file reads anywhere on the playback path; the
   event bridges are notifications/KVO marshaled to main — O(1) each.
7. **Teardown on every exit (§3):** page-away, replace-in-place (`adopt`), and welcome
   (`discardDisplayState`) all stop the session in the same turn — players, decoders, and observers
   never outlive the current item.
8. **Measured evidence (skill §6):** budgets (1) and (4) are carried by tooling output (gate JSON,
   XCTest `measure`) recorded in the story's evidence — never "it feels fast".

## 9 · Security (RNF-04) — mandatory

Loaded skill: `swift-security`. Playback reads media bytes — the D19/D20 posture is inherited, not
extended, and product R17 (S12) is this story's first-class requirement:

- **Read-only reads inside the open session (D19, S12):** the player service operates only on items
  of the currently open collection, whose security-scoped session is already active. The conformance
  performs **no** `start/stopAccessingSecurityScopedResource`, holds no session of its own, and adds
  **no entitlements** — D19's four read-only keys stand unchanged. Stated for the D21 audit: **no
  entitlement, Info.plist, or pbxproj change in this story — expect a zero project-config diff; any
  apparent need is a coordinator escalation (D21 note).**
- **Nothing is ever written (S12, S13 — R17):** playback APIs only (`AVURLAsset`/`AVPlayerItem`/
  `AVPlayer`/`AVPlayerLayer`) — **no `AVAssetExportSession`, no `AVAssetReader`/`AVAssetWriter`, no
  `write(to:)`, no re-encode path of any kind**. No sidecar files (no chapters/thumbnails/previews
  on disk), no disk cache of playback data, and **no playback-state persistence** — no `UserDefaults`,
  no files in `tmp`/`Caches`/`Application Support` (E3-S3's persisted volume will be v1's first
  preference write — not this story). Re-encoded copies are precisely the v1 non-goal "file
  editing/export" (product spec) — playback is a read of the user's file and nothing else.
- **Untrusted media bytes (skill §4):** file content is only ever *played* — playback APIs decode
  media pipelines; nothing executes file content (no WebKit, no dynamic loading, no process
  spawning). A mislabeled `fake.mp4` holding text can only fail to load/decode → `nil` → the
  neutral unavailable state (S14). Corruption or hostile media hits AVFoundation's own hardened
  decoders; allocation is bounded by the decode pipeline, never by us copying the file.
- **File names display-only (D20):** never parsed, never logged; the unavailable state carries no
  name (E2-S2 S14).
- **Logging:** none planned. If diagnostics are added, `os.Logger` with `privacy: .private`, never
  paths or names of user media (skill §5).
- **Dependencies:** none added — AVFoundation/AVKit are system frameworks (skill §6: no new SPM
  surface). ATS/network untouched (no networking in v1, D9).
- **Privacy manifest:** no required-reason API is added (no `UserDefaults`, no file-timestamp APIs)
  — **no `PrivacyInfo.xcprivacy` change**, consistent with E2-S1/E2-S2.

### 9.1 Sandbox/media-read review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements | Unchanged — D19's four read-only keys; no new grant (§9) |
| User files access pattern | Reads only inside the already-open scoped session; the conformance does no start/stop (D19) |
| Writes to disk | None, anywhere — playback APIs only; no export/reader/writer, no sidecars, no disk caches (S12, S13) |
| Persistence | None — no playback state at rest (S13); no `UserDefaults` in this story |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19) |
| Untrusted input | Media bytes play-only, never executed; mislabeled/corrupt → `nil` → unavailable (S14, D20); URLs travel as values |
| File names | Display-only; absent from the unavailable state and from logs (E2-S2 S14, D20) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason | No triggering API used (§9) |
| Dependencies | None added |

## 10 · Testing strategy

### 10.1 Playback policy (unit, `InstantPlayerTests` — the spec's AC)

`FeedViewModelTests` with injected `MediaFolderRepository` + `MediaPreviewService` +
`MediaPlayerService` doubles (spy + scripted handle whose events the test drives) — no UI, no
window, no AVFoundation:

| Case (requirements) | Expected |
|---|---|
| Become-current trigger set (S1) | folder open → `startPlayback` for `startIndex`'s video; `pageForward`/`pageBackward` at rest → start for the new current; replace-in-place → start at the new `startIndex`; image items never started (S4) |
| Settle-only start (S2) | `scrollGestureDidStart` + mid-gesture `moveTo` → **no** start; `scrollGestureDidSettle` → start for the settled item (after the guard correction) |
| Unmuted auto-play (S3) | seam contract asserted at the double (`startPlayback` = play, unmuted) and at the conformance (§10.2) |
| Toggle via space (S5) / via tap (S6) | playing → `pause()`; paused → `resume()`; state observable |
| Click-guard matrix (S7, S4) | non-current tap id → no-op; mid-gesture → no-op; image page → no-op; sticky-failure item → no-op (the §6 table as tests) |
| Stop-on-away (S9) | index change away from a playing video → `stop()` recorded synchronously (before the paging call returns) |
| Restart-on-revisit (S10) | paging back to a played video → fresh `startPlayback` for it — no resume, no reuse |
| Loop, no advance (S11) | `.reachedEnd` → `restart()` on the **same** handle; `currentIndex` unchanged; no neighbor ever started |
| Failure → sticky unavailable (S14, S15) | `startPlayback` → `nil` → `.unavailable`; `.failed` event → `stop()` + `.unavailable`; re-visit does not re-attempt (per-axis stickiness, §7) |
| Late events never paint (§3) | events from a stopped/superseded handle → display state and commands untouched (identity + generation guards); superseded `startPlayback` result never installs |
| Pause presentation (S8) | display state stays `.player` on pause — the frozen frame is the only indication |
| Welcome/replace teardown | `discardDisplayState`/`adopt` → `stop()` + handle dropped (§3) |

### 10.2 Playback seam (unit, Feed Data)

Fixtures (test helper, throwaway temp folders per E2-S2 §10.2's pattern): the existing
`MediaFixture.writeOneFrameMP4` (real `AVAssetWriter` bytes) plus a new tiny multi-frame/short-
duration MP4 helper for end/loop timing; junk cases (`fake.mp4` text bytes); a deleted URL. Cases:
`startPlayback` on a real clip → handle + `.readyForDisplay` (and `isMuted == false`, `volume`
untouched — S3, via `@testable` internals); `pause()` freezes the current time; `resume()` continues;
natural end of the short clip → `.reachedEnd`; `restart()` returns near zero and plays (S11's
mechanism); `fake.mp4` → `nil` (S14 — D20's contract pinned); vanished URL → `nil` (S15);
`stop()` → stream finishes, no further events, display view released (§3); a superseded session is
torn down when `startPlayback` runs again (one live player, §8(3)). Perf case: the `measure` block
of §8(1).

### 10.3 UI tests and the mandate (R14 of E1-S2)

Converge runs `./scripts/validate.sh --uitests`. The launch tests keep asserting the welcome state
(S-spec: playback is unreachable on plain launch) and `testLaunchPerformance` keeps guarding launch
cost (§8(4)). No new UI tests: entry flows are host-driven and playback is unreachable without them
— the spec's honest caveat stands; unit tests (§10.1–10.2) plus stakeholder functional review carry
playback behavior.

### 10.4 Functional review (stakeholder — the spec AC list)

`./scripts/app.sh run` covers: auto-play on arrival at folder open and on every paging move onto a
video — **starting only after paging settles, never mid-scroll**; sound audible (unmuted) on
auto-play; the perceived start feeling instant (budget §8(1) is the number, the review is the
perception); the seamless poster→video swap; spacebar toggling play/pause (no flap on key hold, no
beep on image pages); a single click toggling from anywhere on the page including the letterbox;
clicks on neighbors/mid-gesture/image pages doing nothing; the paused video showing only the frozen
frame with no chrome; paging away silencing the video immediately; paging back restarting from the
beginning; a video looping at its end without advancing the feed; the unavailable state for a
`fake.mp4` and a vanished file with the feed navigable; resize/native fullscreen keeping the playing
video letterbox-filling; and the media files byte-identical on disk after all of the above.

## 11 · ADR plan (continuing from D24)

Four ADRs, cut along independent review axes — lifecycle/isolation, loop, rendering, input — each
mapping to distinct requirements; recorded in [docs/decisions.md](../../decisions.md) by the
implementing tasks:

- **D25 — Playback sessions: one `@MainActor` player service, one live player, restart-on-revisit.**
  `MediaPlayerService` grows `startPlayback` + an opaque `MediaPlayback` session handle (commands,
  event stream, display-ready view); the conformance is `@MainActor` because no mutable state is
  shared across isolation domains (D8 trigger unmet) and stop/pause need synchronous bite (§1.2);
  exactly one live player, torn down synchronously on page-away/replace/welcome; revisits start
  fresh (S9, S10); identity + generation guards make late events inert (§3). → S1–S3, S9, S10, S14, S15.
- **D26 — Loop by seek-to-zero-and-play, policy in the view model.** `actionAtItemEnd = .none` +
  `.reachedEnd` + `restart()`; no auto-advance by construction (one-item session); honest restart,
  not a gapless cycle. → S11.
- **D27 — Chrome-free rendering: opaque handle + display-ready platform view wrapped by
  Presentation.** `MediaPlayback.makeDisplayView() -> AnyObject` vends an `AVPlayerLayer` host
  (resizeAspect) from Data; `PlayerSurfaceView` wraps it (AppKit only); the architecture §4 check-3
  wording gains the display-ready-platform-view refinement; the poster→player swap is gated on
  `.readyForDisplay` (the poster is frame 0). → S4, S8.
- **D28 — Playback input: the App-owned key monitor becomes a feed-key router; clicks are SwiftUI
  taps guarded in the view model.** `ArrowKeyCommand` → `FeedKeyCommand` with space (49,
  repeat-suppressed) → `.togglePlayback`; whole-page `.onTapGesture` with the guard matrix in the
  view model (S7); no mouse monitor, no `onKeyPress`. → S5–S7.

## 12 · Alternatives considered

- **`AVPlayerLooper` (AVQueuePlayer) for the loop** — rejected: queue machinery for a single item;
  its seamless item-swap semantics obscure S11's literal "restart the same video from its beginning"
  and route around the single-item no-auto-advance guarantee; failure observation of looped queue
  items is fuzzier. **Recreate the item on every end** — rejected: a fresh asset load per loop cycle
  buys nothing over one seek. **Loop in the conformance** — rejected: S11 is product policy (which
  the view model keeps unit-testable per D22's precedent); the seam only provides `restart()`.
- **Actor conformance (the E2-S1 pattern) for `MediaPlayerService`** — rejected: D8's trigger is
  unmet (no mutable state shared across isolation domains — one `@MainActor` consumer, events
  marshaled at the boundary) and the executor hop lands exactly on `pause()`/`stop()`, defeating
  S9's deterministic audio cut. **All-async seam (the `MediaPreviewService` shape) kept for the
  player** — rejected for the same reason: synchronous bite is contract here; `startPlayback` is
  async because asset loading is.
- **Commands by item id (`play(itemID:)`, `pause(itemID:)`)** — rejected: invites a registry of
  stale sessions and makes the late-event guard a lookup problem; the session handle gives identity
  (`===`) for free and keeps "exactly one live player" structural. **`AVPlayer` escaping into
  Domain/Presentation** — foreclosed: architecture §4 (AVKit only in Data).
- **SwiftUI `VideoPlayer`** — rejected: built-in transport controls violate S8's chrome-free
  viewport (S7's consequence puts controls in E3's hover bar, if anywhere) and it puts AVKit in
  Presentation. **`AVPlayerView` (`controlsStyle = .none`)** — rejected: heavier, ships interaction
  machinery we must suppress; a bare `AVPlayerLayer` host is unambiguously chrome-free and lighter
  (skill §3). **`PlayerSurfaceView` importing AVFoundation in Presentation** — rejected: media
  operations in Presentation violate architecture §4 check 3; the display-ready-view wrap keeps the
  rule intact. **View-factory closure injected at the composition root** (`(MediaPlayback) -> AnyView`)
  — rejected as the bridge: more plumbing (RootView/AppDependencies) and `AnyView` for what
  `makeDisplayView() -> AnyObject` expresses with the existing display-ready-value precedent.
- **App-level `NSEvent` mouse monitor for the click toggle** — rejected: taps are not
  focus-dependent (evidence §8's failure was key focus), the view tree already knows which page was
  hit, and a global monitor would fight the scroll view's own click handling.
  **`.onKeyPress`/focus-based space** — foreclosed by evidence §8's three failed rounds.
  **Keeping the `ArrowKeyCommand` name** — rejected: the table routes a feed's keys now.
  **Auto-repeated space toggling (like repeated arrows page)** — rejected: play/pause flap is not a
  standard media-player behavior; repeats are consumed and ignored.
- **Starting playback from the current index on every `moveTo` (no settle gate)** — foreclosed by
  the spec's S2 (audible blips for scrolled-past videos; destination undetermined mid-gesture).
  **Deferring the swap until the *poster* also exists** — rejected: the swap gate is the layer's
  first frame (`.readyForDisplay`), not the poster; poster-less playback is honest recovery (§7).
- **Retrying failed playback on every revisit** — rejected: breaks the sticky no-retry contract
  (E2-S2's unavailable semantics extended, S14); per-axis stickiness (§7) is the honest reading.
- **Session-scoped AVPlayer pooling (reuse the player, swap items on revisit)** — rejected: S10
  wants deterministic fresh starts and memory-lightness; skill §3's create/tear-down discipline with
  one live player is simpler and bounded.

## 13 · Consequences & required follow-ups

- **`docs/architecture.md` updates are required in this story** (its §1 rule) — **not committed with
  this design: writing that file is outside this author's permissions (reported to the coordinator
  rather than bypassed, the E2-S2 §13 precedent).** The exact updates, to be applied by an agent
  with write access in this story's task phase:
  1. **§3 tree:** gain `Features/Feed/Domain/MediaPlayback.swift`, `MediaPlaybackEvent.swift`,
     `Features/Feed/Data/AVMediaPlayerService.swift`, `AVMediaPlayback.swift`,
     `Features/Feed/Presentation/PlayerSurfaceView.swift`; rename `App/ArrowKeyCommand.swift` →
     `App/FeedKeyCommand.swift`; re-annotate `MediaPlayerService.swift` (real members),
     `StubMediaPlayerService.swift`, `FeedViewModel`/`FeedView`/`FeedItemView`.
  2. **§4 check (3):** add the display-ready platform-view wording (the third refinement):
     "an opaque, display-ready platform view may travel as an opaque `AnyObject` value from a Data
     conformance; Presentation wraps it into the view hierarchy — a wrap, not processing".
  3. **§8 actor note:** no new actor in this story — the player conformance is `@MainActor` because
     D8's trigger is unmet (no cross-isolation shared state) and synchronous stop/pause bite is
     contract; re-annotate the seam-isolation pattern accordingly (`@MainActor` seams when
     synchronous real-time commands are part of the contract).
- **D21 audit expectation:** zero project-config diff — no pbxproj, entitlements, Info.plist, or
  build-setting change anywhere in this story's commits.
- **E3 handoff:** controls arrive into the chrome-free viewport (S8 carries E2-S2 S14). The spec's
  S7 consequence is binding: E3-S1's scrubbing must live in a **hover/mouse-move overlay control
  bar** — drag-on-video scrubbing is foreclosed (the whole page is the click target). The
  `MediaPlayback` handle will grow seek/rate members for E3-S1/E3-S2 and volume members for E3-S3;
  the loop policy (D26) stays in the view model. Double-click remains meaningless (spec non-goal).
- **E4-S2** supersedes S15's stale-item fail-safe with live removal semantics (product R24/R26);
  the unavailable state remains for genuinely unreadable/unplayable files (S14).
- **Accepted sharp edges, recorded honestly:** a zero-net gesture that transiently moved the index
  restarts the same video from its beginning (§3 — the settled restart semantics read uniformly);
  the loop restart may hold the last frame for a frame or two (§5 — honest restart, not gapless);
  if arrow-page animations emit no scroll-phase signals, the fallback start policy (§3) becomes a
  ratified deviation like E2-S2 round 4's.
