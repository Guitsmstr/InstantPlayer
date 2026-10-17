# Backlog

Story states: `draft` → `refined` → `ready` → `in progress` → `done` (or `postponed`).

Stories in `draft` need refinement: acceptance criteria, dependencies, and resolution of open questions. Refinement happens task by task in iterations with the stakeholder (spec-driven process). Story work is executed through the `sdd` coordinator agent; per-story artifacts live in `docs/specs/<story>/`.

---

## E0 — Agent harness (SDD bootstrap)

- [x] **E0-S1 · Harness bootstrap** (multi-agent SDD pipeline adapted from an earlier project, macOS pillars, deterministic gate) · `done`
  - Agents: `sdd`, `spec-author`, `implementer`, `implementer-flash`, `validator`. Skills: `swift-security`, `swift-performance`. Gate: `scripts/validate.sh` (docs checks, SwiftLint, SwiftFormat, `xcodebuild` build + unit tests, macOS destination) via pre-commit hook. Routing simplified (D3): the coordinator assigns `implementer`/`implementer-flash` batches directly — no routing model. Decisions D1–D6.

## E1 — Product foundation

- [x] **E1-S1 · Product spec authoring** (fill `docs/spec.md` with real scope + EARS requirements) · `done`
  - The bootstrap skeleton has `[NEEDS CLARIFICATION]` placeholders for target user, video sources, and the minimum playback experience. Refine with the stakeholder; then the project has a real source of truth and feature epics can be broken out below.
- [x] **E1-S2 · Baseline hygiene** (SwiftLint/SwiftFormat configs tuned to the team style; CI-ready gate) · `done`
  - The gate currently runs both tools with defaults. Decide the house rules (`.swiftlint.yml`, `.swiftformat`) in a small story; record as an ADR. Optionally run UI tests in the validator/converge phase.
- [x] **E1-S3 · Architecture foundation** (Clean Architecture + MVVM + Swift Concurrency skeleton; runs before E1-S1's parked tasks resume and before any E2 feature work) · `done`
  - Stakeholder decisions: Clean Architecture layering (`Domain/Data/Presentation` per feature); MVVM presentation (`@Observable` view models on `@MainActor`); Swift Concurrency (`async/await`, actors for mutable shared state); folder groups in the single app target (features-as-modules, local SPM extraction later); `Features/{Feed,MediaList}`; `Core/{Protocols,Models,Extensions,Utilities}` — **no networking in v1** (deferred, local-files product); `App/` composition root; Domain stays Swift-pure (AVPlayer wrapped behind a protocol in Data).
  - Delivers: architecture ADRs + `docs/architecture.md` + code skeleton (folder structure, Core base protocols, App composition root, one empty feature shell) with wiring unit tests. Pillar constraints: skeleton must not add launch cost (RNF-02); file-access seams designed for sandbox/security-scoped access (RNF-04).
  - Sequencing note: E1-S1 is parked mid-story (its spec/design/tasks are approved on `feat/e1-s1-product-spec`); it resumes and completes after this story, renumbering its ADR batch if this story takes D7+.

## E2 — Walking skeleton (open a folder, see the feed, play it)

All E2–E5 feature stories implement on the architecture per [docs/architecture.md](architecture.md) (D7–D10) — Clean layering per feature (`Domain`/`Data`/`Presentation`).

- [x] **E2-S1 · Entry & media collection** (open a folder via Finder or drag & drop; native formats, direct children; welcome state) · `done`
  - Requirements: R1–R6, R34–R36 (entry, formats & filtering)
- [x] **E2-S2 · Vertical feed & window** (one combined feed; current item fills the viewport; scroll/arrow paging; single window, new open replaces in place) · `done`
  - Requirements: R7–R10, R37–R40 (feed navigation, window)
- [x] **E2-S3 · Basic playback** (auto-play with no perceptible wait; play/pause; loop in place; media files never rewritten) · `done`
  - Requirements: R11, R12, R15, R17 (playback)

## E3 — Playback controls (inspect footage precisely without leaving the feed)

All E2–E5 feature stories implement on the architecture per [docs/architecture.md](architecture.md) (D7–D10) — Clean layering per feature (see the preamble under E2).

- [x] **E3-S1 · Scrub & seek** (move playback to the indicated point in the current video) · `done`
  - Requirements: R13 (playback)
- [x] **E3-S2 · Playback speed** (apply the selected speed to the current video) · `done`
  - Requirements: R14 (playback)
  - Delivered per [docs/specs/e3-s2-playback-speed/](specs/e3-s2-playback-speed/spec.md) (S1–S18): five-preset ladder (0.25×–2×) on the control bar plus `[`/`]` stepping with hold-to-repeat, ≠1× badge, session-wide carry (relaunch at 1×), start-at-speed, seek/loop preservation (ADRs D36–D38). Functional review: 11/11 items passed (2026-10-14); two review notes deferred (see Follow-ups).
  - Residual (ratified 2026-10-14): the pre-existing E2-S2 display-budget test (≤300 ms p95) is host-speed sensitive and can flake under parallel-runner load; E3-S2's interference was reduced (`dd1ffe0`) and a green-run converge protocol was ratified (story evidence §8.1).
- [ ] **E3-S3 · Volume & mute** (app-level keyboard volume, mute toggle, state restored on relaunch) · `draft`
  - Requirements: R18–R20 (volume)

## E4 — Ordering & live sync (feed and list always match the folder)

All E2–E5 feature stories implement on the architecture per [docs/architecture.md](architecture.md) (D7–D10) — Clean layering per feature (see the preamble under E2).

- [ ] **E4-S1 · Ordering modes** (folder's own order by default; filename / date-added switch) · `draft`
  - Requirements: R21–R22 (ordering)
- [ ] **E4-S2 · Live folder sync** (additions, removals, and renames reflected live; removal of the current item keeps the viewer on a neighbor) · `draft`
  - Requirements: R23–R26 (live sync)

## E5 — List view & operations (act on what you just watched)

All E2–E5 feature stories implement on the architecture per [docs/architecture.md](architecture.md) (D7–D10) — Clean layering per feature (see the preamble under E2).

- [x] **E5-S1 · List view & selection** (every media item listed by file name per the current ordering; ad-hoc multi-select, nothing persisted) · `done`
  - Requirements: R27–R29 (list view & operations)
  - Delivered per [docs/specs/e5-s1-list-view-selection/](specs/e5-s1-list-view-selection/spec.md) (S1–S18): Finder-standard selection model, ⌘L + floating top-left demand-driven toggle (video AND image pages), jump-to-item activation with auto-play, highlight-current-item on open, session-lifetime selection (ADRs D39–D42). Ran in parallel with E3-S3 (2026-10-15). Validator PASS after 2 fix loops; functional review 11/11 accepted (2026-10-15) after three playback-activation fixes (`fcb1de2`, `b20df5e`, `07a9d57`).
- [ ] **E5-S2 · File operations** (zip the selection; move to a chosen destination; reveal in Finder; trash after confirmation, recoverably) · `draft`
  - Requirements: R30–R33 (list view & operations)

Coverage (E2–E5): the ten ranges place R1–R15 and R17–R40 exactly once each (E2-S1: 9, E2-S2: 8, E2-S3: 4, E3: 5, E4: 6, E5: 7); all nine capability groups map onto story-sized work. R16 is deliberately not assigned to a single story — it is the cross-cutting responsiveness requirement (no stalls across browsing, transport, ordering, and view switches) spanning every UI story, and each story's own design carries its share of the responsiveness budget.

## Follow-ups (unscheduled)

- **Control-bar UI polish** — stakeholder notes from the E3-S2 functional review (2026-10-14): redesign the progress bar, and revisit the speed-menu button labeling (the constant "Speed" label with the speed names re-displayed in the menu reads redundant). Fold into the control-bar redesign once the specs are finished.
- **E2-S2 display-budget hardening** — re-record or harden the 24 MP display-budget p95 test (≤300 ms) on a thermally neutral machine; the test is host-speed/load sensitive and can flake under parallel-runner load (E3-S2 evidence §8.1; E3-S2's interference reduced in `dd1ffe0`).
