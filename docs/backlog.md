# Backlog

Story states: `draft` → `refined` → `ready` → `in progress` → `done` (or `postponed`).

Stories in `draft` need refinement: acceptance criteria, dependencies, and resolution of open questions. Refinement happens task by task in iterations with the stakeholder (spec-driven process). Story work is executed through the `sdd` coordinator agent; per-story artifacts live in `docs/specs/<story>/`.

---

## E0 — Agent harness (SDD bootstrap)

- [x] **E0-S1 · Harness bootstrap** (multi-agent SDD pipeline adapted from an earlier project, macOS pillars, deterministic gate) · `done`
  - Agents: `sdd`, `spec-author`, `implementer`, `implementer-flash`, `validator`. Skills: `swift-security`, `swift-performance`. Gate: `scripts/validate.sh` (docs checks, SwiftLint, SwiftFormat, `xcodebuild` build + unit tests, macOS destination) via pre-commit hook. Routing simplified (D3): the coordinator assigns `implementer`/`implementer-flash` batches directly — no routing model. Decisions D1–D6.

## E1 — Product foundation

- [ ] **E1-S1 · Product spec authoring** (fill `docs/spec.md` with real scope + EARS requirements) · `draft`
  - The bootstrap skeleton has `[NEEDS CLARIFICATION]` placeholders for target user, video sources, and the minimum playback experience. Refine with the stakeholder; then the project has a real source of truth and feature epics can be broken out below.
- [ ] **E1-S2 · Baseline hygiene** (SwiftLint/SwiftFormat configs tuned to the team style; CI-ready gate) · `draft`
  - The gate currently runs both tools with defaults. Decide the house rules (`.swiftlint.yml`, `.swiftformat`) in a small story; record as an ADR. Optionally run UI tests in the validator/converge phase.
- [x] **E1-S3 · Architecture foundation** (Clean Architecture + MVVM + Swift Concurrency skeleton; runs before E1-S1's parked tasks resume and before any E2 feature work) · `done`
  - Stakeholder decisions: Clean Architecture layering (`Domain/Data/Presentation` per feature); MVVM presentation (`@Observable` view models on `@MainActor`); Swift Concurrency (`async/await`, actors for mutable shared state); folder groups in the single app target (features-as-modules, local SPM extraction later); `Features/{Feed,MediaList}`; `Core/{Protocols,Models,Extensions,Utilities}` — **no networking in v1** (deferred, local-files product); `App/` composition root; Domain stays Swift-pure (AVPlayer wrapped behind a protocol in Data).
  - Delivers: architecture ADRs + `docs/architecture.md` + code skeleton (folder structure, Core base protocols, App composition root, one empty feature shell) with wiring unit tests. Pillar constraints: skeleton must not add launch cost (RNF-02); file-access seams designed for sandbox/security-scoped access (RNF-04).
  - Sequencing note: E1-S1 is parked mid-story (its spec/design/tasks are approved on `feat/e1-s1-product-spec`); it resumes and completes after this story, renumbering its ADR batch if this story takes D7+.
