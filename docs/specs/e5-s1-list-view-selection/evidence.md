# E5-S1 · List view & selection — Evidence

Verification record for the story's implementation tasks (1–7b, plus the docs tasks 8–10 and this
task 11). Converge-owned evidence (functional review, validator PASS, closure) was **not** recorded
here by task 11; the 2026-10-15 stakeholder functional-review result is recorded in §7.1. Gate usage per [docs/development.md](../../development.md) §3; conventions per the
[SDD README](../README.md) and the [E3-S2 precedent](../e3-s2-playback-speed/evidence.md).

## 1 · Full gate — machine-readable record (task 11.3)

`./scripts/validate.sh --json /tmp/e5s1-gate.json` (session temp, outside the repo; the JSON is
never committed) — the JSON quoted **verbatim**; this is the fresh full-gate run (build + unit
tests, never `--staged`) on the story's final code:

```json
{
  "branch": "feat/e5-s1-list-view-selection",
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

`result` is `pass`; the SwiftLint and SwiftFormat steps read `ok` (this gate's JSON status
vocabulary is `ok`, and the human output likewise prints `ok: swiftlint lint --quiet` and
`ok: swiftformat --lint .`). The gate's own output ends with
`all checks passed`. The unit-test step's xcodebuild log records `** TEST SUCCEEDED **` with no
`failed on` / `error:` lines (a log search for `failed on` / `TEST FAILED` / `error:` in the step
log returns nothing); the step ran the whole `InstantPlayerTests` target, which includes the
story's four new suites (`MediaListSelectionTests`, `MediaListViewModelTests`,
`FeedKeyCommandTests` (grown), `MediaListPerformanceTests`). The ADR-format step reports
**42 ADRs well-formed** — D39–D42 landed on top of the previous 38 (task 11.7's numbering check).

## 2 · UI-test mandate (task 11.4; spec Story context; R14 of E1-S2)

Decision (spec Story context, carried — not re-decided): **flows are NOT affected** — with no media
open, the launch-visible behavior (welcome state, launch cost) is exactly as E2-S1/E2-S2 left it,
and this story's entire surface (the list, the toggle button, ⌘L, selection) exists only once media
is open, which the UI tests cannot reach (entry stays host-driven: Open With and drag & drop). The
converge run keeps the **default gate scope with no `--uitests` obligation**. Honest caveat, in the
predecessors' form: even a `--uitests` run could not open the list view (no media is open in the
launch tests), so selection behavior is verified by the unit suites (tasks 2, 4, 5, 7) plus
stakeholder functional review.

Tooling precision on the "launch tests green" clause (the E3-S2 §2/E3-S2 §8 item-7 precedent):
`testLaunchPerformance` lives in the `InstantPlayerUITests` target, which the default gate's test
step (`-only-testing: InstantPlayerTests`) does **not** run — so §1's gate does not itself record a
launch-test result. Its last recorded green runs are E2-S1/E2-S3's (E2-S3 evidence §2:
`Test case 'InstantPlayerUITests.testLaunchPerformance()' passed … (13.078 seconds)`). What §1's
gate establishes: the launch path is untouched by the story's diff — the launch-relevant files
(`InstantPlayerApp`, `WelcomeView`, `Info.plist`) have no diff, and the story's `RootView` change is
the presentation switch plus the on-demand toggle overlay, neither of which runs without an open
folder (S16; design §7(6)); the launch tests were not re-run here and no claim is made beyond that.
The validator may re-run `--uitests` at converge if it wants a fresh launch-test record.

## 3 · Performance evidence from tooling (task 11.5a; design §7(1)–(3), §7(7); S15)

The four §7 budget methods in `InstantPlayerTests/Features/MediaList/MediaListPerformanceTests.swift`
append their numbers to a **throwaway scratch file** (never committed): the app cache directory
resolves through the test host's sandbox container to
`~/Library/Containers/com.guits.InstantPlayer/Data/Library/Caches/e5s1-list-budget-evidence.txt`.
The file accumulates across gate runs; the **last four blocks** (timestamps `2026-10-15 03:47:04`
to `03:47:06 UTC`) are the fresh §1 gate run — the same run as §1's JSON (the gate's test step log
is timestamped `2026-10-14 22:47:18 -0500` = `03:47:18 UTC`). Quoted verbatim from that file, never
from memory (the `measure iteration` lines each sit on their own line in the scratch file and are
comma-joined here only for readability; all values are milliseconds, formatted `%.3f` by the test):

```
--- 10k arrow-repeat step path (design §7(3)) @ 2026-10-15 03:47:04 +0000 ---
arrow step (S9): 0.008, 0.002, 0.002, 0.001, 0.002, 0.002, 0.002, 0.002, 0.003, 0.002, 0.004, 0.004, 0.004, 0.004, 0.005, 0.005, 0.005, 0.005, 0.005, 0.005 — p95 0.005 (budget 16 ms p95)
boundary-clamped repeat (S9): 2.473, 2.319, 2.323, 2.320, 2.320, 2.313, 2.317, 2.310, 2.314, 2.302, 2.299, 2.300, 2.305, 2.306, 2.302, 2.305, 2.307, 2.305, 2.300, 2.287 — p95 2.323 (budget 16 ms p95)
shift-arrow extend step (S9): 0.021, 0.004, 0.003, 0.004, 0.003, 0.005, 0.005, 0.005, 0.006, 0.006, 0.007, 0.008, 0.007, 0.008, 0.009, 0.010, 0.009, 0.012, 0.010, 0.014 — p95 0.014 (budget 16 ms p95)
30-key boundary burst: 0.264 (one 30 keys/s repeat interval ≈ 33 ms)
clamped repeat measure iteration: 0.061, 0.037, 0.031, 0.030, 0.030, 0.032, 0.033, 0.041, 0.036, 0.037
--- 10k selection-change budget (design §7(3)) @ 2026-10-15 03:47:05 +0000 ---
single click (S6): 0.021, 0.003, 0.002, 0.002, 0.001, 0.002, 0.002, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.002, 0.001, 0.002, 0.001 — p95 0.003 (budget 16 ms p95)
command click (S7): 0.023, 0.002, 0.003, 0.002, 0.002, 0.004, 0.001, 0.003, 0.003, 0.001, 0.002, 0.009, 0.001, 0.001, 0.001, 0.001, 0.001, 0.001, 0.002, 0.002 — p95 0.009 (budget 16 ms p95)
shift-click full range (S8): 10.768, 9.203, 10.672, 12.192, 10.545, 12.675, 11.173, 13.213, 7.825, 8.109, 7.907, 7.471, 10.796, 6.623, 5.988, 5.916, 6.053, 5.942, 5.966, 5.702 — p95 12.675 (budget 16 ms p95)
empty-space clear (S10): 0.049, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.001, 0.000, 0.000, 0.001, 0.000, 0.000, 0.000, 0.000, 0.000 — p95 0.001 (budget 16 ms p95)
selection compound measure iteration: 18.658, 7.581, 6.272, 5.927, 5.706, 5.760, 5.665, 5.719, 5.710, 5.687
--- 50k degenerate extreme (design §7(1)) @ 2026-10-15 03:47:05 +0000 ---
switch pass at 50k (apply + both flips, §7(1)): 5.836, 7.150, 7.033, 6.928, 6.930, 6.933, 6.861, 6.830, 6.842, 6.838, 6.811, 7.055, 7.265, 7.149, 7.090, 7.117, 7.068, 7.105, 7.873, 7.156 — p95 7.265 (budget 300 ms p95)
50k switch measure iteration: 6.918, 6.895, 6.905, 7.396, 7.342, 7.051
--- 10k switch budget (design §7(1)) @ 2026-10-15 03:47:06 +0000 ---
switch pass (apply + both flips, §7(1)): 1.098, 1.386, 1.392, 1.388, 1.459, 1.514, 1.547, 1.476, 1.465, 1.486, 1.483, 1.397, 1.397, 1.468, 1.473, 1.476, 1.471, 1.457, 1.460, 1.465 — p95 1.514 (budget 100 ms p95)
switch measure iteration: 1.409, 1.464, 1.454, 1.380, 1.430, 1.413, 1.423, 1.410, 1.409, 1.407, 1.676
```

Budget verdict against the §7 targets (`assertBudget`/`assertTurnBudget` assert p95 with
`XCTAssertLessThan`, so the gate is red on a breach):

| Design §7 budget | Recorded (this run, p95) | Verdict |
|---|---|---|
| §7(1) view switch ≤ 100 ms p95 at 10k | **1.514 ms** (20 sampled passes); `measure` iterations 1.38–1.68 ms | compliant — ≈ 1.5 % of budget |
| §7(1) view switch ≤ 300 ms p95 at 50k (degenerate extreme, reviewed) | **7.265 ms** (20 sampled passes); `measure` iterations 6.9–7.4 ms | compliant — ≈ 2.4 % of budget |
| §7(3) selection ≤ 16 ms in one main-actor turn: single click | **0.003 ms** | compliant |
| §7(3) ⌘-click | **0.009 ms** | compliant |
| §7(3) ⇧-click full 10k range (O(range) worst case) | **12.675 ms** | compliant, **tightest row** (see below) |
| §7(3) empty-space clear | **0.001 ms** | compliant |
| §7(3) arrow step / ⇧-arrow extend step | **0.005 ms** / **0.014 ms** | compliant |
| §7(3) boundary-clamped repeat (idempotent no-op) | **2.323 ms** | compliant |
| §7(3) 30-key auto-repeat burst fits one repeat interval (`XCTAssertLessThan(0.033)`) | **0.264 ms** vs ≈ 33 ms | compliant — no backlog |

Honesty limits stated: each block is **one recorded run**; the scratch file is appended to by every
gate run and the numbers vary run to run (the previous run's blocks — `03:37:02`–`03:37:03 UTC` —
read 10k switch p95 **1.693 ms**, 50k p95 **7.319 ms**, ⇧-click p95 **14.418 ms**). The stable
claims are (a) budget compliance in every recorded run and (b) the shape: single/⌘-click and the
step path are O(1) (sub-10 µs), the ⇧-click full-range rebuild is O(range) and the tightest row
(p95 12.7–14.4 ms against the 16 ms budget — compliant but with modest headroom at the 10k
degenerate range; realistic selections are far smaller), and held-arrow repeats build no backlog by
construction (one O(1) state write, idempotent clamp). A `measure` unit is not a rendering cost:
§7(2)'s 60 fps / ≤ 1 ms row-`body` target has no unit-reachable SwiftUI cost (a unit test cannot
mount rows), so it is carried by the row's construction (one `Text` + two O(1) membership checks,
`MediaListRowView`) and by the functional review — Instruments on escalation, per skill §6.

## 4 · D21 audit — zero project-config diff (task 11.5b; design §1.1, §8, §12(1))

`git diff main...HEAD --stat` restricted to the project config — recorded as **empty output**:

```
$ git diff main...HEAD --stat -- InstantPlayer.xcodeproj InstantPlayer/Config
(no output — empty)
```

No pbxproj, entitlements, Info.plist, or build-setting change anywhere in the story: the six new
`Features/MediaList/**` files (five Swift sources plus the `Data.md` placement note) and the three
new test files joined their targets automatically through synchronized groups (D21). The full story
`--stat` contains no `InstantPlayer.xcodeproj` or `InstantPlayer/Config` path at all.

`codesign -d --entitlements` is **not in this implementer's shell allowlist** (the E3-S1 evidence §4
precedent — recorded, never a failed attempt). The sanctioned equivalent evidence: the empty config
diff proves the entitlements file is byte-identical to `main`, and the committed
`InstantPlayer/Config/InstantPlayer.entitlements` reads exactly D19's four read-only keys,
unchanged:

- `com.apple.security.app-sandbox` = true
- `com.apple.security.files.user-selected.read-only` = true
- `com.apple.security.temporary-exception.files.home-relative-path.read-only` = [`/`]
- `com.apple.security.files.removable-media.read-only` = true

No key added, removed, or widened; the validator may re-verify the embedded signature at converge
with `codesign` (unrestricted there).

### 4.1 · Design §8.1 sandbox/media-read review table, walked row by row (task 11.5c)

| Concern | Verdict against the shipped code |
|---|---|
| Entitlements | Unchanged — the four read-only keys above; no new grant (§4 audit: empty diff) |
| User files access pattern | None new — the list reads names from the in-memory `MediaCollection.items`; a grep of `InstantPlayer/Features/MediaList/**` for `FileManager`, `start/stopAccessingSecurityScopedResource`, `bookmarkData`, `URLSession` returns **no matches**. The only `startAccessingSecurityScopedResource` in the app is the pre-existing D19 `SecurityScopedMediaFolderRepository` (empty diff this story) |
| Writes to disk | None — no `write(to:)`, no `FileHandle`, no sidecars, no exports in MediaList production code; `MediaList/Data/Data.md` is a placement note (empty Data layer). The only `FileHandle` in the story is the **test-only** perf scratch (§3), never committed, never app state |
| Persistence | None — a repo-wide grep for `UserDefaults`/`@AppStorage` matches nothing at all; the selection is plain in-memory view-model state that dies with the model. The S18 reset is RAM-only (`apply` → `selection.reset()`) |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19's session is never re-derived) |
| External input | Mouse and key events only — clicks/modifiers via SwiftUI gestures and `NSEvent.modifierFlags` (main-thread read, no I/O); keys via the frozen pure routing table (codes 37/36/76/123–126 pinned). No pasteboard (`NSPasteboard` matches nothing), no URL schemes, no new entry channel; the in-memory snapshot is the only data |
| File names | Display-only — `MediaListRowView` renders `Text(item.name)` and nothing else; names are never parsed, never logged (no `Logger`/`print`/`os_log` matches in MediaList code, D20), never pasted, never used as paths |
| ATS / network | Untouched — no networking in v1 (D9); no `URLSession` anywhere |
| Privacy manifest / required-reason | No triggering API added (no `UserDefaults`, no file-timestamp APIs) — no privacy-manifest change and no purpose strings (no `PrivacyInfo.xcprivacy` exists in the repo) |
| Dependencies | None added — SwiftUI/AppKit/Foundation/Observation are system frameworks; no SPM surface |

## 5 · Traceability walk — S1–S18 row by row (task 11.2)

Every row names the shipped artifact (file / test / ADR) and its design section. Test names are the
house suites: "machine suite" = `InstantPlayerTests/Features/MediaList/MediaListSelectionTests.swift`
(task 2); "VM suite" = `…/MediaListViewModelTests.swift` (task 4); "key tests" =
`InstantPlayerTests/App/FeedKeyCommandTests.swift` (task 5, grown); "perf suite" =
`…/MediaListPerformanceTests.swift` (task 7).

| Req | Shipped artifact (file / test / ADR) | Design |
|---|---|---|
| S1 | `MediaListView` (`ScrollView` + `LazyVStack`, `ForEach(collection.items)`) + `MediaListRowView` (`Text(item.name)`) + `MediaListViewModel.collection`/`apply(collection:)`; VM suite `rowsEqualTheCollectionItems`, `mixedMediaFixtureShowsNoNonMediaRows` | §2 |
| S2 | Rows built once per applied snapshot (`apply` sets `collection`/`rowIDs`; the row view is a pure function of the immutable `MediaItem`); VM suite `rowsNeverChangeAfterApply` | §2, §6.3 |
| S3 | `FeedKeyCommand` `.toggleView` row (keyCode **37** + `.command`) + `AppDelegate` dispatch to `activeListModel` + `MediaListViewModel.togglePresentation()`; key tests `commandLTogglesInBothPresentedViews`, `welcomePassesCommandLThrough`, `shiftCommandLStillToggles`, `otherCommandModifierCombosStillPassThrough`; ADR [D39](../../decisions.md) | §5.1 |
| S4 | `ViewToggleControl` (one `togglePresentation()` binding) mounted in `MediaListView`'s top bar and as `RootView.feedSurface`'s top-left floating overlay gated on `FeedViewModel.isChromeDemanded`; the sanctioned Feed-side demand extension (`FeedViewModel.noteMouseMoved`, `FeedItemView.PosterMouseMoveTracker`); ADR [D41](../../decisions.md) | §5.2, §12(7) |
| S5 | `RootView`'s root-owned presentation switch (`isListPresented` → `MediaListView` vs the feed); the router's `isListPresented` flag keeps one active row set; key tests `feedRowsDoNotRouteWhileListIsPresented`, `listRowsDoNotRouteWhileFeedIsPresented`, `listAndFeedRowSetsNeverOverlap`; VM suite `togglingPresentationNeverTouchesThePlaybackSession`; ADR [D42](../../decisions.md) | §1.1, §5.1, §5.3 |
| S6 | `MediaListSelection.select(_:)` + `MediaListRowView`'s single-click gesture → `selectRow`; machine suite `singleClickSetsAndNeverActivates`, `singleClickReplacesPreviousSelection` | §3.1 |
| S7 | `toggle(_:)` + ⌘-click gesture → `toggleRow`; machine suite `commandClickTogglesMembershipPreservingTheRest`, `commandClickCanDeselectTheOnlySelectedRow` | §3.1 |
| S8 | `extend(to:over:)` + ⇧-click gesture → `extendToRow`; machine suite `shiftClickBuildsAnchorTargetRangeAndKeepsTheAnchor`, `shiftClickWithoutAnchorBehavesAsSelect` | §3.1 |
| S9 | `move(_:over:)`/`extend(_:over:)` + the list-presented route rows (126/125, ⇧-modified) → `moveSelection`/`extendSelection`; machine suite `arrowsMoveAndCollapseToTheLead`, `shiftArrowsExtendFromTheAnchor`, `arrowsClampAtBothEndsAndNeverWrap`, `boundaryRepeatsAreIdempotentNoOps`, `arrowWithNoSelectionUsesFinderEntryRow`; key tests `listPresentedPlainArrowsMoveSelection`, `listPresentedShiftArrowsExtendSelection`, `listRowsAutoRepeatRepeatsCalls`; perf suite's step-path block (§3); ADR D39 | §3.1, §5.1 |
| S10 | `clear()` + `clearSelection()` + `MediaListView`'s container `onTapGesture` (row taps win); machine suite `emptyClickClears` | §3.1 |
| S11 | One `MediaListSelection` value held by `MediaListViewModel` — the E5-S2 seam; nothing persisted (§4.1 greps); ADR [D40](../../decisions.md) | §3.2, §6.2 |
| S12 | `MediaListRowView`'s double-click gesture → `activate(itemID:)` → `RootView`'s injected `onActivate` → the existing `FeedViewModel.moveTo(itemID:)` + `presentFeed()`; VM suite `activationEmitsTheRightIntentAndNeverMutatesSelection`, `activationOfTheAlreadyCurrentItemEmitsNothing`; ADR D42 | §4 |
| S13 | The `.activateLeadRow` route rows (Enter 36, keypad 76) + `activateLeadRow()` (the machine's `leadID`); key test `listPresentedEnterActivatesTheLeadRow`; VM suite `activateLeadRowEmitsTheLeadRow` | §4, §5.1 |
| S14 | Display-only rows (`Text(name)`, no I/O, empty Data layer); the §4.1 walk — no writes, no persistence, no bookmarks, no pasteboard, no logging; media-file byte-identity rides the functional review (§7) | §1.1, §8 |
| S15 | `MediaListPerformanceTests` (§3: 10k switch ≤ 100 ms p95, 50k ≤ 300 ms p95, selection ≤ 16 ms, no backlog) + the lazy surface with stable identities + §7(2)'s functional-review/Instruments escalation; ADR D40's recorded perf risks | §7 |
| S16 | `RootView` creates/holds `listModel` only on the folder-open funnel, so welcome mounts no list view and no toggle; the router's welcome rows pass through (key tests `welcomePassesCommandLThrough`, `welcomePassesArrowsThrough`, …); the welcome fallback dismisses the list and resets the selection with its rows (VM suite `welcomeFallbackDismissesTheListAndResetsTheSelection`); the string value list/selection machinery is unreachable (§2) | §2, §5.1 |
| S17 | `MediaListViewModel.highlightItemID` (a read-only projection; the machine has **no** API to accept it) + `RootView.onChange(of: viewModel.currentItemID)` mirroring + `MediaListView`'s `scrollPosition(id:)` + `.scrollTargetLayout()` wiring (the target resolves; **the in-app jump itself is not unit-verifiable** — it rides the AC8 functional review); VM suite `highlightProjectionIsReadOnly` (the projection pin only) | §3.3 |
| S18 | `togglePresentation()` is a different method from every selection op (survival is structural); `selection.reset()` runs at two sanctioned reset points — `apply(collection:)` when a new snapshot value (`capturedAt`) arrives, and `dismissToWelcome()` when the opened folder is left (the welcome fallback, S16); VM suite `toggleFlipsPresentationOnlyAndLeavesSelectionUntouched`, `applyResetsOnlyOnANewSnapshotValue`, `togglingPresentationNeverTouchesThePlaybackSession`, `welcomeFallbackDismissesTheListAndResetsTheSelection`, `applyingASnapshotAgainAfterTheWelcomeFallbackRebuildsTheRows` | §3.2 |

## 6 · Product R-map (task 11.2; the spec's acceptance table carried)

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R27 (list every item by file name, current ordering) | S1 — snapshot-order rows, file names, exactly the collected items; S2 — honest snapshot, no self-reordering | unit tests (VM suite: contents, order, filtering parity with the collection) + functional review (mixed folder, order matches the feed's) |
| R28 (selection; operations act on it) | S6–S9 — single click sets, ⌘-click toggles, ⇧-click extends, arrows move/extend; S11 — the one selection seam for E5-S2; S18 — lifetime is the opened folder, view switches preserve it | unit tests (machine suite: set/toggle/extend/move, boundaries) + functional review (Finder-familiar gestures) |
| R29 (ad-hoc group, nothing persisted) | S11, S18 — one ephemeral group per opened folder, reset on a new folder open; S14 — nothing written | unit tests (selection state is in-memory only) + functional review (no artifacts on disk after selecting) |
| R37 (single window shows feed and list) — context; completed here, not claimed as E5-S1's assignment | S3–S5, S17 — ⌘L and the on-screen button flip views in the same window; the list opens anchored to the feed's current item | functional review (toggle both ways, same window, same collection) |
| R9–R10 (keyboard-first) — context | S3 (shortcut toggle), S9 (arrow-key selection), S13 (Enter activation) | functional review (keyboard-only round trip: open list, select, activate) |
| R34–R36 (format filtering) — inherited collection contract, not claimed | S1 — the list shows exactly the collected items, no more, no fewer | unit tests (VM suite parity rows) + functional review (non-media files absent) |
| R16 (smooth & responsive) — cross-cutting share via S15, not claimed | S15 — open/scroll/select/switch stall-free at large collection sizes | validator performance review (RNF-02; the §3 measurements) + functional review (large folder stays fluid) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S14 — display-only listing, nothing written, no new access paths | validator security review (read-only paths; D19 session not re-derived) + functional review (files byte-identical on disk) |

## 7 · Functional-review checklist (task 11.6 — converge-owned; carried from the spec AC list and design §9.5)

The stakeholder exercises this in the running app (`./scripts/app.sh run`); agent-recorded evidence
is supporting material, never the approval. Nothing here is ticked by task 11.

- [x] a mixed folder listed by file name in the feed's order, with non-media files absent;
- [x] ⌘L and the on-screen button both toggling list↔feed in the same single window and on the same
      collection;
- [x] the floating toggle appearing **on demand** at the top-left of the window/feed area (outside
      the video control bar, gone with the same idle as the bar) over **both a video page and an
      image page** (the 2026-10-14 amendment; task 7b);
- [x] a single click selecting without activating; ⌘-click toggling membership; ⇧-click extending
      from the anchor; arrow keys moving and ⇧-arrows extending the selection with clamping at both
      ends and no wrap; a click on empty space clearing the selection;
- [x] double-click and Enter each switching to the feed positioned on that item;
- [x] the list opening scrolled to and highlighting the feed's current item — and that highlight
      neither counting as nor modifying the selection;
- [x] the selection surviving list↔feed switches and resetting when a new folder is opened;
- [x] large folders (10k+) scrolling, selecting, and switching without stalls (design §7(2): 60 fps
      scroll with ≤ 1 ms row `body` — Instruments on escalation, skill §6);
- [x] switching to the list mid-playback keeping the audio playing, and returning to the feed
      landing on the same item at the same position, still playing (design §5.3);
- [x] activating the already-current row **not** restarting its playback (design §4);
- [x] and the media files byte-identical on disk after all of the above (S14 — this is a UI story,
      so functional review is part of the done gate).

### 7.1 · Review result — 2026-10-15 (stakeholder functional review; AC8, converge-owned)

The stakeholder exercised the app (`./scripts/app.sh run`). First pass: the checklist items 1–7 above
all behaved as specified (7/7), with the playback-activation blocker noted against list activation
(double-click/Enter) — activating a row did not start playback, and a stale in-flight scroll gesture
could guard the auto-play start out. After the approved fixes (`fcb1de2`, `b20df5e`, `07a9d57`) and
the design amendments recorded in §8 item 10, a retest of the fresh build (app pid 82706) passed
items 1–10 outright; final acceptance then closed the remaining item 11 (media files byte-identical
on disk) → **11/11 accepted**. This review is the approval for the items that were previously
agent-only: the floating toggle's in-app visibility over **both a video page and an image page**, the
mid-playback switch observation, and the list-opening scroll/highlight behavior. The §7 checklist
above is ticked on that basis — agent evidence supports, stakeholder review approves.

## 8 · Deviations (task 11.7 — honest; marked for coordinator ratification)

1. **The sanctioned Feed edit is the only `Features/Feed/**` change** (design §12(7), D41 — the
   binding stakeholder decision of 2026-10-14, implemented by task 7b, commit `0dd15ad`). Versus
   `main`: `Features/Feed/Presentation/FeedItemView.swift` (+102) and
   `Features/Feed/Presentation/FeedViewModel.swift` (+35) — the poster-page mouse-move tracker, the
   `isChromeDemanded` demand signal and its lifecycle resets. No control-bar file, layout, or
   behavior changed (`PlaybackControlBarView.swift` has an empty diff). The story's original "zero
   Feed diff" rule is relaxed for exactly this one edit — recorded here and in D41, not a silent
   change.
   **Demand-trigger superset (validator gap 3, 2026-10-15):** the 7b flag described demand rising
   only over `.loading`/`.unavailable` placeholders; the shipped code is broader and is recorded
   here as the truth. The tracker wraps **every** `.preview` poster page
   (`FeedItemView.swift:97-119`) — image pages **and video pages at rest** — and
   `FeedViewModel.noteMouseMoved` writes `isChromeDemanded` **before** the live-player gate
   (`FeedViewModel.swift:651-658`), so demand also rises on the pre-wrap placeholder frame ahead of
   that gate; the `.unavailable` (`FeedItemView.swift:120-131`) and `.loading`
   (`FeedItemView.swift:177-181`) case arms mount no tracker. *(Line citations corrected
   2026-10-15, validator review-2 gap 2: 96 is the `switch` line and 120-140 wrongly included the
   head of `.player`.)* The product outcome still matches D41/S4 (toggle on demand over
   both page kinds) — only the previously recorded trigger scope was wrong. No code change follows;
   D41 carries the dated amendment line.
2. **Design §12(4)'s SwiftUI `scrollPosition(id:)` fallback was NOT taken; the jump's in-app
   behavior is not unit-verifiable**: no escalation, no ADR, no silent swap. The first cut
   over-claimed — the `scrollPosition(id:)` binding sat over a bare `LazyVStack` with no
   `.scrollTargetLayout()`, so the id target never resolved and no test could contradict it (the VM
   suite pins only `highlightProjectionIsReadOnly`). The validator's gap-1 finding is fixed by
   adding `.scrollTargetLayout()` (the feed's exact idiom, `FeedView`). The actual in-app jump —
   and its correctness on macOS 26 — remains **not verifiable by tooling** (a unit test cannot
   mount the list or observe a scroll) and therefore rides the stakeholder functional review (§7,
   AC8) — the risk is open, not closed by tests.
3. **`@testable` internals**: the machine suite asserts the `private(set)` reads
   `selectedIDs`/`anchorID`/`leadID`; the perf suite reads view-model state (`collection`,
   `togglePresentation()`). This is the house pattern (`@testable import InstantPlayer`); the
   production contracts are untouched (no test-only members were added to production types). Not a
   design deviation — recorded per 11.7's watch item.
4. **ADR numbering landed exactly as planned**: D39–D42 on top of the log's previous end at D38
   (tasks 9/10 commits `177a142`, `7d5c02e`) — no renumber shift to record (the gate's ADR step
   reports 42 well-formed entries).
5. **UI-test-clause precision (task 11.4)**: the task text's "the launch tests run green unchanged
   within 11.3's gate" is recorded precisely instead — the default gate does not run the UI-test
   target, so §2 quotes the last recorded green launch-test run (E2-S3) and the launch-path-untouched
   diff, making no claim beyond what tooling showed (the E3-S2 §8 item-7 precedent).
6. **Task 7b's in-app observation has no agent-recorded artifact**: the 7b.5 box in `tasks.md` was
   ticked by its implementer, but the spec dir holds no screenshot/note, and this evidence task did
   not re-run the app (the observable surface needs host-driven entry). The button-on-demand-over-
   video-and-image-pages, ⌘L-unaffected, and no-control-bar-change cases are carried by §7's
   checklist and await AC8 — an honest gap, not a claim.
7. **Performance numbers are transient** (the E3-S2 §3 honesty limit, restated in §3): each quoted
   block is one recorded run; p95 values vary run to run. The stable claims are budget compliance
   and the O(1)/O(range) shapes; the ⇧-click full-range row is the tightest (12.7–14.4 ms p95 across
   recorded runs against 16 ms) and is flagged for the validator's RNF-02 pass.
8. **Unowned branch commits**: the branch also carries two `chore(harness)` provider-repoint commits
   (`90d2a82`, `801c2c0`) and the parked E3-S3 spec (`1482e5c`) — harness/parked-story housekeeping
   outside this story's implementation; the D21 audit is unaffected (xcodeproj/Config diff empty).
9. **The S18 reset has a second sanctioned point** (validator review-2 gap 1, 2026-10-15): the
   design originally said `reset()` "runs at exactly one point" (`apply(collection:)`). The gap-2
   fix (`79d7071`, `MediaListViewModel.dismissToWelcome()`) added the welcome-fallback reset when
   the opened folder is left (a failed entry action, E2-S1 S7/S16), so the machine's `reset()` now
   runs at two points. S18's derivation holds unchanged — no selection outlives its rows, and
   nothing is persisted at either point — so this is a recorded artifact correction, not a spec or
   code change (the EARS S18 text is unchanged). Design §3.2/§6.1, D40's amendment line, and §5's
   S16/S18 rows carry the corrected invariant.
10. **Post-review activation amendments (stakeholder-approved 2026-10-15)** — two related records,
   both design-contract level (R11/S12/S13 already require the behavior; this is HOW):
   (a) the functional-review blocker fix (commit `fcb1de2`) made `FeedViewModel.moveTo` run
   `syncPlayback()` after `setIndex`, so list activation auto-plays the landed item — design §4's
   "ordinary arrive-on-item semantics" is now literally true; no contract change, only the mechanism
   recorded (design §4); (b) the new approved contract — **explicit activation outranks stale
   in-flight scroll-gesture state**: opening the list mid-gesture can leave `gestureStartIndex` set,
   which guards the activation's auto-play start out (the same dead-item symptom). Activation must
   cancel/clear stale gesture state before applying arrive-on-item auto-play; settle-gating for
   ordinary scroll paging stays untouched (the feed's gesture semantics remain). Recorded in design
   §4 (with the §10 note that it sits inside D39/D42's scope, no new ADR); clause (b)'s code fix
   landed: `b20df5e` clears `gestureStartIndex` in `FeedViewModel.moveTo(…, isExplicitActivation:)`
   before `setIndex`/`syncPlayback`, and `07a9d57` adds `cancelStaleGestureState()` (clearing
   `gestureStartIndex` only — `FeedViewModel.swift:383`) fired from `MediaListViewModel.presentFeed()`
   via the injected `onPresentFeed` hook bound in `RootView` — so both activation routes clear it, and
   the pure-flip route touches no playback state. That is exactly what landed; nothing further is
   claimed here. §7's double-click/Enter checklist item is unchanged — the contract sat in
   R11/S12/S13 all along.

No other deviation from the approved design exists: signatures, the `MediaListSelection` API and
semantics, the route table, the file inventory, and the budgets match the design §1–§13 as approved
(the two amendments — §5.2/D41's floating toggle and the sanctioned Feed edit — are the approved
amendments, not deviations; item 10's post-review activation amendments of 2026-10-15 are approved
records for the same reason).

## 9 · Acceptance criteria (task 11.8)

Ticked here and mirrored in [tasks.md](tasks.md); AC8 is ticked from the 2026-10-15 functional review
(§7.1); AC9–AC10 are converge-owned and were ticked by the coordinator at converge (2026-10-15).

- **AC1 · product R27 / S1, S2** — the list shows every collected item by file name in the snapshot
  order and nothing else: rows == `collection.items` (count, order, names), non-media files absent,
  stale rows kept honestly with no self-reordering — VM suite `rowsEqualTheCollectionItems`,
  `mixedMediaFixtureShowsNoNonMediaRows`, `rowsNeverChangeAfterApply`; listing/order verified in
  §1's gate; functional review is converge-owned (§7). ✔ for the implementation evidence.
- **AC2 · product R28 / S6–S10** — Finder-grade selection: single click sets without activating,
  ⌘-click toggles membership, ⇧-click extends from the anchor, arrows move and ⇧-arrows extend with
  clamping at both ends and no wrap, empty-click clears — machine suite (11 rows, §5) + the §3
  selection budget; functional review is converge-owned. ✔ for the implementation evidence.
- **AC3 · product R29 / S11, S18 / S14** — one ephemeral ad-hoc group: selection survives
  list↔feed switches within the opened folder (VM suite `toggleFlipsPresentationOnlyAndLeavesSelectionUntouched`),
  resets only at the two sanctioned points — a new folder opened (`applyResetsOnlyOnANewSnapshotValue`)
  and the opened folder left for the welcome fallback (`welcomeFallbackDismissesTheListAndResetsTheSelection`,
  `applyingASnapshotAgainAfterTheWelcomeFallbackRebuildsTheRows`) — and nothing is
  written or persisted anywhere (D21 audit §4 + §8.1 walk §4.1 — empty config diff, no
  `UserDefaults`/bookmark/pasteboard/write anywhere); files byte-identical in review is
  converge-owned. ✔ for the implementation walk.
- **AC4 · S3–S5, S12, S13, S17 / product R37 (context)** — ⌘L and the on-screen button both flip
  list/feed in the same single window with the collection unchanged (key tests + `RootView` switch);
  double-click and Enter each switch to the feed positioned on that item
  (`activationEmitsTheRightIntentAndNeverMutatesSelection`, `listPresentedEnterActivatesTheLeadRow`),
  and activating the already-current row is presentation-only (`activationOfTheAlreadyCurrentItemEmitsNothing`,
  no `moveTo`/`startPlayback`/`restart()`); the list opens scrolled to and highlighting the feed's
  current item without that highlight counting as or modifying the selection
  (`highlightProjectionIsReadOnly` — the machine has no API for it). ✔ for the pins/unit evidence;
  functional review is converge-owned.
- **AC5 · S15 / product R16 share / RNF-02** — budgets met and measured: the 10k `measure` recorded
  from tooling against §7 (switch p95 1.514 ms ≤ 100 ms; 50k p95 7.265 ms ≤ 300 ms; selection
  ≤ 16 ms — single click 0.003 ms, ⌘-click 0.009 ms, ⇧-click 12.675 ms; no backlog — 30-key burst
  0.264 ms) (§3); 60 fps scroll with ≤ 1 ms row `body` is functional-review/Instruments territory
  (§7); large folders fluid in review is converge-owned. ✔ for the measured/unit evidence.
- **AC6 · S16 / product R17 via S14 / RNF-04 + UI-test decision** — welcome state byte-for-byte
  unchanged with no list/toggle/selection reachable from it (the list model exists only with the
  folder-open snapshot; welcome route rows pass through); display-only listing with zero writes and
  no new access paths (D19 session not re-derived; §4.1 greps) — the empty config diff (§4) and the
  unchanged four-key entitlement posture; the UI-test-mandate decision recorded (default gate scope,
  no `--uitests` obligation, honest caveat, §2); full gate `--json` quoted verbatim (§1).
  ✔ for the implementation evidence.
- **AC7 · evidence & coverage** — the S1–S18 + product R-map walk recorded (§5, §6); ADRs D39–D42
  in `docs/decisions.md` house format with the design §10 titles (verified in the commit diff;
  gate ADR step: 42 well-formed); `docs/architecture.md` updated per §12(1) (incl. the §4 check-3
  verdict and the no-new-actor note — both present in the task-8 commit `9fd564c`); all deviations
  listed honestly (§8). ✔

Converge-owned — the coordinator ticks these; task 11 never does:

- [x] **AC8 · stakeholder functional review** (this is a UI story): in the running app
      (`./scripts/app.sh run`) — the §7 checklist carried from the spec's AC list and design §9.5.
      Explicit approval required. — **passed 2026-10-15; 11/11 accepted (§7.1)**.
- [x] **AC9 · validator review** — adversarial PASS over spec S1–S18 and the product R-map, the
      design §8.1 review table, §9's test tables, and both pillar-skill checklists. — **PASS,
      2026-10-15** (initial gaps closed via fix loops 1–2; review 3 PASS; delta passes confirmed
      the functional-review fixes).
- [x] **AC10 · story closure** — backlog E5-S1 → `done`; `git merge --no-ff` into `main`; delete
      `feat/e5-s1-list-view-selection`. — **executed at converge, 2026-10-15** (backlog updated in
      the final branch commit; merge + branch deletion by the coordinator immediately after).

## 10 · Spec acceptance checklist — mirrored state (task 11.8)

The [spec](spec.md)'s own acceptance checklist, mirrored with its current tick state: the five
spec-side authoring items are met (the gate-evidence item backed by §1's quoted JSON); the
stakeholder functional review and the approval gate are converge-owned and stay unticked:

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
      other product requirement is claimed here (R27–R29 assigned; R37, R9–R10, R34–R36, R16, R17
      only as inherited/context contracts — §6).
- [x] The selection seam is explicit and testable: one current selection (S6), Finder-standard
      multi-select mechanics (S7–S9), empty-click clearing (S10), one ad-hoc group never persisted
      (S11, S18) — and the spec claims no operation on it.
- [x] Snapshot honesty is explicit (S2): the list neither invents live sync (E4-S2) nor breaks on
      stale rows — `rowsNeverChangeAfterApply`.
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json
      /tmp/e5s1-gate.json`, quoted verbatim in §1; the converge run keeps the default gate scope.
- [x] The two `[NEEDS CLARIFICATION]` markers are resolved — by binding stakeholder answers, now
      normative as S17 (list opens scrolled to and highlighting the feed's current item, without
      that highlight counting as or modifying the selection) and S18 (selection survives list↔feed
      switches, resets only on a new folder, never persisted).
- [ ] Stakeholder functional review in the running app — the §7 checklist (converge-owned).
- [ ] This spec passes the stakeholder approval gate (converge-owned).
