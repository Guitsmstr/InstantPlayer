# E5-S1 · List view & selection — Design

How the app shows the open collection as a file-name list next to the feed, how the macOS-standard
multi-select works, and how ⌘L + a button flip the two views in the one window — with no file
operation of any kind. Story spec: [spec.md](spec.md) (S1–S18 over product R27–R29).
Structure follows [docs/architecture.md](../../architecture.md) (D7–D10 — the first story to create
`Features/MediaList/`); window policy follows D18; access and classification contracts follow
D19–D20; input routing follows D28 ([docs/decisions.md](../../decisions.md)). Pillars: RNF-02 and
RNF-04 — mandatory sections below (§7, §8); the design was written against the `swift-performance`
and `swift-security` skills (`.pi/skills/swift-performance`, `.pi/skills/swift-security`), and every
implementer and the validator load them before touching this code (D5).

Scope reminder: this story ends at "the list shows the snapshot's names, the selection works like
Finder's, the two views flip". No file operations (E5-S2 — zip/move/reveal/trash, product R30–R33);
no ordering modes (E4-S1); no live folder sync (E4-S2 — the list is honestly a snapshot, S2); no
playback controls in rows; no persistence of anything (S11, S14, S18). No `[NEEDS CLARIFICATION]` markers exist in this design — §5.3's playback-across-a-view-switch
question is resolved by a binding stakeholder answer (playback continues; no teardown), and the two
spec-level veto points (⌘L as the toggle key, empty-click-clears) are stakeholder-confirmed. Every
decision below is made and traceable to S-/product-R numbers.

## 0 · Platform and toolchain facts this design is built on

1. **macOS 26 SwiftUI offers the whole list stack first-party:** `ScrollView` +
   `LazyVStack` + `scrollPosition(id:)` for a lazy, stable-identity long list with a programmatic
   scroll target (the S17 anchor), and `List` with its own selection machinery as the conventional
   alternative (rejected in §11 — its selection model would compete with the spec's Finder-grade
   semantics and the S17 non-selection highlight).
2. **The feed already holds the entire collection in memory** (`MediaCollection.items` — URLs, names,
   kinds, built off-main by the repository actor at open, E2-S1 design §7.2). The list needs **no
   new file access and no name collection**: rows project `item.name` from values already resident
   (§2). This is why the list can be display-only and still show every name.
3. **Key delivery on macOS 26 goes through the App-owned `NSEvent` monitor, not SwiftUI focus
   (D22/D28):** three failed functional-review rounds proved SwiftUI key delivery cannot reach
   scroll content. All new keyboard behavior (⌘L, list arrows, Enter — §5) extends the existing
   pure routing table (`FeedKeyCommand`) and its monitor; the table stays a value-level decision
   testable without event fixtures.
4. **`MediaItem.ID` is the item's `URL` and is stable within a snapshot** (Core model) — it is the
   row identity for SwiftUI diffing and for the selection machine, with O(1) index↔id mapping over
   the ordered `items` array.

## 1 · Architecture mapping & component inventory

All new code lands per the D7 walkthrough: Presentation → Domain ← Data, framework types behind
seams, composition wired only in `App/`. `Features/MediaList/` is created by this story with the
same three layers (architecture §3 — the reserved name). Files (names + responsibilities):

| File | Layer | Responsibility | Requirements |
|---|---|---|---|
| `InstantPlayer/Features/MediaList/Domain/MediaListSelection.swift` (new) | MediaList Domain | The pure selection state machine: set / toggle / range-extend / move / extend-move / clear over an ordered row array; anchor + lead rows; reset (§3) | S6–S11, S18 |
| `InstantPlayer/Features/MediaList/Data/Data.md` (new) | MediaList Data | Placement note only — **no conformance this story** (the list performs no I/O; E5-S2 lands the operations seam's conformances here, §6.2) | S14 |
| `InstantPlayer/Features/MediaList/Presentation/MediaListViewModel.swift` (new) | MediaList Presentation | `@MainActor @Observable` owner of the selection value, the presented-view toggle, the applied snapshot, and the activation intent (§3, §4, §6) | S3–S13, S17, S18 |
| `InstantPlayer/Features/MediaList/Presentation/MediaListView.swift` (new) | MediaList Presentation | The lazy list surface: one row per snapshot item in snapshot order; dumb binder over the view model (§2) | S1, S2, S15 |
| `InstantPlayer/Features/MediaList/Presentation/MediaListRowView.swift` (new) | MediaList Presentation | One row: the file name plus selection / position-highlight styling (§2, §3.3) | S1, S6, S17 |
| `InstantPlayer/Features/MediaList/Presentation/ViewToggleControl.swift` (new) | MediaList Presentation | The one toggle button, rendered in both presented views (§5.2) | S4 |
| `InstantPlayer/App/FeedKeyCommand.swift` (exists) | App | The routing table grows the ⌘L row and the list rows (arrows, ⇧-arrows, Enter, quiet no-ops) — §5.1 | S3, S9, S13 |
| `InstantPlayer/App/AppDelegate.swift` (exists) | App | The monitor dispatches the new rows to the registered list model | S3, S9, S13 |
| `InstantPlayer/App/AppDependencies.swift` (exists) | App | `makeMediaListViewModel()` factory + weak `activeListModel` registration (the `activeFeedModel` pattern, D10) | S3 |
| `InstantPlayer/App/RootView.swift` (exists) | App | Presents `MediaListView` or `FeedView` from the toggle state; routes each new snapshot to the list model; mediates row activation into `FeedViewModel.moveTo(itemID:)` (§6) | S5, S12, S13, S18 |
| `InstantPlayer/Features/Feed/**` (exists) | Feed | **Effectively untouched** — the list consumes `MediaCollection`, `FeedViewModel.currentItemID`, and `FeedViewModel.moveTo(itemID:)` exactly as they are (S5's "no feed contract altered") | S5, S12, S17 |

### 1.1 Placement justifications (architecture reviewer checks)

- **The selection machine is Domain, not Presentation (D7/D8):** it is a pure value over ordered
  row identifiers — no SwiftUI, no AppKit, no Foundation beyond `Set`/`Array` — which is exactly
  what makes S6–S10 unit-testable without mouse hardware (spec AC). The view model owns exactly one
  `MediaListSelection` value and forwards gestures to it; the spec's semantics live in one place.
- **MediaList/Data is deliberately empty (stated for the architecture reviewer):** the list reads
  names from the already-materialized `MediaCollection` (Core) — it reaches no framework capability
  and needs no seam, so D7's "framework capabilities behind seams" has nothing to gate. Creating the
  folder with a placement note honors architecture §3's "same three layers" while inventing no
  premature seam; the first conformances arrive with E5-S2's operations (§6.2).
- **No Core promotions:** rows are `MediaItem`s; nothing new is shared across features yet. The
  one cross-feature value the list consumes (`MediaCollection`) is already Core (E2-S1).
- **Root-owned presentation switch, Feed untouched:** the feed ↔ list flip (S5) lives in
  `RootView` (App-owned routing is the E2-S1 precedent) — `FeedView` keeps rendering welcome + feed
  exactly as shipped, and the list view is mounted beside it. This makes S5's "alters no feed
  contract" a structural property, not a review promise.
- **Project config: explicitly nothing.** No entitlements, no Info.plist keys, no build settings, no
  pbxproj change (new files join through synchronized groups, D21). **Stated for the D21 audit:
  zero project-config diff in this story** (§8).

## 2 · The list surface: snapshot rows, file names, honesty (S1, S2, S16)

- **S1 — rows = the collection, in the collection's order:** `MediaListView` renders
  `collection.items` in array order — the snapshot order (E2-S1 S14) — one row per item showing
  `item.name`. No sorting, no headers, no grouping (E4-S1 owns ordering); the filtering contract is
  inherited for free: the list shows exactly what the feed shows, no more, no fewer (product
  R34–R36 parity by construction — there is no second scan to diverge).
- **S2 — honest snapshot:** rows are built once per applied snapshot and never mutate afterwards —
  vanished/unreadable files keep their rows (their names are snapshot values needing no file
  access), and nothing re-orders or re-counts rows on its own. Row identity is `MediaItem.ID`
  (stable within the snapshot), so SwiftUI diffing is identity-stable and there is nothing to
  diff against until a new snapshot replaces the old wholesale (§6).
- **S16 — welcome interplay:** the list exists only in the folder-open state; `RootView` presents it
  only when a collection is open, so the welcome surface (E2-S1 S5–S7) is byte-for-byte unchanged
  and no toggle/selection machinery is reachable from it.
- **Row presentation:** the file name is the row's content (product R27); beyond it the row carries
  only selection styling and the S17 position highlight (§3.3). No thumbnails, no metadata columns,
  no per-row controls (non-goal).

## 3 · The selection model — Domain state machine (S6–S11, S18)

`MediaListSelection` (MediaList Domain, `nonisolated struct`) is the single selection concept of
product R28: one ad-hoc group over one ordered row array, with the two standard macOS companion
rows — the **anchor** (⇧-extend base) and the **lead** (the keyboard-focus row arrows move from and
Enter activates). Sketch (contract-level):

```swift
nonisolated struct MediaListSelection {
    private(set) var selectedIDs: Set<MediaItem.ID>
    private(set) var anchorID: MediaItem.ID?   // ⇧-extend base
    private(set) var leadID: MediaItem.ID?     // keyboard focus; Enter activates it

    mutating func select(_ id: MediaItem.ID)                         // S6
    mutating func toggle(_ id: MediaItem.ID)                         // S7
    mutating func extend(to id: MediaItem.ID, over rows: [MediaItem.ID])   // S8
    mutating func move(_ direction: Direction, over rows: [MediaItem.ID])  // S9
    mutating func extend(_ direction: Direction, over rows: [MediaItem.ID])// S9
    mutating func clear()                                            // S10
    mutating func reset()                                            // S18
}
```

### 3.1 Semantics (each op maps to its requirement)

| Input | Effect | Req |
|---|---|---|
| Single click on row R | selection = {R}; anchor = lead = R. Never activates (activation is §4) | S6 |
| ⌘-click on R | flip R's membership in the selection, rest untouched; anchor = lead = R (Finder's anchor-on-⌘-click) | S7 |
| ⇧-click on R | selection = the contiguous range anchor…R in row order (no anchor ⇒ behaves as select); lead = R; anchor unchanged | S8 |
| ↑ / ↓ | selection = {row adjacent to lead in that direction}; anchor = lead = that row. Clamps at first/last row — never wraps; repeat at the boundary is an idempotent no-op | S9 |
| ⇧-↑ / ⇧-↓ | lead moves one row (clamped); selection = range anchor…lead | S9 |
| Click on empty space | `clear()` — no rows selected, anchor/lead dropped | S10 |

Both spec-level stakeholder veto points are now **confirmed** (binding answers 2–3) and closed:
⌘L stands as the toggle key (§5.1) and empty-click-to-clear stands as the S10 reading above —
neither is an open proposal anymore.

All ops are O(1) except range ops (O(range), rendering-lazy anyway); membership checks are O(1)
(`Set`). Arrow auto-repeat is repeated `move`/`extend` calls — the boundary clamp keeps repeats
idempotent (the D38 repeat-parity pattern). ⇧-click's replace-with-range semantics and anchor
maintenance across mixed mouse/keyboard input are the standard macOS behavior the spec adopts
wholesale (S8, S9 derivations); the functional review is the arbiter of "Finder-familiar".

### 3.2 Lifetime and reset (S11, S18)

The view model holds the one `MediaListSelection` value for the one open folder. Ordinary view
switches (S3–S5) and activation switches (S12–S13) never touch it — switching presentation state
and mutating selection are different methods on the view model, so S18 is structural. `reset()`
runs at exactly one point: `MediaListViewModel.apply(collection:)` when a **new** snapshot value
arrives (a new entry action replaces the collection in place, E2-S2 S9) — the old rows the
selection referred to are replaced wholesale, and no selection outlives its rows (S18 derivation).
Nothing about the selection is ever written anywhere (S11, S14 — §8).

### 3.3 The position highlight is not selection (S17)

The S17 highlight is a **derived, read-only projection of the feed's current item**
(`FeedViewModel.currentItemID`) onto the row list — a rendering input, deliberately **not** a case
of `MediaListSelection`. The machine has no API that could accept it; opening the list, scrolling,
and switching views structurally cannot set, clear, or mutate selection (the S17 guarantee becomes
a type property rather than a discipline). On switch-to-list, `MediaListView` also programs its
`scrollPosition(id:)` to that row so the list opens on the user's place (S17); the position is
re-derived on every presentation and dies with the snapshot (S18's reset drops both highlight and
selection consistency together).

## 4 · Row activation (S12, S13)

- **S12 — double-click:** double-clicking row R is a **navigation** intent, not a selection action
  (S12 derivation): `MediaListViewModel` emits `activate(itemID: R.id)`; `RootView` (App-owned
  mediation, D10) calls the existing `FeedViewModel.moveTo(itemID: R.id)` — the inherited
  `startIndex`/positioning contract (E2-S1, E2-S2 S9) reused verbatim — and flips presentation to
  the feed. The selection around the click is untouched (S18), and the later list re-open highlights
  R as the feed's current item without touching selection (S17).
- **S13 — Enter:** the keyboard twin — Enter (key code 36; keypad Enter 76) activates the
  **lead** row (the selection machine's keyboard-focus row, §3). Same outcome, same positioning.
- **Activation on the already-current item never restarts playback (binding answer 1, §5.3):** if
  the activated row R is the feed's current item, activation is a pure presentation flip — `RootView`
  calls `present(.feed)` only and never `moveTo(itemID:)`, `startPlayback`, or `restart()`; the live
  session (playing or paused) continues at its exact position. Only activating a **different** row
  runs the inherited positioning contract, where the feed's ordinary arrive-on-item semantics apply
  unchanged. This keeps the input-delivery decision (§5.1) and the playback-continuation decision
  (§5.3) consistent: no activation path may restart playback that the switch deliberately kept alive.
- **Cross-feature mediation:** `MediaListViewModel` never references `FeedViewModel` (features are
  peers); the activation callback is injected at composition (`RootView` binds it to
  `moveTo(itemID:)` + `present(.feed)`), keeping D7's dependency rule intact.

## 5 · View switching & input delivery (S3–S5, S9, S13)

### 5.1 ⌘L — the keyboard surface (S3)

One toggle method on `MediaListViewModel` (`togglePresentation()` — feed ↔ list), reached from both
surfaces (S4's "two surfaces over one toggle"). Delivery extends the proven App-owned route
(platform fact 3): `FeedKeyCommand.route(...)` grows:

- a `toggleView` row: **⌘L** (key code 37 = `kVK_ANSI_L`, 0x25, with `.command`) in the folder-open
  state, in **both** presented views. Deliberate contract change: ⌘-modified keys previously passed
  through ("system shortcuts are never robbed") — ⌘L is now claimed; every other ⌘/⌥/⌃ combo still
  passes through (recorded consequence, test-pinned like D34/D38's changes).
- list rows, routed only while the list is presented: ↑/↓ → `moveSelection`, ⇧-↑/⇧-↓ →
  `extendSelection` (S9 — note the router's existing "⇧ alone does not modify" rows are inverted
  here: in the list ⇧ *is* the extend modifier, exactly as the spec's S9 mandates), Enter →
  `activateLeadRow` (S13), ←/→ → consumed quiet no-ops (single-column list; D28's never-beep rule).
- the feed rows (space, ←/→ seek, `[`/`]` speed, ↑/↓ paging) route **only while the feed is
  presented** — S5/S9's "never compete" rule: one presented view, one active row set. Their
  behavior is frozen (E2-S2–E3-S2 contracts untouched).
- welcome: everything passes through (S16) — the existing `hasOpenFeed` guard generalizes to the
  presented-state input.

The table stays pure and unit-testable (values in, command out); `AppDelegate`'s monitor dispatches
the new commands to the registered `activeListModel` (the weak `activeFeedModel` registration
pattern, D10). Auto-repeat on the list arrows = repeated moves (D38 parity; the boundary clamp is
idempotent). **Alternative considered:** `.keyboardShortcut("l", modifiers: .command)` on the toggle
button — rejected for consistency and testability (the D22 lesson favors the monitor; one routing
table keeps all keyboard behavior in one testable place). ⌘L is **confirmed** by the stakeholder (binding answer 2 — the spec's proposed key stands, the veto
point is closed); no fallback key is planned.

### 5.2 The on-screen button (S4)

One `ViewToggleControl` (MediaList Presentation) rendered in the folder-open state in both views:
in the list it sits in the list's minimal top bar (always visible); over the feed it joins the
existing demand-driven overlay strip (D33/E3-S1's control bar — the precedent that overlay chrome
over the chrome-free viewport is already established) so the feed's idle chrome-free contract
(E2-S2 S14) is preserved. Both instances bind to the same `togglePresentation()`. Button wording is
one standard label flipping with state ("List" / "Feed" with the corresponding system icon) — UI
detail left to implementation within these bounds. **Flagged for the ADR plan (§10):** extending
the demand-driven strip is a deliberate, minor extension of the chrome policy.

### 5.3 Playback across a view switch — decided (binding stakeholder answer 1)

**Playback CONTINUES across the list↔feed switch.** While the list is shown, audio keeps playing;
video decode may idle since the display surface is hidden — but there is **no teardown**: the
playback session (`MediaPlayback`, D25) is untouched. Returning to the feed shows the same item at
the same position, still playing (paused stays paused). Concretely, a list↔feed switch is **neither a
teardown point nor a revisit**: E2-S3's teardown-on-disappear / stop-on-away path is not entered, and
D25's restart-on-revisit does not fire — no `stop()`, no `startPlayback`, no `restart()` on any such
switch. This is S5's "the switch changes only which of the two views is presented" read literally,
and it keeps S5's "no feed contract altered" honest at the session level too.

Consistency consequences, already folded into §4 and §5.1: while the list is presented the feed's
input rows are not routed (the never-compete rule), so playback runs on without feed keys reaching
it; Enter/double-click activation of the **already-current** row is a presentation flip only — no
`moveTo`, no restart (§4); activating a **different** row is a real item change and keeps the
inherited positioning/auto-play contract. The isolation point is the same as before — `RootView`'s
switch policy (§6.1) — now specified to keep the session alive across the switch instead of tearing
it down. **Alternatives considered:** the inherited E2-S3 contract (teardown on disappear + D25's
restart-on-revisit on return — the former planning default), rejected by the stakeholder because it
silently restarts a playing clip on every view flip; pausing on switch-to-list, rejected for the same
reason (the answer keeps playback running). Recorded for the ADR plan (§10) as its own entry.

## 6 · Composition, wiring & the future seams (D10)

### 6.1 Wiring (this story)

`AppDependencies.makeMediaListViewModel()` (allocation-only, the sanctioned factory pattern) records
the instance weakly as `activeListModel` for the key monitor. `RootView` owns three routings: each
new `MediaCollection` (the funnel is the existing entry route — `handle(entryAction:)` completion)
→ `MediaListViewModel.apply(collection:)` (the S18 reset point); row activation →
`FeedViewModel.moveTo(itemID:)` (§4); presentation state → which feature view is mounted (§1.1) — the playback session lives below this
switch and survives it (§5.3).
The list model receives the feed's `currentItemID` as a read-only value for the S17 highlight.
Launch cost stays exactly at the sanctioned allocations — the list model is created on demand with
the folder-open state, nothing runs at launch (§7).

### 6.2 The E5-S2 operation seam (named now, built later)

Product R28's second half — "list operations shall act on that selection" — lands on this seam:
**`MediaListSelection` is the single input of every future operation.** E5-S2 will add a MediaList
Domain seam (working name **`MediaItemOperations`**) taking an operation enum + the selected
`MediaItem`s resolved from the applied snapshot, with Data conformances (the first real files in
`Features/MediaList/Data/`) performing zip/move/reveal/trash behind D16's "never rewrite" rule and
inside the D19 session — that story, not this one, decides its entitlement delta (read-write) and
confirmation UX. This story guarantees the seam's contract: exactly one selection concept (S6),
Finder-standard mechanics (S7–S9), ephemeral and resettable (S11, S18) — no per-operation scratch
state, no second selection.

### 6.3 The E4-S2 live-sync seam (snapshot now, tracking later)

The list consumes rows only through `MediaListViewModel.apply(collection:)` — today a wholesale
snapshot swap (S2: rows never change after build). E4-S2's tracked-folder updates plug in at that
same point: ordered row updates arrive as collection replacements/patches, and the selection machine
gains a `reconcile(rows:)` policy (drop selected rows that left, keep survivors) designed in that
story. Until then, drift is displayed honestly (S2) — stale rows stay listed.

## 7 · Performance (RNF-02) — mandatory

Loaded skill: `swift-performance`. The performance-relevant surfaces are long-list rendering,
selection changes, and the view switch (S15) — long lists + SwiftUI view cost + main-thread
discipline, exactly what the skill gates. Per-story budgets (the E2-S1–E3-S2 measured-evidence
precedent):

1. **View-switch latency (S3–S5, S15):** toggle input (key or click) → target view presented and
   interactive: **≤ 100 ms p95** for collections up to 10 000 items, **≤ 300 ms p95** at the
   degenerate extreme (up to 50 000). Switch-to-list includes the S17 scroll-to-current (a direct
   jump — no animated scroll — so the budget is layout, not animation). *Verified by:* functional
   review on a large folder; a unit `measure` of the view-model path (state flip + row projection);
   Instruments if review disagrees (skill §6).
2. **Scroll smoothness (S15):** steady-state scrolling holds the display refresh (60 fps ⇒ 16.7 ms
   frame budget) with per-row `body` cost **≤ 1 ms** — the row is one `Text(name)` plus two
   membership checks (skill §2: lazy + stable identities + cheap `body`). `LazyVStack` mounts only
   visible rows; identity is `MediaItem.ID`; **no diffing work after open** — rows are immutable
   per snapshot (S2), so the list is a stable array until a wholesale swap (§6.3). *Verified by:*
   functional review on 10k+ folders; perf test (below); Instruments scroll trace on escalation.
3. **Selection-change latency (S6–S10, S15):** click / key → selection applied and visible rows
   re-styled: **≤ 16 ms** (one frame; the same-main-actor-turn rule of E3-S2 §8(1)). Single/⌘-click
   are O(1); ⇧-click and ⇧-arrow are O(range) on `Set` arithmetic only. Arrow auto-repeat (10–30
   keys/s) builds no backlog — each repeat is one O(1) state write, clamped idempotently at the
   boundaries (D38 parity). *Verified by:* machine unit tests (N ops deterministic); a step-path
   `measure`; functional review (held arrows at both ends stay fluid).
4. **Main-thread discipline (skill §1):** the list performs **no file access at all** — names are
   snapshot values already collected off-main by the repository actor (platform fact 2); nothing to
   schedule, no I/O in `init` or `body`. The only main-actor work is view-tree layout and O(1)
   selection arithmetic. This also answers the "collecting names must not block the main thread"
   concern directly: name collection happened at open, off-main, one snapshot ago.
5. **Memory (skill §4):** zero new caches and zero images — rows hold name strings already owned by
   the collection; selection state is one `Set` of IDs + two optionals (bounded by collection size,
   URL values). No allocation churn per frame; the one-snapshot-per-open bound (E2-S1) carries.
6. **Zero added launch cost (R13 of E1-S3 must survive):** nothing new on the launch path — the
   list model is created with the folder-open state; `ViewToggleControl` exists only in that state;
   no timers, no observers at launch. `testLaunchPerformance` remains the guard.
7. **Measured evidence (skill §6):** a unit performance test through the machine + row projection
   over generated fixture collections (10k synthetic `MediaItem`s) in an XCTest `measure` block,
   recorded as story evidence from tooling alongside the gate JSON — never "it feels fast".

## 8 · Security (RNF-04) — mandatory

Loaded skill: `swift-security`. The list is **display-only over in-memory snapshot values** — the
security posture of D19/D20 is inherited without a single new access path:

- **No new file access, inside or outside the session (D19, S14):** the list reads names from
  `MediaCollection.items`, already in memory; there is no scan, no re-derivation, no
  `start/stopAccessingSecurityScopedResource` anywhere in MediaList code — the D19 security-scoped
  session stays exactly as E2-S1 designed it. The list cannot access files at all; the Data layer is
  empty (§1.1) and nothing in it can reach the filesystem behind `MediaFolderRepository` (the ONLY
  sanctioned path, Core contract).
- **Display-only (product R17, S14):** the row shows the name and nothing else — names are never
  parsed, never logged, and deliberately **not** copied to the pasteboard (non-goal: "no copying
  file names/paths to the pasteboard"); no Quick Look, no preview generation, no thumbnails.
- **Nothing is ever written or persisted (S11, S14, S18 — product R29):** the selection is in-memory
  view-model state — no `UserDefaults`, no `@AppStorage`, no files in `tmp`/`Caches`/`Application
  Support`, no bookmark data (D19's "no bookmark store" holds), no restore across relaunch. Opening
  a new folder resets it in RAM (S18) and that is the whole lifecycle.
- **No external input (skill §4):** this story's inputs are mouse gestures, key events (frozen
  routing table with pinned key codes, D28's pattern), and the in-memory snapshot. No pasteboard, no
  URL schemes, no new entry channel, no new `CFBundleDocumentTypes`; path handling is nil —
  `URL` values travel as opaque values and only `name` (a display string) is rendered.
- **Logging:** none planned. If diagnostics are added, `os.Logger` with `privacy: .private`, never
  paths or names of user media (skill §5) — names are user content.
- **Dependencies:** none added — SwiftUI/AppKit are system frameworks (skill §6); no SPM surface.
- **Privacy manifest / permissions:** no required-reason API is added (no `UserDefaults`, no
  file-timestamp APIs) and no TCC-prompting capability is touched — **no `PrivacyInfo.xcprivacy`
  change, no purpose strings**, consistent with E2-S1–E3-S2.

### 8.1 Sandbox/media-read review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements | Unchanged — D19's four read-only keys; no new grant; zero project-config diff (§8) |
| User files access pattern | None new — names come from the in-memory snapshot; no scan, no start/stop (D19) |
| Writes to disk | None, anywhere — display-only rows; no sidecars, no caches, no exports (S14) |
| Persistence | None — selection and highlight are in-memory only; no `UserDefaults`/`@AppStorage` (S11, S18) |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19) |
| External input | Mouse/key events via the frozen routing table + in-memory snapshot only; no pasteboard/URL/channel (§8) |
| File names | Display-only — rendered as text, never logged, never parsed, never pasted (D20, non-goals) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason | No triggering API used (§8) |
| Dependencies | None added |

## 9 · Testing strategy

The UI-test mandate is settled in the spec (flows not affected — the surface is unreachable without
host-driven entry) and carried, not re-decided: the converge run keeps the default gate scope, no
`--uitests` obligation. Selection behavior is therefore carried by unit tests + functional review.

### 9.1 Selection machine (unit, `InstantPlayerTests` — the spec's AC)

`MediaListSelection` over generated row arrays: single click sets and never activates (S6); ⌘-click
toggles membership, preserving the rest (S7); ⇧-click builds the anchor…target range and keeps the
anchor (S8); arrows move and collapse to the lead (S9); ⇧-arrows extend from the anchor (S9);
clamping at both ends, no wrap, idempotent boundary repeats (S9); empty-click clears (S10);
`reset()` empties everything (S18). Pure value tests — no view hierarchy, no mouse.

### 9.2 View model & lifetime (unit)

One `MediaListViewModel`: toggle flips presentation only and leaves selection untouched (S5, S18);
`apply(collection:)` with a new snapshot resets selection; the same snapshot does not (S18);
the S17 highlight projection is read-only — asserting selection equality across highlight changes
proves S17 mechanically; activation emits the right `MediaItem.ID` intent and does not mutate
selection (S12); activation of the already-current item emits **no** `moveTo` intent and never calls
`startPlayback`/`restart()` (§4, §5.3), while activation of a different item does emit it; toggling
presentation never touches the playback session (§5.3).

### 9.3 Routing table (unit — key codes test-pinned)

The extended `FeedKeyCommand.route` matrix: ⌘L toggles in both presented views and passes through
in welcome (S3, S16); list-presented rows (↑/↓, ⇧-↑/⇧-↓, Enter, ←/→ quiet no-op) and their
feed-presented counterparts never overlap (S5, S9, S13); all other ⌘/⌥/⌃ combos still pass through;
auto-repeat parity rows. Key codes (37, 36, 76, 123–126) pinned by tests, the D34/D38 pattern.

### 9.4 List parity & performance (unit)

Rows == `collection.items` — same count, same order, same names; a mixed fixture folder shows no
non-media rows (R34–R36 parity, S1); the 10k-item `measure` of §7(7). Perf evidence recorded from
tooling (gate JSON + XCTest output), per conventions.

### 9.5 Functional review (stakeholder — the spec AC list)

The spec's acceptance list is the checklist: mixed folder listed by name in the feed's order; ⌘L
and the button toggling both ways in the same window; click/⌘-click/⇧-click/arrows/empty-click
selection; double-click and Enter landing on the item in the feed; the S17 opening highlight that
is not a selection; selection survival across switches and reset on a new folder; large folders
fluid; media files byte-identical afterwards (S14); switching to the list mid-playback keeping the
audio playing and returning to the feed landing on the same item at the same position, still playing
(§5.3); and activating the already-current row not restarting its playback (§4).

## 10 · ADR plan (continuing after D38)

Candidates for the converge ADRs (the coordinator records them in
[docs/decisions.md](../../decisions.md); numbered D39+):

- **D39 (planned) — List keyboard routing on the App-owned router:** ⌘L claims a command-modified
  key (the pass-through contract changes again), list-presented rows re-purpose ↑/↓/Enter with ⇧ as
  the extend modifier — one pure table, one monitor, test-pinned codes (§5.1).
- **D40 (planned) — List surface: custom `ScrollView` + `LazyVStack` with a view-model-owned
  Finder-semantics selection**, over `List`/`NSTableView` (§11); includes the `MediaListSelection`
  Domain machine and the root-owned presentation switch (§1.1, §3).
- **D41 (planned, minor) — Chrome policy extension:** the view-toggle button rides the demand-driven
  overlay strip on the feed and a minimal top bar in the list (§5.2).
- **D42 (planned) — Playback continues across the list↔feed switch (§5.3):** the presentation
  switch is neither a teardown point nor a D25 revisit — the session survives the hidden surface,
  same item and position on return, and activation of the already-current row is presentation-only
  (no restart). The former planning default (teardown-on-disappear + restart-on-revisit) is rejected
  by the stakeholder.

## 11 · Alternatives considered

- **`List` with its built-in selection (`Set` binding) instead of the custom surface:** rejected —
  `List`'s selection model decides its own anchor/focus semantics and would fight the spec's exact
  S7–S10 rules and, above all, S17 (a highlight that must structurally not be selection). Two
  competing selection models is the classic source of exactly the bugs S17/S18 forbid. Revisit only
  together with the §12 perf fallback (ADR D40).
- **`NSTableView`/`NSOutlineView` behind `NSViewRepresentable`:** the battle-tested large-list
  option with native Finder-grade multi-select — rejected for v1: it breaks SwiftUI-first (D1),
  brings a second state owner (AppKit selection) into the D8 model, and the budgets of §7 are
  comfortably met by the lazy SwiftUI stack at realistic folder sizes. It is the named fallback if
  §12's perf risk materializes (an ADR, not a silent swap).
- **Selection state inside `FeedViewModel` (the "one window model"):** rejected — the selection is
  MediaList's domain concept; folding it into the feed feature inverts D7 and makes S18's reset rule
  implicit. The cross-feature seam stays value/callback-level (§4, §6.1).
- **Diffing/observing the folder for live rows (spec S2):** explicitly rejected — live sync is
  E4-S2's product scope; this story's rows are immutable per snapshot by contract, which is also
  the performance answer (no diff work, §7(2)).
- **`.keyboardShortcut` for ⌘L instead of the monitor:** rejected (§5.1) — consistency with the
  proven D22/D28 route and one testable table.
- **Persisting the selection ("convenience"):** rejected by contract (product R29; S11, S14, S18) —
  not a trade-off.

## 12 · Consequences & required follow-ups

1. **`docs/architecture.md` §3 must be updated in this story's implementation** (the MediaList
   arrival rule): the shipped tree gains `Features/MediaList/{Domain,Data,Presentation}` and the
   `App/` rows note the list-model factory and the extended router. An outdated reference is a
   defect.
2. **⌘L is claimed from the pass-through set** — a deliberate input-contract change (like E3-S1's
   123/124 and E3-S2's 33/30), test-pinned; the key is stakeholder-confirmed (binding answer 2), so
   the veto fallback is closed — the consequence stands as recorded (§5.1).
3. **Perf risk — very large folders (§7):** 50k+ direct children stress SwiftUI lazy-stack
   diff/layout on first mount. Budgets (§7(1)(2)) are the tripwire; the fallback is the
   `NSTableView` bridge of §11 under D40. The 10k `measure` test keeps the regression deterministic.
4. **SwiftUI scroll-position risk (platform fact 3's lesson):** `scrollPosition(id:)`-to-row on
   list open (S17) must be proven in the first functional spike; if macOS 26 misbehaves as focus
   did in D22's rounds, the fallback is `List`'s programmatic selection or the §11 bridge — escalate
   early rather than shipping an unpositioned list.
5. **§5.3 is decided (binding answer 1): playback continues across the switch** — implementation
   must keep the session alive at the switch and obey §4's no-restart rule for activation on the
   already-current row; nothing in this design is left undecided.
6. **E5-S2 inherits a clean seam** (§6.2) and its own security delta (read-write entitlement,
   D16's never-rewrite guard, confirmation UX) — none of it leaks into this story's diff.

## 13 · Requirement traceability (S1–S18)

| Req | Design decision | § |
|---|---|---|
| S1 | Rows = `collection.items` in snapshot order, `item.name` shown | §2 |
| S2 | Immutable rows per snapshot; stale rows stay; no self-reordering | §2, §6.3 |
| S3 | ⌘L row on the App-owned router → `togglePresentation()` | §5.1 |
| S4 | `ViewToggleControl` in both views over the one toggle method | §5.2 |
| S5 | Root-owned presentation switch; feed contracts untouched; one presented view; playback continues across the switch — no teardown, no restart | §1.1, §5.1, §5.3 |
| S6 | `select(_:)` — sets selection, never activates | §3.1 |
| S7 | `toggle(_:)` — membership flip, rest preserved | §3.1 |
| S8 | `extend(to:over:)` — anchor…target range, anchor kept | §3.1 |
| S9 | `move`/`extend` arrows via the router rows; clamp, no wrap | §3.1, §5.1 |
| S10 | `clear()` on empty-space click | §3.1 |
| S11 | One `MediaListSelection` value = the E5-S2 seam; ephemeral | §3.2, §6.2 |
| S12 | Double-click → `activate` intent → `moveTo(itemID:)` + feed; current-item row = presentation-only, never restarts playback | §4, §5.3 |
| S13 | Enter (36/76) activates the lead row — same path as S12, same no-restart rule | §4, §5.1, §5.3 |
| S14 | Display-only snapshot values; zero writes; empty Data layer | §1.1, §8 |
| S15 | Budgets: 100/300 ms switch, 16 ms selection, 60 fps scroll, 10k `measure` | §7 |
| S16 | List/toggle only in folder-open; welcome untouched | §2, §5.1 |
| S17 | Highlight = read-only `currentItemID` projection + scroll anchor; structurally not selection | §3.3 |
| S18 | Selection survives switches; `reset()` only on new snapshot; never persisted | §3.2 |
