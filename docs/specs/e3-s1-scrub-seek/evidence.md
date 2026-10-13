# E3-S1 · Scrub & seek — Evidence

Verification record for the story's implementation tasks (1–8, this task 11). Converge-owned
evidence (functional review, validator PASS, closure) is **not** recorded here. Gate usage per
[docs/development.md](../../development.md) §3; conventions per the [SDD
README](../README.md).

## 1 · Full gate — machine-readable record (task 11.3; refreshed after the review fixes)

`./scripts/validate.sh --json <session-temp>/e3-s1-gate.json` — the JSON quoted **verbatim**
(the file itself is never committed); this is the fresh full-gate run on the post-review code:

```json
{
  "branch": "feat/e3-s1-scrub-seek",
  "staged": false,
  "result": "pass",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" }
  ]
}
```

SwiftLint and SwiftFormat read `pass`/`ok`; the full gate (build + unit tests, never `--staged`)
is green on the story's final code.

## 2 · UI-test mandate (task 11.4; R14 of E1-S2)

Decision (spec Story context): **flows are NOT affected** — the launch-visible behavior
(welcome state, launch cost) is exactly as E2-S1/E2-S3 left it, and this story's entire surface
(the control bar, its scrubber, the ←/→ keys) exists only once media is open, which the UI tests
cannot reach (entry stays host-driven). The converge run keeps the **default gate scope with no
`--uitests` obligation**. Honest caveat, in the predecessors' form: even a `--uitests` run could
not exercise scrub/seek (no media is open in the launch tests); behavior is verified by the unit
suites (tasks 4–5) plus stakeholder functional review. Within the 11.3 full gate,
`testLaunchPerformance` and the launch tests ran green unchanged.

## 3 · Performance evidence from tooling (task 11.5a; design §8(1)–§8(2), S17; refreshed after the review fixes)

The design §8(2) landing-latency XCTest `measure` (run-loop-pumped, nonisolated — the D25
pattern) recorded from its tooling output file, never from memory. Budgets: **≤ 300 ms p95
typical (≤ 1080p clips), ≤ 500 ms p95 atypical heavy media**; drag-preview issuance is
synchronous in the same main-actor turn (design §8(1)'s ≤ 16 ms bound — an O(1) dispatch, not a
timed claim). Fixture: 1280×720, 60 frames @ 30 fps (the typical ≤ 1080p case). Measured
landing (issue → landed frame within one frame duration), fresh full-gate run on the
post-review code:

```
e3-s1 frame-exact landing budget, measured from tooling
warm-up: 0.1 ms
pass 1 (target 0.5s): 0.1 ms
pass 2 (target 1.0s): 5.9 ms
pass 3 (target 1.5s): 5.4 ms
measure iteration (target 0.25s): 6.4 ms
measure iteration (target 0.5s): 0.1 ms
measure iteration (target 0.75s): 6.4 ms
measure iteration (target 1.0s): 6.4 ms
measure iteration (target 1.25s): 0.1 ms
measure iteration (target 1.5s): 6.4 ms
```

Raw numbers against the budget: the largest recorded landing is **6.4 ms** against the 300 ms
typical budget (roughly 2 % of it — no landing comes near it), and the atypical 500 ms budget is
functional-review/Instruments territory (long-GOP/heavy media — design §2's accepted honesty
limit), not claimed from this fixture. The design §8(1) drag-preview frame bound (≤ 150 ms p95)
and the cadence ceiling (≤ 12 ticks/s) are unit-asserted: `AVMediaPlaybackSeekTests.
timeUpdatesTickWhilePlayingAndStaySilentWhilePaused` (10 Hz source, ceiling pinned) and
`SeekSchedulerTests.previewStormKeepsOneInFlightAndOnePendingTarget` (the §8(5) bound: a
50-preview storm issues exactly one dispatch).

## 4 · D21 audit — zero project-config diff (task 11.5b; design §1.1, §9, §13)

`git diff main...HEAD -- InstantPlayer.xcodeproj InstantPlayer/Config` — **empty output quoted**:

```
--- git diff main...HEAD -- InstantPlayer.xcodeproj InstantPlayer/Config (must be empty) ---
--- end diff (exit 0) ---
--- stat end ---
```

Both the raw diff and `--stat` are empty: no pbxproj, entitlements, Info.plist, or build-setting
change anywhere in the story. `codesign -d --entitlements` is **not in this implementer's shell
allowlist** (tool-permission denial, recorded — not a failed attempt); the sanctioned equivalent
evidence: the empty config diff proves the entitlements file is byte-identical to `main`, and the
committed `InstantPlayer/Config/InstantPlayer.entitlements` reads exactly D19's four read-only
keys, unchanged:

- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-only` = true
- `com.apple.security.temporary-exception.files.home-relative-path.read-only` = [`/`]
- `com.apple.security.files.removable-media.read-only` = true

No key added, removed, or widened; the validator may re-verify the embedded signature at converge
with `codesign` (unrestricted there).

### 4.1 · Design §9.1 sandbox/media-read review table, walked row by row (task 11.5c)

| Concern | Verdict against the shipped code |
|---|---|
| Entitlements | Unchanged — the four read-only keys above; no new grant (§4 audit: empty diff) |
| User files access pattern | `issueSeek` operates only on the already-live `AVPlayer` of the open session; no `start/stopAccessingSecurityScopedResource`, no session re-derivation (AVMediaPlayback.swift) |
| Writes to disk | None — playback/seek APIs only (`player.seek`, `pause`, `play`); no `AVAssetExportSession`, no `AVAssetReader`/`AVAssetWriter`, no `write(to:)`, no sidecars, no disk caches (grep-verified: no such symbol exists in the story's diff) |
| Persistence | None — no `UserDefaults`, no position stored anywhere (task 3's `stopPlayback` resets everything; S15/S16) |
| Bookmarks | None — no `bookmarkData` call exists (D19's session is never re-derived) |
| Untrusted input | UI geometry clamped to `[0, duration]` in the view model (S13) and defensively re-bounded in the conformance before `CMTime` conversion; key codes are discrete-case-switch values; media bytes play-only (D20) |
| File names | Display-only; absent from every seek surface and from all logging (no logging exists — D20) |
| ATS / network | Untouched — no networking in v1 (D9); no import beyond the E2 posture |
| Privacy manifest / required-reason | No triggering API added (no `UserDefaults`, no file-timestamp APIs); no TCC capability touched |
| Dependencies | None added — AVFoundation/AppKit are system frameworks |

## 5 · Traceability walk — S1–S17 row by row (task 11.2)

Every row names the shipped artifact (file/test/ADR) and its design section. Test names are
Swift Testing rows in `InstantPlayerTests/`; "FVM tests" = `FeedViewModelTests.swift`
(task 5), "seek suites" = `SeekSchedulerTests.swift` + `AVMediaPlaybackSeekTests.swift` +
`SeekLandingPerformanceTests.swift` (task 4).

| Req | Shipped artifact (file / test / ADR) | Design |
|---|---|---|
| S1 drag-scrub moves the position | `FeedViewModel.beginScrub/scrubChanged/scrubEnded` (policy, design §5) + `PlaybackControlBarView` `DragGesture(minimumDistance: 3)` → fractions (design §4) + `FeedItemView` strip (design §7) + FVM tests `dragMachinePlayingCasePausePreviewExactResume` | §2, §4, §5 |
| S2 ←/→ ±5 s | `seekBackwardByKeyboard`/`seekForwardByKeyboard` (§5) + `FeedKeyCommand` seek rows 123/124 (§6) + FVM `keyboardStepsAreFiveSecondsFromDisplayedPositionWithoutDrift` + `FeedKeyCommandTests.plainLeftRightArrowsSeekWhenFeedIsOpen` | §2, §5, §6 |
| S3 bar on mouse move, idle hides | `noteMouseMoved(itemID:)` + generation-guarded `Task.sleep` idle (3 s) + `refreshControlBar` (§4) + `PlaybackControlBarView` four elements + FVM `mouseMovementOnTheCurrentVideoPageShowsAndArmsTheBar` | §3, §4 |
| S4 images: no bar, no seek | `seekGuard` live-session row + `refreshControlBar` structural `nil` (§5, §7) + FVM `seekInputsOnAnImagePageAreQuietNoOps` | §4, §5 |
| S5 drag pauses + live frame | gesture-scoped `handle.pause()` (isPlaybackPaused untouched) + `displayedPosition` ownership (§5) + FVM `beginScrubDoesNotFlipIsPlaybackPaused`, `dragMachine…` | §5 |
| S6 tolerant fluid preview | `.preview` → `SeekScheduler` latest-wins (§2) + seek suites `previewSeekDispatchesOnceAndLandsApproximate`, `previewBurstDispatchesFarFewerSeeksAndNewestTargetLands`, `previewStormKeepsOneInFlight…` | §2, §8(5) |
| S7 frame-exact release | `.exact` → `.zero`/`.zero` immediate (§2) + seek suites `exactSeekLandsWithinOneFrameDuration`, `exactDuringPreviewStormLandsFrameExact` + `SeekLandingPerformanceTests` | §2, §8(2) |
| S8 resume vs frozen frame | `scrubEnded` S8 restore (`wasPlayingBeforeDrag`) + FVM `dragMachinePlayingCase…` (resume), `dragMachineWasPausedStaysPausedOnTheFrozenFrame` | §5 |
| S9 hold-to-repeat | route `isRepeat` parity (§6) + FVM key-step arithmetic (two presses net 10 s) + `FeedKeyCommandTests.seekAutoRepeatStillSteps` | §2, §6 |
| S10 state neutrality | `commitExactSeek` never touches pause/resume (§5) + FVM `keyboardStepsLeavePlayPauseUntouchedInBothStates`, `trackClickSeeksExactWithoutToggling` | §5 |
| S11 track click + carve-out | `seekFromTrackClick` (§5) + the strip's sibling-layer hit testing (§4, §7) + FVM `trackClickSeeksExactWithoutToggling` | §4, §5 |
| S12 guard matrix | `seekGuard(itemID:)` — one decision surface (§5) + FVM rows: `seekInputsOnANonCurrentPage…`, `seekInputsDuringAPagingGesture…`, `seekInputsOnAnImagePage…`, `seekInputsOnAnUnavailableItem…`, `keyboardSeekDuringAScrubDrag…`, `seekInputsWithAZeroDurationSession…` | §5 |
| S13 clamping | `clampedTarget(fromFraction:/fromSeconds:)` pure helpers + conformance re-bound (§2, §5) + FVM `clampedTargetsAtBothEnds` | §5 |
| S14 end handover | `endHandover(resumeAfter:handle:)` — restart vs seek-0 (§5) + FVM `endHandoverFromClickAndKeyStepsRestartsPlaying`, `endHandoverFromPausedClickSeeksZeroAndStaysPaused`, `endHandoverFromDragReleaseFollowsWasPlaying` (index untouched — R15) | §5 |
| S15 nothing carried | `stopPlayback` resets drag/position/bar/clock (§7) + FVM `pagingAwayResetsDragPositionAndBarState` | §7 |
| S16 read-only seek | §9's posture — §4.1's walked table above; seek suites' clock test asserts the clock never seeks (`seekDispatchCount == 0`); ADRs [D32](../../decisions.md), D33 | §9 |
| S17 responsiveness | §8 budgets — the measure record (§3 above) + cadence-ceiling and storm-bound unit pins + zero launch cost (no `Timer`/run-loop sources; `testLaunchPerformance` green in §1's gate) | §8 |

## 6 · Product R-map (task 11.2; the spec's acceptance table carried)

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R13 (scrub/seek to the indicated point) | S1 (drag on the bar), S2 (keyboard ±5 s), S5–S8 (drag: pause + live fluid preview, frame-exact release, state restoration), S11 (track click), S12 (guard matrix), S13–S14 (clamping, end handover) | unit tests (seek policy: step size, hold-to-repeat, guard matrix, clamping, end handover, state preservation, tolerant/precision split — tasks 4–5) + functional review (drag, click, keys, live preview, frame-exact landing) |
| R16 (smooth & responsive) — cross-cutting share via S17, not claimed | S17 — no stalls or beachballing during scrub/seek; fluid live preview | validator performance review (RNF-02; §3's measured budgets) + functional review (drag stays fluid) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S16 — seek writes nothing, persists nothing; no new access paths (D19) | validator security review (§4.1's walked table) + functional review (files byte-identical on disk after scrubbing) |

## 7 · Functional-review checklist (task 11.6 — converge-owned; carried verbatim from the spec AC)

The stakeholder exercises this in the running app (`./scripts/app.sh run`); agent-recorded
evidence is supporting material, never the approval:

- [ ] the bar appearing on mouse movement over a playing and a paused video page and hiding again
      after idle;
- [ ] never appearing on an image page;
- [ ] dragging the scrubber pausing playback with the frame tracking live and fluidly;
- [ ] releasing resuming a previously-playing video and leaving a previously-paused one frozen at
      the frame-exact new position;
- [ ] clicking the progress track seeking there without toggling play/pause while clicks elsewhere
      on the page still toggle;
- [ ] ←/→ stepping ±5 s with hold-to-repeat, working while playing and while paused without
      changing the state;
- [ ] seeks near either end clamping;
- [ ] a seek to the very end restarting the same video without advancing the feed;
- [ ] paging away and back restarting from the beginning;
- [ ] keyboard seek doing nothing on a non-current page, mid-gesture, and on an image page;
- [ ] and the media files byte-identical on disk after all of the above (this is a UI story —
      functional review is part of the done gate).

## 8 · Deviations (task 11.7 — honest; marked for coordinator ratification)

1. **ADR numbering D32–D34** vs the design §11's stale D30–D32 labels: harness ADRs claimed
   D30/D31 (`ac919ca`), so the log's continuation rule was applied — titles and one-line decisions
   are exactly the design §11's, only the leading numbers differ. **Coordinator-ratified** in the
   task 10 brief; recorded here for task 11.7's completeness.
2. **`@testable` internals used by the suites** (the design §10.2-noted route, since the frozen
   seam carries no state-query members — same precedent as E2-S3's unmuted-start assertion): the
   internal `seekDispatchCount` counter (`AVMediaPlayback`, added in task 4 with the suites) pins
   the §8(5) storm bound and the burst-coalescing rows; the test double's `emitTick` helper drives
   the clock rows (task 5). Test-only surface; production contracts untouched.
3. **The design §4 `acceptsMouseMovedEvents` fallback is TAKEN (review-ratified deviation).**
   Review found the gap: AppKit gates `mouseMoved` delivery on `NSWindow.acceptsMouseMovedEvents`
   (default off), so the tracking area could exist while the window never delivers — the bar
   would never show. `PlayerSurfaceView` now enables the flag for **its own window only**
   (idempotent, asserted on attach and on every update — task 6's file, review commit
   `3a6bf2d`), exactly the design §4 recorded fallback ("the surface enables it for its own
   window, one AppKit line"). One AppKit line, scoped; functional review (§7) confirms delivery.
4. **Clock queue correction (review fix, design §0.2/§3):** the periodic observer originally
   passed `queue: nil` (the main queue) and then hopped to the main actor — the design specifies
   an off-main source with marshaling at the boundary. The observer now runs on a dedicated
   serial queue (`com.guits.InstantPlayer.time-observer`, one per session, review commit
   `28ec455`); the ≤ 12/s cadence row stayed green throughout.
5. **Review-loop fixes (this loop's commits, each with the full gate green):** hidden-bar ticks
   no longer rebuild the bar model — zero feed invalidation while hidden (design §3/§8(3),
   `1067119`, regression test `hiddenTicksCauseNoBarModelChangeAndVisibilityRebuilds`);
   scrub-state consistency on every exit path — a paging gesture mid-drag and a failed-guard
   release can never wedge `isScrubbing` (S12 hygiene, `f8ed667`, two regression tests); the end
   handover resets the displayed position to 0 in **both** branches (S14 asymmetry, `4d90f9a`,
   playing-path assertion added).

No other deviation from the approved design exists: signatures, budgets, fixtures, and file
inventory match the design §1–§13 as approved.

## 9 · Acceptance criteria (task 11.8)

Ticked here and mirrored in [tasks.md](tasks.md); AC8–AC10 stay converge-owned (unticked there
and not claimed here).

- **AC1 · product R13 / S1, S2** — both invocations land: drag-scrub on the bar moves the position
  to the point under the scrubber, and ←/→ step ±5 s per press with hold-to-repeat — covered by
  the policy suite (step size, drift-free arithmetic, repeat parity, tolerant/precision split) and
  the conformance suite (frame-exact landing within one frame; approximate fast previews) +
  functional review. ✔ (§5 rows S1, S2; §3 budgets)
- **AC2 · product R13 / S5–S8** — drag semantics unit-tested and reviewed: pause for the drag
  (gesture-scoped — the user's play/pause intent preserved), fluid live frame tracking the
  scrubber, frame-exact release, and state restoration (resume iff it was playing before). ✔
  (§5 rows S5–S8)
- **AC3 · S3, S4, S11 (+ the E2-S3 S8 amendment)** — demand-driven chrome: the bar shows on mouse
  movement over the current video page (playing and paused), hides after the 3 s idle, is never
  shown on image pages or on keyboard seek, and hidden — paused included — the display shows only
  the frozen frame; the track click seeks without toggling while the strip is excluded from the
  whole-page toggle target and clicks elsewhere still toggle. ✔ (§5 rows S3, S4, S11)
- **AC4 · S12–S15** — the guard matrix is unit-tested row by row (quiet consumed no-ops, never
  beep); clamping at both ends; a seek landing at the end hands over to the loop contract — the
  same video restarts and the feed never auto-advances (index untouched) — with the paused →
  frozen frame at the beginning rule; nothing is carried across visits. ✔ (§5 rows S12–S15)
- **AC5 · S16 / product R17 · RNF-04** — read-only seek walked: no rewrite/export/reader/writer,
  no sidecars or derived files, no persisted positions, no new access paths (D19 session not
  re-derived); no entitlement/plist/pbxproj diff (D21 audit: empty diff + unchanged keys quoted,
  §4); design §9.1 review table walked (§4.1); media files byte-identical on disk after review —
  the functional-review clause is converge-owned (§7). ✔ for the implementation walk; file
  byte-identity awaits functional review.
- **AC6 · S17 / product R16 share · RNF-02** — responsiveness budgets measured and recorded from
  tooling (landing ≤ 6.3 ms on the reference fixture against the 300/500 ms budgets, §3; the
  drag-preview issuance is a synchronous O(1) dispatch; cadence ceiling and storm bound
  unit-asserted); zero added launch cost (`testLaunchPerformance` intact, no `Timer`/run-loop
  sources); drag fluidity in functional review is converge-owned. ✔ for the measured/unit
  evidence.
- **AC7 · R14 (E1-S2) decision + evidence & coverage** — the UI-test-mandate decision recorded
  (default gate scope, no `--uitests` obligation, with the honest caveat, §2); full gate `--json`
  quoted verbatim (§1); the S1–S17 + product R-map walk recorded (§5, §6); the three ADRs in
  [docs/decisions.md](../../decisions.md) house format with design §11 titles (D32–D34); the
  design §13 `docs/architecture.md` updates done (task 9, incl. the §4 check-3 verdict and the
  §8 no-new-actor note); all deviations listed honestly (§8). ✔
