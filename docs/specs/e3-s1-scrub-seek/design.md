# E3-S1 · Scrub & seek — Design

How the current video's playback position moves: drag-scrub on the ratified hover/mouse-move overlay
control bar (S1, S5–S8), keyboard seek with ←/→ (S2, S9, S10), track click (S11), all guarded to the
settled current video (S12), clamped and handed over to the loop contract at the end (S13, S14),
read-only and position-free (S15, S16), and smooth under every input (S17). Story spec:
[spec.md](spec.md) (S1–S17 over product R13; R16 via S17, R17 via S16; the E2-S3 S8 amendment is in
the spec's Story context and S3). Structure follows [docs/architecture.md](../../architecture.md)
(D7–D10); this story builds exactly the surface E2-S3 handed over — §13 of
[the E2-S3 design](../e2-s3-basic-playback/design.md) (D27's consequence: drag-on-video scrubbing
stays foreclosed). Pillars: RNF-02 and RNF-04 — mandatory sections below (§8, §9); the design was
written against the `swift-performance` and `swift-security` skills
(`.opencode/skills/swift-performance`, `.opencode/skills/swift-security`), and every implementer and
the validator load them before touching this code (D5).

Scope reminder: this story ends at "the user can move the playback position precisely, from the bar
and from the keyboard, without chrome at rest and without touching the files". No playback speed
(E3-S2), no volume/mute (E3-S3), no extra seek keys or variable steps (spec non-goals), no bar
contents beyond the four named elements (S3), no drag-on-video scrubbing (foreclosed), no resume or
persisted positions (S15, S16). **No project-config work of any kind** (D21 note, §1.1, §9). No
`[NEEDS CLARIFICATION]` markers exist in this design — every decision below is made and traceable to
S-/product-R numbers.

**Requirements map (S1–S17 → sections):**

| Req | Served by | Req | Served by |
|---|---|---|---|
| S1 drag-scrub | §2 (seek seam), §4 (bar), §5 (drag machine) | S10 state neutrality | §5 (commit seeks never touch rate) |
| S2 keyboard ±5 s | §6 (router), §5 (step arithmetic) | S11 track click + carve-out | §4 (hit-test split), §5, §6 |
| S3 bar lifecycle & contents | §4 (visibility policy, idle timer) | S12 guard matrix | §5 (the matrix table) |
| S4 images: no bar, no seek | §4 (model is `nil`), §5 (guard) | S13 clamping | §5 (mapping + clamp) |
| S5 drag pauses + live frame | §5 (drag machine), §2 (preview seeks) | S14 end handover | §5 (end rule → D26 loop) |
| S6 tolerant preview | §2 (`.preview`, coalesced) | S15 nothing carried | §7 (fresh session carries none) |
| S7 frame-exact release | §2 (`.exact`), §8 budget 2 | S16 read-only | §9 (Security, RNF-04) |
| S8 state restoration | §5 (`wasPlayingBeforeDrag`) | S17 responsiveness | §8 (Performance, RNF-02) |
| S9 hold-to-repeat | §6 (repeat parity) | | |

## 0 · Platform and toolchain facts this design is built on

1. **`AVPlayer` seeks are tolerant-or-exact and self-superseding.** `seek(to:toleranceBefore:
   toleranceAfter:)` with `.positiveInfinity` tolerances serves the nearest convenient position fast
   (decode from a nearby sync sample); with `.zero` both sides it lands the playhead on the requested
   time exactly (decode from the preceding sync sample — the cost of exactness). A newer seek
   supersedes an in-flight one; completions arrive on arbitrary threads as callbacks. Completion
   handlers are forbidden across our seam (D8, R4) — completion state stays inside the conformance.
2. **A bounded cadence clock exists off-main:** `addPeriodicTimeObserver(forInterval:queue:using:)`
   fires on its own queue *as time advances* — a paused video produces no ticks, so there is no
   timer to gate. `AVPlayerItem.duration` is known once the asset load `startPlayback` already awaits
   completes (E2-S3 §2).
3. **`NSTrackingArea` is the deterministic mouse-move primitive.** A tracking area with `.mouseMoved`
   delivers `mouseMoved` while the pointer is inside its rect, independent of key focus — and
   `mouseMoved` does *not* fire during a mouse-down drag (that is `mouseDragged`), which is exactly
   S3(a)'s "a drag is not idle" for free. `.inVisibleRect`/`updateTrackingAreas` keep it correct
   across resize and native fullscreen (E2-S2 §5.3's container-derived geometry carries).
4. **The recorded input lesson is binding (D22's round-4 amendment, D28):** SwiftUI input delivery
   that is not plain hit-tested tapping proved unreliable on this OS build — three failed
   focused-view key-delivery rounds ([E2-S2 evidence §8](../e2-s2-vertical-feed-window/evidence.md)).
   Taps (`.onTapGesture` + `.contentShape`) are the one proven SwiftUI input. No hover primitive has
   ever been proven in this codebase (the only hover-adjacent mechanism shipped is
   `dropDestination`'s `isTargeted`); S3's trigger is *mouse movement*, which `NSTrackingArea`
   expresses 1:1. Overlay siblings with their own `contentShape` consume their own hits; a
   `highPriorityGesture` on a child claims its drags from the enclosing scroll surface.
5. **Key codes and repeats:** `NSEvent.keyCode` 123 = ←, 124 = → (already pinned in
   `FeedKeyCommandTests`), `isARepeat` identifies auto-repeat; paging's carried behavior is that
   auto-repeat equals repeated presses (D22) — S9 demands exactly that parity.

## 1 · Architecture mapping & component inventory

All changes land per the D7 walkthrough: Presentation → Domain ← Data, framework types behind seams,
composition wired only in `App/`. The seams of D25/D27 are grown additively — no new seam, no new
actor (§8). Files (names + responsibilities; member names are contract-level):

| File | Layer | Change | Requirements |
|---|---|---|---|
| `InstantPlayer/Features/Feed/Domain/MediaPlayback.swift` (exists) | Feed Domain | The handle grows `duration`, `timeUpdates`, `seek(to:tolerance:)` + `MediaSeekTolerance` (§2, §3). Foundation-only | S1, S2, S5–S7, S11 |
| `InstantPlayer/Features/Feed/Domain/MediaPlaybackEvent.swift` (exists) | Feed Domain | **Untouched** — the clock is a separate stream (§3) so rare events keep their "never dropped" semantics | — |
| `InstantPlayer/Features/Feed/Data/AVMediaPlayback.swift` (exists) | Feed Data | Seek mechanism: the coalescing seek scheduler (§2), the periodic clock bridge (§3) | S1, S2, S5–S7, S17 |
| `InstantPlayer/Features/Feed/Data/SeekScheduler.swift` (new) | Feed Data | The pure latest-wins seek-dispatch state machine (conformance-internal; unit-testable without AVFoundation) | S6, S7 |
| `InstantPlayer/Features/Feed/Data/StubMediaPlayerService.swift` (exists) | Feed Data | Stub handle grows the new members (house pattern; wiring tests) | — |
| `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (exists) | Feed Presentation | All scrub/seek policy: drag state machine (S5–S8), guard matrix (S12), mapping/clamping (S13), end handover (S14), keyboard steps (S2, S9, S10), bar-visibility + idle policy (S3), time-display state (§3) | S1–S17 |
| `InstantPlayer/Features/Feed/Presentation/PlaybackControlBarView.swift` (new) | Feed Presentation | Dumb binder: track, scrubber, elapsed/duration labels; reports gesture geometry as fractions (§4) | S1, S3, S5–S7, S11 |
| `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (exists) | Feed Presentation | `.player` case becomes tap-surface + optional bar overlay siblings (§4, §7); the strip carve-out (S11) | S3, S4, S11 |
| `InstantPlayer/Features/Feed/Presentation/PlayerSurfaceView.swift` (exists) | Feed Presentation | Grows the mouse-move tracking area + coordinator-held callback (AppKit only — a wrap, not processing) | S3 |
| `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (exists) | Feed Presentation | Drills the per-page bar model + action closures (the tap-closure pattern of E2-S3 §6) | S1, S3, S5, S11 |
| `InstantPlayer/App/FeedKeyCommand.swift` (exists) | App | The frozen route table gains `.seekForward`/`.seekBackward` (124/123) | S2, S9 |
| `InstantPlayer/App/AppDelegate.swift` (exists) | App | Monitor switch gains the two seek cases | S2 |
| `InstantPlayer/App/AppDependencies.swift`, `App/RootView.swift`, `App/InstantPlayerApp.swift`, `FeedState.swift` | — | **Untouched** — the composition root needs no new wiring (§7) | — |

### 1.1 Placement justifications (architecture reviewer checks)

- **Seek rides the existing opaque handle (D25, D27), not a new seam or a player type:** Domain stays
  Foundation-only (`TimeInterval` is a value, like the `URL`/`Data`/platform-view precedents of
  E2-S1–E2-S3 — architecture §4 check 3 unchanged, §13). No `CMTime`, no `AVPlayer`, no completion
  handler appears in any Domain signature.
- **Policy in `FeedViewModel`, mechanism in the Data conformance (D8, D22, D26's split):** the drag
  machine, guards, clamping, end handover, step arithmetic, and idle policy are presentation
  semantics — pure and unit-testable without hardware. The seek scheduler, the tolerance mapping
  into `CMTime`, and the periodic observer are AVFoundation mechanism — they never surface above the
  seam.
- **Bar visibility is presentation policy, its event source is AppKit plumbing:** the tracking area
  lives on the surface Presentation already wraps (§4); the Data display view stays interaction-free
  (D27: no interaction machinery behind `makeDisplayView()`).
- **Project config: explicitly nothing.** No entitlements, no Info.plist keys, no build settings, no
  pbxproj diff — seek is a read of an already-open file (§9) and new source files join the target
  through synchronized groups (D21). **Any apparent need for project-config change is a coordinator
  escalation, not a task** (D21 note).

## 2 · The seek seam (`Features/Feed/Domain` + the Data mechanism)

`MediaPlayback` (D25's handle) grows three members and one value type:

```swift
enum MediaSeekTolerance: Sendable { case preview, exact }

// additions to protocol MediaPlayback: AnyObject (@MainActor, unchanged isolation)
var duration: TimeInterval { get }                                  // known once startPlayback returns
var timeUpdates: AsyncStream<TimeInterval> { get }                  // elapsed ticks — §3
func seek(to seconds: TimeInterval, tolerance: MediaSeekTolerance)  // synchronous dispatch
```

Contract on `seek` (the S6/S7 split made structural):

- **`.preview` — the drag's live preview (S1, S5, S6): tolerant and coalesced.** The conformance
  issues a maximum-tolerance seek (`.positiveInfinity` both sides — fastest serve, approximate
  landing — exactly what S6's "approximate position while the drag lasts" asks for). Dispatch is
  **latest-wins and bounded**: at most one seek is in flight; while one is in flight, newer preview
  targets *replace* the pending one (never queued); when the in-flight seek completes, exactly one
  seek to the newest pending target is issued. A fast drag therefore cannot build a seek storm — the
  scheduler's entire pending state is one target (§8(5)).
- **`.exact` — every commit action (S7's release, S11's track click, S2/S9's key steps):
  zero-tolerance and immediate.** The conformance issues `.zero`/`.zero` at once, abandoning and
  superseding any in-flight or pending seek (AVPlayer semantics — fact 1). This is "frame-exact"
  concretely: the playhead lands on the requested time value and the displayed frame is the frame
  whose presentation interval contains it. **Honesty limits, recorded:** (a) a video has no position
  between frames — exactness is to the media's frame grid, and variable-frame-rate media has an
  irregular grid; (b) sub-frame rounding of the requested seconds value into the media timescale is
  possible (sub-visible — under one frame duration); (c) the cost is a decode from the preceding
  sync sample — long-GOP or heavy media can exceed the §8(2) landing budget, which is the accepted
  price of exactness (S6 exists precisely so fluidity never depends on it); (d) a pending `.exact`
  seek orders correctly against a following `resume()` — AVPlayer applies rate after the seek lands,
  so S8's resume-after-release starts at the landed frame with no completion plumbing across the
  seam.
- **Both** are synchronous dispatch (D25's synchronous bite: the call decides and issues in the same
  main-actor turn) and never change rate (S10). Seconds are clamped by the caller to `[0, duration]`
  (§5; S13) and defensively bounded again in the conformance when converting to `CMTime`.
- **Completion is mechanism, not contract:** no completion event, no callback (D8, R4). Everything
  above the seam reasons in targets, not completions.

**Why coalescing lives in the conformance (the placement question), mirroring D26's split:** the
in-flight/pending state is AVPlayer mechanism — it exists because seek completion is asynchronous
and self-superseding (fact 1). Pulling it up would force a per-seek completion signal across the
seam (a callback — forbidden — or an event flood on the main actor) and turn the pure view-model
policy into a state machine over mechanism callbacks. Keeping the *policy* above (which target,
when, and the S5–S8/S13/S14 rules) and the *dispatch* below gives each side one job: the view model
may call `seek(.preview)` at pointer rate and rely on the documented bound; the conformance owns
exactly one tiny pure state machine (`SeekScheduler`) whose dispatch decisions are unit-testable
without AVFoundation (§10.2). The rejected placements are in §12.

**View-model position arithmetic (why seeks never drift):** the view model keeps its own
`displayedPosition` (what the labels and thumb show) and computes every commit target *from it*
(±5 s steps, drag fractions), never by reading the player's possibly-stale position — two quick key
presses net exactly 10 s, and coalescing intermediate seeks cannot eat a step (§5).

**Converge amendment — `.preview` zero-tolerance (2026-10-13, coordinator-ratified, functional
review):** `.preview` now issues a **zero-tolerance** seek (`.zero`/`.zero`), not
`.positiveInfinity`. Functional review found maximum tolerance landed on the nearest sync sample
(keyframe), so a drag showed only a few keyframe-steppy pictures instead of the frame under the
scrubber — the stakeholder requires the frame under the scrubber. The `.preview`/`.exact` split and
the coalescing are unchanged: the distinction is now **dispatch policy** (latest-wins coalesced vs
immediate/superseding), not landing slack — both modes land the frame whose presentation interval
contains the requested point. Measured zero-tolerance preview cost on the 720p reference fixture:
warm-up 6.3 ms, 1.9 ms average over ten seeks → ~517 updates/s (see [evidence](evidence.md) §8),
so the coalescing already outpaces pointer input and `SeekScheduler` is unchanged — no bounded
refresh policy is needed.

## 3 · Time display source (elapsed/duration without a timer storm)

- **Duration** is a synchronous handle value (fact 2): known when `startPlayback` returns; the
  duration label and the fraction↔seconds mapping read it (a `duration <= 0` session rejects seek
  input — §5's defensive row).
- **Elapsed** flows through `timeUpdates: AsyncStream<TimeInterval>`, a **separate stream** from
  `events`, emitted from the periodic time observer at **100 ms cadence (10 Hz)** on AVFoundation's
  queue and marshaled to the main actor at the conformance boundary (D25's existing brace pattern;
  the stream finishes on `stop()` like `events`). Three coalescing layers bound the cost (RNF-02):
  (a) the observer fires at a fixed 10 Hz off-main, never per frame; (b) the stream is created with
  **`.bufferingNewest(1)`** — at most one tick ever waits for the consumer, a stalled main actor
  drops stale ticks instead of replaying a backlog; (c) the view model ignores ticks during a scrub
  drag (the drag target owns the display position, §5) and for **250 ms after any `.exact` seek**
  (a stale tick right after a commit would otherwise bounce the thumb backwards — testable
  suppression, cosmetic polish).
- **Why a second stream:** `events` carries rare correctness events (`.reachedEnd`, `.failed`) whose
  contract is ordered-and-never-dropped — applying `.bufferingNewest` to them would drop the loop
  trigger; sharing the unbounded buffer would let clock ticks back up behind a stalled consumer.
  Different reliability semantics, different streams (§12).

The bar's labels and thumb read the view model's `displayedPosition`/`duration` — `mm:ss` formatting
is a tiny pure helper evaluated only in the bar's two label views at 10 Hz while the bar is visible
(skill §2: no formatting of bulk data in `body`; this is two labels). When the bar is hidden the
ticks cost one O(1) observable write each — `@Observable` per-property scoping means no view
invalidates (skill §2).

## 4 · The overlay control bar (surface, visibility lifecycle, hit-test carve-out)

**Surface (S3, D27's ratified handoff).** `PlaybackControlBarView` is a SwiftUI strip pinned along
the bottom edge of the current video page, over the letterbox: progress track (thin line, full
width), scrubber thumb riding on it, elapsed label (leading), duration label (trailing) — exactly
the four named elements (spec non-goals exclude everything else). It renders **iff the page's bar
model is non-`nil`** (§7) — structurally absent on image pages (S4), unavailable items, non-current
pages, and mid-paging (S12). When hidden at rest it is fully inert (below), so the amendment to
E2-S3 S8 holds literally: chrome is demand-driven, and hidden — paused included — the display shows
only the frozen frame.

**Visibility (S3) — the event source is an AppKit tracking area, not a SwiftUI hover primitive.**
`PlayerSurfaceView` (the wrap of D27) installs an `NSTrackingArea` (`.mouseMoved`, `.activeInKeyWindow`,
`.inVisibleRect`) on the surface it already vends — AppKit-only plumbing on the Presentation side; the
Data display view stays interaction-free. The area covers the whole page (the surface is full-bleed;
the letterbox is inside it). Each `mouseMoved` reaches the view model through a coordinator-held
closure (refreshed in `updateNSView` — the wrap stays once-per-session) as
`noteMouseMoved(itemID:)`. Justification against the record (fact 4): taps are the only proven
SwiftUI input on this OS build; key-focus delivery failed three rounds and hover primitives are
unproven here; `NSTrackingArea.mouseMoved` maps 1:1 to S3's literal trigger ("when the mouse
moves") and carries no focus dependence — the exact failure axis of E2-S2 evidence §8. AppKit enters
as a wrap of a platform view (the D27/`NSImage` precedent), the policy stays in the `@MainActor` view
model (D8), and nothing is wired in `App/` (D10). A recorded fallback: if functional review shows
tracking-area `mouseMoved` gated on `NSWindow.acceptsMouseMovedEvents`, the surface enables it for
its own window (one AppKit line — ratified as a deviation if taken, the E2-S3-fallback pattern).

**Policy (view model, pure):**

- Mouse movement over the **settled current video page** → bar visible (`barVisible = true`) and the
  idle deadline set (S3). Movement anywhere else — neighbors, welcome, image pages — is not tracked
  and never shows a bar (S4, S12).
- **Idle timeout = 3 s** without mouse movement → hidden (S3's "short idle"; the value is this
  design's RNF-02 output — long enough to read the labels and reach back to the scrubber, short
  enough to restore chrome-free watching; §8(4) budgets its machinery). Hidden = `opacity(0)` with
  `allowsHitTesting(false)` — a hidden bar cannot swallow clicks, so the whole-page toggle (E2-S3
  S6) is intact at rest (the S11 carve-out applies only while the strip is actually shown).
- **A scrub drag suspends the idle policy entirely and the deadline restarts after release**
  (S3(a), spelled by the spec): `mouseDragged` is not `mouseMoved` (fact 3), so without the suspend
  the bar would hide mid-drag; release re-arms the 3 s countdown. Keyboard seek never shows the bar
  (S3(b), the spec's recorded reading).
- Paging gesture in flight → the bar model goes `nil` (S12's premise) and any visible bar hides at
  once; after settle, the next mouse movement re-shows it.

**The idle machinery is one cancellable `Task`, never a run-loop timer (§8(4)):** a generation-
guarded `Task.sleep` scheduler (re-armed on activity, throttled to ≤ 4 re-arms/s) calls the pure
policy with an injected `now` — no `Timer`, no `CADisplayLink`, no launch-time run-loop source;
the task exists only while a bar is visible. (skill §4's retain-cycle discipline: the task is owned
by the view model, cancelled on every exit path.)

**Hit-test split (S11's carve-out, mechanically):** the page's content is a `ZStack` of two sibling
layers — the **tap surface** (full-bleed display content with `.contentShape` + `.onTapGesture` →
`togglePlaybackFromTap(itemID:)` — E2-S3 S6 unchanged) and, above it, the **bar strip** with its own
`contentShape` and gestures. A click on the strip hit-tests the topmost sibling and never reaches
the tap surface; a click anywhere else on the page toggles exactly as E2-S3 S6/S7 specify. The
track (with the thumb's footprint) is one gesture surface: a **drag** past a 3 pt minimum distance
is the scrub (S1, S5–S8); a **tap** is the track-click seek (S11); the labels and strip padding are
consumed no-ops (the spec seeks only on the track — everything on the strip is excluded from the
toggle target). The strip's drag is a `highPriorityGesture` so a scrub never starts a paging
gesture — a vertical drag originating on the strip scrubs (fraction from x) instead of paging; the
strip is an interaction surface and its drags belong to it. Drag gestures track past the strip's
bounds once started (standard SwiftUI drag semantics).

## 5 · Seek policy in `FeedViewModel` (the one decision surface)

Pure state, no hardware, no AVFoundation (D8, D22's precedent — spec semantics live in the view
model). Inputs arrive as **fractions** (`0...1` along the track — geometry is a view concern); the
view model maps to seconds (`target = clamp(fraction × duration, 0, duration)`, S13), which also
doubles as input validation (no unbounded geometry ever reaches the player).

**Drag state machine (S5–S8):**

1. `beginScrub(itemID:)` — guard (matrix below); record `wasPlayingBeforeDrag = !isPlaybackPaused`;
   `handle.pause()` (S5 — **gesture-scoped**: `isPlaybackPaused` itself is untouched, so the user's
   intent is preserved for S8); suspend the idle policy; enter scrubbing.
2. `scrubChanged(itemID:fraction:)` — guard `isScrubbing`; `target = clamp(fraction × duration)`;
   `displayedPosition = target` (labels and thumb track the pointer exactly — S5);
   `handle.seek(to: target, .preview)` (S6 — tolerant, coalesced; the frame follows at the §8(1)
   cadence and may lag the pointer within the S6 budget).
3. `scrubEnded(itemID:fraction:)` — guard `isScrubbing`; `target = clamp(...)`;
   if `target == duration` → **end handover** (S14 — supersedes the plain restore, see below);
   else `handle.seek(to: target, .exact)` (S7) and restore per S8: `wasPlayingBeforeDrag` →
   `resume()`, else stay paused on the frozen frame at the new position. Restart the idle countdown
   (S3(a)). `isScrubbing = false`.

**Commit seeks (S2, S9–S11) never change rate (S10):** the track click
`seekFromTrackClick(itemID:fraction:)` and the keyboard steps map/clamp and issue `.exact`, leaving
play/pause exactly as found — a playing video continues from the new position, a paused one shows
the frozen frame there. Keyboard steps compute from `displayedPosition ± 5 s` (the drift-proof
arithmetic of §2), with auto-repeat = repeated steps (S9, paging parity — §6).

**End handover (S14):** "lands at the end" is **`target == duration` after clamping** — the clamp
assigns `duration` exactly, so the rule is exact, not epsilon-based. The handover enters the D26
loop contract with this story's play-state rules (the spec's S14 derivation): playing (or
`wasPlayingBeforeDrag`) → `handle.restart()` (D26's seek-zero-and-play); paused → `handle.seek(to:
0, .exact)` and stay paused on the frozen frame at the beginning. **The index is never touched** —
no auto-advance by construction (product R15). "Plays into the end" is E2-S3 S11's unchanged
`.reachedEnd` → `restart()` path. A seek to 0 is an ordinary clamped seek (no special case).

**The guard matrix (S12 + recorded derivations) — one unit-tested decision surface:**

| Input situation | Result | Source |
|---|---|---|
| Scrub / track click / ←→ on the settled current video | seek per S1/S2/S11 | S1, S2, S11 |
| Any seek input on a non-current page | no-op (consumed) | S12 |
| Any seek input while a paging gesture is in flight | no-op (consumed) | S12 |
| Current item is an image | no-op (consumed) — no bar exists (S4) | S4, S12 |
| Current item in the neutral unavailable state (incl. sticky playback failure) | no-op (consumed) — no bar exists | S12 (E2-S3 S14/S15 composed) |
| Keyboard seek while a scrub drag is in progress | no-op (consumed) | derived from S7 — the release lands on the scrubber's point regardless, so a mid-drag key seek could never survive |
| Session with `duration <= 0` | no-op (consumed) | defensive: S13's clamp needs a duration |
| Mouse movement over anything but the settled current video page | no bar shows | S3, S12 |
| No open feed (welcome) | keys pass through (route level) | D28 unchanged |

Guarded inputs do nothing quietly, never beep (D28's input-policy principle). S15 falls out of
E2-S3's fresh-session semantics — a seek position is not stored anywhere (§7, §9), so a revisit
restarts from the beginning by construction.

## 6 · Input delivery (keyboard routing + bar gestures)

**Keyboard (S2, S9) — the D28 App-owned key monitor is the single key path; only the frozen table
grows.** `FeedKeyCommand` gains two cases and two rows:

| Key (keyCode) | Open feed | No open feed | Auto-repeat | Modifiers ⌘/⌥/⌃ |
|---|---|---|---|---|
| ← (123) | `.seekBackward` | `.passThrough` | repeated steps (S9) | `.passThrough` |
| → (124) | `.seekForward` | `.passThrough` | repeated steps (S9) | `.passThrough` |
| ↓/↑ (125/126), space (49) | unchanged (D28) | unchanged | unchanged | unchanged |

`AppDelegate`'s monitor switch routes the two new cases to `seekBackwardByKeyboard()` /
`seekForwardByKeyboard()`. With an open feed, ←/→ are **always consumed** — routed to the guard
matrix, which no-ops quietly on ineligible states (S12) — because passing through would re-expose
them to the system's unhandled-key path (the D28 beep lesson). ⇧ alone does not modify (consistent
with ⇧↓ paging). This is a deliberate contract change: 123/124 previously passed through; the
frozen table's `nonRoutedArrowsPassThrough` test is replaced by the seek rows (§10.1). The table
stays pure and unit-tested as the frozen contract.

**Bar gestures (S1, S5–S8, S11)** are SwiftUI gestures on the strip (§4): `DragGesture(
minimumDistance: 3)` → begin/change/end at gesture phase transitions (a pure click never crosses
the threshold and stays a tap — so a click cannot pause, per S11/S10); tap on the track → the
click seek. Both are drilled per page as closures capturing the item id (the
`togglePlaybackFromTap(itemID:)` precedent of E2-S3 §6) into the §5 entry points. No App-level mouse
monitor (D28's rejected alternative stands — the view tree knows the page), no focus handling
anywhere.

## 7 · Composition & wiring

- **Current-item representation:** `FeedItemDisplayState.player(MediaPlayback)` is unchanged
  (E2-S3 §4). The bar is a Presentation overlay driven by a separate view-model value —
  `controlBarModel: PlaybackControlBarModel?` (`nonisolated struct`: `elapsed`, `duration`,
  `scrubFraction`, `isVisible`), **non-`nil` only for the settled current video's live player
  page** (S3, S4, S12's structural absence: images, unavailable, non-current, mid-gesture → `nil`).
- **`FeedItemView`:** each page's content becomes `ZStack { tap-surface (display content +
  `.contentShape` + tap) ; bar overlay (model non-nil only) }` — the strip carve-out of §4. The cell
  still never sees the item (S8's structural absence holds): it receives a presentation value and
  closures only.
- **`FeedView`:** drills per-page `PlaybackControlBarModel?` + an actions value (scrub begin/change/
  end, track click, mouse-moved — each capturing the item id) exactly as it drills the tap closure.
- **Composition root:** `AppDependencies`, `RootView`, `InstantPlayerApp` are **untouched** — no new
  seam, no new binding (seek rides the already-bound `MediaPlayback` handle, D25). `AppDelegate`
  gains only the two monitor-switch cases (§6). The stub handle grows the new members for wiring
  tests (house pattern).
- **Nothing carries across visits (S15):** no new state outlives the session — the drag machine,
  `displayedPosition`, and the clock all reset when `startPlayback` vends a fresh handle (E2-S3
  §3's lifecycle carries unchanged).

## 8 · Performance (RNF-02) — mandatory

Loaded skill: `swift-performance`. The performance-relevant surfaces are drag fluidity (the story's
headline, S17), the frame-exact landing, the clock cadence, and the idle/visibility machinery. Per-
story budgets (the E2-S1–E2-S3 measured-evidence precedent):

1. **Drag preview fluidity (S6, S17):** pointer movement → preview seek *issued* in the same
   main-actor turn (O(1) work; ≤ 16 ms — one display frame); dispatch bounded to ≤ 1 seek in flight
   (§2), steady-state preview rate bounded by tolerant-seek completion (typically 10–30/s); issued
   → **preview frame on screen ≤ 150 ms p95** for typical media (≤ 1080p clips) — the visible
   staleness bound of a fast drag. The labels/thumb track the pointer with zero lag by construction
   (§5). Heavy/long-GOP media can exceed the frame bound — accepted, it is exactly what S6's
   "approximate while the drag lasts" tolerates.
2. **Frame-exact landing and key steps (S7, S2):** release/keypress/click → `.exact` issued
   immediately (≤ 16 ms); issued → landed frame **≤ 300 ms p95 typical (≤ 500 ms atypical heavy
   media)**. The number is the zero-tolerance decode cost (§2 honesty limits); S8's resume applies
   at the landed frame with no added delay.
3. **Clock cadence (§3):** 10 Hz off-main ticks; ≤ 10 main-actor wake-ups/s, each one O(1) observable
   write; view invalidation scoped to the bar's two labels + thumb while visible (per-property
   `@Observable` reads — skill §2); zero consumer work while hidden beyond the O(1) store; ticks
   suppressed during drags and for 250 ms post-commit.
4. **Idle/visibility machinery — zero launch cost:** no `Timer`/`CADisplayLink`/run-loop sources
   anywhere; the idle policy is one cancellable generation-guarded `Task.sleep`, created only while
   a bar is visible, re-arms throttled to ≤ 4/s (pointer-rate `mouseMoved` is O(1) per event).
   Tracking areas exist only inside the current video's surface (created with the session). The
   route table adds two O(1) switch cases. `testLaunchPerformance` remains the guard.
5. **Bounded work under input storms (skill §3 discipline):** a fast drag cannot queue a seek storm —
   pending state is one target, in-flight seeks ≤ 1 (the `SeekScheduler` bound, unit-asserted);
   mouse-move storms cannot timer-storm (4). Memory is unchanged: no new caches, no per-seek
   allocations beyond AVFoundation's own; the existing one-live-player bound (E2-S3 §8(3)) carries.
6. **Main-thread discipline (skill §1):** `seek`/`pause`/`resume`/`restart` are synchronous O(1)
   `AVPlayer` calls on the `@MainActor` conformance (D25's synchronous bite carries — no executor
   hop on the commit path); all decode/asset work stays on AVFoundation's threads; nothing on the
   drag path touches disk (seek is a position read of the open player).
7. **Body cost (skill §2):** the bar is two labels + two shapes rendered only while visible; the
   scrub drag writes one observable fraction; no formatting of bulk data, no per-frame work.
8. **Measured evidence (skill §6):** conformance perf tests via XCTest `measure` (the E2-S3/D25
   run-loop-pumped pattern — a semaphore bridge would deadlock the `@MainActor` seam) for seek
   dispatch→land latency; unit tests asserting the coalescing bound and the clock cadence ceiling;
   gate JSON plus stakeholder functional review for perceptual fluidity; Instruments is the
   escalation (skill §6 — measurement, not vibes).

## 9 · Security (RNF-04) — mandatory

Loaded skill: `swift-security`. Seek is a **read** of the already-open security-scoped session (D19)
— the posture is inherited, not extended, and product R17 (S16) is the inherited no-regression
contract:

- **Read-only reads inside the open session (D19, S16):** the seek mechanism operates on the
  `AVPlayer` that is already playing the file of the currently open collection. No
  `start/stopAccessingSecurityScopedResource`, no session re-derivation, no new access path of any
  kind. **D21 audit expectation, verified against this design: zero project-config diff** — no
  entitlement, no Info.plist key, no build setting, no pbxproj change is needed or permitted; D19's
  four read-only keys stand unchanged (any apparent need is a coordinator escalation).
- **Nothing is ever written or persisted (S16 — R17):** playback/seek APIs only — **no
  `AVAssetExportSession`, no `AVAssetReader`/`AVAssetWriter`, no `write(to:)`**; no sidecar or
  derived file (no chapters, thumbnails, or previews on disk); **no playback- or seek-position
  persistence** — no `UserDefaults`, no files in `tmp`/`Caches`/`Application Support` (this
  contradicts nothing in v1: E2-S3 S13 established that no playback-state persistence exists, and
  S15/S16 keep it so — seeks are forgotten on revisit and on relaunch).
- **Untrusted input (skill §4):** this story's inputs are UI geometry and key codes — pure values
  clamped to `[0, duration]` before they reach the player (S13 doubles as boundary validation: no
  out-of-range position can ever be passed to AVFoundation; a `duration <= 0` session rejects seek
  input). Media bytes remain play-only (never executed — E2-S3 §9 carries: mislabeled/corrupt →
  the neutral unavailable state, D20).
- **Logging:** none planned. If diagnostics are added, `os.Logger` with `privacy: .private`, never
  paths or names of user media (skill §5).
- **Dependencies:** none added — AVFoundation/AppKit are system frameworks (skill §6). ATS/network
  untouched (no networking in v1, D9).
- **Privacy manifest / permissions:** no required-reason API is added (no `UserDefaults`, no
  file-timestamp APIs) and no TCC-prompting capability is touched — **no `PrivacyInfo.xcprivacy`
  change, no purpose strings**, consistent with E2-S1–E2-S3.

### 9.1 Sandbox/media-read review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements | Unchanged — D19's four read-only keys; no new grant (§9) |
| User files access pattern | Reads only inside the already-open scoped session, via the already-live player; no start/stop (D19) |
| Writes to disk | None, anywhere — playback/seek APIs only; no export/reader/writer, no sidecars, no disk caches (S16) |
| Persistence | None — no positions at rest (S15, S16); no `UserDefaults` in this story |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19) |
| Untrusted input | UI geometry + key codes clamped to `[0, duration]` before the player (S13); media bytes play-only (D20) |
| File names | Display-only; absent from logs and from any seek surface (D20) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason | No triggering API used (§9) |
| Dependencies | None added |

## 10 · Testing strategy

The UI-test mandate is settled in the spec and carried, not re-decided: launch flows are untouched
and the story's surface is unreachable without host-driven entry, so the converge run keeps the
**default gate scope, no `--uitests` obligation** ([docs/development.md](../../development.md) §3);
behavior is verified by the unit tests below plus stakeholder functional review (spec's honest
caveat).

### 10.1 Policy (unit, `InstantPlayerTests` — the spec's AC)

`FeedViewModelTests` with injected seam doubles (the E2-S3 §10.1 pattern: spy `MediaPlayerService` +
scripted handle) — no UI, no window, no AVFoundation:

| Case (requirements) | Expected |
|---|---|
| Drag machine (S5–S8) | begin records `wasPlayingBeforeDrag` + calls `pause()` without flipping `isPlaybackPaused`; change issues `.preview` to the mapped target and moves `displayedPosition`; end issues `.exact` to the final target; was-playing → `resume()`, was-paused → stays paused; idle countdown suspended during, re-armed after (S3(a)) |
| Tolerant/precision split (S6, S7) | every `scrubChanged` call is `.preview`; the release, track click, and key steps are `.exact` — asserted at the spy handle |
| Key steps (S2, S9, S10) | ±5 s from `displayedPosition` (two quick presses net 10 s — no drift); auto-repeat = repeated steps; rate untouched in both states |
| Track click (S11) | `.exact` to the mapped target; never `pause()`/`resume()`; the play/pause state observable-unchanged |
| Guard matrix (S12) | the §5 table as tests — non-current, mid-gesture, image, unavailable, mid-drag keyboard, `duration <= 0` all consumed no-ops (spy records nothing) |
| Clamping & end handover (S13, S14) | out-of-range targets clamp; `target == duration` → playing → `restart()`, paused → `seek(to: 0, .exact)` + stays paused; index never changes; click/step/drag-release all share the rule |
| Bar visibility policy (S3, S4) | mouse activity on the current video page shows + arms 3 s; idle hides; movement on neighbors/image pages shows nothing; keyboard seek never shows (S3(b)); hidden model keeps the toggle surface intact |
| Time display (§3) | ticks update `displayedPosition`; ignored during drag; suppressed 250 ms after `.exact`; stale ticks never bounce the thumb |
| Nothing carried (S15) | current-item change → new session → drag/position state reset (E2-S3 lifecycle tests extend) |
| `SeekScheduler` (S6, S7 — pure, Feed Data) | latest-wins pending; ≤ 1 in flight; exactly one dispatch after completion; `.exact` supersedes pending and dispatches immediately; pending dropped on stop |

`FeedKeyCommandTests` (the frozen table): 123 → `.seekBackward`, 124 → `.seekForward` with
auto-repeat parity (`arrowAutoRepeatStillPages`' sibling for seeks); **`nonRoutedArrowsPassThrough`
is replaced** (this story's contract change — §6); modifier/welcome/space/paging rows unchanged and
stay green.

### 10.2 Playback seam (unit, Feed Data — the real conformance)

Fixtures per E2-S3 §10.2's pattern (`MediaFixture` one-frame + short multi-frame MP4, throwaway temp
folders): `seek(.exact)` lands `currentTime` within one frame duration of the target (the §2
frame-exact contract pinned); `seek(.preview)` lands approximate and fast; a burst of N preview
seeks dispatches far fewer actual seeks (internal dispatch counter via `@testable`) and the final
target lands (S6's storm bound + S7's authority); `.exact` during a preview storm lands immediately;
`duration` correct; `timeUpdates` ticks at ≤ 12/s while playing and produces nothing while paused
(§3); `stop()` finishes both streams; a superseded session drops pending seeks (E2-S3 §10.2
patterns carry). Perf case: the §8(2) landing-latency `measure` (run-loop-pumped, nonisolated —
the D25 test-infrastructure pattern).

### 10.3 Functional review (stakeholder — the spec AC list)

`./scripts/app.sh run` covers the spec's AC checklist verbatim: bar appearance on mouse movement over
playing and paused video pages, idle hiding, never on image pages; drag → pause + fluid live frame;
release → resume-vs-frozen-frame per prior state at the frame-exact position; track click seeking
without toggling while elsewhere-on-page clicks still toggle; ←/→ ±5 s with hold-to-repeat in both
play states without state change; clamping at both ends; seek-to-end restarting the same video
without advancing; revisit restarting from the beginning; keyboard seek inert on non-current/mid-
gesture/image pages; and the media files byte-identical on disk afterwards (this is a UI story —
functional review is part of the done gate).

## 11 · ADR plan (continuing from D29)

Three ADRs, cut along independent review axes — seek mechanism, chrome surface, keyboard input —
recorded in [docs/decisions.md](../../decisions.md) by the implementing tasks (proposed titles +
kern; the coordinator appends them at converge):

- **D30 — Scrub & seek mechanism: tolerant coalesced preview seeks vs zero-tolerance commit seeks,
  scheduler in the conformance.** One `seek(to:tolerance:)` member on the `MediaPlayback` handle
  (`MediaSeekTolerance` `.preview`/`.exact`); the Data conformance owns a latest-wins seek scheduler
  (≤ 1 seek in flight, preview targets merge, `.exact` supersedes and dispatches immediately); the
  view model owns target arithmetic (fraction→seconds mapping, ±5 s from its own `displayedPosition`,
  clamping) and the drag/loop state policy (S5–S8, S13, S14). Frame-exact means the frame whose
  interval contains the requested time — sub-frame precision does not exist visually. → S1, S2,
  S5–S8, S11, S13, S14, S17.
- **D31 — Demand-driven transport chrome: overlay control bar with AppKit tracking-area mouse-move
  visibility and view-model idle policy.** The ratified surface (D27's §13 handoff) built exactly:
  four named elements; visibility via `NSTrackingArea.mouseMoved` on the wrapped player surface
  (Presentation-side plumbing; the Data display view stays interaction-free; hover primitives unproven
  on this OS build per E2-S2 evidence §8's precedent); idle-hide at 3 s via one cancellable
  generation-guarded `Task`, suspended during drags, re-armed on release (S3(a)); the hidden bar is
  fully inert so the whole-page toggle survives; the strip is excluded from the toggle target by
  sibling-layer hit testing. → S3, S4, S11, and the E2-S3 S8 amendment.
- **D32 — Keyboard seek on the feed-key router: ←/→ = ±5 s with paging's repeat parity.**
  `FeedKeyCommand` gains `.seekForward`/`.seekBackward` (124/123, auto-repeat = repeated steps per
  S9, always consumed with an open feed — quiet no-ops per D28) routed into the view-model step
  methods; no new delivery mechanism (the D28 App-owned monitor stays the single key path); the
  frozen table's contract change (123/124 no longer pass through) is the recorded consequence.
  → S2, S9, S10.

## 12 · Alternatives considered

- **Coalescing in the view model** — rejected: seek completion is AVPlayer mechanism; above the seam
  it would need a per-seek completion signal (callbacks forbidden — D8/R4) or an event flood, and
  would smear mechanism state into pure policy. **Coalescing by trusting `AVPlayer`'s self-
  superseding seeks** — rejected: a pointer-rate drag still issues unbounded seek *calls*, each
  interrupting the decode pipeline — previews starve and CPU churns; the pending state must be one
  merged target. **Coalescing as its own Domain seam** — rejected: one consumer, conformance-internal
  mechanism (the seam-placement rule, architecture §4).
- **Two intent-named seek members (`previewSeek`/`seekExactly`)** — rejected: one `seek(to:tolerance:)`
  keeps the handle surface flat and names the contract modes as values (a third mode never grows the
  protocol). **Seek completion event (`.seekFinished`)** — rejected: nothing above the seam reasons
  in completions (§2); AVPlayer orders rate-after-seek for us. **A paused-aware `restart()` overload**
  for S14 — rejected: D26's member semantics stay frozen; composing `seek(to: 0, .exact)` keeps the
  loop policy in the view model and `restart()` honest.
- **Clock through the existing `events` stream** — rejected twice: unbounded buffering replays stale
  ticks after a main-actor stall (no coalescing), and `.bufferingNewest(1)` would drop `.reachedEnd`/
  `.failed` correctness events (§3). **`TimelineView(.periodic)` / `Timer` / `CADisplayLink` driving
  the labels** — rejected: per-frame or run-loop-scheduled `body` work and formatting churn
  (skill §2), plus always-on timers for a bar that is usually hidden. **Polling `handle.currentTime`
  from `body`** — rejected: dumb-binder violation (D8) and unbounded reads. **1 Hz clock** —
  rejected: visibly steppy thumb; 10 Hz costs nothing (§8(3)).
- **SwiftUI `.onHover` / `.onContinuousHover` for the bar trigger** — rejected: hover-phase
  primitives are unproven on this OS build (the recorded input history is three failed SwiftUI
  delivery rounds — E2-S2 evidence §8; the only shipped hover-adjacent mechanism is
  `dropDestination`'s `isTargeted`), `.onHover` reports enter/exit rather than S3's "mouse moves",
  and a spec contract must not rest on an unproven primitive when `NSTrackingArea.mouseMoved` is the
  deterministic 1:1 mechanism (fact 4). **App-level `NSEvent` mouse monitor** — rejected on D28's
  click rationale (the view tree knows which page; a global monitor fights the scroll surface) and
  app-wide `mouseMoved` floods. **Tracking area on the Data display view** — rejected: keeps
  `makeDisplayView()` interaction-free (D27) and policy plumbing out of Data. **`Timer.publish`/
  `DispatchQueue.asyncAfter` for the idle hide** — rejected: run-loop sources and non-async spelling
  (D8/R4) plus retain-cycle surface (skill §4); **`.task(id:)` in the view** — rejected: policy in
  views violates D8's dumb-binder rule.
- **`.seek(delta:)` as one payload route case** — rejected: the frozen table is discrete-case switch
  style (D28); two cases keep the table mechanical and test-pinnable. **Repeat-ignored ←/→ like
  space** — rejected: S9 explicitly demands paging's repeat parity (steps repeat; space's flap is a
  different phenomenon). **Tolerant keyboard steps** — rejected: S2's "5 seconds" is a precise
  contract and keyboard seek is a fine-tuning tool (US2); accumulated tolerance drift would defeat
  it. **Passing ←/→ through on ineligible states** — rejected: the unhandled-key beep (D28's lesson)
  and S12's silent-no-op rule.
- **Thumb-only drag + separate track tap** — rejected: dragging along the track is the expected
  scrub behavior (S11 already makes the track interactive); one gesture surface with
  `minimumDistance` separates tap from drag mechanically. **Thumb-follows-only-the-player position**
  — rejected: stale-tick lag between label and pointer reads as a bug; the pointer is the truth
  during a drag (S5). **"At the end" as a within-one-frame epsilon** — rejected: after clamping,
  `target == duration` is exact and needs no tolerance tuning (S13/S14). **Seeking the mid-drag
  keyboard input through** — rejected: derived from S7, the release lands on the scrubber's point
  regardless, so it could never survive (§5 matrix).
- **Bar always composed with opacity toggling from the view** — rejected: S4/S12 demand structural
  absence (an always-composed bar risks stray hits and invalidation); the `nil` model expresses both
  absence and demand-hiding distinctly. **Keeping the page-root tap with a gesture-exclusion
  modifier** — rejected: SwiftUI gesture exclusion between parent and child is modifier-order
  fragile; sibling-layer hit testing makes S11 structural (§4).

## 13 · Consequences & required follow-ups

- **`docs/architecture.md` updates are required in this story** (its §1 rule) — **not committed with
  this design: writing that file is outside this author's permissions (reported to the coordinator
  rather than bypassed, the E2-S2/E2-S3 §13 precedent).** The exact updates, to be applied by an
  agent with write access in this story's task phase:
  1. **§3 tree:** re-annotate `Features/Feed/Domain/MediaPlayback.swift` (gains `duration`,
     `timeUpdates`, `seek(to:tolerance:)` + `MediaSeekTolerance`), `Features/Feed/Data/AVMediaPlayback.swift`
     (seek scheduler + clock bridge), `Features/Feed/Presentation/FeedViewModel.swift` (scrub/seek/
     idle policy), `FeedItemView.swift` (tap-surface + bar overlay split), `PlayerSurfaceView.swift`
     (tracking area + mouse-move closure), `App/FeedKeyCommand.swift` (seek rows), `App/AppDelegate.swift`
     (seek cases); add `Features/Feed/Data/SeekScheduler.swift` and
     `Features/Feed/Presentation/PlaybackControlBarView.swift`.
  2. **§4 check (3):** explicitly **no wording change** — this story moves no new kind across the
     seam (`TimeInterval`/`Double` is Foundation; no new platform views — the tracking area rides the
     already-ratified wrapped view). Record that verdict so the section does not look overlooked.
  3. **§8 evolution note:** no new actor — D8's trigger is unmet again (the seek scheduler and clock
     bridge are conformance-internal state on the `@MainActor` conformance; the periodic observer
     marshals at the boundary like the existing event bridges); the `@MainActor`-seam pattern of D25
     carries unchanged.
- **D21 audit expectation:** zero project-config diff — no pbxproj, entitlements, Info.plist, or
  build-setting change anywhere in this story's commits (§9's verification).
- **E3 handoff:** E3-S2 (speed) grows rate members on the same handle and may extend the bar strip;
  E3-S3 (volume) grows volume/mute members and lands v1's first persisted preference. The bar strip
  is the ratified home for future transport chrome, each addition its own spec decision (this
  story's four elements are the whole contract — spec non-goals). The keyboard table has room for
  more rows (D28's frozen-contract pattern). Double-click remains meaningless (spec non-goal).
- **Accepted sharp edges, recorded honestly:** the preview frame can trail the scrubber by up to the
  §8(1) bound while the labels track the pointer exactly (S6's tolerance is the contract); strip
  clicks outside the track are silent consumed no-ops (S11's carve-out is the whole strip, the
  spec's track-click is the track alone); a drag originating on the strip scrubs even when the
  pointer moves vertically (the strip owns its drags — §4); the bar shows on mouse *movement*, so
  entering the page without moving the mouse shows nothing until the first move (S3's literal
  trigger); zero-tolerance landings on very long-GOP media can exceed the §8(2) budget (§2's honesty
  limits — measured evidence or a ratified deviation if review disagrees); E2-S3's zero-net-gesture
  restart sharp edge carries unchanged.
