# E3-S2 · Playback speed — Evidence

Verification record for the story's implementation tasks (1–7, this task 10). Converge-owned
evidence (functional review, validator PASS, closure) is **not** recorded here. Gate usage per
[docs/development.md](../../development.md) §3; conventions per the [SDD README](../README.md).

## 1 · Full gate — machine-readable record (task 10.3)

`./scripts/validate.sh --json <session-temp>/e3-s2-gate.json` — the JSON quoted **verbatim**
(the file itself is never committed); this is the fresh full-gate run (build + unit tests, never
`--staged`) on the story's final code:

```json
{
  "branch": "feat/e3-s2-playback-speed",
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

SwiftLint and SwiftFormat read `pass`/`ok`; the full gate is green on the story's final code.
(One earlier evidence run of the same gate failed on
`MediaPreviewPerformanceTests.testDisplayBudgetThroughPreviewSeam` — E2-S2's preview budget, a
load-sensitive p95-over-20 catch in an untouched file; see §8 item 3. It passed on the re-run
quoted above and in every other gate run of this story.)

## 2 · UI-test mandate (task 10.4; R14 of E1-S2)

Decision (spec Story context): **flows are NOT affected** — the launch-visible behavior (welcome
state, launch cost) is exactly as E2-S1/E2-S3 left it, and this story's entire surface (the bar's
speed control and badge, the `[`/`]` keys) exists only once media is open, which the UI tests
cannot reach (entry stays host-driven). The converge run keeps the **default gate scope with no
`--uitests` obligation**. Honest caveat, in the predecessors' form: even a `--uitests` run could
not exercise speed selection (no media is open in the launch tests); behavior is verified by the
unit suites (tasks 4 and 7) plus stakeholder functional review.

Tooling precision on the "launch tests green" clause: `testLaunchPerformance` lives in the
`InstantPlayerUITests` target, which the default gate's test step (`-only-testing:
InstantPlayerTests`) does not run; the launch tests' last recorded green runs are E2-S1/E2-S3's
(e.g. E2-S3 evidence §2: `testLaunchPerformance() passed … (13.078 seconds)`). What this story's
gate does establish: the launch path is untouched by the story's diff — the only `App/` changes
are the key-router files (`git diff main...HEAD --stat -- InstantPlayer/App/`:
`AppDelegate.swift | 12 ++`, `FeedKeyCommand.swift | 30 ++` — the two monitor-switch cases and
route rows, which no launch flow reaches; `WelcomeView`/`InstantPlayerApp`/`RootView`/
`AppDependencies` have no diff at all, per the composition rule), and the full gate of §1 is
green. The validator may re-run `--uitests` at converge if it wants a fresh launch-test record.

## 3 · Performance evidence from tooling (task 10.5a; design §8(1), §8(2), §8(3); S18, S12)

The two §8 speed-path XCTest `measure` cases (run-loop-pumped, nonisolated — the D25 pattern;
task 4.5) recorded from their tooling output files, never from memory. Budgets: **≤ 16 ms** per
input (one display frame — the command is decided and the `AVPlayer.rate` write bites in the same
main-actor turn). Quoted from the same recorded full-gate run as §1:

```
e3-s2 §8(1) rate-change command → rate-write budget, measured from tooling
warm-up: 0.06 ms
pass 1 (2.0×): 0.03 ms
pass 2 (0.5×): 0.06 ms
pass 3 (1.0×): 0.04 ms
measure iteration (1.5×): 0.02 ms
measure iteration (1.0×): 0.03 ms
measure iteration (1.5×): 0.01 ms
measure iteration (1.0×): 0.01 ms
measure iteration (1.5×): 0.01 ms
measure iteration (1.0×): 0.01 ms
```

```
e3-s2 §8(3) keyboard step-path budget, measured from tooling
step warm-up: 0.11 ms
step pass 1 (up: true): 0.05 ms
step pass 2 (up: true): 0.04 ms
step pass 3 (up: false): 0.04 ms
step pass 4 (up: false): 0.03 ms
step measure iteration (up: true): 0.05 ms
step measure iteration (up: false): 0.02 ms
step measure iteration (up: true): 0.05 ms
step measure iteration (up: false): 0.02 ms
step measure iteration (up: true): 0.03 ms
step measure iteration (up: false): 0.08 ms
```

Raw numbers against the budget — with the tooling's honesty limit stated: each quoted block is
**one recorded run**; the scratch files are truncated and rewritten by every full-gate run (each
perf test resets its file at test start and appends per measurement), so per-line values vary run
to run (≈0.01–0.14 ms observed across this story's runs) and are not independently reproducible.
The stable claim is budget compliance: the largest value recorded in any run of this story is
**0.14 ms** (a warm-up; the largest budgeted pass/iteration is 0.08 ms) against the 16 ms budget —
roughly 1 % of it. Rapid stepping builds no backlog by construction (each step is one O(1) ladder
move + one O(1) observable write + one synchronous rate write; the clamp makes end-of-ladder
repeats idempotent — unit-pinned by `FeedViewModelTests.keyboardStepsRepeatAndClampIdempotently`).

**§8(2) zero-added-start-wait (S12):** verified by the *existing* E2-S3 start-latency measure not
regressing — the speed is one argument on the existing `playImmediately(atRate:)` call, adding no
work to the asset-load-to-first-frame path. That test runs in every full gate; its tooling file,
refreshed by the same §1 run (budget ≤ 300 ms typical, the E2-S3 contract, unchanged and not
re-claimed):

```
e2-s3 auto-play start budget, measured from tooling
warm-up: 133.8 ms
cold-pass 1: 10.1 ms
cold-pass 2: 10.0 ms
cold-pass 3: 9.4 ms
measure iteration: 9.6 ms
measure iteration: 7.5 ms
measure iteration: 8.2 ms
measure iteration: 8.2 ms
measure iteration: 8.7 ms
measure iteration: 8.2 ms
```

Within E2-S3's recorded band (cold passes 7.2–11.3 ms, measure iterations 6.6–12.3 ms in the
E2-S3 evidence §3) — no regression; the warm-up figure is framework cold-start noise, not the
budget's subject (same caveat as E2-S3's). The ordering half of S12 (no 1× beat — the start call
*is* at the selected speed) is unit-pinned by
`AVMediaPlaybackSpeedTests.startAtDoubleBeginsAtRateTwo` (immediately after `startPlayback`
returns, and holding through the first frame) and
`FeedViewModelTests.startAtSpeedOrderingOnAutoPlayAndRevisit` (the spy's call log: a fresh 2×
session records no 1× request anywhere).

## 4 · D21 audit — zero project-config diff (task 10.5b; design §1.1, §9, §13)

`git diff main...HEAD -- InstantPlayer.xcodeproj InstantPlayer/Config` — **empty output quoted**:

```
--- git diff main...HEAD -- InstantPlayer.xcodeproj InstantPlayer/Config (must be empty) ---
--- end diff (exit 0) ---
--- stat end ---
```

Both the raw diff and `--stat` are empty: no pbxproj, entitlements, Info.plist, or build-setting
change anywhere in the story (the one new source file,
`Features/Feed/Domain/MediaPlaybackSpeed.swift`, joined the target through synchronized groups).
`codesign -d --entitlements` is **not in this implementer's shell allowlist** (the E3-S1
evidence §4 precedent — recorded, not a failed attempt); the sanctioned equivalent evidence: the
empty config diff proves the entitlements file is byte-identical to `main`, and the committed
`InstantPlayer/Config/InstantPlayer.entitlements` reads exactly D19's four read-only keys,
unchanged:

- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-only` = true
- `com.apple.security.temporary-exception.files.home-relative-path.read-only` = [`/`]
- `com.apple.security.files.removable-media.read-only` = true

No key added, removed, or widened; the validator may re-verify the embedded signature at converge
with `codesign` (unrestricted there).

### 4.1 · Design §9.1 sandbox/media-read review table, walked row by row (task 10.5c)

| Concern | Verdict against the shipped code |
|---|---|
| Entitlements | Unchanged — the four read-only keys above; no new grant (§4 audit: empty diff) |
| User files access pattern | The rate mechanism operates only on the already-live `AVPlayer` of the open session (`setPlaybackSpeed`/`resume`/`restart` write `player.rate`; `startPlayback` loads the already-open item's asset); no `start/stopAccessingSecurityScopedResource`, no session re-derivation (AVMediaPlayback.swift, AVMediaPlayerService.swift) |
| Writes to disk | None — playback/rate APIs only (`player.rate`, `playImmediately(atRate:)`, `seek`, `pause`); no `AVAssetExportSession`, no `AVAssetReader`/`AVAssetWriter`, no `write(to:)`, no sidecars, no disk caches (grep-verified: no such symbol exists in the story's diff) |
| Persistence | None — **no speed preference anywhere** (S9, S17): no `UserDefaults`, no files in `tmp`/`Caches`/`Application Support`; the selection is plain in-memory session state that resets by object lifetime at relaunch (task 3's `selectedSpeed`; the perf evidence files in §3 are test-only scratch, never app state) |
| Bookmarks | None — no `bookmarkData` call exists (D19's session is never re-derived) |
| Untrusted input | Enum ladder — menu values are one of five cases by construction, no raw float can reach AVFoundation (S2 doubles as validation, design §1.1); key codes are `NSEvent` values routed through the frozen pure table (33/30 test-pinned); media bytes play-only, never executed (D20 carries) |
| File names | Display-only; absent from every speed surface and from all logging (no logging exists — D20) |
| ATS / network | Untouched — no networking in v1 (D9); speed reads the local file only |
| Privacy manifest / required-reason | No triggering API added (no `UserDefaults`, no file-timestamp APIs); no TCC capability touched |
| Dependencies | None added — AVFoundation/AppKit are system frameworks |

## 5 · Traceability walk — S1–S18 row by row (task 10.2)

Every row names the shipped artifact (file/test/ADR) and its design section. Test names are Swift
Testing rows in `InstantPlayerTests/`; "FVM tests" = `FeedViewModelTests.swift` (task 7), "speed
seam suite" = `AVMediaPlaybackSpeedTests.swift` (task 4), "key tests" =
`FeedKeyCommandTests.swift` (task 6).

| Req | Shipped artifact (file / test / ADR) | Design |
|---|---|---|
| S1 menu applies | `FeedViewModel.selectSpeed(_:itemID:)` → `applySpeedSelection` (§5) + `PlaybackControlBarView` speed `Menu`/`Picker` (§4) + `FeedPageActions.speedSelected`/`FeedView` drill (§7) + FVM `barModelSpeedTracksTheSelectionAndSpeedTextIsPinned`, `menuSelectionRearmsTheIdleCountdownAndStepsLeaveTheBarAsFound` | §2, §4, §5, §7 |
| S2 five presets | `MediaPlaybackSpeed` (new Domain file — the ladder as a type, §2) + FVM `presetLadderIsExactlyFiveCases` | §2 |
| S3 bar contents + control/badge | `PlaybackControlBarView` six-element strip + cluster hit-test island (§4) + `FeedItemView`/`FeedView` drill (§7) + FVM badge/model rows | §4, §7 |
| S4 badge iff ≠ 1× | `SpeedCluster` badge rule + `speedText` five strings (§4) + FVM `barModelSpeedTracksTheSelectionAndSpeedTextIsPinned` (strings + model tracking) | §4, §5 |
| S5 keyboard step | `stepSpeedDownByKeyboard`/`stepSpeedUpByKeyboard` (§5) + `FeedKeyCommand` rows 33/30 (§6) + `AppDelegate` cases + FVM `keyboardStepsRepeatAndClampIdempotently` + key tests `plainBracketKeysStepSpeedWhenFeedIsOpen` | §5, §6 |
| S6 hold-to-repeat | the route ignores `isRepeat` (§6 — the D22/D34 parity) + FVM `keyboardStepsRepeatAndClampIdempotently` + key tests `speedKeyAutoRepeatStillSteps` + the §8(3) step-path measure (§3) | §5, §6, §8(3) |
| S7 clamping at ladder ends | `FeedViewModel.stepped(_:up:)` pure function (§5) + FVM `steppedWalksTheLadderAndClampsAtBothEnds` | §5 |
| S8 carry until changed | `selectedSpeed` app-session state, not cleared by stop/adopt/welcome (§3) + FVM `selectedSpeedCarriesUntilChangedAndResetsOnlyAtRelaunch`, `startAtSpeedOrderingOnAutoPlayAndRevisit` | §3, §5 |
| S9 relaunch at 1× | nothing persisted — reset by object lifetime (§3, §9) + FVM carry row's fresh-view-model assertion (`.normal`) + §4.1's persistence row | §3, §9 |
| S10 immediate while playing | conformance `setPlaybackSpeed` — in-turn rate write, position/pause untouched (§2) + speed seam suite `speedChangeWhilePlayingIsAnInTurnRateWrite` + FVM `speedInputsAreStateNeutral` + the §8(1) measure (§3) | §2, §8(1) |
| S11 remembered while paused | conformance paused case (rate-0 skip) (§2) + speed seam suite `speedChangeWhilePausedIsRememberedAndAppliesOnResume` + FVM `speedInputDuringAScrubDragIsRememberedAndAppliesOnResume` (S10's composition note) | §2, §5 |
| S12 start-at-speed | `startPlayback(for:at:)` + `playImmediately(atRate:)` (§2, §3) + install re-apply (§3, F2) + speed seam suite `startAtDoubleBeginsAtRateTwo` + FVM `startAtSpeedOrderingOnAutoPlayAndRevisit`, `speedInputWhileStillStartingIsAcceptedAndReappliedAtInstall` + §8(2) start-latency not regressing (§3) | §2, §3, §8(2) |
| S13 seek preserves speed | seek paths never write speed (§5) + speed seam suite `seekLeavesTheSelectedSpeedUntouched` + FVM `seekPathsNeverTouchTheSelectedSpeed` | §2, §5 |
| S14 loop preserves speed | `restart()` = seek-zero + rate at the selection; `play()` retired (§2) + speed seam suite `restartPlaysAtTheSelectedSpeed` + FVM `loopRestartPreservesTheSelectedSpeed` | §2, §5 |
| S15 pitch-corrected audio | `playerItem.audioTimePitchAlgorithm = .spectral` at item creation (§2) + speed seam suite `audioTimePitchAlgorithmIsPinnedSpectralAtCreation` (over the with-audio fixture, design §10.2) | §2 |
| S16 guard matrix | `speedGuard(itemID:)` — one decision surface, no duration/handle needed (§5) + FVM `speedInputsOnIneligibleStatesAreQuietNoOps` (non-current, mid-gesture, image, unavailable, welcome) + key tests `welcomePassesSpeedKeysThrough` (route level) | §5, §6 |
| S17 read-only speed | §9's posture — §4.1's walked table above; nothing written or persisted anywhere; D36 | §9 |
| S18 responsiveness | §8 budgets — the two measures (§3) + O(1) route cases (§6) + no `Timer`/run-loop sources (the one re-arm call site, §8(5)) + the launch-path-untouched diff (§2) | §8 |

## 6 · Product R-map (task 10.2; the spec's acceptance table carried)

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R14 (apply the selected speed to the current video) | S1 (menu selection), S2 (five presets), S5–S7 (keyboard stepping, repeat, ladder ends), S8 (carries until changed), S10–S11 (immediate while playing, remembered while paused), S13–S14 (preserved across seeks and the loop) | unit tests (speed policy: preset ladder, stepping and boundary clamping, hold-to-repeat, guard matrix, carry semantics, seek/loop preservation, start-at-speed — tasks 4, 6, 7) + functional review (menu, keys, badge, immediate apply, carry across clips) |
| R16 (smooth & responsive) — cross-cutting share via S18, not claimed | S18 — speed changes instant and stall-free; S12 — no 1× flash and no added wait at start | validator performance review (RNF-02; §3's measured budgets) + functional review (rapid speed changes stay fluid; clips start already at speed) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S17 — speed writes nothing and persists nothing; no new access paths (D19); S9 — relaunch at 1× | validator security review (§4.1's walked table) + functional review (files byte-identical on disk; relaunch starts at 1×) |

## 7 · Functional-review checklist (task 10.6 — converge-owned; carried verbatim from the spec AC)

The stakeholder exercises this in the running app (`./scripts/app.sh run`); agent-recorded
evidence is supporting material, never the approval:

- [ ] selecting each preset from the bar's speed menu and seeing it applied immediately on a
      playing video;
- [ ] selecting while paused and seeing it applied on resume;
- [ ] the badge appearing whenever the speed differs from 1× and vanishing at 1×;
- [ ] `[`/`]` stepping through the ladder with hold-to-repeat and clamping at 0.25× and 2×;
- [ ] the speed carrying to the next clip and across revisits and newly opened folders until
      changed;
- [ ] a relaunch starting at 1×;
- [ ] every clip starting already at the selected speed with no 1× flash and no extra wait;
- [ ] scrubs, track clicks, keyboard seeks, and loop restarts all keeping the selected speed;
- [ ] audio sounding natural at 0.25× and at 2×;
- [ ] speed keys doing nothing — and changing nothing — on an image page, a non-current page, and
      mid-paging-gesture;
- [ ] clicks on the speed control never toggling play/pause;
- [ ] rapid speed changes staying stall-free;
- [ ] and the media files byte-identical on disk after all of the above (this is a UI story —
      functional review is part of the done gate).

## 8 · Deviations (task 10.7 — honest; marked for coordinator ratification)

1. **Task 1's compile-fix surface exceeded the two files named in tasks.md 1.6.** The seam
   signature change (`startPlayback(for:at:)`) forced minimal `at: .normal` call-site updates in
   four further test files the tasks text did not name (`AVMediaPlayerServiceTests`,
   `AVMediaPlaybackSeekTests`, `MediaPlayerPerformanceTests`, `SeekLandingPerformanceTests` —
   everything must compile from the commit on, the task's own stated goal), and the real
   conformance needed compile-only minimal shapes (`AVMediaPlayback.setPlaybackSpeed` empty body;
   `playImmediately(atRate: 1)` with the `at:` parameter unused) — replaced by task 2's real
   mapping in the very next commit, the documented E3-S1 task-1 precedent ("task-1 minimal
   shape"). Impact: none at story end; every intermediate commit gate-green.
2. **Task 4's fixture adjustments (design §10.2's "extended if needed" latitude):** the
   audio-track fixture builder retries 5× (vs the video builder's 3×) — the AAC encoder contends
   harder under the gate's parallel test load (two encoders per attempt); the speed-clip fixture
   is 30 frames (1 s) — the design pins the *pattern* (short multi-frame MP4 with an audio track,
   throwaway folders), not a length; and the suite's ready-event wait is bounded at 30 s (vs the
   siblings' 10 s default) for the same load reason. All suite rows green in every gate run since
   (the one pre-fix failure cluster is recorded in the task 4 history).
3. **Pre-existing `MediaPreviewPerformanceTests.testDisplayBudgetThroughPreviewSeam` flaked
   transiently in 2 of this story's ~12 gate runs** (E2-S2's preview-display budget: a
   p95-over-20-cold-passes catch). Isolated as environmental, not a regression: the preview seam
   files have an **empty diff vs `main`** (`git diff main...HEAD --stat --
   InstantPlayer/Features/Feed/Data/AVMediaPreviewService.swift
   InstantPlayerTests/Features/Feed/MediaPreviewPerformanceTests.swift` — empty), and the test
   passed on every re-run and in the §1 evidence gate. Likely mechanism: this story's added test
   classes increased the gate's parallel-suite load past the budget's headroom on this machine.
   Flagged for the validator/converge — the budget may want its own load-hardening story (its
   owner is E2-S2, not this story; nothing was changed here).
4. **`@testable` internals used by the suites** (the design §10.2-noted route, since the frozen
   seam carries no state-query members — the D25 unmuted-start precedent): the conformance rows
   read `session.player`/`session.playerItem` directly (rate, pitch pin, item detachment);
   `StubMediaPlayback` was widened from `private` to internal so task 4.4's wiring rows can read
   its recorded `speedSelections`; the test doubles record `speedCommands`/`startSpeeds`/`emit`/
   `emitTick` helpers. Test-only surface; production contracts untouched.
5. **The design §4 idle/menu fallback is NOT taken:** a menu selection re-arms the idle countdown
   (the pinned mitigation) and nothing suspends the policy on menu-open. If functional review
   (§7) shows the 3 s hide disturbing an open menu, the recorded fallback (menu label's press
   suspends the idle policy) remains available as a ratified deviation per task 5.7.
6. **ADR numbering landed exactly as planned:** D36–D38 (the log ended at D35; tasks 8/9 commits
   `6e77e08`, `8102e5e`) — no renumber shift to record.
7. **Evidence-accuracy note on the launch-test clause (task 10.4):** the task text's "run green
   unchanged within the full gate of 10.3" is recorded precisely instead: the default gate does
   not run the UI-test target, so §2 quotes the last recorded green launch-test run (E2-S3), the
   launch-path-untouched diff, and the §1 gate — no claim is made beyond what tooling showed.

No other deviation from the approved design exists: signatures, budgets, the bar form, the route
table, and the file inventory match the design §1–§13 as approved.

## 9 · Acceptance criteria (task 10.8)

Ticked here and mirrored in [tasks.md](tasks.md); AC8–AC10 stay converge-owned (unticked there
and not claimed here).

- **AC1 · product R14 / S1, S2, S5–S7** — both invocations land on the exact five-preset ladder:
  the bar's speed menu selects any preset, and `[`/`]` step one preset per press (hold-to-repeat)
  with clamping at 0.25× and 2× and no wrap — covered by the policy suite (§5 rows S1, S2, S5–S7)
  + functional review. ✔ for the implementation evidence; the review is converge-owned (§7).
- **AC2 · S8, S9, S12** — session scope and starts: the selection carries across paging, revisits,
  and newly opened folders until changed; a relaunch starts at 1× (nothing persisted); every
  start — auto-play, revisit restart, loop — begins at the selected speed from the first frame
  with no 1× flash and no added wait (§5 rows S8, S9, S12; §3's §8(2) record). ✔ for the
  implementation evidence.
- **AC3 · S3, S4 (+ S1's carve-out)** — the bar is the four E3-S1 elements plus the speed control
  and the speed badge (badge iff ≠ 1×, identifying the selection); the cluster is a hit-test
  island, so clicks and drags on the speed surface never toggle play/pause, scrub, or page;
  keyboard steps never show the bar (approved F1) (§5 rows S3, S4). ✔ for the implementation
  evidence.
- **AC4 · S10, S11, S13, S14, S16 (+ S10's composition note, approved F2)** — application rules:
  immediate rate change while playing (position and play/pause untouched), remembered while
  paused, mid-scrub-drag, and mid-start (applied at install); no seek or loop restart resets the
  speed; the full guard matrix unit-tested row by row — quiet consumed no-ops, never beep (§5
  rows S10, S11, S13, S14, S16). ✔
- **AC5 · S15, S17, S9 / product R17 · RNF-04** — pitch-corrected audio pinned `.spectral` at
  item creation (seam suite); read-only speed walked: no rewrite/export/reader/writer, no sidecars
  or derived files, no speed preference at rest, no new access paths (D19 session not re-derived);
  no entitlement/plist/pbxproj diff (D21 audit: empty diff quoted, §4; unchanged keys listed);
  design §9.1 review table walked (§4.1); media files byte-identical on disk after review — the
  functional-review clause is converge-owned (§7). ✔ for the implementation walk; file
  byte-identity awaits functional review.
- **AC6 · S18 / product R16 share · RNF-02** — responsiveness budgets measured and recorded from
  tooling (§3: rate change issued in the same main-actor turn — largest recorded 0.08 ms against
  the 16 ms budget; the §8(3) step path likewise; §8(2)'s zero-added-start-wait via the existing
  start-latency measure not regressing); rapid stepping O(1) and backlog-free (unit-pinned);
  zero added launch cost (no `Timer`/run-loop sources — the one re-arm call site; the
  launch-path-untouched diff, §2); speed-change fluidity in functional review is converge-owned.
  ✔ for the measured/unit evidence.
- **AC7 · R14 (E1-S2) decision + evidence & coverage** — the UI-test-mandate decision recorded
  (default gate scope, no `--uitests` obligation, with the honest caveat and the tooling
  precision note, §2); full gate `--json` quoted verbatim (§1, lint/format `ok`); the S1–S18 +
  product R-map walk recorded (§5, §6); the three ADRs in
  [docs/decisions.md](../../decisions.md) house format with design §11 titles (D36–D38); the
  design §13 `docs/architecture.md` updates done (task 8, incl. the §4 check-3 verdict and the
  §8 no-new-actor note); all deviations listed honestly (§8). ✔

## 10 · Spec acceptance checklist — mirrored state (task 10.8)

The [spec](spec.md)'s own acceptance checklist, mirrored with its current tick state: the four
spec-side authoring items and the gate-evidence item are met (the latter backed by §1's quoted
JSON); the stakeholder functional review and the approval gate are converge-owned and stay
unticked:

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
      other product requirement is claimed here.
- [x] The two contract changes are stated plainly in Story context (bar contents four → six;
      seek contract evolved to "never changes the *selected* speed").
- [x] Speed semantics are explicit and testable (both invocations, the ladder, bar additions and
      badge rule, stepping/repeat/clamps, carry, no persistence, immediate/remembered,
      start-at-speed, preservation, pitch, guard).
- [x] Read-only speed is a reviewable contract (S17, S9; the RNF-04 posture unchanged).
- [x] Gate evidence is recorded from tooling per conventions (`--json` quoted verbatim, §1; the
      converge run keeps the default gate scope).
- [ ] Stakeholder functional review in the running app — the §7 checklist (converge-owned).
- [ ] This spec passes the stakeholder approval gate (converge-owned).
