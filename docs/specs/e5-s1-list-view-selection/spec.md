# E5-S1 · List view & selection — Story Spec

## Story context

- **Why this story, why now.** E5's "inspect & organize" epic opens here
  ([docs/backlog.md](../../backlog.md)). Until now the folder-open state is feed-only — one item at a
  time, chrome-free by design (E2-S2 S14). A reviewer with a camera dump needs to see the whole batch
  at once, by name, and mark the items a later action (zip, move, reveal, trash — E5-S2) should act
  on. This story lands the second of product R37's two views — the **list** — and the **selection**
  model it feeds; it lands no file operations at all.
- **What "list view & selection" means end to end.** (Settled interview answers 1–2 plus the binding clarification answers
  on the list's opening state and the selection's lifetime (S17, S18) — bound, no re-litigation.) The list view shows **every media item of the opened collection by file name, in
  the current ordering** (product R27). It is reached and left by a **keyboard toggle (proposed:
  ⌘L) and an on-screen button in the main window**; both flip between list and feed **in the same
  single window** (settled answer 1; product R37). When the list view opens, it scrolls to and
  highlights the feed's current item — a position highlight that does not count as or modify the
  selection (binding answer 1; S17). In the list, a **single click only sets the
  selection**; **double-click or Enter on a focused row activates the row**, switching back to the
  feed positioned on that item (settled answer 2). **Multi-select follows standard macOS
  conventions** — ⌘-click toggles membership, ⇧-click extends from an anchor, arrow keys (⇧-arrow)
  move (extend) the selection (settled answer 2). The selection is **one ad-hoc group, never
  persisted** (product R29): it survives list↔feed switches within the same opened folder and resets
  only when a new folder is opened (binding answer 2; S18); nothing is written to disk, no albums or tags exist (product non-goal
  "Persistent albums/tags").
- **Product requirements carried.** product R27–R29 (list view & operations) from
  [docs/spec.md](../../spec.md) — cited below as `product R#`, never renumbered or restated as new
  normative text. Context requirements shaping the story without being claimed as its own: product
  R37 (single window shows feed and list — this story completes its "and list" half), product R9–R10
  (keyboard-first, applied here to the list), product R34–R36 (format filtering — which items appear
  is the collection's contract), product R17 (never modify media files — display-only listing), and
  product R16 (cross-cutting responsiveness) as this story's share via S15, per the coverage note in
  [docs/backlog.md](../../backlog.md). Story-scoped requirements (derivations and refinements) are
  numbered **S1…S18** in this file only.
- **Pillars.** Both pillars are engaged. **RNF-02 (performance):** the list is a long list over a
  folder that may hold hundreds or thousands of items — opening it, scrolling it, changing the
  selection, and switching views must never stall the interface (S15); numeric budgets are this
  story's design-phase output, which loads the `swift-performance` skill per the pillar rule (D5).
  **RNF-04 (security):** the list is **display-only** — file names are read from the already-open
  security-scoped session of the collection (D19) with no new access paths, nothing is written to
  disk (product R17; S14), and the selection is session state only (S11, S18); the design loads the
  `swift-security` skill.
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE NOT affected.** Same decision and same
  reasoning as E3-S1/E3-S2's: with no media open, launch-visible behavior is unchanged — the welcome
  state and its launch cost are exactly as earlier stories left them — and this story's entire
  surface (the list, the toggle button, the toggle shortcut, selection) exists only once media is
  open, which the UI tests cannot reach: entry remains host-driven (Open With and drag & drop), the
  standing caveat recorded since E2-S1. The UI-test-covered flows are launch flows and are untouched,
  so the converge run keeps the default gate scope with **no `--uitests` obligation**
  ([docs/development.md](../../development.md) §3). Honest caveat: even a `--uitests` run could not
  open the list view (no media is open in the launch tests), so selection behavior is carried by unit
  tests and stakeholder functional review.
- **Inherited contracts.** The collection snapshot (E2-S1 S14 — the folder's own order at open time;
  E2-S1 design §6 — the snapshot may drift from disk) and its filtering (E2-S1/D20: direct children
  only, native formats only — product R34–R36); the single `Window` scene and close-quits lifecycle
  (D18, E2-S2 S7–S8); replace-in-place on a new open (E2-S2 S9); the feed's paging and chrome-free
  viewport (E2-S2 S4–S6, S14 — untouched here); the feed's current-item positioning contract (E2-S1
  `startIndex`, E2-S2 S9 — row activation lands on it, and the list's opening position anchors to it
  (S17)); the quiet no-op input guard (D28); and
  display-time fail-safe for stale items (E2-S2 S12–S13). **Seam for E5-S2:** R28's "list operations
  shall act on that selection" — this story defines the current selection as the single seam
  operations will act on (S6, S11); the operations themselves (product R30–R33) are non-goals below.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md) (MediaList feature
  alongside Feed, per D7–D10). Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a Mac user with a folder of clips and photos open, I want to see every item listed by
  file name in the collection's order, so that I can take in the whole batch at a glance instead of
  paging one item at a time.
- **US2** · As a keyboard-first user, I want one shortcut (and a visible button) to flip between the
  list and the feed in the same window, so that I can move between "overview" and "watching" without
  losing my place in the app.
- **US3** · As a user preparing to organize a batch, I want to mark several items with familiar Mac
  selection gestures — ⌘-click, ⇧-click, arrow keys — so that I can build a group exactly the way I
  do in Finder.
- **US4** · As a user who spots an item of interest in the list, I want to double-click it (or press
  Enter) and land on it in the feed, so that I can go from overview straight to watching that item.

## Story requirements (EARS)

Numbering is story-local: **S1…S18** for this story only. Product requirements are cited as
`product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that merely
anchor product text cite it; requirements that refine or derive add a short derivation note.

### List contents & ordering (product R27; R34–R36 as the collection contract)

- **S1:** WHEN the user opens the list view in the folder-open state
  THE SYSTEM SHALL list every media item of the opened collection, showing each item's file name, in
  the current ordering (product R27)

*Derivation (S1):* "every media item" is exactly the collection's items — the direct children of the
opened folder that are media (product R34–R36, E2-S1/D20), so the list shows nothing the feed does
not and excludes every non-media file (product R36). "The current ordering" is the collection's
snapshot order (the folder's own order at open time, E2-S1 S14) — ordering switches are E4-S1
(product R21–R22, D15) and no ordering behavior is designed or claimed here. The row's visible
content is the file name (product R27); any additional row presentation is UI detail, design-phase
output.

- **S2:** WHEN items of the collection have vanished or become unreadable since the snapshot was
  taken
  THE SYSTEM SHALL keep listing them by file name per the snapshot — the list SHALL NOT gain, drop,
  or reorder rows on its own after it is built

*Derivation (S2):* the collection is a point-in-time snapshot that may drift from disk (E2-S1 design
§6); live folder sync is E4-S2 (product R23–R26) and is not claimed here. Until it exists, the list
is honestly a snapshot view: stale rows stay listed (the display-time fail-safe of E2-S2 S12–S13 is
the feed's contract, and the list's row is the file name itself, which requires no file access).

### View switching (settled answer 1; product R37; product R9–R10 keyboard-first)

- **S3:** WHEN the user presses the view-toggle keyboard shortcut — **proposed: ⌘L** — in the
  folder-open state
  THE SYSTEM SHALL switch between the list view and the feed in the same single window (product R37)

*Derivation (S3):* settled answer 1 delegates the concrete shortcut to this spec; **⌘L** is proposed
as the mnemonic ("L" for list) toggle. Invocation delivery is design detail (D28's precedent). The
stakeholder confirmed this proposal (binding answer 2 — the ⌘L veto point is closed); the toggle's
existence and behavior were settled regardless of the final key.

- **S4:** WHEN the user clicks the on-screen view-toggle button in the main window
  THE SYSTEM SHALL perform the same switch between the list view and the feed (settled answer 1)

*Note (S4):* the button's wording and styling are UI detail, design-phase output; S3 and
S4 are two surfaces over one toggle. Placement is pinned by the binding stakeholder decision of
2026-10-14: the button is a **standalone floating control in the top-left corner of the window/feed
area** (never inside the video control bar), **demand-driven** on the same trigger as the control
bar/progress bar but independent of it, and present on **both video pages and image pages**. The
button and shortcut live only in the folder-open state.

- **S5:** WHEN the view is switched by either surface
  THE SYSTEM SHALL keep showing the same opened collection in the same single window — the switch
  changes only which of the two views is presented (product R37)

*Derivation (S5):* settled answer 1 ("toggling switches between list and feed in the same window")
operates inside the inherited single-window contract (D18; E2-S2 S7–S9): no new window, no second
collection, no change to close-quits (E2-S2 S8) or replace-in-place (E2-S2 S9) semantics. The feed
side of the switch is unchanged — its paging, letterboxing, and chrome-free viewport (E2-S2) stand
as written, and the arrow keys keep their feed meanings while the feed is shown.

- **S17:** WHEN the view is switched to the list view and the feed has a current item
  THE SYSTEM SHALL scroll the list to that item's row and highlight it — and that highlight SHALL NOT
  count as or modify the current selection

*Derivation (S17):* binding stakeholder answer 1, resolving the ambiguity formerly recorded under
S5: the list's opening state is anchored to the feed's current item so the user never loses their
place (US2). The highlight is a position marker, not a selection: it is applied without any
selection action and changes no selection state — S6–S10 remain the only ways the selection is set,
toggled, extended, moved, or cleared. Consistency (S2): the highlighted row is the snapshot row of
the feed's current item and, like every other row, never moves on its own; the highlight follows
that row wherever the snapshot places it and goes away when a new folder's snapshot replaces the
list (S18).

### Selection (product R28, R29 — settled answer 2)

- **S6:** WHEN the user single-clicks a row in the list
  THE SYSTEM SHALL set that row as the current selection — and SHALL NOT activate it (product R28;
  settled answer 2)

*Derivation (S6):* product R28's "the current selection" is a single selection concept that may
cover one or many rows; settled answer 2 fixes that a single click only sets it. R28's second half —
"list operations shall act on that selection" — is the seam E5-S2 builds on: the selection is what a
future operation will act on (S11), and no operation exists in this story.

- **S7:** WHEN the user Command-clicks a row in the list
  THE SYSTEM SHALL add that row to the current selection, or remove it if already selected — toggling
  membership without discarding the rest (settled answer 2, standard macOS conventions)

- **S8:** WHEN the user Shift-clicks a row in the list
  THE SYSTEM SHALL extend the current selection from its anchor row to that row (settled answer 2,
  standard macOS conventions)

- **S9:** WHEN the list view is the presented view and holds keyboard focus and the user presses an
  arrow key, or ⇧ plus an arrow key
  THE SYSTEM SHALL move the selection one row in that direction, or extend the selection one row in
  that direction respectively — the standard macOS multi-select keyboard conventions (settled answer
  2; product R9–R10 keyboard-first)

*Derivation (S9):* settled answer 2 names "arrow keys" among the standard macOS conventions, so the
list's arrows move the selection the way Finder's do (⇧-arrow extending). This is scoped to the list
view only: while the feed is shown, the arrows keep their feed meaning — paging one item
(product R10, E2-S2 S5) — and the two behaviors never compete, because only one view is presented
at a time (S5). Boundary behavior follows the same standard conventions (the selection clamps at the
first and last row and never wraps); the anchor's exact maintenance across mixed mouse/keyboard
selection is the standard macOS behavior and is not re-specified here.

- **S10:** WHEN the user clicks empty space in the list (no row under the pointer)
  THE SYSTEM SHALL clear the current selection, leaving no rows selected (standard macOS conventions)

*Derivation (S10):* recorded as a reading of settled answer 2's "standard macOS conventions" — the
enumerated mechanisms (S7–S9) name the multi-select gestures, and empty-click-to-clear is the same
Finder-native selection behavior the answer adopts wholesale. The stakeholder confirmed this reading
(binding answer 3 — the S10 veto point is closed).

- **S11:** WHEN a multi-selection exists
  THE SYSTEM SHALL treat it as one ad-hoc group for the next operation and SHALL NOT persist groups
  or tags — nothing about the selection survives past the opened folder (product R29; its
  in-session lifetime is fixed by S18)

*Derivation (S11):* product R29 and the product non-goal "Persistent albums/tags" make the selection
ephemeral by contract: it is in-memory session state of the open collection, written nowhere (S14)
and never restored across relaunch; its lifetime within the session is fixed by S18. The selection
is the single seam E5-S2's operations (product R30–R33) will act on (R28) — one selection concept,
not per-operation scratch state.

- **S18:** WHEN the user switches between the list view and the feed within the same opened folder
  THE SYSTEM SHALL keep the current selection unchanged; the selection SHALL reset only when a new
  folder is opened, and SHALL NOT be persisted to disk (product R29)

*Derivation (S18):* binding stakeholder answer 2, resolving the ambiguity formerly recorded under
S11: the selection's lifetime is the opened folder, not the presented view. Ordinary switches
(S3–S5) and activation switches (S12–S13) preserve it — returning to the list shows the same group
still selected, and the S17 highlight never touches it. Opening a new folder (E2-S2 S9
replace-in-place) rebuilds the collection snapshot and resets the selection with it — consistent
with S2: the old rows the selection referred to are replaced wholesale by the new snapshot's rows
and never carried over, so no selection outlives the rows it referred to. Nothing here loosens
product R29: the selection stays in-memory state of the opened folder, written nowhere and never
restored across relaunch (S14).

### Row activation (settled answer 2)

- **S12:** WHEN the user double-clicks a row in the list
  THE SYSTEM SHALL switch to the feed positioned on that item — that item shown as the feed's current
  item (settled answer 2)

*Derivation (S12):* "positioned on that item" is the inherited feed-positioning contract (E2-S1's
`startIndex` entry contract, E2-S2 S9's positioning principle) applied to activation: the feed opens
on the double-clicked item, whatever the selection around it. Activation is a navigation action, not
a selection action — it does not replace the selection model (S6), and the selection around it
survives the switch untouched (S18); the S17 highlight on the list's later re-opening is likewise
not a selection change. Consistency with playback continuation (binding answer 1; design §5.3):
activating the row the feed is already on flips presentation only — it restarts neither the item's
playback nor its position.

- **S13:** WHEN a row in the list has keyboard focus and the user presses Enter
  THE SYSTEM SHALL switch to the feed positioned on that item (settled answer 2)

*Note (S13):* Enter is the keyboard twin of double-click (settled answer 2's parenthetical): same
outcome, same positioning. Both activation paths land in the feed per S5 — same collection, same
window.

### Read-only listing (product R17 — inherited no-regression contract; RNF-04)

- **S14:** WHEN the user opens the list, scrolls it, or builds or changes a selection
  THE SYSTEM SHALL write nothing to disk and modify nothing — no rewrite, move, sidecar, or derived
  file for any media item, and no persisted selection (product R17; product R29; RNF-04)

*Derivation (S14):* product R17 is an inherited no-regression contract here, not a new claim: the
list is display-only, reading file names through the already-open security-scoped session of the
collection (D19) — no new access paths, no re-derived access — and product R29 forbids persisting
the selection. The file-modifying half of E5 (zip/move/reveal/trash, product R30–R33) is exactly
what this story does not do (non-goals below); its future operations live under D16's "never rewrite"
rule.

### Responsiveness (product R16 — this story's share)

- **S15:** WHEN the user opens the list, scrolls through it, changes the selection, or switches
  between list and feed
  THE SYSTEM SHALL keep the interface smooth and responsive, with no stalls — including for
  collections at the largest size the app can open (product R16, RNF-02)

*Note (S15):* product R16 is deliberately not assigned to any single story
([docs/backlog.md](../../backlog.md) coverage note) — S15 states this story's share of the
responsiveness budget: a large folder must not turn list presentation, scrolling, selection changes,
or view switches into a stall or beachball. Numeric budgets are set in this story's design (RNF-02),
which loads the `swift-performance` skill.

### Welcome interplay (inherited, E2-S1 S5–S7)

- **S16:** WHEN the app is presenting the welcome state
  THE SYSTEM SHALL present no list view, no view toggle, and no selection — the list, the toggle
  surfaces, and selection apply only in the folder-open state, and the welcome state's behavior is
  unchanged

*Derivation (S16):* the list and its toggle presuppose an open collection; E2-S1's welcome-state
contract (S5–S7) stands untouched, including drop-target behavior and entry transitions.

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in
[docs/spec.md](../../spec.md) apply unchanged):

- **File operations — zip, move, reveal, trash** (E5-S2) — product R30–R33. This story defines the
  selection as the seam those operations act on (S6, S11) and nothing more: no operation buttons, no
  context-menu actions, no confirmation dialogs, no Trash interaction, no Finder reveal. The
  operations' effect on feed and list follows from live sync (E4-S2), not from here.
- **Persistent albums/tags** — product non-goal ("selection is ephemeral; grouping beyond ad-hoc
  multi-select is future work"); S11's no-persistence rule is this story's enforcement of it.
- **Ordering modes** (E4-S1) — product R21–R22 (D15); the list follows the collection's snapshot
  order (S1) and offers no sort controls, headers, or grouping.
- **Live folder sync** (E4-S2) — product R23–R26; snapshot drift is displayed honestly (S2), not
  tracked.
- **Feed behavior changes** — the feed's paging, letterboxing, chrome-free viewport, posters, and
  unavailable states (E2-S2, E2-S3) are untouched; this story adds the second view and the switch,
  and alters no feed contract (S5).
- **Playback controls in the list** — no inline play, no preview thumbnails, no scrubbing from list
  rows; row content is the file name (S1), and playback remains feed-side (E2-S3, E3).
- **List chrome beyond the rows** — no column customization, no metadata columns (size, duration,
  dates), no search/filter field, no position counter; row presentation beyond the file name is
  unclaimed future work.
- **Selection persistence or export** — no saving a selection, no copying file names/paths to the
  pasteboard, no smart groups; the selection lives only for the next operation of the session (S11).
- **In-app folder picker / reopen path** — v1 non-goal ([docs/spec.md](../../spec.md)); unchanged.
- **Network** — excluded from v1 entirely (D9); the list reads the local collection only.

## Acceptance criteria

Product-requirement coverage map — the product requirements assigned to this story (the three of
[docs/backlog.md](../../backlog.md): R27–R29) map to verifiable story outcomes; the context
requirements shape the story and are carried as inherited contracts or shared notes, never claimed
as this story's own:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R27 (list every item by file name, current ordering) | S1 — snapshot-order rows, file names, exactly the collected items; S2 — honest snapshot, no self-reordering | unit tests (list model: contents, order, filtering parity with the collection) + functional review (mixed folder, order matches the feed's) |
| R28 (selection; operations act on it) | S6–S9 — single click sets, ⌘-click toggles, ⇧-click extends, arrows move/extend; S11 — the one selection seam for E5-S2; S18 — lifetime is the opened folder, view switches preserve it | unit tests (selection state machine: set/toggle/extend/move, boundaries) + functional review (Finder-familiar gestures) |
| R29 (ad-hoc group, nothing persisted) | S11, S18 — one ephemeral group per opened folder, reset on a new folder open; S14 — nothing written | unit tests (selection state is in-memory only) + functional review (no artifacts on disk after selecting) |
| R37 (single window shows feed and list) — context; completed here, not claimed as E5-S1's assignment | S3–S5, S17 — ⌘L and the on-screen button flip views in the same window; the list opens anchored to the feed's current item | functional review (toggle both ways, same window, same collection) |
| R9–R10 (keyboard-first) — context | S3 (shortcut toggle), S9 (arrow-key selection), S13 (Enter activation) | functional review (keyboard-only round trip: open list, select, activate) |
| R34–R36 (format filtering) — inherited collection contract, not claimed | S1 — the list shows exactly the collected items, no more, no fewer | unit tests (list/collection parity) + functional review (non-media files absent) |
| R16 (smooth & responsive) — cross-cutting share via S15, not claimed | S15 — open/scroll/select/switch stall-free at large collection sizes | validator performance review (RNF-02; numeric budgets from this story's design) + functional review (large folder stays fluid) |
| R17 (media files never rewritten) — inherited no-regression contract, not re-claimed | S14 — display-only listing, nothing written, no new access paths | validator security review (read-only paths; D19 session not re-derived) + functional review (files byte-identical on disk) |

- [x] Every product requirement assigned to this story maps to at least one story requirement; no
  other product requirement is claimed here (product R30–R33 stay with E5-S2; product R37, R9–R10,
  R34–R36 appear only as inherited/context contracts; product R16 appears only as the shared
  responsiveness note S15; product R17 appears only as the inherited no-regression contract S14).
- [x] The selection seam is explicit and testable: one current selection (S6), Finder-standard
  multi-select mechanics (S7–S9), empty-click clearing (S10), one ad-hoc group never persisted
  (S11, S18) — and the spec claims no operation on it (non-goals: E5-S2's R30–R33).
- [x] Snapshot honesty is explicit (S2): the list neither invents live sync (E4-S2) nor breaks on
  stale rows.
- [x] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json
  <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run keeps the default gate
  scope (UI-test mandate decision in Story context: flows are not affected).
- [x] The two `[NEEDS CLARIFICATION]` markers (selection lifetime across view switches; list's
  initial selection/position on switch — under S5 and S11) are resolved — by binding stakeholder
  answers, now normative as S17 (list opens scrolled to and highlighting the feed's current item,
  without that highlight counting as or modifying the selection) and S18 (the selection survives
  list↔feed switches within the same opened folder, resets only when a new folder is opened, and is
  never persisted — product R29).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: the list
  showing every item of a mixed folder by file name in the feed's order with non-media files absent;
  ⌘L and the on-screen button both toggling between list and feed in the same window; a single click
  selecting without activating; ⌘-click toggling membership; ⇧-click extending from the anchor;
  arrow keys moving and ⇧-arrows extending the selection with clamping at both ends; a click on empty
  space clearing the selection; double-click and Enter each switching to the feed positioned on that
  item; the list opening scrolled to and highlighting the feed's current item without that highlight
  counting as or modifying the selection; the selection surviving list↔feed switches and resetting
  when a new folder is opened; large folders scrolling, selecting, and switching without stalls; and the media files
  byte-identical on disk after all of the above (this is a UI story — functional review is part of
  the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R27–R29; R37, R9–R10, R16, R17,
  R34–R36 context; RNF-02 / RNF-04; non-goals)
- [docs/decisions.md](../../decisions.md) — D5 (pillars), D7 (layering & seams), D8 (presentation &
  concurrency), D11–D12 (entry & collection), D15 (ordering & live sync — E4 territory), D16 (file
  operations on ephemeral groups, never rewrite — E5-S2 territory), D18 (one window), D19 (scoped
  access), D20 (classification), D28 (input router & quiet no-op guard)
- [docs/specs/e2-s1-entry-media-collection/spec.md](../e2-s1-entry-media-collection/spec.md) —
  inherited contracts (collection snapshot S14, welcome state S5–S7, `startIndex`)
- [docs/specs/e2-s1-entry-media-collection/design.md](../e2-s1-entry-media-collection/design.md) —
  §6 (snapshot/staleness contract), §3.4 (`Window` scene)
- [docs/specs/e2-s2-vertical-feed-window/spec.md](../e2-s2-vertical-feed-window/spec.md) — feed
  contracts carried unchanged (S4–S11 paging/window, S14 chrome-free viewport; S12–S13 fail-safe);
  its "List view & file operations (E5-S1 / E5-S2)" non-goal is landed here in its list half
- [docs/specs/e3-s2-playback-speed/spec.md](../e3-s2-playback-speed/spec.md) — conventions precedent
  (cross-cutting share note, inherited no-regression contract, derived readings with stakeholder veto)
- [docs/architecture.md](../../architecture.md) — MediaList feature layout alongside Feed (D7–D10)
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E5-S1) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
- Skills (loaded and honored; design-phase detail): `swift-performance` (RNF-02 — long-list view
  cost, main-thread discipline), `swift-security` (RNF-04 — display-only reads, no persistence)
