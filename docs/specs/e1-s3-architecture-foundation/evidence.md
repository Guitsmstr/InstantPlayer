# E1-S3 · Verification & evidence (task 7)

Story: [spec](spec.md) (R1–R16) · [design](design.md) (§11 matrix) · [tasks](tasks.md).
Evidence below is quoted verbatim from tooling output, never paraphrased (SDD
conventions). Walk date: 2026-10-09, branch `feat/e1-s3-architecture-foundation`.

**Functional evidence — not applicable, stated explicitly.** This story ships
structure and wiring only (spec non-goals: no product behavior). There is no
product behavior to exercise, so `./scripts/app.sh` evidence does not apply to
this story; the skeleton's behavior surface is proven by the unit tests below.
Runtime hosting of feature views is E2 story work (design §2.1, R13); the
converge-owned stakeholder glance (AC7) may still use `./scripts/app.sh run` —
it shows static placeholder text only.

## 1 · Requirement traceability — design §11 walked row by row

| Spec | Shipped artifact(s) (verified on disk, `git ls-files`) | Design | Verdict |
|---|---|---|---|
| R1 (feature = Domain/Data/Presentation) | `InstantPlayer/Features/Feed/{Domain,Data,Presentation}/` — three-layer shell with all five types | §2, §2.1 | **PASS** |
| R2 (Presentation → Domain ← Data) | `FeedView` → `FeedViewModel` → `MediaPlayerService` ← `StubMediaPlayerService`; `FeedView.swift` imports SwiftUI only, no Data import; tests `AppDependenciesTests.swift`, `FeedViewModelTests.swift` | §3.4–3.8, §5 | **PASS** |
| R3 (view models only state holders) | `FeedViewModel.swift` (`@MainActor @Observable final class`, `private(set) var probeResult`); `FeedView` stateless (`let viewModel`) | §3.7, §3.8 | **PASS** |
| R4 (async/await, actors, no completion handlers) | Both seams `async` (`wiringProbe() async -> String`); `runWiringProbe() async`; zero completion handlers; zero actors shipped (convention in [architecture.md](../../architecture.md) §5, D8) | §4 | **PASS** |
| R5 (single target, folder groups) | No `Package.swift` anywhere in `git ls-files`; one app target + two test targets; features are synchronized folder groups | §2 | **PASS** |
| R6 (two features, Core, App) | `Features/Feed/` shipped; `Features/MediaList/` reserved (first MediaList story creates it, reconciliation §2.2); `Core/` + `App/` present | §2, §2.2 | **PASS** |
| R7 (shared code in Core) | `Core/Protocols/MediaFolderRepository.swift` (the one ≥2-consumer seam); placement rules in `Core/{Models,Extensions,Utilities}/*.md` + [architecture.md](../../architecture.md) §3–4 | §2.1, §2.2, §3.4 | **PASS** |
| R8 (no networking) | Zero network APIs in shipped code (all 12 Swift files inspected this session); no URL/URLSession/AVKit anywhere; D9 restates the exclusion | §7 | **PASS** |
| R9 (composition root in App) | `App/AppDependencies.swift` (only non-test type referencing Data concretions / constructing view models); `App/InstantPlayerApp.swift` scene wiring; `App/RootView.swift` | §3.1–3.3 | **PASS** |
| R10 (Domain Swift-pure) | `Features/Feed/Domain/MediaPlayerService.swift` — zero imports; no SwiftUI/AppKit/AVKit in any Domain file | §3.5 | **PASS** |
| R11 (playback/filesystem via protocols) | `MediaPlayerService` (feature Domain) + `MediaFolderRepository` (Core) — the only two capability seams | §3.4, §3.5 | **PASS** |
| R12 (seams anticipate security-scoped access) | `MediaFolderRepository` doc contract: bookmarks, start/stop access, sandbox-safe resolution live *behind* the seam without changing callers | §3.4, §7 | **PASS** |
| R13 (zero launch cost) | §11 walk asserts: `AppDependencies.init` allocation-only (two stateless structs, no tables/registers/IO); `RootView` static text, no `.task`; `FeedView` never hosted → its `.task` never runs; nothing scheduled at launch; README placeholders ride as inert bundle bytes | §6 | **PASS** |
| R14 (ADRs continuing from D6) | [docs/decisions.md](../../decisions.md) — D7–D10 appended in house format, all `accepted` (read and verified this session; gate ADR-format step ok) | §8 | **PASS** |
| R15 (`docs/architecture.md`) | [docs/architecture.md](../../architecture.md) — all eight §9 sections present (purpose/maintenance, decision index, source tree & reserved locations, dependency rule, conventions, composition-root walkthrough, pillar hooks, evolution notes) | §9 | **PASS** |
| R16 (compiling skeleton + gate + wiring tests) | Full inventory compiled by the gate; 7 wiring tests green (verbatim below); one empty-of-product-behavior feature shell | §2, §3, §5 | **PASS** |

**Matrix verdict: 16/16 rows PASS, zero deviations open.**

Pillar assertions carried by this walk (AC6): zero launch work in shipped code
(R13 row) and zero file/network access in shipped code (R8/R12 rows) — verified
by direct inspection of every shipped Swift file during implementation and this
walk, and enforced going forward by [architecture.md](../../architecture.md) §7.

## 2 · Gate evidence — verbatim (7.3)

Command: `./scripts/validate.sh --json /private/var/folders/jc/h7sw5n3d0m1dkqfw00ymkh240000gn/T/opencode/e1-s3-gate.json`
(full gate: build + unit tests, never `--staged` for this story's code). File
contents quoted verbatim:

```json
{
  "branch": "feat/e1-s3-architecture-foundation",
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

Overall `result: "pass"`; every step `status: "ok"` (the gate's green step
status — none failed, none skipped).

### 2.1 Pillar-style steps (7.4) — quoted from the same run's step list

```
{ "name": "Lint (SwiftLint)", "status": "ok" }
{ "name": "Format check (SwiftFormat --lint)", "status": "ok" }
```

Human-readable console output of the same run:

```
== Lint (SwiftLint) ==
ok:   swiftlint lint --quiet

== Format check (SwiftFormat --lint) ==
ok:   swiftformat --lint .
```

## 3 · Wiring tests — cases enumerated, verbatim from the unit-test log (AC2)

From the same gate run's test log
(`instantplayer-gate.mUPKTA/03-xcodebuild-test-only-testing-InstantPlayerTests.log`):

```
** TEST SUCCEEDED **

Testing started
Test suite 'AppDependenciesTests' started on 'My Mac - InstantPlayer (11917)'
Test suite 'FeedViewModelTests' started on 'My Mac - InstantPlayer (11917)'
Test case 'FeedViewModelTests/shellViewModelProbesEndToEndThroughCompositionRoot()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'AppDependenciesTests/bindingAPIAcceptsInjection()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'AppDependenciesTests/filesystemSeamBindingResolvesToStub()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'AppDependenciesTests/stubProbesAnswerWithConstants()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'AppDependenciesTests/playerSeamBindingResolvesToStub()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'FeedViewModelTests/viewConstructsWithViewModel()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
Test case 'AppDependenciesTests/defaultDependencyGraphConstructs()' passed on 'My Mac - InstantPlayer (11917)' (0.000 seconds)
```

Coverage vs design §5: §5.1 cases 1–5 → `defaultDependencyGraphConstructs`,
`playerSeamBindingResolvesToStub`, `filesystemSeamBindingResolvesToStub`,
`bindingAPIAcceptsInjection`, `stubProbesAnswerWithConstants`; §5.2 cases 1–2 →
`shellViewModelProbesEndToEndThroughCompositionRoot`,
`viewConstructsWithViewModel`. All seven present, all passed.

## 4 · Recorded deviation — task 1 placeholder names (already-noted)

The design §2 inventory named three `README.md` placeholders under
`Core/{Models,Extensions,Utilities}`. Reality: synchronized groups copy bundle
resources flattened, so three same-named files collide — first gate run failed
with `error: Multiple commands produce '…/Resources/README.md'`. The only
in-design remedy (membership exception set) is forbidden pbxproj surgery
(design §1: "not worth it"). Minimal fix applied in task 1: per-folder names
`Models.md` / `Extensions.md` / `Utilities.md`, content and placement-rule
intent unchanged; §3 type contracts untouched. **Coordinator-ratified** and
codified as a standing rule in [architecture.md](../../architecture.md) §5
("Synchronized-group placeholder files"). No other deviations from design §1
facts or §3 contracts occurred.

## 5 · Acceptance criteria (mirroring tasks.md — AC1–AC6 ticked here)

- [x] **AC1 · R16** — skeleton compiles; gate `result: "pass"` (verbatim JSON §2;
  every step `status: "ok"` — the gate's green value).
- [x] **AC2 · R16** — all seven design §5 wiring-test cases present and green
  (unit-test step `ok`; cases enumerated verbatim §3).
- [x] **AC3 · R14** — D7–D10 recorded in [docs/decisions.md](../../decisions.md)
  in house format (ADR-format step `ok`).
- [x] **AC4 · R15** — [docs/architecture.md](../../architecture.md) exists with
  design §9's eight sections.
- [x] **AC5** — design §11 walked row-by-row (R1–R16) in §1 above — 16/16 PASS.
- [x] **AC6 · pillars & style** — SwiftLint + SwiftFormat steps `ok` (quoted
  §2.1); the §1 walk asserts zero launch work (R13) and zero file/network access
  (R8, R12) in shipped code.

Converge-owned, intentionally unticked here:

- [ ] **AC7 · stakeholder gate** — explicit approval of the delivered structure
  (optional glance via `./scripts/app.sh run` — static placeholder only).
- [ ] **AC8 · validator review** — adversarial PASS over spec R1–R16, design §11,
  both pillar-skill checklists.
- [ ] **AC9 · story closure** — backlog E1-S3 → `done`; `git merge --no-ff` into
  `main`; delete the story branch.
