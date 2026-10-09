# InstantPlayer — Architecture Reference

Standing reference for the codebase's structure and rules (R15). Decisions live in
[docs/decisions.md](decisions.md) (D7–D10); product pillars live in
[docs/spec.md](spec.md) (RNF-02, RNF-04).

## 1 · Purpose & maintenance rule

- **Who reads it:** any contributor, reviewer, or validator touching structure — before
  adding a feature, moving a file, or introducing a new seam. Later stories cite this
  document (and the ADRs) instead of re-litigating structure (spec US2).
- **When it is updated:** **every story that changes structure must update this file in
  the same story.** New feature folder → section 3. New seam or promotion → sections 3–4.
  New convention or trigger → sections 5 or 8. An outdated reference is a defect.
- **Decision anchors:** the rules here trace to four architecture ADRs —
  [D7](decisions.md) (layering & dependency rule), [D8](decisions.md) (presentation &
  concurrency model), [D9](decisions.md) (module organization), [D10](decisions.md)
  (composition root). The E1-S3 requirement set (R1–R16) and its artifact-by-artifact
  traceability live in the story spec
  ([specs/e1-s3-architecture-foundation/spec.md](specs/e1-s3-architecture-foundation/spec.md)).

## 2 · Decision index

- **D7 — Clean Architecture layering & dependency rule.** Every feature owns
  Domain/Data/Presentation; dependencies run Presentation → Domain ← Data; Domain is
  Swift-pure; framework capabilities are reached only through protocol seams shaped for
  security-scoped access (R1, R2, R10, R11, R12).
- **D8 — Presentation & concurrency model: MVVM `@Observable` + async/await.** View
  models (`@MainActor` + `@Observable`) are the only presentation-state holders;
  async/await everywhere, actors for future mutable shared state, completion handlers
  forbidden (R3, R4).
- **D9 — Module organization: single target, folder groups, Core, no networking.** One
  app target with `App/` + `Core/` + `Features/` folder groups (SPM extraction
  deferred); Core = shared Protocols/Models/Extensions/Utilities; exactly two v1
  features; networking excluded from v1 (R5–R8).
- **D10 — Hand-wired composition root in App.** `AppDependencies` is the single binding
  site for Domain protocols and window wiring; no DI framework (R9, R16).

## 3 · Source tree & reserved locations

Shipped tree (app target `InstantPlayer/`, test target mirrors it):

```
InstantPlayer/
├── Assets.xcassets                                  template asset catalog (unchanged)
├── App/                                             composition root (D10)
│   ├── InstantPlayerApp.swift                       @main entry + window/scene wiring
│   ├── AppDependencies.swift                        the binding container
│   └── RootView.swift                               App-owned placeholder root view
├── Core/                                            shared code (D9; R7 trigger below)
│   ├── Protocols/
│   │   └── MediaFolderRepository.swift              the filesystem seam (R11, R12)
│   ├── Models/Models.md                             reserved — placement rules only
│   ├── Extensions/Extensions.md                     reserved — placement rules only
│   └── Utilities/Utilities.md                       reserved — placement rules only
└── Features/
    └── Feed/                                        the one shipped feature shell (D7)
        ├── Domain/
        │   └── MediaPlayerService.swift             player seam (feature-owned protocol)
        ├── Data/
        │   ├── StubMediaPlayerService.swift         player-seam stub conformance
        │   └── StubMediaFolderRepository.swift      folder-seam stub conformance
        └── Presentation/
            ├── FeedViewModel.swift                  @MainActor @Observable view model
            └── FeedView.swift                       dumb binder view
```

- **Reserved:** `Features/MediaList/` does not exist yet — the first MediaList story
  creates it with the same three layers (D7). The location is reserved; nothing else
  may claim the name.
- **Core placement rules (R7):** code goes to `Core/` only when **more than one
  feature** needs it — `Core/Protocols` for shared seam protocols, `Core/Models` for
  cross-feature value types, `Core/Extensions` for cross-cutting type extensions,
  `Core/Utilities` for shared helpers. Anything with a single consumer lives in its
  feature; a promotion to Core is a mechanical move (section 8). The placeholder
  `.md` files in `Core/{Models,Extensions,Utilities}` carry these rules on disk and
  contain zero code — real types arrive with the first story that satisfies the trigger.

## 4 · The dependency rule

- **Direction (D7, R2):** `Presentation → Domain ← Data`. Presentation calls Domain;
  Data conforms to Domain-owned protocols; **Presentation never imports Data.**
- **Domain purity (R10):** Domain files import nothing beyond Foundation — no SwiftUI,
  AppKit, AVKit. UI and media frameworks appear only behind seam protocols (R11).
- **Seam placement rule:** a seam protocol lives in `Core/Protocols` **iff ≥2 features
  consume it**; otherwise the owning feature's Domain declares it. Promotion to Core
  when a second consumer appears is a mechanical move — file relocation plus import
  fix-ups, no signature change.
- **How reviewers check it:** (1) no `import` of a Data type appears under any
  `Presentation/` file; (2) Domain files compile with Foundation-only imports; (3)
  every framework type (AVKit, FileManager, URL) appears only inside a Data
  conformance behind a seam; (4) every new Core file cites its ≥2 consumers in the
  story's design; (5) the story's wiring tests still pass the composition-root
  end-to-end probe.

## 5 · Conventions

- **View models (D8, R3):** always `@MainActor @Observable final class`; views are dumb
  binders — no state of their own; view models are the only presentation-state holders.
- **Async (D8, R4):** async/await only. **No completion handlers, ever.** View
  lifecycle work uses `.task { … }`.
- **Actors:** no actor is shipped before shared mutable state exists. **Trigger:** the
  story that introduces mutable state shared across isolation domains designs and ships
  the actor for it (D8).
- **Naming:** features are PascalCase folders (`Feed`, `MediaList`); layers are fixed
  folder names (`Domain`, `Data`, `Presentation`); seams are protocol nouns
  (`MediaPlayerService`, `MediaFolderRepository`); Data conformances are
  `Stub*`/real-implementation names of the protocol.
- **Language (D6):** everything in English — code, comments, tests, docs, commit
  messages, UI copy.
- **Synchronized-group placeholder files (coordinator-ratified pitfall, E1-S3 task 1):**
  under file-system-synchronized groups, non-source files ride as **bundle resources
  copied flattened** into `Contents/Resources/` — placeholder files must **not share a
  filename across folders** (three `README.md` placeholders collided: "Multiple
  commands produce …/Resources/README.md", first gate run failed). Placeholder files
  are therefore named after their folder — `Models.md`, `Extensions.md`,
  `Utilities.md`. Any future placeholder follows the same per-folder-name rule.
- **Project file:** never hand-edit `project.pbxproj` — synchronized groups make disk
  moves the only sanctioned change; target membership is proven by the gate compiling
  the files.

## 6 · Composition root: adding a feature

The fixed walkthrough for every new feature (D10; R9, R13):

1. **Domain protocol** — declare the feature's seam(s) in
   `Features/<Feature>/Domain/`, `Sendable`, async members (check the ≥2-consumer rule
   first — section 4).
2. **Data conformance** — implement the protocol in `Features/<Feature>/Data/`;
   framework types (AVKit, FileManager, security-scoped handling) live only here.
3. **View model** — `@MainActor @Observable final class` in
   `Features/<Feature>/Presentation/`, taking the seam via initializer.
4. **View** — a dumb binder in `Presentation/`, observing the view model.
5. **Factory on `AppDependencies`** — add `make<Feature>ViewModel()` (binding rules:
   the container is the only non-test type referencing Data concretions or constructing
   view models; the factory is called on demand — **never at launch**).
6. **Host in `RootView`** — present the feature view from the App-owned root.

Wiring tests mirror this sequence in `InstantPlayerTests/` (Swift Testing,
`@MainActor` suites, injected conformances through the same initializer).

## 7 · Pillar hooks

Both pillars are non-negotiable (D5); each story touching them loads its skill
**before editing**:

- **Launch-cost discipline (RNF-02):** the composition root is allocation-only and
  feature factories are on-demand — keep it that way. Any story that adds launch work
  (folder scanning, playback warm-up) sets a per-story launch budget per
  [docs/spec.md](spec.md) RNF-02 and loads `swift-performance`
  (`.opencode/skills/swift-performance`) first. Also required before touching playback,
  lists, images, threading, launch, or SwiftUI views.
- **Security-scoped seam guidance (RNF-04):** `MediaFolderRepository` is the only
  sanctioned filesystem path (R11); sandbox/security-scoped handling — bookmarks,
  start/stop access, sandbox-safe resolution — is added **behind** it without changing
  callers (R12). Any story giving a seam real filesystem or network-adjacent behavior
  loads `swift-security` (`.opencode/skills/swift-security`) first; also required for
  persisted data, permissions, secrets, or file handling. Untrusted input (filenames,
  metadata) is validated at the Data edge.

## 8 · Evolution notes

- **SPM extraction trigger (D9, R5):** features stay folder groups in the single app
  target. Revisit when layering violations repeatedly slip through review — extraction
  into local packages is the sanctioned response, decided by ADR.
- **MediaList arrival:** the first MediaList story creates `Features/MediaList/` with
  Domain/Data/Presentation and follows the section-6 walkthrough; it updates section 3.
- **Seam promotion:** when a second consumer appears for a feature-owned seam (e.g.
  `MediaPlayerService` if MediaList ever previews media), the seam moves to
  `Core/Protocols` — a mechanical move, then recorded here.
- **Actor introduction:** deferred until shared mutable state exists (D8); the
  introducing story designs it and documents the isolation boundary here.
- **E1-S1 ADR renumbering:** parked story E1-S1 renumbers its planned ADR batch because
  this story took D7–D10 — expected and stakeholder-acknowledged (backlog sequencing
  note); no action in this document beyond this record.
