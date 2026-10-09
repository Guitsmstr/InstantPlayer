# E1-S3 · Architecture foundation — Story Spec

## Story context

- **Why this story, why now.** The stakeholder directed that the project's architecture be established **before any implementation** (architecture-first directive). Nothing is implemented yet: the codebase holds only the bootstrap harness — targets, deterministic gate, docs scaffolding. `docs/spec.md` is still a skeleton with placeholder scope; authoring the real product spec is the parked story **E1-S1** (its artifacts live on another branch and are not referenced here). This story runs before E1-S1's parked tasks resume and before any feature work (E2+).
- **Product shape assumed for this story** (stakeholder-stated; E1-S1 authors the real product spec): v1 is a macOS stories-style viewer for a folder's videos and images — a vertical media **Feed** (entry, folder loading, playback controls) and a **MediaList** (list, selection, file operations). **Local files only — no networking.**
- **What this story delivers.** Not product behavior: the architecture decisions recorded as ADRs, a standing architecture reference, and a compiling code skeleton — structure and wiring only, with unit tests verifying the wiring. All architecture decisions below are stakeholder-final; this spec has no open questions.
- **Pillars.** RNF-02 (performance) and RNF-04 (security) in [docs/spec.md](../../spec.md) are non-negotiable (D5) and shape this story's constraints: the skeleton must not add launch cost, and file-access seams must anticipate sandbox/security-scoped access.

## User stories

- **US1** · As a developer, I want the architecture foundation decided and scaffolded before any feature implementation, so that every feature story lands into a pre-agreed structure and no refactor tax accumulates.
- **US2** · As a stakeholder, I want the architecture decisions recorded as ADRs and captured in a standing architecture reference, so that later stories cite them instead of re-litigating structure.
- **US3** · As a reviewer/validator, I want the architecture expressed as explicit guarantees (dependency direction, domain purity, abstraction seams), so future stories can be reviewed against them and drift is caught early.

## Requirements (EARS)

Architecture constraints — guarantees on the codebase, not user-facing behavior. WHAT and WHY only: the concrete file tree, protocol names, and type signatures are design-phase output (`design.md`).

### Layering & dependency rule

- **R1:** WHEN a new feature is added to the product
  THE SYSTEM SHALL implement it as a self-contained unit that owns three internal layers — **Domain**, **Data**, and **Presentation**
- **R2:** WHEN a feature's layers reference each other
  THE SYSTEM SHALL follow the dependency rule **Presentation → Domain ← Data**: Data implements protocols owned by Domain, and Presentation never imports Data

### Presentation (MVVM)

- **R3:** WHEN a feature presents state to the user
  THE SYSTEM SHALL hold presentation state only in view models, with SwiftUI views binding to and observing them — view models are the only presentation-state holders

### Concurrency model

- **R4:** WHEN asynchronous work is performed (e.g. folder loading, playback, file operations)
  THE SYSTEM SHALL express it with async/await, isolate mutable shared state behind actors, and not introduce completion-handler patterns

### Module organization

- **R5:** WHEN code is organized into modules
  THE SYSTEM SHALL keep a single app target with features as folder groups inside it — extraction into separate local packages is deferred until needed
- **R6:** WHEN v1's feature set is scoped
  THE SYSTEM SHALL consist of exactly two features — **Feed** (vertical media feed: entry, folder loading, playback controls) and **MediaList** (media list: listing, selection, file operations) — served by shared code in **Core** and composed by **App**
- **R7:** WHEN code is needed by more than one feature
  THE SYSTEM SHALL provide it from **Core** (base protocols, cross-feature models, extensions, utilities) instead of coupling features to each other
- **R8:** WHEN networking is considered anywhere in v1 (Core or any feature)
  THE SYSTEM SHALL exclude it — v1 is a local-files product; networking is explicitly deferred

### Composition root & domain purity

- **R9:** WHEN Domain protocols need concrete implementations, or windows and scenes need wiring
  THE SYSTEM SHALL provide them only in **App** — the composition root, the single place where Domain protocols bind to concrete implementations and windows/scenes are wired
- **R10:** WHEN Domain code is written
  THE SYSTEM SHALL keep it Swift-pure — no SwiftUI, AppKit, or AVKit imports (no UI or media-framework dependencies in Domain)

### Abstraction seams & pillars

- **R11:** WHEN Presentation or Domain code needs media playback or filesystem access
  THE SYSTEM SHALL reach them only through protocol-defined abstractions (e.g. a wrapped player service, repositories), so presentation never touches framework objects directly
- **R12:** WHEN file access is designed behind those abstractions
  THE SYSTEM SHALL anticipate sandboxed and security-scoped access — seams shaped so security-scoped resource handling can live behind them without changing their callers (RNF-04: "sandbox + security-scoped access for files")
- **R13:** WHEN the app launches with only the architecture skeleton in place
  THE SYSTEM SHALL add no launch cost relative to an empty app — the skeleton contributes structure and wiring only, not launch work (RNF-02: "launch is minimal")

### Deliverables & acceptance criteria

- **R14:** WHEN this story completes
  THE SYSTEM SHALL have its architecture decisions recorded as ADRs in [docs/decisions.md](../../decisions.md), continuing the log's numbering (currently through D6)
- **R15:** WHEN a contributor needs the standing architecture reference
  THE SYSTEM SHALL provide `docs/architecture.md` describing the layers, dependency rule, and conventions — maintained as the codebase evolves
- **R16:** WHEN the code skeleton is delivered
  THE SYSTEM SHALL compile and pass the deterministic gate (`./scripts/validate.sh`), shipping the folder structure, Core base protocols, the App composition root, one empty feature shell, and unit tests verifying the composition-root wiring

## Non-goals

- **Implementing any product feature** — Feed and MediaList are scaffolded as structure only; no folder loading, playback, listing, selection, or file-operation behavior.
- **Networking** — excluded from v1 entirely (Core and features); explicitly deferred.
- **SPM package extraction** — features remain folder groups in the single app target; extraction is deferred until needed.
- **Third-party DI frameworks** — the composition root is hand-wired; no dependency-injection library is introduced.
- **Product-spec authoring** — filling `docs/spec.md` with real scope and requirements is the parked story E1-S1's business.
- **Concrete architecture artifacts** — file tree, protocol names, and type signatures are design-phase output (`design.md`), not this spec.

## References

- [docs/spec.md](../../spec.md) — product source of truth (RNF-02 / RNF-04 wording quoted above)
- [docs/decisions.md](../../decisions.md) — D1 (stack), D5 (pillars), D6 (English)
- [docs/backlog.md](../../backlog.md) — story entry (E1-S3) with the full stakeholder decision set
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
