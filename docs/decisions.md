# Decision Log (ADR)

Format: **D# — title** · date · status (`accepted` / `pending` / `postponed` / `superseded` / `temporary`). Each entry includes context, decision, alternatives, and consequences. This log is historical: decisions are never deleted; they are marked as superseded when they change.

---

## D1 — Stack: SwiftUI + Swift, Xcode 26, macOS · 2026-10-09 · accepted

- **Context:** existing Xcode 26 project (`InstantPlayer`, bundle `com.guits.InstantPlayer`, `SDKROOT = macosx`) with app, unit-test, and UI-test targets; product is an instant video player. The project is configured as a Mac app ("My Mac" is the only destination) — confirmed with the stakeholder at bootstrap.
- **Decision:** Swift + SwiftUI on **macOS**, standard `xcodebuild` toolchain with the `platform=macOS` destination, no simulator involved.
- **Alternatives:** retarget to iOS (discarded: the stakeholder wants a Mac app); UIKit-first (discarded: SwiftUI is the platform default for new apps and the UI surface here is small); UIKit via SwiftUI wrappers where playback needs it (possible later, per-story design decision).
- **Consequences:** macOS idioms apply — App Sandbox, security-scoped file access, Keychain, window-based SwiftUI; playback via `AVKit`/`AVPlayer` (`VideoPlayer` or `NSViewRepresentable` around `AVPlayerView`) when needed.

## D2 — SDD harness adoption (mirrors an earlier project) · 2026-10-09 · accepted

- **Context:** an earlier project runs a proven spec-driven flow: `sdd` coordinator + `spec-author`/`implementer`/`implementer-flash`/`validator` subagents, per-story artifacts in `docs/specs/<story>/`, stakeholder gates, ADR log, backlog states, and a deterministic pre-commit gate.
- **Decision:** adopt the same system for InstantPlayer, adapted to the Swift toolchain: pillars mapped to `swift-security`/`swift-performance` skills; deterministic gate rebuilt around `xcodebuild` + SwiftLint + SwiftFormat; stakeholder functional review happens in the running app (`scripts/app.sh`) instead of a preview URL.
- **Alternatives:** keep the default build agent only (discarded: loses gates, evidence discipline, and review); wait until the codebase grows (discarded: harness is cheapest to adopt at day zero).
- **Consequences:** all story work goes through the `sdd` coordinator; `AGENTS.md` is the constitution; the gate is law.

## D3 — No routing model; coordinator assigns batches · 2026-10-09 · accepted

- **Context:** an earlier project routes tasks to implementer tiers through a pnpm-managed routing plugin. InstantPlayer starts with no Node toolchain, and the routing machinery needs deps, pinning, and calibration.
- **Decision:** drop the routing plugins for now. The `sdd` coordinator assigns task batches itself: mechanical, well-scoped tasks → `implementer-flash`; everything else → `implementer`; when in doubt → `implementer`. Gaps follow the same rule.
- **Alternatives:** full routing-plugin copy (discarded for now: heavy machinery for a young codebase; revisit when task volume makes manual routing a bottleneck).
- **Consequences:** slightly more coordinator judgment per story; no `.opencode` Node deps; can be superseded later by re-introducing the routing plugin if routing quality or cost demands it.

## D4 — Gate scope: build + unit tests + lint on every commit · 2026-10-09 · accepted

- **Context:** the gate runs on every commit via the pre-commit hook. Full `xcodebuild test` including UI tests takes minutes; the gate must stay fast enough to never tempt a bypass.
- **Decision:** `scripts/validate.sh` runs, in order: docs checks (ADR format, internal links, approved-spec hygiene), branch policy (`--staged`), SwiftLint, SwiftFormat `--lint`, `xcodebuild build`, and `xcodebuild test -only-testing:InstantPlayerTests` (unit tests) with the `platform=macOS` destination and a pinned derived-data path (`.deriveddata/`). UI tests (`InstantPlayerUITests`) are out of the per-commit gate — the `validator`/converge step runs them when the story touches flows UI tests cover.
- **Alternatives:** include UI tests per commit (discarded: minutes per commit); lint/docs only (discarded: compile+unit regressions would land on main).
- **Consequences:** commits stay reasonably fast; slow UI tests are a validation-phase concern; the macOS destination is fixed, so there is no device/simulator variance to manage.

## D5 — Pillars: security (RNF-04) and performance (RNF-02) via macOS skills · 2026-10-09 · accepted

- **Context:** an earlier project enforces two pillars through `web-security`/`web-performance` skills loaded before any touching work. InstantPlayer's risk surface is different: local media, files from outside the sandbox, playback efficiency.
- **Decision:** keep two non-negotiable pillars with the same RNF numbering (RNF-02 performance, RNF-04 security) and adapt the skills: `swift-security` (data at rest, network/ATS, permissions & privacy manifest, untrusted input, secrets, dependencies) and `swift-performance` (main thread, SwiftUI view cost, playback lifecycle, memory, launch).
- **Alternatives:** no skills until the codebase grows (discarded: pillar checklists are cheapest applied from the first real feature).
- **Consequences:** every story brief touching pillar surfaces must name the skill; the validator applies both checklists.

## D6 — Language: English everywhere · 2026-10-09 · accepted

- **Context:** an earlier project mandates Spanish UI copy (Colombian market) with English for everything else. InstantPlayer has no defined localization market yet.
- **Decision:** everything in English — code, tests, docs, commit messages, and user-facing UI copy. Localization is a future story (String Catalogs) if a market is defined.
- **Alternatives:** Spanish UI like the earlier project (discarded: no market requirement yet; adds copy-review overhead).
- **Consequences:** one language to keep consistent; when localization comes, UI copy migrates into `Localizable.xcstrings` in a dedicated story.

## D7 — Clean Architecture layering & dependency rule · 2026-10-09 · accepted

- **Context:** the stakeholder directed architecture-first (E1-S3): every feature story must land into a pre-agreed structure so no refactor tax accumulates (spec US1/US3). InstantPlayer is a local-media Mac app whose risk surface — files from outside the sandbox, playback — must stay contained behind reviewable seams (RNF-04), and presentation must never touch framework objects directly (R11).
- **Decision:** every feature is a self-contained unit owning three internal layers — **Domain**, **Data**, **Presentation** — with dependencies running **Presentation → Domain ← Data**: Data implements protocols owned by Domain, and Presentation never imports Data (R1, R2). Domain code is Swift-pure — no SwiftUI, AppKit, or AVKit imports (R10). Framework capabilities (playback, filesystem) are reached only through protocol seams shaped so security-scoped resource handling (bookmarks, start/stop access, sandbox-safe resolution) can be added *behind* them without changing callers (R11, R12). Seam placement follows the house rule: a seam lives in `Core/Protocols` iff ≥2 features consume it; otherwise the owning feature's Domain declares it, and it is promoted to Core when a second consumer appears.
- **Alternatives:** parking every seam as a Core base protocol up front (rejected: Core-parking single-consumer seams couples features to unused surface and invites ceremony — the ≥2-consumer trigger plus mechanical promotion gives the same guarantee lazily; only filesystem access has two v1 consumers today); empty seam protocols, declarations only (rejected: a member nothing calls and nothing conforms to is dead code — the wiring probe + stubs make the dependency rule true in shipped code and give the wiring tests something to assert).
- **Consequences:** reviewers and the validator check dependency direction and Domain purity on every story; validation of untrusted external input (file metadata, filenames) lives at the Data edge, never smeared across layers; feature-to-feature coupling is impossible by construction (shared code goes through Core). As the first taker of the D7+ numbering: parked story E1-S1 must renumber its ADR batch — expected and stakeholder-acknowledged (backlog sequencing note).

## D8 — Presentation & concurrency model: MVVM `@Observable` + async/await · 2026-10-09 · accepted

- **Context:** the app is SwiftUI on macOS 26.0 (D1), far above the `@Observable` floor (macOS 14+). The concurrency model must be uniform from day one so feature stories copy a proven pattern instead of inventing one per feature (spec US1); presentation state must have exactly one kind of home (R3) and asynchronous work one spelling (R4).
- **Decision:** view models are `@MainActor` + `@Observable` `final class`es and are the **only** presentation-state holders; SwiftUI views are dumb binders that observe them (R3). All asynchronous work is expressed with async/await; completion-handler and delegate patterns are forbidden (R4). Mutable state shared across isolation domains becomes an actor in the story that introduces it — no actor is shipped before such state exists.
- **Alternatives:** `ObservableObject` + `@Published` (rejected: the legacy path for a brand-new codebase — `@Observable` tracks per-property reads for cheaper re-renders (RNF-02) and drops `objectWillChange` boilerplate); introducing an actor now, e.g. shared playback state (rejected: no shared mutable state exists in the skeleton — shipping one is ceremony; the trigger and convention are documented instead).
- **Consequences:** every view model follows one recognizable shape; observation cost is proportional to what views actually read; async seams (e.g. the wiring probes) make the house pattern visible from the first commit; when an actor eventually appears it lands with its own story's design work, guided by the convention recorded in `docs/architecture.md`.

## D9 — Module organization: single target, folder groups, Core, no networking · 2026-10-09 · accepted

- **Context:** v1 has exactly two features — **Feed** and **MediaList** (R6) — served by shared **Core** code and composed by **App**. The project uses file-system-synchronized groups, where files on disk join their target automatically; introducing package boundaries now would add target/manifest management at a size where review plus the validator enforce layering anyway.
- **Decision:** one app target; features are folder groups inside it (`App/`, `Core/`, `Features/<Feature>/{Domain,Data,Presentation}`) — extraction into separate local SPM packages is deferred until needed (R5). Core holds shared Protocols, Models, Extensions, Utilities (R7). Networking is excluded from v1 entirely — Core and features — as a local-files product (R8).
- **Alternatives:** SPM local packages per feature now (rejected: compile-time enforcement of the dependency rule is not worth manifest overhead in a synchronized-group project at this size; trigger to revisit — repeated layering violations slipping through review); real shared types in `Core/{Models,Extensions,Utilities}` immediately (rejected: any model or extension invented before its feature story fabricates product design — placement-rule placeholders carry the rules with zero code).
- **Consequences:** the dependency rule is enforced by review and the validator, not the compiler, until an extraction trigger fires; `Features/MediaList/` is a reserved location (the first MediaList story creates it — an empty folder would need invented types); Core placeholder files ride in the bundle as inert resources (bytes, not launch work — RNF-02 unaffected); adding a third feature or a package boundary are deliberate, ADR-recorded events.

## D10 — Hand-wired composition root in App · 2026-10-09 · accepted

- **Context:** Domain protocols need concrete implementations somewhere, and windows/scenes need wiring (R9); the story explicitly excludes third-party DI frameworks (spec non-goal). Without a single binding site, seams scatter and launch cost grows (RNF-02).
- **Decision:** `AppDependencies` in `App/` is the composition root — the **only** non-test type allowed to reference feature Data concretions and construct feature view models; the `@main` app entry wires the container to the window through an App-owned `RootView` (R9, R16). It is hand-wired and allocation-only: two bound seams plus a view-model factory called on demand, never at launch. It is also the only place Domain protocols bind to concrete implementations, with tests injecting conformances through the same initializer.
- **Alternatives:** a third-party DI framework such as Factory or swift-dependencies (rejected: R9 needs exactly one binding site; a framework adds a dependency (RNF-04 dependency hygiene) to remove three lines); hosting the Feed shell from `RootView` to "prove" it at runtime (rejected: hosting would construct a view model and run an async probe at launch (R13) — the shell is proven by unit tests; keeping the template `ContentView` as placeholder was also rejected: the placeholder root view is an App concern, not a feature's).
- **Consequences:** launch cost is one object allocation (R13); adding a feature is a fixed mechanical sequence — Domain protocol → Data conformance → view model → view → factory method on `AppDependencies` → host in `RootView` — documented in `docs/architecture.md`; the container must stay small (two properties + factories today) — growth beyond that is a design-amendment signal; wiring is unit-testable end-to-end without launching the app (R16).
