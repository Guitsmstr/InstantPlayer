# E1-S3 · Architecture foundation — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md) (R1–R16).
Branch: `feat/e1-s3-architecture-foundation` — already checked out; never switch branches mid-story.
One task = one commit. Checkboxes are ticked during implementation, each task's boxes in its own
commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story defines the launch
   path and the file-access seams every later story inherits; both checklists apply (design §6, §7).
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI copy.
3. **Style:** SwiftLint + SwiftFormat are gate steps and must pass. Doc comments and formatting are
   implementer latitude; style tuning is E1-S2's story, never this one.
4. **Synchronized groups (design §1):** all three targets use file-system-synchronized groups —
   files land on disk under `InstantPlayer/` / `InstantPlayerTests/` and join their target
   automatically. **Never hand-edit `project.pbxproj`.** Target membership is proven by the gate's
   build compiling the new files.
5. **Gate:** tasks 1–4 (code) run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Tasks 5–6 (docs-only) stage first, then run `./scripts/validate.sh --staged`. Task 7
   runs the full gate with `--json` for evidence. Fix every failure before moving on; the
   pre-commit hook re-runs the gate on every commit.
6. **Contracts are frozen:** design §3 signatures are the contract — name/signature changes are
   design amendments: stop and report to the coordinator, never deviate silently. Same for any
   design §1 fact that no longer holds.
7. **No invented behavior:** structure and wiring only (spec non-goals) — no product features, no
   networking (R8), no SPM extraction, no DI framework, no actor (design §4), no `#Preview`.

## Sequencing & parallelism

- **Code tasks are strictly sequential: 1 → 2 → 3 → 4** (compile dependencies per design §3).
  *Order note:* the coordinator sketch listed the composition root before the feature shell; the
  design's contracts force the reverse — `AppDependencies` (design §3.1) references
  `StubMediaPlayerService`, `StubMediaFolderRepository`, and `FeedViewModel`, so the App task
  cannot compile before the shell, while the shell needs only Core's seam (task 1). Tests (task 4)
  cover tasks 2–3 and land after both (design §5). The plan follows the design.
- **`[P]` tasks 5 and 6** are docs-only, independent of each other and of tasks 1–4 — they
  transcribe the approved design (§8, §9), not shipped code, so the coordinator may route them in
  any wave, including alongside code tasks. Order 5 → 6 reads best (architecture.md's decision
  index once D7–D10 exist) but is not required.
- **Task 7 is last** and depends on all others.
- Routing (D3 — coordinator's call): tasks 1–4 → `implementer` (contract-bound code); tasks 5–6 →
  `implementer-flash` candidates (approved-design transcription); task 7 → `implementer`
  (evidence discipline).

---

## Task 1 — Core seam + reserved folders · design §1, §2–§2.1, §3.4

Deliverable (code): `InstantPlayer/Core/Protocols/MediaFolderRepository.swift` +
`InstantPlayer/Core/Models/README.md`, `InstantPlayer/Core/Extensions/README.md`,
`InstantPlayer/Core/Utilities/README.md`.

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** Re-verify every design §1 fact against the repo (first task, per §1): synchronized
  root groups over `InstantPlayer/`, `InstantPlayerTests/`, `InstantPlayerUITests/`;
  `MACOSX_DEPLOYMENT_TARGET = 26.0` in every configuration; `SWIFT_VERSION = 5.0`; Swift Testing in
  the template test; baseline `.swiftlint.yml`. **Any drift (especially deployment target below 14
  or synchronized groups gone): stop and report — a design amendment is required.**
  *(All facts hold: 3× PBXFileSystemSynchronizedRootGroup; 26.0 in all 4 configs; 5.0 in all 6;
  Swift Testing template; baseline config present.)*
- [x] **1.3** `MediaFolderRepository.swift` exactly per design §3.4:
  `protocol MediaFolderRepository: Sendable` with `func wiringProbe() async -> String`. Doc
  comments carry the §3.4 contract: the only sanctioned filesystem path (R11); security-scoped
  handling (bookmarks, start/stop access, sandbox-safe resolution) will be added *behind* the seam
  without changing callers (R12); real operations arrive with the feature stories that need them.
- [x] **1.4** The three READMEs per design §2.1: each states its group's purpose and the placement
  rule (when code goes here vs. a feature). Zero code, zero invented types — READMEs are the
  sanctioned placeholder because git cannot hold empty folders. They ride as bundle resources
  (§1 fact) — expected, no launch cost.
  *(Deviation for coordinator ratification: files named `Models.md` / `Extensions.md` /
  `Utilities.md` instead of three `README.md` — synchronized groups copy bundle resources
  flattened into `Contents/Resources/`, so three same-named files collide
  ("Multiple commands produce …/Resources/README.md", first gate run failed). Content and
  placement-rule intent unchanged; the §3.4 contract is untouched.)*
- [x] **1.5** Full gate `./scripts/validate.sh` — the new protocol must compile (that is what
  proves target membership). Fix, tick this task's boxes, commit:
  `feat(e1-s3): core seam + reserved folders`.

## Task 2 — Feed feature shell · design §2, §2.1, §3.5–§3.8

Deliverable (code): under `InstantPlayer/Features/Feed/` — `Domain/MediaPlayerService.swift`,
`Data/StubMediaPlayerService.swift`, `Data/StubMediaFolderRepository.swift`,
`Presentation/FeedViewModel.swift`, `Presentation/FeedView.swift`.

- [x] **2.1** Load `swift-security` + `swift-performance` before editing.
- [x] **2.2** `MediaPlayerService.swift` per design §3.5 — the feature-owned player seam:
  `protocol MediaPlayerService: Sendable` with `func wiringProbe() async -> String`. Swift-pure
  Domain (R10): no SwiftUI/AppKit/AVKit imports (no imports needed at all).
- [x] **2.3** Stubs per design §3.6: stateless `Sendable` structs; `wiringProbe()` returns the
  constants `"StubMediaPlayerService"` / `"StubMediaFolderRepository"`. Zero I/O — no FileManager,
  no URL, no AVKit, no networking anywhere in shipped code (design §7, R8).
- [x] **2.4** `FeedViewModel.swift` per design §3.7 — the house pattern: `@MainActor @Observable
  final class`; `init(mediaPlayerService: any MediaPlayerService)`; `private(set) var probeResult:
  String?`; `func runWiringProbe() async` assigning `probeResult = await
  mediaPlayerService.wiringProbe()`.
- [x] **2.5** `FeedView.swift` per design §3.8 — a dumb binder: `let viewModel: FeedViewModel`;
  body shows `Text(viewModel.probeResult ?? "Feed shell — wiring only, no product behavior yet")`,
  padded, with `.task { await viewModel.runWiringProbe() }` (the lifecycle pattern feature stories
  copy). No state of its own, no Data imports (R2), no `#Preview`, hosted nowhere yet (R13).
- [x] **2.6** No App-layer references — the shell compiles standalone against Core (task 1). Full
  gate; fix; tick; commit: `feat(e1-s3): feed feature shell — domain seam, data stubs, view model,
  view`.

## Task 3 — App composition root · design §2 (App tree + deletions), §3.1–§3.3

Deliverable (code): `InstantPlayer/App/InstantPlayerApp.swift` (moved from target root +
rewritten), `InstantPlayer/App/AppDependencies.swift`, `InstantPlayer/App/RootView.swift`; delete
`InstantPlayer/ContentView.swift`.

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** Move `InstantPlayer/InstantPlayerApp.swift` → `InstantPlayer/App/` (plain disk move;
  synchronized group — no pbxproj edit) and rewrite per design §3.2: `@State private var
  dependencies = AppDependencies()` + `WindowGroup { RootView(dependencies: dependencies) }`. If
  the compiler flags MainActor isolation of the default initializer under the Swift 5 language
  mode: add an explicit `@MainActor` on the struct (sanctioned fallback, §3.2). No window styling —
  feature-story work. *(Fallback not needed — build clean on first gate run.)*
- [x] **3.3** `AppDependencies.swift` per design §3.1, exact contract: `@MainActor final class`;
  `let mediaPlayerService: any MediaPlayerService`; `let mediaFolderRepository: any
  MediaFolderRepository`; `init(mediaPlayerService: any MediaPlayerService =
  StubMediaPlayerService(), mediaFolderRepository: any MediaFolderRepository =
  StubMediaFolderRepository())`; `func makeFeedViewModel() -> FeedViewModel`. Doc comments carry
  the binding rules (§3.1): the only non-test type allowed to reference feature Data concretions
  or construct feature view models; allocation-only construction (R13); the factory is called on
  demand — never at launch.
- [x] **3.4** `RootView.swift` per design §3.3: `let dependencies: AppDependencies`; body = padded
  VStack with `Text("InstantPlayer")` + footnote `Text("Architecture skeleton — features land in
  E2 stories")`. Static text only — hosts no feature view (R13); the stored `dependencies` is
  intentionally unused by the body (it is the wiring guarantee later stories plug into).
- [x] **3.5** Delete `InstantPlayer/ContentView.swift` — template placeholder superseded by
  `RootView` (disk deletion drops it from the target; no pbxproj edit).
- [x] **3.6** Keep `InstantPlayerTests/InstantPlayerTests.swift` until task 4: the template example
  test is replaced by the real wiring tests *in that task's same commit*, so the unit-test target
  is never empty at a commit boundary (the gate runs `xcodebuild test
  -only-testing:InstantPlayerTests` on every commit).
- [x] **3.7** Full gate; fix; tick; commit: `feat(e1-s3): app composition root — entry,
  dependencies container, root view`.

## Task 4 — Wiring tests · design §2 (test tree), §5

Deliverable (code): `InstantPlayerTests/App/AppDependenciesTests.swift`,
`InstantPlayerTests/Features/Feed/FeedViewModelTests.swift`; delete
`InstantPlayerTests/InstantPlayerTests.swift`.

- [ ] **4.1** Load `swift-security` + `swift-performance` before editing.
- [ ] **4.2** Swift Testing per design §5 + §1: `import Testing`, `@testable import InstantPlayer`,
  `@MainActor` suites (the types under test are MainActor-isolated), `@Test` + `#expect` — never
  XCTest.
- [ ] **4.3** `AppDependenciesTests.swift` — all five §5.1 cases: (1) the default dependency graph
  constructs; (2) `deps.mediaPlayerService is StubMediaPlayerService`; (3)
  `deps.mediaFolderRepository is StubMediaFolderRepository`; (4) the binding API accepts injection
  — a test-local `private struct ProbeMediaPlayerService: MediaPlayerService` passed to the
  initializer is what `makeFeedViewModel()` uses, its probe value flowing through (the
  seam-swapping pattern future security/performance tests reuse, §5.1 item 4 + §7); (5) behavioral
  end-to-end — `await` both stub probes and expect their constants.
- [ ] **4.4** `FeedViewModelTests.swift` — both §5.2 cases: (1) `deps.makeFeedViewModel()` → `await
  viewModel.runWiringProbe()` → `probeResult == "StubMediaPlayerService"` — Presentation → Domain
  ← Data end-to-end through the binding (R1, R2, R3, R16); (2) `_ = FeedView(viewModel:)`
  constructs (no rendering in unit tests).
- [ ] **4.5** Delete `InstantPlayerTests/InstantPlayerTests.swift` — superseded by the two files
  above, in this same commit.
- [ ] **4.6** `InstantPlayerUITests/` untouched — template launch tests stay; UI tests are out of
  the per-commit gate per D4 and this story adds no UI behavior.
- [ ] **4.7** Full gate — the unit tests run and must be green (they are the R16 deliverable);
  fix; tick; commit: `test(e1-s3): composition-root and feed wiring tests`.

## Task 5 — ADR batch D7–D10 `[P]` · design §8 (+ §10), spec R14

Deliverable (docs): `docs/decisions.md` — append D7–D10.

- [ ] **5.1** Append four ADRs continuing the numbering (the log currently ends at D6), house
  heading `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each with context,
  decision, alternatives, consequences. Titles and one-line decisions exactly per the §8 table:
  **D7 — Clean Architecture layering & dependency rule** (R1, R2, R10, R11, R12) ·
  **D8 — Presentation & concurrency model: MVVM `@Observable` + async/await** (R3, R4) ·
  **D9 — Module organization: single target, folder groups, Core, no networking** (R5–R8) ·
  **D10 — Hand-wired composition root in App** (R9, R16).
- [ ] **5.2** Pull each entry's alternatives from the matching design §10 rows (SPM packages per
  feature, third-party DI, Core-parking every seam, `ObservableObject`, `RootView` hosting
  `FeedView`, empty seam protocols, an actor now, real Core types).
- [ ] **5.3** Status `accepted` — the decisions are stakeholder-final (spec story context) and
  design §8 requires them accepted by convergence. Record as a consequence in D7 (the first taker
  of D7+): parked E1-S1 must renumber its ADR batch — expected and stakeholder-acknowledged.
- [ ] **5.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links — the pre-commit hook runs the same check); fix; tick; commit:
  `docs(e1-s3): ADRs D7–D10 — architecture decisions`.

## Task 6 — Standing architecture reference `[P]` · design §9, spec R15

Deliverable (docs): `docs/architecture.md` — new file.

- [ ] **6.1** Create `docs/architecture.md` with exactly design §9's eight sections: (1) purpose &
  maintenance rule — updated by every story that changes structure, links to D7–D10; (2) decision
  index — one line per architecture ADR; (3) source tree & reserved locations — the shipped tree
  (design §2) plus reserved `Features/MediaList/` (the first MediaList story creates it) and the
  Core placement rules; (4) the dependency rule — Presentation → Domain ← Data, Domain purity, the
  seam placement rule (Core iff ≥2 consumers; promotion is a mechanical move), how reviewers check
  it; (5) conventions — `@MainActor` + `@Observable` view models, async/await only, actor
  introduction trigger, no completion handlers, naming, English (D6); (6) composition root: adding
  a feature — Domain protocol → Data conformance → view model → view → factory on
  `AppDependencies` → host in `RootView`; (7) pillar hooks — launch-cost discipline (RNF-02) and
  security-scoped seam guidance (RNF-04), each naming the skill to load and when; (8) evolution
  notes — SPM extraction trigger, MediaList arrival, seam promotion, actor introduction, E1-S1 ADR
  renumbering.
- [ ] **6.2** Internal links must resolve (the gate checks them): link only to existing files
  (`docs/decisions.md`, `docs/spec.md`) — safe in either 5/6 order, those files exist regardless.
- [ ] **6.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e1-s3): standing architecture reference`.

## Task 7 — Verification & evidence · design §11, spec R14–R16

Deliverable (docs): `docs/specs/e1-s3-architecture-foundation/evidence.md` (new) +
acceptance-criteria ticks in this file.

- [ ] **7.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [ ] **7.2** Walk design §11's traceability matrix **row by row** (R1–R16): for each row, name
  the shipped artifact — file, ADR, or test — that satisfies it, with its design section. Record
  the full table in evidence.md.
- [ ] **7.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/e1-s3-gate.json` (`<tmp>` = session temp dir outside the
  repo; the JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every
  step name and status. Evidence comes from tooling, never memory (SDD conventions).
- [ ] **7.4** Confirm the SwiftLint and SwiftFormat steps read `pass` in that output and quote
  them. Any red step: reopen the owning task (fix → rerun → re-quote) before committing.
- [ ] **7.5** Tick AC1–AC6 below and mirror them in evidence.md; leave the converge-owned AC7–AC9
  unticked.
- [ ] **7.6** Commit (docs-only — the hook's staged docs checks cover it):
  `docs(e1-s3): evidence and acceptance — traceability walk + gate output`.

---

## Acceptance criteria

Ticked by task 7, each backed by quoted gate evidence:

- [ ] **AC1 · R16** — skeleton compiles; full gate `result: "pass"` with every step `pass`
  (verbatim JSON in evidence.md)
- [ ] **AC2 · R16** — all design §5 wiring-test cases present and green (unit-test step `pass`,
  cases enumerated in evidence.md)
- [ ] **AC3 · R14** — D7–D10 recorded in `docs/decisions.md` in house format (ADR-format step
  `pass`)
- [ ] **AC4 · R15** — `docs/architecture.md` exists with design §9's eight sections
- [ ] **AC5** — design §11 walked row-by-row (R1–R16) in evidence.md
- [ ] **AC6 · pillars & style** — SwiftLint + SwiftFormat steps `pass` (quoted); the §11 walk
  asserts zero launch work (R13) and zero file/network access (R8, R12) in shipped code

Converge-owned — the coordinator ticks these; task 7 never does:

- [ ] **AC7 · stakeholder gate** — explicit approval of the delivered structure (spec/design were
  pre-approved; this gate covers the implementation). Optional glance via `./scripts/app.sh run` —
  static placeholder only; this is not a UI story.
- [ ] **AC8 · validator review** — adversarial PASS over spec R1–R16, design §11, and both
  pillar-skill checklists (UI tests at the validator's discretion — D4 keeps them out of the
  per-commit gate).
- [ ] **AC9 · story closure** — backlog E1-S3 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e1-s3-architecture-foundation`.

## Converge (coordinator)

1. **Stakeholder gate** on the delivered skeleton + D7–D10 + `docs/architecture.md`.
2. **Validator review** — loads both pillar skills; adversarial pass over R1–R16 / design §11.
3. **Closure** — tick AC7–AC9, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

After this story merges, **E1-S1 resumes** (parked mid-story on `feat/e1-s1-product-spec` with its
approved artifacts): it renumbers its ADR batch because this story took D7–D10 — expected and
stakeholder-acknowledged (backlog sequencing note).

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D6; this story appends D7–D10)
- [docs/spec.md](../../spec.md) — product source of truth (RNF-02, RNF-04)
- [docs/backlog.md](../../backlog.md) — story entry and sequencing context
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
