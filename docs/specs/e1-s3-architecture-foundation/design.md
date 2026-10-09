# E1-S3 · Architecture foundation — Design

HOW the skeleton is built. The WHAT is the approved [spec](spec.md) (R1–R16); every
design decision below cites the R-number(s) it serves. Stakeholder decision set and
sequencing context: [docs/backlog.md](../../backlog.md) (E1-S3 entry). Product pillar
wording: [docs/spec.md](../../spec.md) (RNF-02, RNF-04). Prior decisions:
[docs/decisions.md](../../decisions.md) D1 (SwiftUI/macOS stack), D5 (pillars),
D6 (English everywhere).

This story's deliverable is code (a compiling skeleton), so this is a software design:
concrete file inventory, type-level contracts, concurrency rules, and the wiring tests.
No product behavior is designed here — that is feature-story work (spec non-goals).

## 1 · Verified project facts (implementation baseline)

Facts read from the repository at design time; the implementer **re-verifies each**
before/while building (first task in `tasks.md`):

| Fact | Evidence | Implementer consequence |
|---|---|---|
| All three targets use **file-system-synchronized groups** (`PBXFileSystemSynchronizedRootGroup` over `InstantPlayer/`, `InstantPlayerTests/`, `InstantPlayerUITests/`; no membership exception sets) | `InstantPlayer.xcodeproj/project.pbxproj` | New files/folders on disk join their target automatically — **no pbxproj surgery** for additions, moves, or deletions. Verify after adding: the gate's `xcodebuild build`/`test` compiles the new files (a file that never compiles is not in the target). |
| `MACOSX_DEPLOYMENT_TARGET = 26.0` in every build configuration | `project.pbxproj` | `@Observable` needs macOS 14+ — the floor is far above it. **No deployment-target bump is task work.** If the value is ever below 14, stop and report. |
| `SWIFT_VERSION = 5.0` (Swift 5 language mode) | `project.pbxproj` | `@Observable`, `@MainActor`, actors, async/await all available via the Xcode 26 SDK. Flipping to Swift 6 language mode is a future hygiene decision, out of scope here. |
| Unit tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) | `InstantPlayerTests/InstantPlayerTests.swift` | New wiring tests use Swift Testing, not XCTest. |
| SwiftLint/SwiftFormat run repo-wide with baseline configs | `.swiftlint.yml`, gate (D4) | New Swift files are linted/formatted automatically; style tuning is E1-S2's story. |
| Non-source files under a synchronized folder are added to the app bundle as **resources** | synchronized-group behavior | The three Core README placeholders (§2) ride in the bundle — a few hundred bytes, never loaded at launch (R13 unaffected). Membership exceptions would require pbxproj surgery; not worth it (noted for E1-S2 if the team objects). |

## 2 · Skeleton inventory (every file the story ships)

Target folder `InstantPlayer/` (app target) — additions, moves, and deletions are all
reference-safe under synchronized groups (§1):

```
InstantPlayer/
├── Assets.xcassets                       (unchanged, template asset catalog)
├── App/
│   ├── InstantPlayerApp.swift            entry + window/scene wiring          → R9, R13
│   ├── AppDependencies.swift             composition root (binding container) → R9, R16
│   └── RootView.swift                    minimal placeholder root view         → R9
├── Core/
│   ├── Protocols/
│   │   └── MediaFolderRepository.swift   filesystem seam (base protocol)      → R7, R11, R12
│   ├── Models/README.md                  reserved — placement rules only      → R7
│   ├── Extensions/README.md              reserved — placement rules only      → R7
│   └── Utilities/README.md               reserved — placement rules only      → R7
└── Features/
    └── Feed/                             the ONE feature shell                → R1, R16
        ├── Domain/
        │   └── MediaPlayerService.swift  player seam (feature-owned protocol) → R2, R10, R11
        ├── Data/
        │   ├── StubMediaPlayerService.swift     player-seam stub conformance  → R2
        │   └── StubMediaFolderRepository.swift  folder-seam stub conformance  → R2, R7
        └── Presentation/
            ├── FeedViewModel.swift       @MainActor @Observable view model    → R3, R4
            └── FeedView.swift            SwiftUI view binding the view model  → R3
```

Test target `InstantPlayerTests/` (mirrors the app structure; §5):

```
InstantPlayerTests/
├── App/
│   └── AppDependenciesTests.swift        composition-root wiring tests        → R16
└── Features/
    └── Feed/
        └── FeedViewModelTests.swift      shell wiring + construction tests    → R16
```

**Deletions** (template scaffolding, replaced by the skeleton):

- `InstantPlayer/ContentView.swift` — template placeholder; the placeholder root view
  now lives in `App/` (`RootView.swift`), because what the window shows is a
  composition-root concern (R9), never a feature's.
- `InstantPlayerTests/InstantPlayerTests.swift` — template empty example test;
  superseded by the real wiring tests.

**Untouched:** `InstantPlayerUITests/` (template launch tests remain; UI tests are out
of the per-commit gate per D4 and this story adds no UI behavior), `Assets.xcassets`,
Xcode project settings, scripts, configs.

### 2.1 Per-item justification

| Item | Why it ships now | Why not more |
|---|---|---|
| `App/InstantPlayerApp.swift` (moved from target root) | `@main` + the `WindowGroup` scene is the window wiring R9 demands; moving it into `App/` makes the composition root one place. | No window styling/toolbar code — window chrome decisions are feature-story work. |
| `App/AppDependencies.swift` | The composition root is a named deliverable (R16) and the binding site for every Domain protocol (R9). | Two seams to bind today; the container stays three properties/methods big (§3). |
| `App/RootView.swift` | R9: the scene must land on an App-owned view, and the spec pins the placeholder in App, not in a feature. Static text only, receives the container so later feature stories swap content without touching the app entry. | Hosts **no** feature view — hosting would run wiring work at launch (R13); the Feed shell is proven by unit tests, not by the running app (§6). |
| `Core/Protocols/MediaFolderRepository.swift` | Filesystem access is the one capability both v1 features need (Feed: folder loading; MediaList: file operations) → R7 puts the base protocol in Core; R11/R12 make it the only sanctioned filesystem path. | Exactly one member today (wiring probe, §3) — real operations are feature-story design output; inventing them now would be inventing product behavior. |
| `Core/{Models,Extensions,Utilities}/README.md` | The stakeholder structure (R6/R7, backlog) names these four Core groups; R16 ships "the folder structure", and git cannot hold empty folders. Each README states the group's purpose and the placement rule (when code goes here vs. a feature). | **No invented types.** A `MediaItem` model or a `String` extension would fabricate product/feature design that belongs to later stories. READMEs are the sanctioned zero-code placeholder. |
| `Features/Feed/Domain/MediaPlayerService.swift` | Playback is the archetypal wrapped-service seam (R11); Feed is its only v1 consumer, so the owning feature's Domain declares it (R2 — Data will implement protocols owned by Domain). | Protocol only, one member; the AVKit-backed conformance arrives with the Feed playback story (D1 names AVKit/AVPlayer for that future). |
| `Features/Feed/Data/Stub*.swift` (2 files) | R2 must be *true in shipped code*, not just documented: Data implements the Domain-owned protocols (player seam) and the Core-owned base protocol (folder seam — Feed is the consumer that will hold the real security-scoped conformance). | Stubs return constants; no AVKit, no FileManager, no URL — zero framework access in the skeleton (R12/R13, §6–§7). |
| `Features/Feed/Presentation/{FeedViewModel,FeedView}.swift` | Proves the Presentation layer of the pattern end-to-end: view → view model → Domain protocol ← Data stub (R1, R3, R16's "unit tests verifying the composition-root wiring" needs these types to exist). | No product UI, no folder loading, no playback (non-goals); no `#Preview` — nothing worth previewing yet. |
| Test files (2) | R16's deliverable: wiring tests (§5). | Mirror only what has behavior: no Core test folder — Core has no executable behavior yet (its seam is asserted through the composition root). |

### 2.2 Reconciliations (explicit, spec-cited)

1. **`Features/MediaList/` does not ship** — R6 vs R16. R6 fixes v1's *product* feature
   set ("exactly two features") at product-completion time; R16 fixes the *skeleton*
   deliverable to "one empty feature shell". An empty MediaList folder would need
   either invented types (product behavior — a non-goal) or README placeholders
   duplicating `docs/architecture.md`. Decision: MediaList is a **reserved location**
   documented in the standing reference (§9); the first MediaList story creates it.
   R6 is satisfied by the time v1 completes, not by this skeleton.
2. **"Core base protocols" (R16, plural) ships one protocol** — R7 is a trigger rule:
   code goes to Core when *needed by more than one feature*. That trigger fires today
   only for filesystem access. The player seam is Feed-only in v1 → feature-Domain.
   **Seam placement rule (house rule):** a seam lives in `Core/Protocols` iff ≥2
   features consume it; otherwise the owning feature's Domain declares it, and it is
   promoted to Core (a mechanical move) when a second consumer appears. Shipping a
   second Core protocol now would be ceremony with no second consumer.
3. **"One empty feature shell" (R16) ships four real types** — "empty" means *empty of
   product behavior* (spec non-goals: "scaffolded as structure only"); the wiring-only
   types exist because the same R16 demands unit tests that verify composition-root
   wiring, which requires exactly these types.

## 3 · Type-level contracts

Signatures are the contract for `tasks.md`; doc comments and formatting are
implementer latitude, name/signature changes are design amendments. All identifiers
and UI copy in English (D6).

### 3.1 Composition root — `App/AppDependencies.swift` (R9)

```swift
/// The composition root: the ONLY place Domain protocols bind to concrete
/// implementations (R9). Hand-wired — no DI framework (story non-goal).
/// Construction cost at launch: one object allocation + two stateless
/// structs (R13 — see §6).
@MainActor
final class AppDependencies {
    /// Bound seams. Feature code sees only the protocol types.
    let mediaPlayerService: any MediaPlayerService
    let mediaFolderRepository: any MediaFolderRepository

    /// Binding API: production uses the defaults (stubs today); tests and
    /// previews inject conformances through the same initializer.
    init(
        mediaPlayerService: any MediaPlayerService = StubMediaPlayerService(),
        mediaFolderRepository: any MediaFolderRepository = StubMediaFolderRepository()
    )

    /// Feature factory (R9): view models are constructed only here.
    /// Called when a feature view appears — never at launch (R13).
    func makeFeedViewModel() -> FeedViewModel
}
```

Rules encoded here (enforced by review, referenced from `docs/architecture.md`):
`AppDependencies` is the only non-test type allowed to (a) reference feature **Data**
concretions, (b) construct feature view models. Everything else depends on protocols.

### 3.2 App entry + window wiring — `App/InstantPlayerApp.swift` (R9, R13)

```swift
@main
struct InstantPlayerApp: App {
    /// Container created once per app instance; zero work beyond §6 allocations.
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
        }
    }
}
```

If the compiler flags MainActor isolation of the default initializer under the Swift 5
language mode, the fallback is an explicit `@MainActor` annotation on the struct — a
compile detail, not a design change. Window styling/behavior is feature-story work.

### 3.3 Placeholder root view — `App/RootView.swift` (R9, R13)

```swift
/// App-owned placeholder: the future host point for feature views.
/// Receives the container so feature stories swap content here without
/// touching the app entry. Displays static text only — no async, no
/// feature views, no launch work (R13).
struct RootView: View {
    let dependencies: AppDependencies

    var body: some View  // VStack: "InstantPlayer" + footnote "Architecture
                         // skeleton — features land in E2 stories"
}
```

The stored `dependencies` is intentionally unused by the placeholder body: it is the
wiring guarantee (scene → container → root) that later stories plug into.

### 3.4 Filesystem seam (Core base protocol) — `Core/Protocols/MediaFolderRepository.swift` (R7, R11, R12)

```swift
/// The ONLY sanctioned path to the filesystem for both v1 features (R11).
/// Shaped so security-scoped resource handling (RNF-04: bookmarks,
/// start/stop access, sandbox-safe resolution) can be added BEHIND this
/// seam without changing its callers (R12). Real operations arrive with
/// the feature stories that need them.
protocol MediaFolderRepository: Sendable {
    /// Wiring probe: constant from the bound conformance; proves the
    /// binding in tests (R16). Replaced by real operations later.
    func wiringProbe() async -> String
}
```

### 3.5 Player seam (feature Domain protocol) — `Features/Feed/Domain/MediaPlayerService.swift` (R2, R10, R11)

```swift
/// Player service seam (R11): Presentation and Domain reach playback only
/// through this abstraction — never AVKit/AVPlayer directly. Owned by
/// Feed's Domain because playback has one v1 consumer (seam placement
/// rule, §2.2). Domain stays Swift-pure (R10): no imports beyond Foundation.
protocol MediaPlayerService: Sendable {
    /// Wiring probe — same contract as MediaFolderRepository.wiringProbe().
    func wiringProbe() async -> String
}
```

### 3.6 Stub conformances — `Features/Feed/Data/` (R2)

```swift
/// Skeleton conformance for the player seam. The AVKit-backed wrapper
/// (D1) arrives with the Feed playback story; this stub keeps the
/// skeleton framework-free.
struct StubMediaPlayerService: MediaPlayerService {
    func wiringProbe() async -> String { "StubMediaPlayerService" }
}

/// Skeleton conformance for the Core filesystem seam. The real
/// security-scoped conformance (R12) arrives with the Feed folder-loading
/// story — Feed is the consumer that will own it.
struct StubMediaFolderRepository: MediaFolderRepository {
    func wiringProbe() async -> String { "StubMediaFolderRepository" }
}
```

Both are stateless `Sendable` structs; both return constants — zero I/O (§7).

### 3.7 View model — `Features/Feed/Presentation/FeedViewModel.swift` (R3, R4)

The house pattern, `@MainActor` + `@Observable` + `final class`; view models are the
only presentation-state holders (R3):

```swift
@MainActor
@Observable
final class FeedViewModel {
    private let mediaPlayerService: any MediaPlayerService
    private(set) var probeResult: String?

    init(mediaPlayerService: any MediaPlayerService) {
        self.mediaPlayerService = mediaPlayerService
    }

    /// Calls the Domain seam; Data answers through the bound conformance.
    func runWiringProbe() async {
        probeResult = await mediaPlayerService.wiringProbe()
    }
}
```

### 3.8 View — `Features/Feed/Presentation/FeedView.swift` (R3)

```swift
struct FeedView: View {
    let viewModel: FeedViewModel

    var body: some View {
        // Text(viewModel.probeResult ?? "Feed shell — wiring only, no product
        // behavior yet"), padded, with:
        .task { await viewModel.runWiringProbe() }   // lifecycle pattern for feature stories
    }
}
```

Views are dumb binders: no state of their own, no Data imports (R2), no direct
framework access (R11). `FeedView` is not hosted by `RootView` in the skeleton (R13);
it exists as the template future feature views copy and is construction-tested (§5).

## 4 · Concurrency and platform rules (R4, R3)

- **Floor:** macOS 26.0 verified (§1) — `@Observable` (macOS 14+) available; no bump.
- **View models:** always `@MainActor` + `@Observable` + `final class` (§3.7). Views
  and the app entry rely on SwiftUI's MainActor isolation.
- **Async work:** async/await only (R4). Completion-handler and delegate patterns are
  forbidden; the two `wiringProbe()` members are async by design so the house pattern
  is visible from day one.
- **Actors:** convention — mutable state shared across isolation domains becomes an
  actor in the story that introduces it. The skeleton ships **no** actor: no shared
  mutable state exists yet, and shipping one would be ceremony. Recorded as a rule in
  `docs/architecture.md` (§9) and in D8 (§8).
- **Sendable:** seam protocols are `Sendable`; stateless conformances are `Sendable`
  structs. View models are MainActor-isolated instead.
- **Container:** `@State` on the `App` struct (App/Scene support `@State` storage) —
  created once, never observed.

## 5 · Wiring tests (R16) — `InstantPlayerTests/`

Swift Testing (`import Testing`), `@MainActor` suites (the types under test are
MainActor-isolated), `#expect` assertions, `@testable import InstantPlayer`. Deleted
template test file is replaced by:

### 5.1 `App/AppDependenciesTests.swift`

1. **Dependency graph constructs** — `AppDependencies()` with default bindings
   initializes (R9, R16).
2. **Player-seam binding resolves** — `deps.mediaPlayerService is
   StubMediaPlayerService` (R2, R9, R16).
3. **Filesystem-seam binding resolves** — `deps.mediaFolderRepository is
   StubMediaFolderRepository` (R7, R9, R16).
4. **Binding API accepts injection** — a test-local conformance
   (`private struct ProbeMediaPlayerService: MediaPlayerService`) passed to the
   initializer is what `makeFeedViewModel()` uses; its probe value flows through
   (this is also the seam-swapping pattern security/performance tests will use, §7).
5. **Behavioral end-to-end** — `await deps.mediaFolderRepository.wiringProbe()` and
   `await deps.mediaPlayerService.wiringProbe()` return the stub constants.

### 5.2 `Features/Feed/FeedViewModelTests.swift`

1. **Shell view model initializes via the composition root** —
   `deps.makeFeedViewModel()` → `await viewModel.runWiringProbe()` →
   `probeResult == "StubMediaPlayerService"`: proves Presentation → Domain ← Data
   end-to-end through the binding (R1, R2, R3, R16).
2. **View constructs with a view model** — `_ = FeedView(viewModel:)` proves the
   Presentation layer instantiates with its dependencies (no rendering in unit tests).

No UI-test changes: `InstantPlayerUITests/` stays as the template launch tests (D4
keeps UI tests out of the per-commit gate; this story adds no UI behavior).

## 6 · Performance — RNF-02 (mandatory pillar)

Requirement R13: the skeleton adds **no launch cost relative to an empty app**. How
the design guarantees it:

- **Composition root is allocation-only:** `AppDependencies()` does one object
  allocation plus two stateless struct values — no registration tables, no
  dictionaries, no singletons, no global mutable state, no I/O, no timers, nothing
  registered at `init` (§3.1).
- **No eager view models:** `makeFeedViewModel()` is a factory called on demand; in
  the skeleton it is never called at runtime — only tests call it (§3.7, §5).
- **No async at launch:** nothing schedules work at launch. `RootView` is static
  text; `FeedView`'s `.task` never runs because no feature view is hosted (§3.3).
- **Observation cost is proportional:** `@Observable` tracks per-property reads —
  no `objectWillChange` broadcast to uninterested views (also an input to the
  `@Observable` vs `ObservableObject` choice, §10).
- **Bundle weight:** the three Core READMEs ride as bundle resources — bytes, not
  launch work (§1).
- **Test guidance:** wiring tests construct the graph directly and assert; nothing
  needs perf measurement at skeleton stage. Later stories that add launch work
  (scanning folders, opening media) must set per-story launch budgets per
  [docs/spec.md](../../spec.md) RNF-02 — the skeleton adds none.
- **Skill gate:** the implementer loads `swift-performance`
  (`.opencode/skills/swift-performance`) before writing the skeleton files — they
  define the launch path every later story inherits; the validator applies the same
  checklist.

## 7 · Security — RNF-04 (mandatory pillar)

Requirements R8 (no networking) and R12 (seams anticipate security-scoped access):

- **Zero file and network access in shipped code:** no `FileManager`, no `URL`, no
  AVKit, no networking API anywhere in the skeleton. Both stubs return string
  constants (§3.6). Nothing to sandbox, nothing to leak.
- **Security-scoped handling has a home:** `MediaFolderRepository` is the only
  sanctioned filesystem path (R11); its future members (folder loading, file
  operations) will be designed around security-scoped bookmarks and start/stop
  access *behind* the seam, so callers — view models and Domain code — never change
  when that lands (R12). The seam placement and its rules are recorded in D7/D9 (§8)
  and `docs/architecture.md` (§9).
- **Domain purity (R10) anchors validation at the edge:** with Domain Swift-pure and
  Presentation framework-free, validation of untrusted external input (file
  metadata, filenames) will live at the Data edge in feature stories — never
  smeared across layers.
- **No secrets, no credentials, no user data** in the skeleton; nothing belongs in
  the Keychain yet; no tracking of any kind.
- **Test seam-swapping:** the injected-binding test (§5.1 item 4) establishes the
  pattern future security tests use — fake repositories conform to the seam, so
  sandbox behavior is tested without touching real files.
- **Skill gate:** the implementer loads `swift-security`
  (`.opencode/skills/swift-security`) before the skeleton (it defines the seams
  security work will live behind); any story that gives the seams real filesystem
  behavior must load it first — non-negotiable per D5 and `AGENTS.md`.

## 8 · ADR plan (R14 — written during implementation, not now)

Continuing the log's numbering (currently through D6). Note: per
[docs/backlog.md](../../backlog.md), taking D7+ forces parked E1-S1 to renumber its
ADR batch — expected and acknowledged by the stakeholder. Each entry follows the
house format (`## D# — title · date · status`), with context, decision, alternatives
(pull from §10), and consequences; all four are `accepted` at story convergence:

| ADR | Title | One-line decision | Spec |
|---|---|---|---|
| **D7** | Clean Architecture layering & dependency rule | Every feature owns Domain/Data/Presentation layers; dependencies run Presentation → Domain ← Data; Domain is Swift-pure; framework capabilities are reached only through protocol seams shaped for security-scoped access. | R1, R2, R10, R11, R12 |
| **D8** | Presentation & concurrency model: MVVM `@Observable` + async/await | View models (`@MainActor` + `@Observable`) are the only presentation-state holders; async/await everywhere, actors for future mutable shared state, completion handlers forbidden. | R3, R4 |
| **D9** | Module organization: single target, folder groups, Core, no networking | One app target with `App/` + `Core/` + `Features/` folder groups (SPM extraction deferred); Core = shared Protocols/Models/Extensions/Utilities; exactly two v1 features; networking excluded from v1. | R5, R6, R7, R8 |
| **D10** | Hand-wired composition root in App | `AppDependencies` is the single binding site for Domain protocols and window wiring; no DI framework. | R9, R16 |

## 9 · `docs/architecture.md` plan (R15 — written during implementation, not now)

Standing reference maintained as the codebase evolves. Section layout:

1. **Purpose & maintenance rule** — who reads it, when it is updated (every story
   that changes structure), links to D7–D10.
2. **Decision index** — one line per architecture ADR.
3. **Source tree & reserved locations** — the shipped tree (§2) plus reserved
   locations: `Features/MediaList/` (first MediaList story creates it, §2.2),
   `Core/{Models,Extensions,Utilities}` placement rules.
4. **The dependency rule** — Presentation → Domain ← Data; Domain purity; seam
   placement rule (Core iff ≥2 consumers, promotion is a mechanical move); how
   reviewers check it.
5. **Conventions** — view-model pattern (`@MainActor` + `@Observable`), async/await
   only, actor introduction trigger, naming, no completion handlers, English (D6).
6. **Composition root: adding a feature** — walkthrough: Domain protocol → Data
   conformance → view model → view → factory on `AppDependencies` → host in
   `RootView`.
7. **Pillar hooks** — launch-cost discipline (RNF-02) and security-scoped seam
   guidance (RNF-04), each naming the skill to load and when.
8. **Evolution notes** — SPM extraction trigger (R5/D9), MediaList arrival,
   seam promotion examples, actor introduction, E1-S1 ADR renumbering note.

## 10 · Alternatives considered

| Alternative | Verdict | Why |
|---|---|---|
| **SPM local packages per feature now** vs folder groups | Rejected (D9) | R5/stakeholder decision: single app target, extraction deferred. Package boundaries would give compile-time enforcement of the dependency rule, but cost target/manifest management in a synchronized-group project at a size where review + the validator enforce it anyway. Trigger to revisit: repeated layering violations slipping through review. |
| **Third-party DI (Factory, swift-dependencies)** vs hand-wired | Rejected (D10) | Story non-goal (spec) and R9 needs exactly one binding site; the container is two properties and one factory — a framework would add a dependency (RNF-04 dependency hygiene) to remove three lines. |
| **All seams as Core base protocols up front** vs feature-owned with promotion trigger | Rejected for the player seam | R7's trigger (≥2 consumers) fires only for filesystem access today; Core-parking every seam couples features to unused surface and invites ceremony. Placement rule + mechanical promotion (§2.2) gets the same guarantee lazily. |
| **`ObservableObject` + `@Published`** vs `@Observable` | Rejected (D8) | macOS floor is 26.0 — the modern macro is fully available; it tracks per-property observation (cheaper re-renders, RNF-02) and drops `objectWillChange` boilerplate. `ObservableObject` is the legacy path for a brand-new codebase. |
| **`RootView` hosting `FeedView`** vs pure placeholder | Rejected | R13: hosting would construct a view model and run an async probe at launch. The shell is proven by unit tests; runtime hosting is the Feed feature story's job. (Also considered: keeping template `ContentView` — rejected: the placeholder is an App concern, R9.) |
| **Empty seam protocols (declarations only)** vs probe member + stubs | Rejected | A member nothing calls and nothing conforms to is dead code; the probe + stubs make R2 true in shipped code and give R16's wiring tests something to assert, at ~10 lines total. |
| **An actor now** (e.g. a shared playback state) vs documented convention | Rejected | R4 asks for actors *when* shared mutable state appears; none exists. Convention + trigger documented (§4, D8, and the Conventions section planned in §9). |
| **Real types in `Core/{Models,Extensions,Utilities}`** vs README placeholders | Rejected | Any model/extension invented now fabricates feature-story design (product behavior is a non-goal); READMEs carry the placement rules with zero code (§2.1). |

## 11 · Requirement traceability

| Spec | Satisfied by |
|---|---|
| R1 (feature = Domain/Data/Presentation) | `Features/Feed` three-layer shell (§2) · D7 |
| R2 (Presentation → Domain ← Data) | Contracts §3.4–3.8; `FeedView`→`FeedViewModel`→`MediaPlayerService`←`StubMediaPlayerService`; tests §5 · D7 |
| R3 (view models only state holders) | `FeedViewModel` pattern (§3.7); `FeedView` stateless (§3.8) · D8 |
| R4 (async/await, actors, no completion handlers) | Concurrency rules §4; both seams async; no actor shipped, convention documented · D8 |
| R5 (single target, folder groups) | Inventory §2 — no package manifests; SPM deferred · D9 |
| R6 (two features, Core, App) | Structure §2 + MediaList reconciliation §2.2 · D9 |
| R7 (shared code in Core) | `Core/Protocols/MediaFolderRepository` + README placement rules; seam placement rule §2.2 · D9 |
| R8 (no networking) | Zero network APIs (§7); non-goal restated in D9 |
| R9 (composition root in App) | `AppDependencies` binding rules (§3.1); app entry scene wiring (§3.2) · D10 |
| R10 (Domain Swift-pure) | `MediaPlayerService` imports nothing beyond Foundation (§3.5); enforced by review, documented in D7/architecture.md |
| R11 (playback/filesystem via protocols) | `MediaPlayerService` + `MediaFolderRepository` seams (§3.4, §3.5) · D7 |
| R12 (seams anticipate security-scoped access) | Seam shape + behind-the-seam rule (§3.4, §7) · D7 |
| R13 (zero launch cost) | Performance section §6 |
| R14 (ADRs continuing from D6) | ADR plan §8 (D7–D10) |
| R15 (`docs/architecture.md`) | Standing-reference plan §9 |
| R16 (compiling skeleton + gate + wiring tests) | Inventory §2, contracts §3, tests §5 |
