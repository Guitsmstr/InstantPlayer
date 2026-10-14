# E5-S1 · List view & selection — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S18 over product R27–R29; R37, R9–R10, R34–R36, R16, R17 as context/inherited contracts).
Branch: `feat/e5-s1-list-view-selection` — verified checked out at authoring; never switch branches
mid-story. One task = one commit. Checkboxes are ticked during implementation, each task's boxes in
its own commit (bookkeeping — not a second deliverable). Evidence lives in a per-story
`evidence.md` (the [E3-S2 precedent](../e3-s2-playback-speed/tasks.md)).

## Standing rules (every task)

1. **Pillars first (D5):** every code/test task (1–7) loads BOTH skills — `swift-security` and
   `swift-performance` (`.pi/skills/`) — **before editing**. Both pillars are directly in play: the
   list reads user file names display-only from in-memory snapshot values (RNF-04, S14) and is a
   long-list surface with strict open/scroll/select/switch budgets (RNF-02, S15 — design §7, §8).
   Each task repeats the load step so it cannot be skipped.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy.
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source; the
   SwiftLint and SwiftFormat gate steps must pass. Never edit the configs to make code pass.
4. **Synchronized groups / D21:** new source files land under `InstantPlayer/Features/MediaList/**`
   and `InstantPlayerTests/**` and join their targets automatically — **no manual
   `project.pbxproj` edit, ever.** This story needs **no** config change (design §1.1, §8): no
   entitlements, no Info.plist keys, no build settings — the D21 audit expects a **zero
   project-config diff** (checked in task 11). If anything appears to need one, **stop and report —
   a coordinator escalation (D21), never an implementer edit.**
5. **Gate:** code/test tasks 1–7 run the **full** `./scripts/validate.sh` — build + unit tests,
   never `--staged`. Docs tasks 8–10 stage first, then run `./scripts/validate.sh --staged`. Task 11
   runs the full gate with `--json` for evidence. Fix every failure before moving on; the pre-commit
   hook re-runs the gate on every commit. `--no-verify` is forbidden. **Default gate scope
   throughout — no `--uitests` obligation** (the spec's UI-test-mandate decision: launch flows are
   untouched and the entire surface is unreachable without host-driven entry; design §9).
6. **Contracts are frozen:** the design §3 `MediaListSelection` API and §3.1 semantics table
   (set / toggle / range-extend / move / extend-move / clear / reset; anchor + lead rows; clamps,
   no wrap, idempotent boundary repeats), §3.3's highlight-is-not-selection (no machine API accepts
   it), §4's activation semantics incl. the **no-restart rule** for the already-current row, §5.1's
   route rows (⌘L = keyCode 37 with `.command`, claimed from the pass-through set — a recorded
   contract change; list rows only while the list is presented; feed rows only while the feed is
   presented and behavior-frozen; welcome passes through; every other ⌘/⌥/⌃ combo still passes
   through), §5.2's toggle surface ("List"/"Feed" + system icon; minimal top bar in the list;
   demand-driven strip over the feed), §5.3's playback continuation (a list↔feed switch is
   **neither teardown nor revisit** — no `stop()`, no `startPlayback`, no `restart()` on any such
   switch), §6.1's wiring shape, the §7 budgets (switch ≤ 100 ms p95 to 10k items / ≤ 300 ms p95 at
   50k; selection ≤ 16 ms; 60 fps scroll with ≤ 1 ms row body; the 10k `measure`), and the §8.1
   review table. Name/signature/semantic changes are design amendments: stop and report to the
   coordinator, never deviate silently. Same for any design §0 fact that no longer holds.
7. **No invented behavior:** spec non-goals hold — no file operations (E5-S2: no operation buttons,
   context-menu actions, dialogs, Trash interaction, Finder reveal), no ordering modes (E4-S1), no
   live sync (E4-S2 — rows are immutable per snapshot, S2), no playback controls/thumbnails/metadata
   columns/search/headers in rows, no pasteboard copies, no Quick Look, no persistence of anything
   (`UserDefaults`/`@AppStorage`/bookmarks — S11, S14, S18), no new access paths (the D19 session is
   never re-derived; names come from the in-memory snapshot), no logging of names or paths (D20), no
   networking (D9), no beep ever (D28), welcome state untouched (S16).
8. **Feed is effectively untouched (design §1):** `Features/Feed/**` changes nothing — the list
   consumes `MediaCollection`, `FeedViewModel.currentItemID`, and `FeedViewModel.moveTo(itemID:)`
   exactly as shipped (S5's "no feed contract altered" is structural). This story's `App/` touch
   points are `FeedKeyCommand`, `AppDelegate`, `AppDependencies`, `RootView`. If any Feed edit
   appears necessary (e.g. the feed-side toggle placement), **stop and report** — a design
   amendment, not an implementer call.

## Sequencing & parallelism

- **Wave 1 — task 1** (Domain selection machine + the Data placement note): everything consumes the
  machine value.
- **Wave 2 — tasks 2 and 3 `[P]`**: the machine suite (2) tests only task 1's file; the presentation
  layer (3) consumes it — disjoint file sets, both depend only on 1.
- **Wave 3 — tasks 4, 5, 7 `[P]`**: the view-model/lifetime/parity suite (4) and the budget measure
  (7) test tasks 1/3's files; the key router (5) is `App/` code over task 3's policy. **Test
  placement note (the E3-S2 rule):** a test commit cannot gate-green before the code it tests is
  committed, so each suite sits in the wave immediately after its code — except task 5, which
  carries its own frozen-table pins in the same commit (the table's tests are its contract; the
  E3-S2 task-6 precedent).
- **Wave 4 — task 6** (wiring) alone: it mounts task 3's views, feeds task 5's registration, and
  owns the S18 reset funnel and the §5.3 switch policy.
- **Wave 5 — tasks 8 `[P]` and 9**: the architecture reference (8) and the first ADR batch (9) are
  transcription of the approved design into two different docs files, after all code.
- **Wave 6 — task 10** (second ADR batch): the ADR log is one file, so the two batches land in
  numbering order — task 10 follows task 9 and is **not** marked `[P]` against it.
- **Task 11 is last** and depends on everything else.
- **UI tests: none exist by design (§9)** — the UI-test-mandate decision (flows not affected; the
  surface is unreachable without host-driven entry) is carried, never re-decided. Selection behavior
  is carried by unit tests (tasks 2, 4, 5, 7) + stakeholder functional review; task 11 records the
  decision and the honest caveat.
- Routing (D3 — coordinator's call): tasks 1–7 → `implementer` (contract-bound code; both skills
  mandatory); tasks 8–10 → docs-transcription assignees — **task 8 needs write access to
  `docs/architecture.md`, outside the spec-author's permissions (design §12(1)): the coordinator
  assigns it to an implementation agent with docs write access** (the E3-S2 task-8 precedent);
  task 11 → `implementer` (evidence discipline).

---

## Task 1 — MediaList Domain: selection machine + Data placement note · design §1, §3, §1.1

**Intent:** land the one selection concept of product R28 — the pure state machine that is also the
E5-S2 seam — and create the empty Data layer with its placement note. Deliverable (code):
`InstantPlayer/Features/MediaList/Domain/MediaListSelection.swift` (new),
`InstantPlayer/Features/MediaList/Data/Data.md` (new, placement note only — no conformance this
story). **Covers:** S6–S11, S18 (machine semantics), S14 (a pure in-memory value writes nothing).

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** `MediaListSelection` exactly per design §3: `nonisolated struct` with
  `private(set) var selectedIDs: Set<MediaItem.ID>`, `anchorID`/`leadID: MediaItem.ID?`, and the
  seven mutating ops (`select`, `toggle`, `extend(to:over:)`, `move(_:over:)`, `extend(_:over:)`,
  `clear`, `reset`) over `[MediaItem.ID]` rows. §3.1 semantics exactly: single click sets
  {R}, anchor = lead = R and never activates (S6); ⌘-click flips membership, rest preserved,
  anchor = lead = R (S7); ⇧-click = the contiguous anchor…target range in row order, lead = R,
  anchor unchanged, no anchor ⇒ select (S8); arrows move to the adjacent row collapsing to the lead,
  ⇧-arrows move the lead and select anchor…lead — clamp at first/last row, never wrap, idempotent
  boundary repeats (S9); `clear()` drops rows and anchor/lead (S10); `reset()` empties everything
  (S18). Membership O(1) via `Set`; range ops O(range). Pure value — no SwiftUI, no AppKit; the
  file joins the target through synchronized groups (D21) — **no pbxproj edit**.
- [x] **1.3** `Data/Data.md` per design §1.1: the placement note — MediaList Data is deliberately
  empty this story (the list performs no I/O); E5-S2's operations seam conformances land here.
- [x] **1.4** **Done:** full gate `./scripts/validate.sh` green — the new type compiles into the app
  target (that proves target membership) and the note is committed. Commit:
  `feat(e5-s1): task 1 — MediaList selection machine`.

## Task 2 — Selection-machine suite `[P]` · design §9.1

**Intent:** pin the Finder-grade mechanics as pure value tests — the spec's AC that selection needs
no mouse hardware. Deliverable (tests):
`InstantPlayerTests/Features/MediaList/MediaListSelectionTests.swift` (new). **Covers:** S6–S11,
S18.

- [ ] **2.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **2.2** §9.1 rows over generated row arrays (Swift Testing house pattern — `@testable import
  InstantPlayer`, `@Test` + `#expect`; no view hierarchy, no mouse): single click sets and never
  activates (S6); ⌘-click toggles preserving the rest (S7); ⇧-click builds the anchor…target range
  and keeps the anchor (S8); arrows move and collapse to the lead, ⇧-arrows extend from the anchor
  (S9); clamping at both ends, no wrap, idempotent boundary repeats (S9); empty-click clears (S10);
  `reset()` empties everything (S18).
- [ ] **2.3** **Done:** full gate green with the new suite running. Commit:
  `test(e5-s1): task 2 — selection machine tests`.

## Task 3 — MediaList Presentation: view model + list surface + toggle control `[P]` · design §2, §3.2, §3.3, §4, §5.2, §6.1

**Intent:** the presentation layer — one view model owning the selection value, the toggle, the
applied snapshot and the activation intent; the lazy list surface; the row; the one toggle button.
Deliverable (code): `InstantPlayer/Features/MediaList/Presentation/MediaListViewModel.swift`,
`MediaListView.swift`, `MediaListRowView.swift`, `ViewToggleControl.swift` (all new).
**Covers:** S1, S2, S3–S5 (toggle + switch surfaces), S6–S10 (gesture forwarding into the machine),
S12–S13 (activation intent), S16, S17.

- [ ] **3.1** Load `swift-security` + `swift-performance` before editing (SwiftUI view cost + the
  long-list surface — skill §2 directly).
- [ ] **3.2** `MediaListViewModel` (`@MainActor @Observable`) per design §3.2/§6.1: holds the one
  `MediaListSelection` value; `togglePresentation()` flips presentation only (S5/S18 are structural —
  selection untouched); `apply(collection:)` runs `reset()` **only when a new snapshot value
  arrives** (§3.2's single reset point); gesture-forwarding methods delegate to the machine; the
  activation intent is an injected callback (`activate(itemID:)`) — the model never references
  `FeedViewModel` (D7; §4's cross-feature mediation).
- [ ] **3.3** Highlight per design §3.3 (S17): a derived, read-only projection of the feed's
  `currentItemID` onto the rows — a rendering input the machine has no API to accept; on
  presentation `MediaListView` programs `scrollPosition(id:)` to that row as a **direct jump, no
  animation** (§7(1)). Flag the §12(4) scroll-position risk for the coordinator's first functional
  spike; if macOS 26 misbehaves, escalate early — §12(4)'s fallbacks are an ADR, never a silent swap.
- [ ] **3.4** Surface per design §2 (S1, S2, S15): `ScrollView` + `LazyVStack` (§0 fact 1 — the
  chosen alternative, §11), rows = `collection.items` in array order showing `item.name`, identity
  `MediaItem.ID`, rows immutable per snapshot; `MediaListRowView` = one `Text(name)` + selection /
  highlight styling + two O(1) membership checks (≤ 1 ms `body`, §7(2)). No sorting, headers,
  grouping, thumbnails, metadata columns, or per-row controls (non-goals).
- [ ] **3.5** `ViewToggleControl` per design §5.2 (S4, S16): one button bound to
  `togglePresentation()`, label flipping "List"/"Feed" with the corresponding system icon (constant
  copy), in the list's minimal top bar (always visible) and over the feed riding the demand-driven
  overlay strip — placed **without editing `Features/Feed/**`** (standing rule 8; a Feed edit = stop
  and report). Nothing renders in the welcome state (S16).
- [ ] **3.6** **Done:** full gate green — the app compiles with the MediaList feature present and
  the welcome/feed surfaces byte-for-byte unchanged. Commit:
  `feat(e5-s1): task 3 — MediaList presentation layer`.

## Task 4 — View-model, lifetime & list-parity suite `[P]` · design §9.2, §9.4 (parity)

**Intent:** prove the S17/S18 guarantees mechanically and the R34–R36 parity by construction.
Deliverable (tests): `InstantPlayerTests/Features/MediaList/MediaListViewModelTests.swift` (new).
**Covers:** S1, S2, S5, S12, S17, S18, S14.

- [ ] **4.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **4.2** §9.2 rows (injected seam doubles — the E2-S3 house pattern; no UI, no window): toggle
  flips presentation only and leaves selection untouched (S5, S18); `apply(collection:)` with a new
  snapshot resets selection, the same snapshot does not (S18); the highlight projection is
  read-only — selection equality asserted across highlight changes (S17); activation emits the right
  `MediaItem.ID` intent and never mutates selection (S12); activation of the already-current item
  emits **no** `moveTo`/`startPlayback`/`restart()` (§4, §5.3) while a different item does; toggling
  presentation never touches the playback session (§5.3).
- [ ] **4.3** §9.4 parity rows (S1, S2; product R34–R36 parity): rows == `collection.items` — same
  count, same order, same names; a mixed fixture folder shows no non-media rows; no row gains,
  drops, or reorders after `apply` (S2's honest snapshot).
- [ ] **4.4** **Done:** full gate green. Commit:
  `test(e5-s1): task 4 — list view-model, lifetime, and parity tests`.

## Task 5 — Key-command routing: ⌘L + list rows `[P]` · design §5.1, §9.3

**Intent:** extend the frozen routing table and its monitor — the one keyboard path (D22/D28) —
with the toggle row and the list rows, with the table's pins in the same commit. Deliverable
(code): `InstantPlayer/App/FeedKeyCommand.swift` (grown), `InstantPlayer/App/AppDelegate.swift`
(grown), `InstantPlayer/App/AppDependencies.swift` (minimal registration property),
`InstantPlayerTests/App/FeedKeyCommandTests.swift` (grown). **Covers:** S3, S5, S9, S13, S16.

- [ ] **5.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **5.2** Route table per design §5.1: a `.toggleView` row for **⌘L** (keyCode **37** =
  `kVK_ANSI_L`, with `.command`) in the folder-open state in **both** presented views — **recorded
  contract change:** ⌘-modified keys previously passed through; ⌘L is now claimed while every other
  ⌘/⌥/⌃ combo still passes through. List-presented rows: ↑/↓ (126/125) → `moveSelection`,
  ⇧-↑/⇧-↓ → `extendSelection` (in the list ⇧ **is** the extend modifier — the router's "⇧ alone
  does not modify" rows invert here), Enter (36; keypad **76**) → `activateLeadRow`, ←/→ (123/124)
  → consumed quiet no-ops (single-column list — D28's never-beep rule). The feed rows (space 49,
  ←/→ seek, `[`/`]` speed, ↑/↓ paging) route **only while the feed is presented** and stay
  behavior-frozen (S5's never-compete rule); welcome → everything passes through (S16 — the
  `hasOpenFeed` guard generalizes to presented-state input). Auto-repeat = repeated calls (D38
  parity; the machine clamps idempotently).
- [ ] **5.3** `AppDelegate`'s monitor switch dispatches the new commands to the registered
  `activeListModel` (the weak `activeFeedModel` pattern, D10); the minimal weak registration
  property on `AppDependencies` lands in this commit as the compile enabler — the factory and
  `RootView` wiring are task 6. No new delivery mechanism (D28).
- [ ] **5.4** Pins per design §9.3 **in this same commit** (the frozen table's tests are its
  contract — the E3-S2 task-6 precedent): 37+⌘ toggles in both presented views and passes through
  in welcome; the list-presented and feed-presented row sets never overlap; 36/76 activate the lead
  row; 123/124 list-presented are consumed no-ops while their feed-presented seek rows stay green;
  all other ⌘/⌥/⌃ combos pass through; auto-repeat parity rows. **No existing pin changes.**
- [ ] **5.5** **Done:** full gate green. Commit:
  `feat(e5-s1): task 5 — list keyboard rows and ⌘L on the key router`.

## Task 6 — Composition wiring: factory, root switch, activation mediation · design §6.1, §4, §5.3

**Intent:** wire the story end to end in `App/` — the sanctioned factory, the root-owned
presentation switch, the snapshot funnel (S18's reset point), and the activation mediation.
Deliverable (code): `InstantPlayer/App/AppDependencies.swift` (factory),
`InstantPlayer/App/RootView.swift`. **Covers:** S3, S5, S12, S13, S17, S18.

- [ ] **6.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **6.2** `AppDependencies.makeMediaListViewModel()` — the allocation-only factory (D10)
  recording the instance weakly as `activeListModel` for the key monitor. Nothing runs at launch
  (§7(6) — the list model is created with the folder-open state; `testLaunchPerformance` intact).
- [ ] **6.3** `RootView`'s three routings per design §6.1: each new `MediaCollection` (the existing
  `handle(entryAction:)` completion funnel) → `apply(collection:)` (the S18 reset point); row
  activation → `FeedViewModel.moveTo(itemID:)` + presentation to the feed — **except** activation of
  the feed's current item: a pure presentation flip, never `moveTo`/`startPlayback`/`restart()`
  (§4, §5.3's no-restart rule); presentation state → which feature view is mounted, with the
  playback session alive below the switch (§5.3 — a switch is neither teardown nor revisit; no
  `stop()`/`startPlayback`/`restart()` on any list↔feed switch). The list model receives
  `currentItemID` as a read-only value (S17).
- [ ] **6.4** Feed untouched (standing rule 8) and welcome untouched (S16) — structural, not a
  review promise.
- [ ] **6.5** **Done:** full gate green; in the running app (`./scripts/app.sh run`) switching to
  the list mid-playback keeps the audio playing and returning to the feed lands on the same item at
  the same position, still playing (the §9.5 first observation). Commit:
  `feat(e5-s1): task 6 — composition wiring for the list view`.

## Task 7 — Budget check: 10k-item measure (RNF-02) `[P]` · design §7(1)–(3), §7(7), §9.4

**Intent:** make the RNF-02 budgets deterministic and measured — the explicit budget-check task.
Deliverable (tests): `InstantPlayerTests/Features/MediaList/MediaListPerformanceTests.swift` (new —
XCTest `measure`, the E3-S2 §8 deliberate-exception pattern). **Covers:** S15.

- [ ] **7.1** Load `swift-security` + `swift-performance` (performance is the whole task).
- [ ] **7.2** Per design §7(7): a unit performance test through the selection machine + row
  projection over generated fixture collections of **10 000 synthetic `MediaItem`s** in an XCTest
  `measure` block — covering the §7(1) switch path (state flip + row projection), the §7(3)
  selection-change path (single/⌘-click O(1) ops, ⇧ range ops), and the arrow-repeat step path
  (idempotent boundary clamps, no backlog).
- [ ] **7.3** Budgets asserted/reported per design §7: switch ≤ 100 ms p95 to 10k items (≤ 300 ms at
  50k — degenerate extreme reviewed), selection ≤ 16 ms in one main-actor turn, per-row `body`
  ≤ 1 ms at 60 fps. Measured numbers are recorded in task 11 **from tooling, never from memory**.
- [ ] **7.4** **Done:** full gate green with the `measure` output captured for evidence. Commit:
  `test(e5-s1): task 7 — 10k-item budget measure`.

## Task 8 — Architecture reference updates `[P]` · design §12(1)

Deliverable (docs): `docs/architecture.md` — the MediaList arrival rule. Follows the E2-S2–E3-S2
precedent: the standing reference is updated by its own docs commit once the code has landed
(tasks 1–7). **This task needs docs write access outside `docs/specs/`** (the design could not write
this file — the coordinator assigns it accordingly).

- [ ] **8.1** Update `docs/architecture.md` per design §12(1): **§3 source tree** — add
  `Features/MediaList/Domain/MediaListSelection.swift`, `Features/MediaList/Data/Data.md` (placement
  note), `Features/MediaList/Presentation/{MediaListViewModel,MediaListView,MediaListRowView,ViewToggleControl}.swift`;
  re-annotate `App/AppDependencies.swift` (list-model factory + weak registration),
  `App/RootView.swift` (presentation switch, snapshot funnel, activation mediation),
  `App/FeedKeyCommand.swift` (⌘L + list rows), `App/AppDelegate.swift` (dispatch to
  `activeListModel`); note `Features/Feed/**` effectively untouched. **§4 check:** the MediaList
  feature reaches no framework capability (empty Data layer — §1.1) and no new kind crosses a seam —
  record the verdict so the check does not look overlooked. **§8 evolution note:** no new actor
  (D8's trigger unmet — the selection is one value on one `@MainActor` view model).
- [ ] **8.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [ ] **8.3** Stage, then gate `./scripts/validate.sh --staged`; fix; commit:
  `docs(e5-s1): task 8 — architecture reference updates`.

## Task 9 — ADR batch: D39–D40 · design §10

Deliverable (docs): `docs/decisions.md` — append the first two ADRs of design §10.

- [ ] **9.1** Append **D39 and D40** continuing the numbering from the log's current end (AGENTS.md
  rule 6). The design §10 plans D39–D42 and at authoring the log ends at **D38**, so the next free
  numbers are **D39, D40**; if the log moves before this task runs, use the next free numbers and
  record the shift in task 11's deviations list (the E3-S1/E3-S2 renumber precedent). House heading
  `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each with context, decision,
  alternatives, consequences; status `accepted`; consequences cite the implementing task commits
  (tasks 1–6). **Titles and one-line decisions exactly per design §10:**
  **D39 — List keyboard routing on the App-owned router: ⌘L claims a command-modified key (the
  pass-through contract changes again), list-presented rows re-purpose ↑/↓/Enter with ⇧ as the
  extend modifier — one pure table, one monitor, test-pinned codes** (→ S3, S5, S9, S13, S16) ·
  **D40 — List surface: custom `ScrollView` + `LazyVStack` with a view-model-owned Finder-semantics
  selection, over `List`/`NSTableView`; includes the `MediaListSelection` Domain machine and the
  root-owned presentation switch** (→ S1, S2, S6–S11, S17, S18).
- [ ] **9.2** Alternatives from the matching design rows — D39: `.keyboardShortcut` on the toggle
  button and SwiftUI focus delivery (§5.1, §11, §0 fact 3 — rejected for consistency and
  testability, the D22 lesson); D40: `List` with its built-in selection, `NSTableView` behind
  `NSViewRepresentable` (the named §12(3) fallback), selection state inside `FeedViewModel`,
  diffing/observing the folder for live rows (E4-S2's scope), persisting the selection (§11 —
  foreclosed by product R29).
- [ ] **9.3** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; commit:
  `docs(e5-s1): task 9 — ADRs D39–D40 — list keyboard routing and list surface`.

## Task 10 — ADR batch: D41–D42 · design §10

Deliverable (docs): `docs/decisions.md` — append the remaining two ADRs of design §10. Follows
task 9 in numbering order (the log is one file — not parallel with task 9).

- [ ] **10.1** Append **D41 and D42** (same numbering rule as 9.1 — if the log moved, next free
  numbers, shift recorded in task 11). **Titles and one-line decisions exactly per design §10:**
  **D41 (minor) — Chrome policy extension: the view-toggle button rides the demand-driven overlay
  strip on the feed and a minimal top bar in the list** (→ S4) · **D42 — Playback continues across
  the list↔feed switch: the presentation switch is neither a teardown point nor a D25 revisit — the
  session survives the hidden surface, same item and position on return, and activation of the
  already-current row is presentation-only (no restart)** (→ S5, S12, S13; §5.3).
- [ ] **10.2** Alternatives from the matching design rows — D41: a keyboard-only toggle (rejected —
  S4 demands a visible button), always-visible chrome over the feed (rejected — the chrome-free /
  demand-driven policy of D27, E2-S2 S14, D33 that §5.2 preserves), a second window or palette
  (rejected — D18's one window); D42: the former planning default — teardown-on-disappear +
  D25 restart-on-revisit — and pausing on switch-to-list (both rejected by the stakeholder, §5.3).
  Each entry cites its implementing task commits in its consequences; D39 records the frozen-table
  contract change (⌘L claimed from the pass-through set); D42 records the no-restart rule for the
  already-current row.
- [ ] **10.3** Stage, then gate `./scripts/validate.sh --staged`; fix; commit:
  `docs(e5-s1): task 10 — ADRs D41–D42 — chrome extension and playback continuation`.

## Task 11 — Verification & evidence · spec acceptance criteria, design §7–§10, §13

Deliverable (docs): `docs/specs/e5-s1-list-view-selection/evidence.md` (new — the E3-S2 precedent)
+ acceptance-criteria ticks in this file.

- [ ] **11.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **11.2** Traceability walk: **S1–S18 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product R-map**
  of the spec's acceptance table (product R27–R29 → story outcome → verified by; product R37,
  R9–R10, R34–R36, R16, R17 carried as context/inherited notes, never claimed). Record both tables
  in evidence.md.
- [ ] **11.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/gate.json` (`<tmp>` = session temp dir outside the repo; the
  JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every step name
  and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [ ] **11.4** **UI-test mandate (spec Story context; R14 of E1-S2):** record the decision — flows
  are **not** affected, the converge run keeps the **default gate scope with no `--uitests`
  obligation** ([docs/development.md](../../development.md) §3) — together with the spec's honest
  caveat (even a `--uitests` run could not open the list view: no media is open in the launch tests)
  and the fact that `testLaunchPerformance` and the launch tests run green unchanged within 11.3's
  gate.
- [ ] **11.5** Record from tooling, never from memory: (a) the design §7 budget measurements —
  task 7's `measure` numbers against §7(1) (switch ≤ 100 ms p95 to 10k, ≤ 300 ms at 50k), §7(3)
  (selection ≤ 16 ms; arrow-repeat step path backlog-free), with §7(2)'s 60 fps / ≤ 1 ms row-body
  verified by functional review (Instruments on escalation — skill §6); (b) the **D21 audit**
  (design §1.1, §8, §12(1)) — `git diff main...HEAD --stat` restricted to
  `InstantPlayer.xcodeproj/ InstantPlayer/Config/` showing **no changes** (empty output quoted) and
  the `codesign -d --entitlements` output showing D19's four read-only keys unchanged; (c) the
  design §8.1 sandbox/media-read review table walked row by row (no new access paths, no writes, no
  persistence, no bookmarks, no pasteboard, no logging, no dependencies, no required-reason API).
- [ ] **11.6** Functional-review checklist: carry the spec's AC list and the design §9.5 list
  verbatim into evidence.md (the mixed folder listed by name in the feed's order with non-media
  files absent; ⌘L and the button toggling both ways in the same window; click/⌘-click/⇧-click/
  arrows/⇧-arrows/empty-click selection with clamping at both ends; double-click and Enter each
  landing on the item in the feed; the S17 opening highlight that is not a selection; selection
  survival across switches and reset on a new folder; large folders scrolling, selecting, and
  switching without stalls; media files byte-identical on disk after all of the above — S14; plus
  §9.5's two additions: switching to the list mid-playback keeping the audio playing and returning
  to the feed landing on the same item at the same position still playing, and activating the
  already-current row not restarting its playback) as the checklist the stakeholder exercises in
  `./scripts/app.sh run` — functional evidence is recorded as what was exercised and observed in the
  running app (screenshot paths may be recorded, never read back into context); agent-recorded
  evidence is supporting material, never the approval.
- [ ] **11.7** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, budgets) with its impact, marked for coordinator ratification — silently deviating is
  forbidden (standing rule 6). Specifically watch for: the §12(4) scroll-position fallback if taken
  (an escalation/ADR, never a silent swap); any `@testable` internals used in conformance-style
  assertions; and the ADR numbering (D39–D42 vs the log's next free numbers if it moved — tasks
  9.1/10.1).
- [ ] **11.8** Tick AC1–AC7 below and mirror them in evidence.md; leave the converge-owned AC8–AC10
  unticked. Confirm the spec's acceptance checklist is mirrored into evidence.md with its tick state
  (the spec-side items met; the functional-review and approval-gate boxes are coordinator-owned and
  stay unticked).
- [ ] **11.9** Commit (docs-only; stage first, the hook runs the gate):
  `docs(e5-s1): task 11 — evidence and acceptance`.

---

## Acceptance criteria

Ticked by task 11, each backed by quoted tooling evidence:

- [ ] **AC1 · product R27 / S1, S2** — the list shows every collected item by file name in the
  snapshot order and nothing else: rows == `collection.items` (count, order, names), non-media files
  absent, stale rows kept honestly with no self-reordering — parity suite + functional review.
- [ ] **AC2 · product R28 / S6–S10** — Finder-grade selection: single click sets without activating,
  ⌘-click toggles membership, ⇧-click extends from the anchor, arrows move and ⇧-arrows extend with
  clamping at both ends and no wrap, empty-click clears — machine suite + functional review.
- [ ] **AC3 · product R29 / S11, S18 / S14** — one ephemeral ad-hoc group: selection survives
  list↔feed switches within the opened folder, resets only when a new folder is opened, and nothing
  is written or persisted anywhere (D21 audit + §8.1 walk + files byte-identical in review).
- [ ] **AC4 · S3–S5, S12, S13, S17 / product R37 (context)** — ⌘L and the on-screen button both flip
  list/feed in the same single window with the collection unchanged; double-click and Enter each
  switch to the feed positioned on that item, and activating the already-current row is
  presentation-only (no playback restart); the list opens scrolled to and highlighting the feed's
  current item without that highlight counting as or modifying the selection — routing pins +
  view-model suite + functional review.
- [ ] **AC5 · S15 / product R16 share / RNF-02** — budgets met and measured: the 10k-item `measure`
  recorded from tooling against §7 (switch ≤ 100 ms p95 / ≤ 300 ms at 50k; selection ≤ 16 ms;
  60 fps scroll with ≤ 1 ms row body per functional review); large folders fluid in review.
- [ ] **AC6 · S16 / product R17 via S14 / RNF-04 + UI-test decision** — welcome state byte-for-byte
  unchanged with no list/toggle/selection reachable from it; display-only listing with zero writes
  and no new access paths (D19 session not re-derived); the UI-test-mandate decision recorded
  (default gate scope, no `--uitests` obligation, honest caveat); full gate `--json` quoted verbatim
  (lint/format `pass`).
- [ ] **AC7 · evidence & coverage** — the S1–S18 + product R-map walk recorded; ADRs D39–D42 in
  `docs/decisions.md` house format with the design §10 titles; `docs/architecture.md` updated per
  §12(1) (incl. the §4 verdict and the no-new-actor note); all deviations listed honestly.

Converge-owned — the coordinator ticks these; task 11 never does:

- [ ] **AC8 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — the task 11.6 checklist carried from the spec's AC list and design
  §9.5. Explicit approval required.
- [ ] **AC9 · validator review** — adversarial PASS over spec S1–S18 and the product R-map, the
  design §8.1 review table, §9's test tables, and both pillar-skill checklists.
- [ ] **AC10 · story closure** — backlog E5-S1 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e5-s1-list-view-selection`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review in the running app (`./scripts/app.sh run`): the AC8
   list (task 11.6's checklist).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S18 / product R-map,
   §7 budgets, and §8.1's review table.
3. **Converge run** — `./scripts/validate.sh` (**default scope** — the UI-test-mandate decision:
   flows are not affected; no `--uitests` obligation for this story) alongside the functional
   review; its output is the story's final gate record.
4. **Closure** — tick AC8–AC10, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §6.2/§12(6): **E5-S2** acts on `MediaListSelection` — the single seam
this story defines — through a MediaList Domain operations seam (working name `MediaItemOperations`)
with the first real `Features/MediaList/Data/` conformances (zip/move/reveal/trash under D16's
never-rewrite rule and its own read-write entitlement decision). The router's table has room for
more rows (D28's frozen pattern; D39 is the fourth addition). E4-S2 plugs live updates into
`apply(collection:)` with a `reconcile(rows:)` policy (§6.3) — designed there, not here.

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D38; tasks 9–10 append D39–D42)
- [docs/spec.md](../../spec.md) — product source of truth (product R27–R29; R37, R9–R10, R16, R17,
  R34–R36 context; RNF-02, RNF-04; non-goals)
- [docs/architecture.md](../../architecture.md) — MediaList feature layout (D7–D10); task 8 applies
  design §12(1)
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E5-S1) and the E2–E5 coverage note
- [e3-s2 tasks](../e3-s2-playback-speed/tasks.md) — format, evidence, ADR-task, and
  frozen-table-pin precedent
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
