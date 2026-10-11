# E2-S1 · Entry & media collection — Tasks

Executable plan for the approved [design](design.md) against the approved [spec](spec.md)
(S1–S15 over product R1–R6, R34–R36). Branch: `feat/e2-s1-entry-media-collection` — already
checked out; never switch branches mid-story. One task = one commit. Checkboxes are ticked during
implementation, each task's boxes in its own commit (bookkeeping — not a second deliverable).

## Standing rules (every task)

1. **Pillars first (D5):** every code task (1–4) loads BOTH skills — `swift-security` and
   `swift-performance` (`.opencode/skills/`) — **before editing**. This story is file access plus
   entry-time scanning: both pillar checklists apply (design §7, §8), and each task repeats the
   load step so it cannot be skipped.
2. **Language (D6):** everything in English — code, comments, tests, docs, commit messages, UI
   copy (the welcome copy included).
3. **Style (D17):** the committed `.swiftlint.yml` and `.swiftformat` are the style source (picked
   up automatically, no flags); the SwiftLint and SwiftFormat gate steps must pass. Never edit the
   configs to make code pass — re-baselining style is a story of its own.
4. **Synchronized groups (design §1.2):** files land on disk under `InstantPlayer/`,
   `InstantPlayerTests/`, `InstantPlayerUITests/` and join their targets automatically.
   **Never hand-edit `project.pbxproj`.** The only build-setting wiring this story needs
   (`INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`, file-membership exceptions for the two `Config/`
   files) goes through Xcode build settings/UI per design §1.2 — if it cannot be applied without
   hand-editing `project.pbxproj`, stop and report: that is a coordinator escalation.
5. **Gate:** code tasks 1–4 run the **full** `./scripts/validate.sh` — build + unit tests, never
   `--staged`. Docs tasks 5–6 stage first, then run `./scripts/validate.sh --staged`. Task 7 runs
   the full gate with `--json` **and** the `--uitests` run (UI-test mandate, R14 of E1-S2).
   Fix every failure before moving on; the pre-commit hook re-runs the gate on every commit. Never
   weaken the gate; `--no-verify` is forbidden.
6. **Contracts are frozen:** the design §2 seam contract and §5.4 value shapes are contract —
   name/signature/shape changes are design amendments: stop and report to the coordinator, never
   deviate silently. Same for any design §1 fact that no longer holds (re-verified in task 1).
7. **No invented behavior:** spec non-goals hold — no feed rendering or paging (E2-S2), no
   playback (E2-S3), no ordering modes (E4-S1), no folder watching (E4-S2), no in-app picker, no
   network (D9), no bookmark store (S9). The interim folder-open placeholder is deliberately not a
   feed.

## Sequencing & parallelism

- **Code tasks are strictly sequential: 1 → 2 → 3 → 4** (compile dependencies per design §1): the
  seam contract and value types (1) are consumed by the Feed Data conformations (2), which the
  presentation and App wiring (3) bind; the test suites (4) exercise tasks 1–3. Within-task
  sub-steps land in one commit, so every commit keeps the gate green (e.g. task 1 updates the stub
  in the same commit as the protocol requirement it must satisfy).
- **`[P]` tasks 5 and 6** are docs-only transcription of the approved design (§10, §12) —
  independent of the code tasks and of each other; the coordinator may route them in any wave,
  including alongside code tasks. *Split justification:* design §12 makes the
  `docs/architecture.md` follow-ups a required same-story deliverable; the ADR log and the standing
  architecture reference are distinct files reviewed on distinct axes and get distinct commits
  (e1-s3 precedent: ADR batch and architecture reference were separate tasks). Folding either into
  task 7 would mix transcription with evidence.
- **Task 7 is last** and depends on all others.
- Routing (D3 — coordinator's call): tasks 1–4 → `implementer` (contract-bound code; both skills
  mandatory); tasks 5–6 → `implementer-flash` candidates (approved-design transcription);
  task 7 → `implementer` (evidence discipline).

---

## Task 1 — Core models + seam contract · design §1, §2, §5.4

Deliverable (code): `InstantPlayer/Core/Models/EntryAction.swift`, `MediaItem.swift`,
`MediaCollection.swift`; extend `InstantPlayer/Core/Protocols/MediaFolderRepository.swift`; extend
`InstantPlayer/Features/Feed/Data/StubMediaFolderRepository.swift`.

- [x] **1.1** Load `swift-security` + `swift-performance` before editing.
- [x] **1.2** Re-verify every design §1 fact against the repo: the files marked "exists" are
  present (`MediaFolderRepository.swift`, `StubMediaFolderRepository.swift`, `FeedViewModel.swift`,
  `FeedView.swift`, `InstantPlayerApp.swift`, `AppDependencies.swift`, `RootView.swift`), `Config/`
  is new (absent), synchronized root groups intact. **Any drift: stop and report — a design
  amendment is required.**
- [x] **1.3** `EntryAction.swift` per design §5.4 + §3.1: the single internal entry value —
  `enteredURL: URL`. Doc comments carry the routing contract: Open With, Dock drop and window drop
  are delivery channels for the same payload (S1–S4 branch only on what the URL is, never on the
  channel).
- [x] **1.4** `MediaItem.swift` per design §5.4: `id` (the resolved file URL; identity within a
  snapshot), `url`, `name` (display name = last path component, captured at open), `kind`
  (`video` / `image`); `Hashable`, `Sendable`, `Identifiable`.
- [x] **1.5** `MediaCollection.swift` per design §5.4 + §6: `folderURL`, `items: [MediaItem]`
  (the folder's own order, S14), `startIndex: Int` with invariant `0 ≤ startIndex < items.count`
  (an empty result is never a collection — it is `nil` → welcome per §3.3 step 5), `capturedAt:
  Date` (the S13 snapshot marker).
- [x] **1.6** Seam per design §2: add `prepareCollection(forEntryAt:)` to `MediaFolderRepository` —
  accepts one `EntryAction`, `async`, returns `MediaCollection?`. Doc comments carry the contract:
  derives the folder per S1–S4, collects per S10–S12/S14, resolves the starting item per §3.3
  step 6, manages the security-scoped session per S8–S9 **behind the seam**; `nil` means "no
  folder opens" (welcome, S5–S7); no `throws` — fail-open per §5.3, empty results are product
  states; deliberately **no** start/stop members (session lifecycle is conformance-internal).
  `wiringProbe()` unchanged (R16).
- [x] **1.7** `StubMediaFolderRepository.swift` gains the new member **in this same commit** (a
  protocol requirement without a conformer fails the build): returns a canned `MediaCollection`
  for wiring tests. The stub stays zero-I/O — no FileManager, no URL construction from disk.
- [x] **1.8** Full gate `./scripts/validate.sh` — the new types must compile (that is what proves
  target membership). Fix, tick this task's boxes, commit:
  `feat(e2-s1): core models and seam entry contract`.

## Task 2 — Feed Data: classifier + security-scoped repository · design §3, §5, §6, §8

Deliverable (code): `InstantPlayer/Features/Feed/Data/MediaTypeClassifier.swift`,
`InstantPlayer/Features/Feed/Data/SecurityScopedMediaFolderRepository.swift`.

- [x] **2.1** Load `swift-security` + `swift-performance` before editing.
- [x] **2.2** `MediaTypeClassifier` per design §5.2 — the S11 rule as one predicate plus kind:
  include iff (1) the entry is a regular file (excludes directories, packages/bundles, symlinks,
  fifos/sockets/devices — a symlink's target is **never** followed); (2) it is not hidden
  (`URLResourceValues.isHidden` — covers dot-names and the hidden flag, keeping `.DS_Store` and
  AppleDouble `._*` junk out); (3) its system-declared content type
  (`URLResourceValues.contentType`) conforms to `UTType.movie`/`UTType.video` (→ `.video`) or
  `UTType.image` (→ `.image`). **No hardcoded extension list, no name parsing** (S11); file names
  are display-only (§8.3). Doc comments record the honest §5.2 contract: declared-type judgment,
  content bytes are not sniffed — a mislabeled file collects as its declared kind and fails later
  at consumption (E2-S3).
- [x] **2.3** `SecurityScopedMediaFolderRepository` — the `actor` conforming to
  `MediaFolderRepository` (design §1, §5.4's D8 trigger): entry derivation exactly per §3.3 —
  classify the entered URL (standardize; symlink/package/non-regular → treated as *file*, target
  never followed; non-package directories are *folders*); **folder** → itself, `startIndex` = 0
  (S3); **media file** → its parent, `startIndex` = that file's index (S1, S2); **unsupported
  file** → its parent, never in the collection, `startIndex` = 0 (S4); derived folder with no
  media → `nil` (S5); general starting rule (step 6): start at the entered file's index when that
  file is part of the collection, otherwise at the first item (covers e.g. entered-but-hidden).
- [x] **2.4** Scan per design §5.1: one shallow enumeration of the folder's **direct children**
  with resource-value prefetch (S10 — never recursive); enumeration order preserved as returned,
  **no sorting** (S14); exactly one scan per entry action, the snapshot retained in the result
  (§6, §7.4).
- [x] **2.5** Fail-open per design §5.3: per-entry failures (unreadable resource values, broken
  symlinks, races with deletions) skip that entry and continue; only an unreadable/missing folder
  (enumeration itself fails) yields `nil` → welcome.
- [x] **2.6** Security-scoped lifecycle per design §8.1 (S8, S9): `prepareCollection` calls
  `startAccessingSecurityScopedResource()` on the entered URL and the derived folder; the actor
  tracks the active session's scoped URLs and stops the previous session when a new entry begins;
  process exit releases the rest (S9). **No `bookmarkData` call and no bookmark store anywhere**
  (S9 makes persistence a non-goal); no start/stop members leak onto the seam (§2).
- [x] **2.7** Untrusted input per design §8.3: only file URLs accepted; standardized before use;
  folder derivation by URL operations, never string path concatenation (no `..` traversal
  surface); names never logged unredacted; folder contents treated as hostile (§2.2 exclusions are
  security-relevant as well as product-relevant).
- [x] **2.8** Performance per design §7: the actor is the explicit isolation boundary that moves
  enumeration and type resolution off the main thread (§7.2 — the project defaults to MainActor
  isolation); the `@MainActor` view model receives only the finished value. No synchronous file
  I/O in any view, view model, or `App` code (skill §1).
- [x] **2.9** Full gate; fix; tick; commit:
  `feat(e2-s1): media classifier and security-scoped collection repository`.

## Task 3 — Presentation + App entry routing + project config · design §1, §3, §4, §8.2, §1.2

Deliverable (code): `InstantPlayer/Features/Feed/Presentation/FeedState.swift`,
`FeedViewModel.swift` (rewrite), `WelcomeView.swift` (new), `FeedView.swift` (rewrite);
`InstantPlayer/App/InstantPlayerApp.swift` (scene change), `InstantPlayer/App/RootView.swift`
(entry modifiers), `InstantPlayer/App/AppDependencies.swift` (binding);
`InstantPlayer/Config/Info.plist` + `InstantPlayer/Config/InstantPlayer.entitlements` (new) with
the §1.2 wiring.

- [x] **3.1** Load `swift-security` + `swift-performance` before editing.
- [x] **3.2** `FeedState` per design §4: the presentation state value `welcome` ↔
  `folderOpen(MediaCollection)`.
- [x] **3.3** `FeedViewModel` per design §4 (rewrite): `@MainActor @Observable final class`, the
  only presentation-state holder (D8); starts in `welcome` (S5); `handle(entryAction:)` awaits
  `prepareCollection(forEntryAt:)` and sets `.folderOpen(collection)` or `.welcome` (S6: leave
  welcome when media arrives; S7: drop back to welcome — and to no open folder — when an action
  yields no media mid-session). Entry actions arriving during an in-flight collection supersede it
  (last wins, §3.1) — no queue, no re-scan of superseded work (§7.4). Remove the wiring-probe UI
  (`probeResult` / `runWiringProbe`) from the view model — the probe stays on the seam for wiring
  tests (§4); update the existing `FeedViewModelTests` wiring case **in this same commit** so the
  suite compiles and stays green (minimal compile-level fix; the full §9 suites are task 4).
- [x] **3.4** `WelcomeView` per design §4 (with S5): static English drop-target copy (D6; draft —
  "Drop videos or images here", "or open a file with InstantPlayer from Finder"), hover affordance
  driven by the drop's `isTargeted`, and the accessibility identifier the §9.4 launch assertion
  keys on. `FeedView` per design §4: a dumb binder — `WelcomeView` for `.welcome`, an **interim
  folder-open placeholder** for `.folderOpen` (item count + starting-item name; deliberately not a
  feed — E2-S2 replaces it).
- [x] **3.5** Scene per design §3.4: switch `WindowGroup` → **`Window`** in
  `InstantPlayerApp.swift` — one window, one `RootView`, one `FeedViewModel` (one state machine,
  one open session). R37–R40 window behaviors remain E2-S2's work; the single-window
  precondition is this story's only window change.
- [x] **3.6** Entry routing per design §3.1 in `RootView`: `.onOpenURL` (Finder "Open With" and
  Dock-icon drop) and `.onDrop(of: [UTType.fileURL], isTargeted:)` (window drop) convert system
  events into `EntryAction`s routed **once** to `FeedViewModel.handle(entryAction:)`. Multi-item
  events (N URLs in one gesture) process as N entry actions in event order, **last one wins**
  (§3.1). The §3.1 fallback (`NSApplicationDelegateAdaptor`) is **not built speculatively** — if
  the converge functional review shows open-document events not delivered, that is a coordinator
  escalation per §3.1, not an implementer improvisation.
- [x] **3.7** `AppDependencies` per design §1: bind `SecurityScopedMediaFolderRepository` as the
  `MediaFolderRepository` seam; `makeFeedViewModel()` passes both seams; `init` stays
  **allocation-only** (R13 of E1-S3, §7.3) — no I/O, nothing scheduled, no scan at launch (the
  only launch-path additions are two allocations).
- [x] **3.8** `InstantPlayer/Config/Info.plist` per design §1.2 + §3.2: the partial plist merged
  into the generated one — `INFOPLIST_FILE = InstantPlayer/Config/Info.plist` with
  `GENERATE_INFOPLIST_FILE = YES` kept (existing `INFOPLIST_KEY_*` build settings stay).
  `CFBundleDocumentTypes` exactly as the §3.2 table: **A** `public.movie`, `public.image` —
  Viewer / Default (S1, S2); **B** `public.folder` — Viewer / Default (S3); **C** `public.data` —
  Viewer / **Alternate** (S4's derivation runs for unsupported files; Alternate never hijacks a
  default handler). The §3.2 exact-type fallback is likewise not built speculatively — a
  functional-review finding (Open With not listing InstantPlayer) is a coordinator escalation.
- [x] **3.9** `InstantPlayer/Config/InstantPlayer.entitlements` per design §8.2 — **exactly four
  read-only keys**, wired via `CODE_SIGN_ENTITLEMENTS`:
  `com.apple.security.app-sandbox`,
  `com.apple.security.files.user-selected.read-only`,
  `com.apple.security.temporary-exception.files.home-relative-path.read-only` = `["/"]`,
  `com.apple.security.files.removable-media.read-only`.
  Both `Config/` files are excluded from bundle-resource copying via synchronized-group
  file-membership exceptions (§1.2). **D19 boundary:** this entitlement posture targets
  **direct/notarized distribution** (hardened runtime already on); Mac App Store distribution
  would revisit D19 (§8.2). **Any deviation from this four-key read-only posture — adding,
  removing, or widening any entitlement (no write, no network, no full-disk) — is a coordinator
  escalation, never an implementer decision.**
- [x] **3.10** Verify entitlement reality per design §1.2 / §9.4: `codesign -d --entitlements` on
  the built app shows the four keys merged with the file. If the build-setting keys do not merge,
  move the two existing keys into the entitlements file too (the §1.2 sanctioned fallback).
  Record the output for task 7's evidence.
- [x] **3.11** Full gate (the template UI tests assert no UI text — the placeholder → welcome swap
  breaks nothing, §9.4). Fix, tick; commit:
  `feat(e2-s1): welcome state, entry routing, and project config`.

## Task 4 — Tests through the seam + launch UI assertion · design §7.1, §9

Deliverable (code): `InstantPlayerTests/` — fixture helper, seam tests, `FeedViewModelTests`
(extended), §7.1 performance test; `InstantPlayerUITests/` — one launch assertion added.

- [x] **4.1** Load `swift-security` + `swift-performance` before editing.
- [x] **4.2** Frameworks per house pattern: Swift Testing (`import Testing`, `@testable import
  InstantPlayer`, `@Test` + `#expect`) for the suites; the design §7.1 performance test uses
  XCTest `measure` exactly as the design names it — the one deliberate exception.
- [x] **4.3** Fixtures per design §9.1: a helper builds throwaway folders under
  `FileManager.default.temporaryDirectory/<UUID>/` and removes them in teardown. Deterministic
  byte payloads typed by extension (the pinned honest declared-type contract of §5.2): 1×1 PNG
  constant for `.png`, minimal JPEG constant for `.jpg`, minimal ISO-BMFF `ftyp` stub for
  `.mp4`/`.mov` (bytes need not be playable).
- [x] **4.4** Entry-derivation matrix per design §9.3 — through the `MediaFolderRepository` seam
  only (S15: no UI, no running app): S1/S2 media-file entry (`a.jpg`, `b.mov`, `clip.mp4`; entry
  `clip.mp4` → `folderURL` = parent, `startIndex` = its index); S3 folder entry (→ itself,
  `startIndex` = 0); S4 unsupported entry (`notes.txt` → parent, `startIndex` = 0, `notes.txt`
  absent); S5 empty folder **and** only-`notes.txt` folder → `nil` both; the §3.3 step-6 edge case
  (entered media file excluded, e.g. hidden → `startIndex` = 0).
- [x] **4.5** Collection rules per design §9.1: S10 — media inside a subfolder is absent;
  **S11 anti-spoofing — misleading-extension cases are rejected regardless of file name:
  `clip.mp4.txt` (declared plain text), a folder named `folder.mp4`, a fifo named `pipe.mp4`,
  hidden `._clip.mp4` and `.hidden.mp4`, while `a.jpg`/`b.mov` are accepted** (the
  conformance rule, never an extension list); S12 — every excluded entry appears in no item of
  the collection (boundary enforcement); S14 — `items` order equals the scan's enumeration order,
  no alphabetical sorting.
- [x] **4.6** **S13 snapshot/staleness per design §9.1:** collect, then add/remove files on disk →
  the returned collection is unchanged (no re-scan on read); a fresh entry action re-collects; a
  call-counting repository spy verifies **one repository call per entry action** (also §7.4's
  no-redundant-work assertion). Fail-open and unreadable-folder cases: a broken symlink plus one
  entry whose resource values fail → the folder's other media is still collected; a
  nonexistent/derelict path → `nil` (welcome).
- [x] **4.7** `FeedViewModelTests` per design §9.2 with an injected repository double: starts
  `welcome`; media entry → `folderOpen` with correct `startIndex`; no-media entry while open →
  `welcome` with no folder (S7); no-media entry while welcome → stays `welcome` (S5); rapid
  successive actions → last wins and one repository call per action.
- [x] **4.8** Performance test per design §7.1: XCTest `measure` through the seam over a generated
  **1,000-entry** fixture folder. Budget (design §7.1): ≤ 1,000 direct children collected within
  **1 s** wall time at p95, a typical folder (≤ 200 children) within **250 ms**; the budget covers
  derivation + scan + classification (scope handshake excluded). Measured numbers are recorded in
  task 7's evidence from tooling.
- [x] **4.9** UI tests per design §9.4 (the R14 mandate's subject): add **one** assertion to the
  launch tests that a plain launch shows the drop-target welcome state (keyed on the task-3
  accessibility identifier) — making the launch tests meaningful; keep `testLaunchPerformance` as
  the launch-budget guard (§7.3). Open With and drag & drop stay undriven — host-driven flows UI
  tests cannot drive; unit tests (4.4–4.7) and stakeholder functional review carry them (the
  spec's honest caveat).
- [x] **4.10** Full gate — the tests run and must be green. Fix, tick; commit:
  `test(e2-s1): entry, collection, and welcome-state tests + launch UI assertion`.

## Task 5 — ADR batch D18–D20 `[P]` · design §10

Deliverable (docs): `docs/decisions.md` — append D18–D20.

- [x] **5.1** Append three ADRs continuing the numbering (the log currently ends at D17), house
  heading `## D# — title · date · status` (date = commit date, `YYYY-MM-DD`), each with context,
  decision, alternatives, consequences. Titles and one-line decisions exactly per design §10:
  **D18 — Entry convergence: one entry action, one open session, one window** (→ S1–S7) ·
  **D19 — Per-entry security-scoped access without bookmark persistence; entitlement posture**
  (→ S8, S9, product R6) · **D20 — Media classification by system UTType conformance with junk
  exclusions** (→ S11, S12).
- [x] **5.2** Pull each entry's alternatives from the matching design §11 rows —
  D18: first-wins and merged multi-item resolution, `NSApplicationDelegateAdaptor` as the primary
  route, `.dropDestination(for: URL.self)`, AppKit `NSDraggingDestination`, entry routing inside
  the Feed feature, `WindowGroup` + app-scoped shared state; D19: `user-selected.read-only` alone,
  absolute-path temporary exception `["/"]`, standard-folder entitlements only, sandbox off,
  bookmarks/recents, stopping scoped access at the end of `prepareCollection`; D20: hardcoded
  extension lists, content sniffing, recursive scans, including hidden files, resolving symlinks,
  sorting now.
- [x] **5.3** Status `accepted`. D19 carries its consequences honestly (design §8.2): the posture
  targets direct/notarized distribution and MAS would revisit it; the kernel grant is broader
  than one user action (S8 is enforced architecturally — one seam, fixed read set, unit tests);
  file-entry derivation on network-mounted shares is not covered.
- [x] **5.4** Stage, then gate `./scripts/validate.sh --staged` (docs-only mode: ADR format +
  internal links); fix; tick; commit:
  `docs(e2-s1): ADRs D18–D20 — entry, access, and classification decisions`.

## Task 6 — Architecture reference follow-ups `[P]` · design §12

Deliverable (docs): `docs/architecture.md` — the four required same-story updates.

- [x] **6.1** Update `docs/architecture.md` exactly per design §12: (1) **§3 source tree** gains
  this story's files (the design §1 inventory: the three `Core/Models` values, the extended seam,
  `MediaTypeClassifier` + `SecurityScopedMediaFolderRepository`, `FeedState` + `WelcomeView` and
  the updated views, the App scene/entry wiring, `Config/Info.plist`,
  `Config/InstantPlayer.entitlements`); (2) **§4 check (3)** gets the design §1.1 URL refinement —
  filesystem and media framework *operations* (`FileManager`, security-scoped calls, `UTType`
  resolution, AVKit) live only in Data conformances, while Foundation `URL` may travel as an
  opaque value in Core/Domain contracts; (3) **§8** records this story as the D8 actor trigger
  (mutable session state shared across isolation domains) and names the shipped actor;
  (4) **§6 walkthrough step 6** becomes "host in `RootView` (which owns entry modifiers)".
- [x] **6.2** Internal links must resolve (the gate checks them) — link only to existing files.
- [x] **6.3** Stage, then gate `./scripts/validate.sh --staged`; fix; tick; commit:
  `docs(e2-s1): architecture reference updates for entry & collection`.

## Task 7 — Verification & evidence · spec acceptance criteria, design §7, §9

Deliverable (docs): `docs/specs/e2-s1-entry-media-collection/evidence.md` (new) +
acceptance-criteria ticks in this file.

- [x] **7.1** Load `swift-security` + `swift-performance` (the walk covers the pillar rows).
- [x] **7.2** Traceability walk: **S1–S15 row by row** — for each row name the shipped artifact
  (file, test, or ADR) that satisfies it, with its design section — and then the **product
  R-map** of the spec's acceptance table (product R1–R6, R34–R36 → story outcome → verified by).
  Record both tables in evidence.md.
- [x] **7.3** Run the full gate with machine-readable evidence:
  `./scripts/validate.sh --json <tmp>/e2-s1-gate.json` (`<tmp>` = session temp dir outside the
  repo; the JSON is never committed). Quote it **verbatim** into evidence.md — `result` plus every
  step name and status — and confirm the SwiftLint and SwiftFormat steps read `pass`.
- [x] **7.4** **UI-test mandate (R14 of E1-S2):** run
  `./scripts/validate.sh --uitests --json <tmp>/e2-s1-uitests-gate.json` and quote it **verbatim**
  (design §9.4; spec Story context). The run is additive and fail-closed: a failing UI test fails
  it; the flag never skips or weakens a step (docs/development.md §3).
- [x] **7.5** Record from tooling, never from memory: the design §7.1 performance measurement
  (the test run's output against the 1 s / 250 ms budget) and the `codesign -d --entitlements`
  output showing the four §8.2 keys (task 3.10).
- [x] **7.6** Deviations honest: list every deviation from the approved design (files, signatures,
  fixtures, UI copy, config wiring) with its impact, marked for coordinator ratification —
  silently deviating is forbidden (standing rule 6).
- [x] **7.7** Tick AC1–AC8 below and mirror them in evidence.md; leave the converge-owned
  AC9–AC11 unticked.
- [x] **7.8** Commit (docs-only): `docs(e2-s1): evidence and acceptance — traceability walk +
  gate output`.

---

## Acceptance criteria

Ticked by task 7, each backed by quoted tooling evidence:

- [x] **AC1 · R1–R4 / S1–S4, S15** — the entry-derivation matrix (media file, folder, unsupported
  file, empty; plus the excluded-entry starting rule) is covered by unit tests **through the
  `MediaFolderRepository` seam** — no UI, no running app — and green.
- [x] **AC2 · R34–R36 / S10–S12** — collection rules green: direct children only, the S11
  conformance rule incl. **misleading-extension anti-spoofing** (rejected regardless of file
  name), and S12 boundary enforcement (excluded entries in no item of the collection).
- [x] **AC3 · S13, S14** — snapshot/staleness and ordering-neutral semantics asserted explicitly:
  no folder watching after open, one collection per entry action (spy), enumeration order with no
  sorting.
- [x] **AC4 · R5 / S5–S7** — welcome-state machine tested (start `welcome`; both transitions;
  empty result → no folder open).
- [x] **AC5 · RNF-02** — the entry-time budget (design §7.1: 1 s / 250 ms) measured by the §7.1
  performance test and recorded from tooling; zero added launch work — `testLaunchPerformance`
  guard intact and green.
- [x] **AC6 · R6, RNF-04 / S8–S9** — entitlements exactly the design §8.2 four read-only keys
  (`codesign -d --entitlements` output recorded); no bookmark persistence anywhere; untrusted
  input validated at the Data edge (design §8.3/§8.4 table).
- [x] **AC7 · R14 (E1-S2)** — the `--uitests` converge-mandate run is green and quoted verbatim,
  including the launch smoke assertion (launch completion + chrome exposure; window-content
  queries are a documented macOS 26 XCUITest limitation — see evidence.md §6.3) and
  `testLaunchPerformance`.
- [x] **AC8 · evidence & coverage** — full gate `--json` quoted verbatim (lint/format `pass`); the
  S1–S15 + product R-map walk recorded; D18–D20 in `docs/decisions.md` house format; the
  design §12 architecture updates done; all deviations listed honestly.

Converge-owned — the coordinator ticks these; task 7 never does:

- [ ] **AC9 · stakeholder functional review** (this is a UI story): in the running app
  (`./scripts/app.sh run`) — welcome at launch, Open With on a file, drop of a file, drop of a
  folder, an unsupported file, and **both** welcome-state transitions; explicit approval required.
- [ ] **AC10 · validator review** — adversarial PASS over spec S1–S15 and the product R-map,
  design §8.4's sandbox table, and both pillar-skill checklists.
- [ ] **AC11 · story closure** — backlog E2-S1 → `done`; `git merge --no-ff` into `main`; delete
  `feat/e2-s1-entry-media-collection`.

## Converge (coordinator)

1. **Stakeholder gate** — functional review of the entry flows in the running app
   (`./scripts/app.sh run`): welcome at launch, Open With on a file, drop of a file, drop of a
   folder, an unsupported file, and both welcome-state transitions (S5–S7).
2. **Validator review** — loads both pillar skills; adversarial pass over S1–S15 / product R-map
   and design §9's test tables + §8.4's review table.
3. **Converge run** — `./scripts/validate.sh --uitests` (the UI-test mandate's final run, R14 of
   E1-S2) alongside the functional review; its output is the story's final gate record.
4. **Closure** — tick AC9–AC11, backlog `done`, `git merge --no-ff` into `main`, delete the story
   branch.

Handoff recorded in design §12: **E2-S2** inherits `FeedState.folderOpen(MediaCollection)` with
`startIndex`, the interim placeholder to replace, the `Window` scene, and the §6 staleness
contract; **E2-S3** inherits the open session's scoped access (§8.1) — it must not re-derive or
re-scan.

## References

- [spec](spec.md) · [design](design.md) — this story's approved artifacts
- [docs/decisions.md](../../decisions.md) — ADR log (D1–D17; task 5 appends D18–D20)
- [docs/spec.md](../../spec.md) — product source of truth (product R1–R6, R34–R36; RNF-02,
  RNF-04)
- [docs/architecture.md](../../architecture.md) — seam, layering; task 6 applies design §12
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S1)
- [SDD conventions](../README.md) — tasks artifact rules and evidence discipline
