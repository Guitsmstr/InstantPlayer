# E2-S1 · Entry & media collection — Design

How the app opens a folder from Finder or drag & drop and produces the media collection behind the
`MediaFolderRepository` seam. Story spec: [spec.md](spec.md) (S1–S15 over product R1–R6, R34–R36).
Structure follows [docs/architecture.md](../../architecture.md) (D7–D10); entry policy follows
D11–D12 ([docs/decisions.md](../../decisions.md)). Pillars: RNF-02 and RNF-04 — mandatory sections
below; the design was written against the `swift-performance` and `swift-security` skills
(`.opencode/skills/swift-performance`, `.opencode/skills/swift-security`), and every implementer and
the validator load them before touching this code (D5).

Scope reminder: this story ends at "the folder is open and its media collection is prepared, with a
starting item named". Feed rendering, paging, window behavior (product R37–R40) are E2-S2; playback
is E2-S3. No `[NEEDS CLARIFICATION]` markers exist in this design — every decision below is made and
traceable to S-/product-R numbers.

## 0 · The one hard platform fact this design is built on

macOS grants sandbox access **per item the user acts on** (Apple, *Accessing files from the macOS App
Sandbox*): open-panel results, Dock drops and open-document ("Open With") deliveries extend the
sandbox to the delivered URLs; a folder URL extends recursively to its contents; **a file URL extends
to that file only**. A sandboxed app therefore cannot enumerate the *containing folder* of a file it
was given. Confirmed in the wild by CotEditor's maintainer: "A sandboxed app can open only
files/folders the user intentionally opened… [a file document] has the access permission only to its
file and therefore cannot turn into a folder document afterward" (coteditor/CotEditor#1717).

Consequence: S3 (folder entry) works under the current `user-selected.read-only` grant; **S1, S2 and
S4 (file entry → collect the containing folder) do not**. The entitlement posture must change — see
§8.2. This is exactly the "verify … or needs adjustment" question the coordinator brief raised; the
answer is: *needs adjustment*, and the minimal adjustment is designed and ADR-planned below (D19).

## 1 · Architecture mapping & component inventory

All new code lands per the D7 walkthrough: Presentation → Domain ← Data, framework types behind
seams, composition wired only in `App/`. Files (names + responsibilities; member names are
contract-level, matching the level `docs/architecture.md` publishes):

| File | Layer | Responsibility | Requirements |
|---|---|---|---|
| `InstantPlayer/Core/Protocols/MediaFolderRepository.swift` (exists) | Core seam | Extended with the entry/collection operation; `wiringProbe()` kept for wiring tests | S15 (D7, R12) |
| `InstantPlayer/Core/Models/EntryAction.swift` | Core | The single internal entry value: the URL the user acted on. Converges Open With and drag & drop onto one routed action | S1–S4 |
| `InstantPlayer/Core/Models/MediaItem.swift` | Core | Collected item value: identity + resolved file URL + display name + kind (video/image) | S11, S13 |
| `InstantPlayer/Core/Models/MediaCollection.swift` | Core | The prepared collection: opened folder, ordered items, starting-item index, capture moment | S1–S4, S13, S14 |
| `InstantPlayer/Features/Feed/Domain/` (no new files) | Feed Domain | Feed's Domain stays empty of types in this story; the entry contract lives in Core (see §1.1) | — |
| `InstantPlayer/Features/Feed/Data/SecurityScopedMediaFolderRepository.swift` | Feed Data | Real `MediaFolderRepository` conformance, an `actor`: entry derivation (S1–S4), security-scoped session start/stop (S8–S9), directory scan (S10, S13, S14), fail-open per-entry errors | S1–S4, S8–S10, S13, S14 |
| `InstantPlayer/Features/Feed/Data/MediaTypeClassifier.swift` | Feed Data | Data-internal helper: UTType-conformance media rule + junk exclusions (hidden, packages, symlinks, non-regular files) | S11, S12 |
| `InstantPlayer/Features/Feed/Data/StubMediaFolderRepository.swift` (exists) | Feed Data | Stub gains the new member; returns a canned collection for wiring tests | S15 |
| `InstantPlayer/Features/Feed/Presentation/FeedState.swift` | Feed Presentation | The state machine value: `welcome` ↔ `folderOpen(MediaCollection)` | S5–S7 |
| `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (exists) | Feed Presentation | `@MainActor @Observable` owner of `FeedState`; routes the one entry action to the seam, applies the result | S5–S7, S15 |
| `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (exists) | Feed Presentation | Dumb binder: renders `WelcomeView` for `welcome`, an interim folder-open placeholder for `folderOpen` (E2-S2 replaces it with the feed) | S5–S7 |
| `InstantPlayer/Features/Feed/Presentation/WelcomeView.swift` | Feed Presentation | Drop-target welcome surface (hover affordance + English copy per D6) | S5 |
| `InstantPlayer/App/InstantPlayerApp.swift` (exists) | App | Scene: `WindowGroup` → **`Window`** so one window owns the one state machine (§3.4) | S1–S7 |
| `InstantPlayer/App/AppDependencies.swift` (exists) | App | Composition root: binds `SecurityScopedMediaFolderRepository`; `makeFeedViewModel()` passes both seams; init stays allocation-only | R13 of E1-S3 |
| `InstantPlayer/App/RootView.swift` (exists) | App | Hosts `FeedView`; scene-level entry modifiers (`.onOpenURL`, `.onDrop`) convert system events into `EntryAction`s routed once | S1–S4 |
| `InstantPlayer/Config/Info.plist` (new) | Project config | Partial plist merged into the generated one: `CFBundleDocumentTypes` (§3.2) | S1–S4 delivery |
| `InstantPlayer/Config/InstantPlayer.entitlements` (new) | Project config | Entitlement additions for derived-folder reads (§8.2) | S8 |

### 1.1 Placement justifications (architecture reviewer checks)

- **`Core/Models` types (≥2 consumers, §4 check 4):** `MediaItem`/`MediaCollection` are the seam's
  output contract. Consumers: **Feed** (this story through E2-S3) and **MediaList** (E5-S1 consumes
  the same collection for product R27–R28; the location is reserved per D9). This is D7's own
  precedent — "only filesystem access has two v1 consumers today" — applied to the seam's value
  types so no later promotion move is needed. `EntryAction` is consumed by `App` routing, the Feed
  view model, and the seam itself.
- **`URL` in Core/Domain contracts:** `docs/architecture.md` §4 check (3) lists `URL` among types
  allowed "only inside a Data conformance". `URL` is Foundation (R10 allows Foundation) and is the
  system's value type for "this file the user picked"; passing file *paths as strings* would invite
  the traversal bugs RNF-04 forbids. This story refines §4 check (3) to: **filesystem and media
  framework *operations* (`FileManager`, security-scoped calls, `UTType` resolution, AVKit) live only
  in Data conformances; Foundation `URL` may travel as an opaque value in Core/Domain contracts.**
  The wording update to `docs/architecture.md` is a required same-story consequence (§12).
- **No Feed Domain types:** the entry contract is consumed by `App` and by `Core/Protocols` as well
  as Feed; parking it in Feed/Domain would make Core depend on a feature (inversion). `MediaPlayerService`
  and `StubMediaPlayerService` are untouched (playback is E2-S3).

### 1.2 Project-config mechanism (verified)

The project generates its Info.plist (`GENERATE_INFOPLIST_FILE = YES`, no `INFOPLIST_FILE`) and its
entitlements from build settings (`ENABLE_APP_SANDBOX = YES`, `ENABLE_USER_SELECTED_FILES = readonly`,
hardened runtime on). Document types cannot be expressed as `INFOPLIST_KEY_*` settings, so:

- **`CFBundleDocumentTypes` lands in a partial `InstantPlayer/Config/Info.plist`**, wired by setting
  `INFOPLIST_FILE = InstantPlayer/Config/Info.plist` while keeping `GENERATE_INFOPLIST_FILE = YES`.
  Xcode merges the file's keys with the Info.plist Values build settings
  (*Managing your app's information property list values* — "If the value is Yes, then Xcode merges
  the content of the property list file with the values from the Info.plist Values build settings").
  The existing `INFOPLIST_KEY_NSHumanReadableCopyright` stays as a build setting.
- **Entitlement additions land in `InstantPlayer/Config/InstantPlayer.entitlements`**, wired by
  `CODE_SIGN_ENTITLEMENTS`. If the built entitlements (checked with `codesign -d --entitlements`) do
  not show the build-setting keys merged with the file, the two existing keys move into the file too
  (verification task, §9.4).
- Both files sit under the file-system-synchronized `InstantPlayer/` group; non-source files there
  ride as flattened bundle resources (architecture §5). Both are excluded from target resource
  copying via Xcode's synchronized-group **file membership exceptions** (target → File System
  Synchronized Groups → Exceptions). `project.pbxproj` is never hand-edited; all wiring goes through
  Xcode build settings/UI (architecture §5).
- Window **drag & drop needs no registration**: it is the SwiftUI drop API (`UTType.fileURL`
  providers), §3.3. Dock-icon drops and Open With are delivered by Launch Services through the
  document types declared above (§3.2).

## 2 · Seam contract (`Core/Protocols/MediaFolderRepository`)

The seam stays the only filesystem path (R11); sandbox handling is added *behind* it (R12). Members:

- `wiringProbe()` — unchanged; proves binding in wiring tests (R16).
- `prepareCollection(forEntryAt:)` — accepts one `EntryAction`, returns `MediaCollection?`.
  Contract: derives the folder per S1–S4, collects per S10–S12/S14, resolves the starting item per
  S1–S4, manages the security-scoped session per S8–S9. `nil` means "no folder opens" (welcome,
  S5–S7). No `throws`: all failure modes are fail-open (§5.3) and empty results are product states,
  not errors.

There are deliberately **no** start/stop members: session lifecycle is conformance-internal (§8.1),
so callers cannot misuse it and E2-S2/E2-S3 consume the same seam unchanged.

## 3 · Entry mechanics (S1–S4)

### 3.1 One entry action, routed once

Open With, Dock-icon drop and window drop are three delivery channels for the same payload: a URL
the user acted on. S1–S4 branch only on **what the URL is** (media file / folder / unsupported
file), never on the channel, so all channels converge on the single `EntryAction` value and are
routed once by `RootView` into `FeedViewModel.handle(entryAction:)`, which calls the seam exactly
once per action. Sources of URLs:

| Channel | Mechanism | Notes |
|---|---|---|
| Finder "Open With" (app running or cold-launching) | Launch Services open-document event → SwiftUI `.onOpenURL` on the root view | Cold launch: the event is delivered after the scene exists; state goes straight to `folderOpen` (S6) |
| Drop on Dock icon | Same open-document event → `.onOpenURL` | macOS auto-starts security-scoped access for Dock drops (Apple doc) |
| Drop on open window | SwiftUI `.onDrop(of: [UTType.fileURL], isTargeted:perform:)` on the root view | URLs read from `NSItemProvider`; `isTargeted` drives the drop-target hover affordance |

Fallback if functional review shows SwiftUI not delivering open-document events: an
`NSApplicationDelegateAdaptor` whose `application(_:openURLs:)` routes the same `EntryAction`s — the
routing target does not change.

**Multi-item events** (Finder "Open With" with N files selected, multi-item drop): one user gesture
produces N URLs; they are processed as N entry actions in event order, **last one wins** —
deterministic, and consistent with product R38 (a later open replaces the current one). Alternative
rejected: first-wins (arbitrary) or merging (no spec basis).

### 3.2 Document-type declarations (`CFBundleDocumentTypes`)

Conformance-based claims where Launch Services allows (declaring a family root claims its conforming
types), role `Viewer` (R17: never an editor), plus a generic claim so unsupported files can arrive
for S4:

| Entry | `LSItemContentTypes` | Role / Rank | Purpose |
|---|---|---|---|
| A | `public.movie`, `public.image` | Viewer / Default | Open With and drops for native video/image families (S1, S2) |
| B | `public.folder` | Viewer / Default | Folder entry (S3). Finder never delegates folder double-clicks, so Default is inert |
| C | `public.data` | Viewer / **Alternate** | Lets unsupported files be dropped/opened so S4's derivation runs; Alternate never hijacks any type's default handler |

Fallback if functional review finds Open With not listing InstantPlayer for MP4/JPEG etc. (i.e. LS
matching proves exact-type): replace the family roots in entry A with the documented standard types
(`public.mpeg-4`, `com.apple.quicktime-movie`, `com.apple.m4v-video`, `public.jpeg`, `public.png`,
`public.heic`, `public.tiff`, `public.gif`) — verified against the same review. The in-app
collection rule (§5.2) is unaffected by which spelling ships.

### 3.3 URL → folder derivation and the starting-item rule

For one `EntryAction` (applied uniformly on all channels; S1–S4):

1. Classify the entered URL (Data edge, untrusted input): standardize; read resource values; if it
   is a **symlink, package, or non-regular file** → treat as *file* (its own target is never
   followed — §5.2). Directories that are not packages are *folders*.
2. **Folder** → the folder to open is the entered folder itself; starting position = first item of
   the collection (S3).
3. **Media file** (classifier says video/image) → the folder to open is its parent
   (`deletingLastPathComponent`); starting position = the position of that file in the collection
   (S1, S2).
4. **Unsupported file** → its parent; the file is never in the collection; starting position = first
   item (S4).
5. If the derived folder yields no media → `nil` → welcome, no folder open (S5), regardless of which
   case derived it.
6. General starting-item rule covering S1–S4 and edge cases (e.g. the entered file is media but
   hidden and thus excluded): **start at the entered file's index when that file is part of the
   collection; otherwise at the first item.**

### 3.4 Single state machine needs a single window

`WindowGroup` gives each opened document its own window and its own root view — incompatible with
"one entry action routed once" and with S6/S7's app-level transitions (and product R37–R38's single
window). This story switches the scene to **`Window`** (one window, one `RootView`, one
`FeedViewModel`). R37–R40's behaviors (resizing, fullscreen, replace-in-place presentation) remain
E2-S2's work; the single-window precondition is established here because entry routing requires it.
Alternative rejected: `WindowGroup` + app-scoped shared model (windows would mirror one state while
still multiplying per open event).

## 4 · Welcome / feed-state model (S5–S7)

`FeedState` (Presentation value): `welcome` ↔ `folderOpen(MediaCollection)`. `FeedViewModel`
(`@MainActor @Observable`, the only presentation-state holder, D8):

- starts in `welcome` (S5);
- `handle(entryAction:)` awaits `prepareCollection(forEntryAt:)` and sets `.folderOpen(collection)`
  or `.welcome` (S6: leaving welcome when media arrives; S7: dropping back to welcome — and to no
  open folder — when an action yields no media mid-session);
- entry actions arriving during an in-flight collection supersede it (last wins, §3.1); no queue, no
  re-scan of superseded work.

`FeedView` renders `WelcomeView` (static drop-target copy in English, D6 — draft: "Drop videos or
images here", "or open a file with InstantPlayer from Finder") or an **interim folder-open
placeholder** (e.g. item count and starting-item name). The placeholder is deliberately not a feed:
E2-S2 replaces it. The wiring probe UI (`probeResult`) is removed from the view model; the probe
stays on the seam for wiring tests.

## 5 · Collection implementation (S10–S12, S14)

### 5.1 Scan (S10, S14)

One shallow enumeration of the folder's **direct children** (`FileManager.contentsOfDirectory`,
including resource-value prefetch for content type and the exclusion keys). Never recursive (D12
forecloses subfolders). **Order = enumeration order as returned, stable within the snapshot; no
sorting is applied** (S14 — the ordering-neutral contract; filename/date orderings are E4-S1's).

### 5.2 Media rule and exclusions (S11, S12)

Include an entry iff **all** of:

1. it is a regular file (excludes directories, packages/bundles, symlinks, fifos/sockets/devices) —
   a folder or package named `clip.mp4` is not media, and symlinks never pull content from outside
   the folder into the collection (untrusted-input rule, §8.3);
2. it is not hidden (`URLResourceValues.isHidden` — covers dot-names and the hidden flag). This is
   the documented junk exclusion that keeps `.DS_Store` and AppleDouble `._*` metadata (whose names
   often end in media extensions) out of the feed (US4, S12);
3. its **system-declared content type** (`URLResourceValues.contentType`) **conforms to the system's
   video family (`UTType.movie` or `UTType.video`) or image family (`UTType.image`)** — the S11
   conformance rule: no hardcoded extension list, no name parsing.

`MediaTypeClassifier` turns the conformance into `MediaItemKind` (`.video` / `.image`) at the same
pass. Honest contract, recorded deliberately: declared type is the system's type judgment (extension
and metadata based); **content bytes are not sniffed at collection time** — a file named `fake.mp4`
holding text is collected as a video and surfaces as unplayable at playback (E2-S3's failure
handling). Content sniffing per file was rejected on performance grounds (D12: the scan must stay
cheap enough to re-run for live sync) and is not a security vector (nothing executes file content —
§8.3). The "misleading name" cases the rule *does* reject: `clip.mp4.txt` (declared plain text),
folders/packages/media-named special files, hidden `._clip.mp4`.

### 5.3 Error handling (fail-open)

Per-entry failures (resource values unreadable, broken symlinks, races with deletions) **skip that
entry and continue** — never fail the folder (S12's boundary is the collection itself). Only an
unreadable/missing folder (enumeration itself fails) yields `nil` → welcome (S5).

### 5.4 Value shape (`Core/Models`)

- `MediaItem` — `id` (the resolved file URL; identity within a snapshot), `url`, `name` (display
  name = last path component, captured at open), `kind` (`video` / `image`). `Hashable`, `Sendable`,
  `Identifiable`.
- `MediaCollection` — `folderURL` (the opened folder), `items: [MediaItem]` (ordered per §5.1),
  `startIndex: Int` (invariant `0 ≤ startIndex < items.count`; per §3.3 step 6), `capturedAt: Date`.
- `EntryAction` — `enteredURL: URL` (§3.1).

## 6 · Freshness (S13) — snapshot contract

Captured at open: resolved file URLs, display names, kinds, the folder URL, the order, the starting
index, and a capture timestamp. **The collection never changes after `prepareCollection` returns**:
no directory watching exists in this story (live tracking is product R23–R26 / E4-S2), and no view
or state read re-scans the folder. Documented staleness contract: after an entry action, the
collection is a point-in-time snapshot and may drift from disk — files added later are absent
(until the next entry action or E4-S2's live sync), files removed later leave stale items whose
failure surfaces at consumption time (display/playback, E2-S2/E2-S3), renames show their open-time
name. Renames/removals reflected live are explicitly product R25/R24, not this story.

## 7 · Performance (RNF-02)

Loaded skill: `swift-performance`. The entry path is the only performance-relevant surface of this
story (no playback, no lists, no images yet).

1. **Entry-time budget (per-story, this design sets it):** collecting a folder of **≤ 1,000 direct
   children completes within 1 second** of wall time at p95 on Apple-silicon reference hardware,
   and a typical folder (≤ 200 children) within **250 ms**. Measurement: a unit performance test
   through the seam (XCTest `measure` block) over a generated 1,000-entry fixture folder, recorded
   as story evidence from tooling (§9). The budget covers derivation + scan + classification;
   security-scope handshake is excluded (kernel-side, not ours to bound).
2. **Off-main scanning:** all enumeration and type resolution runs off the main thread on the
   `SecurityScopedMediaFolderRepository` actor's executor; the view model is `@MainActor` and
   receives only the finished value. Note the project's Swift settings (`SWIFT_DEFAULT_ACTOR_ISOLATION
   = MainActor`, approachable concurrency): the actor is the explicit isolation boundary that moves
   this work off main; the gate compiles the real spelling. No synchronous file I/O in any view,
   view model, or `App` code (skill §1).
3. **Zero added launch work (R13 of E1-S3 must survive):** `AppDependencies.init` remains
   allocation-only — binding one repository actor and a factory, no I/O, nothing scheduled. The
   welcome state is static UI rendered synchronously. The only additions to the launch path are two
   allocations (the `FeedViewModel` created when `RootView` appears via `makeFeedViewModel()`, and
   the repository actor). No scan runs at launch: with no entry action, no folder is ever touched.
   The existing UI launch test (`testLaunchPerformance`) guards regression and is part of the
   `--uitests` converge run.
4. **No redundant work per entry:** exactly one scan per entry action; the snapshot is retained in
   state (no re-derivation on redraw/state read); superseded in-flight actions are dropped, not
   re-run; multi-item events scan each derived folder as their own action (last wins — if all items
   share a folder, that folder is scanned once per action, bounded by the user's own gesture count).
5. **Memory:** collections hold URLs + names + kind only — no thumbnails, no decoded media, no file
   bytes (image/video cost belongs to E2-S2/E2-S3 and their designs). Snapshot size is bounded by
   the folder's entry count.

## 8 · Security (RNF-04)

Loaded skill: `swift-security`. Review checklist status: no secrets, no network (D9 — ATS untouched),
no new dependencies (RNF-04 dependency hygiene), no required-reason API use this story (no
`UserDefaults`, no file-timestamp APIs — content-type resource values are not on the required-reason
list), so **no `PrivacyInfo.xcprivacy` change is needed**; logs (none added) must redact paths and
names (`privacy: .private`) if any are introduced.

### 8.1 Security-scoped access lifecycle (S8, S9)

Access is granted by the user's entry action and held for the **open session** — the period during
which the prepared collection is the current one (E2-S3 will read its files during playback):

| Entry path | Grant source | `startAccessing` | `stopAccessing` |
|---|---|---|---|
| Open With (running or cold launch) | Powerbox user-selected grant on the delivered URL (implicit scope) | On entry: `prepareCollection` calls `startAccessingSecurityScopedResource()` on the entered URL and the derived folder (belt-and-braces: implicit scope is idempotent here) | When superseded by a later entry action, or process exit |
| Dock-icon drop | Same user-selected grant (Apple doc: Dock drops auto-start scoped access) | Same | Same |
| Window drop | Same user-selected grant via the drop's file URLs | Same (required for uniformity; harmless on implicitly-scoped URLs) | Same |

All start/stop lives **in the Data conformance** (behind the seam, R12): the actor tracks the active
session's scoped URLs, stops the previous session when a new entry begins, and relies on process
exit to release everything (S9). S8 on every path: the app touches exactly what the user's action
nominates — the entered item and the derived folder's direct children — and nothing else; the single
input boundary (D12) is the enforcement point.

### 8.2 Entitlement reality and the minimal adjustment (S8, S8-S9, product R6)

Verified current state: `ENABLE_APP_SANDBOX = YES`, `ENABLE_USER_SELECTED_FILES = readonly`
(`com.apple.security.files.user-selected.read-only`), hardened runtime. Per §0 this **suffices for
folder entry and for reading the entered file, but not for collecting a file's containing folder**
(S1/S2/S4). The design adjusts, minimally and read-only:

- keep `com.apple.security.app-sandbox` + `com.apple.security.files.user-selected.read-only`
  (the honest grant for entered items and folder subtrees — also the only access to folders on
  volumes outside the two keys below);
- add `com.apple.security.temporary-exception.files.home-relative-path.read-only` = `["/"]` —
  read-only access under the user's home, which is where file-entry derivations must enumerate;
- add `com.apple.security.files.removable-media.read-only` — camera dumps and SD cards (product
  outline's "camera dumps"; R1 says *any* file).

No write entitlement anywhere (product R17's read-only-media guarantee), no network entitlements
(D9), no full-disk access. Residual boundaries, stated honestly: the kernel grant is broader than a
single user action (S8 is enforced architecturally — one seam, a fixed read set, unit tests — not
kerned per action); file-entry derivation on **network-mounted shares** is not covered (folder entry
there works via the user-selected grant). If Mac App Store distribution is ever mandated, this
posture must be revisited — temporary exceptions are App-Review-sensitive and the MAS-safe fallback
(standard-folder entitlements + an in-app folder picker) contradicts D11's non-goal, i.e. would need
a spec decision. This is ADR **D19**.

### 8.3 Untrusted input (RNF-04)

Everything crossing the entry boundary is untrusted and validated at the Data edge (D7):

- **URLs from events/drops:** only file URLs accepted; standardized before use; folder derivation is
  done by URL operations, never by string path concatenation (no `..` traversal surface);
  classification reads system resource values, never parses names for media-ness (S11);
- **File names:** used for display only; never logged unredacted; never used in code paths;
- **Folder contents:** treated as hostile: symlinks are not followed and not collected (no
  boundary-escape via links into other trees — the classification exclusions in §5.2 are
  security-relevant as well as product-relevant); packages/bundles and non-regular files are
  excluded (a `.app` or `.photoslibrary` in the folder can never enter the collection);
- **No content execution:** file bytes are never interpreted (no WebKit, no dynamic loading);
  playback (E2-S3) uses playback APIs only. A mislabeled file (§5.2) can only fail to render.

### 8.4 Sandbox/scoped-access review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements minimal & deliberate | Three keys, all read-only, each justified (§8.2); no "just in case" grants |
| User files access pattern | Powerbox grants + per-session scoped start/stop behind the seam (§8.1) |
| Bookmarks | None — S9 makes persistence a non-goal; no `bookmarkData` call exists in this story |
| Untrusted input | Validated at the Data edge (§8.3) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason APIs | No triggering API used (§8) |
| Dependencies | None added |

## 9 · Testing strategy

### 9.1 Fixtures (unit, `InstantPlayerTests`)

A test helper builds throwaway fixture folders under
`FileManager.default.temporaryDirectory/<UUID>/` and removes them in teardown. Determinism
decisions: classification is declared-type-based (§5.2), so fixtures are typed by **extension** with
fixed byte payloads — a 1×1 PNG constant for `.png`, a minimal JPEG constant for `.jpg`, and a
minimal ISO-BMFF `ftyp` stub for `.mp4`/`.mov` (bytes need not be playable; the honest contract in
§5.2 is part of what the tests pin). Cases and their assertions:

| Case (requirements) | Fixture | Expected |
|---|---|---|
| S1/S2 media file entry | `a.jpg`, `b.mov`, `clip.mp4` in folder | entry `clip.mp4` → `folderURL` = parent, `startIndex` = index of `clip.mp4` |
| S3 folder entry | same folder | entry folder → `folderURL` = itself, `startIndex` = 0 |
| S4 unsupported entry | `notes.txt`, `a.jpg` | entry `notes.txt` → parent, `startIndex` = 0, `notes.txt` absent |
| S5 empty / no media | empty folder; folder with only `notes.txt` | `nil` both |
| S10 direct children | media inside a subfolder | subfolder media absent |
| S11 conformance rule | `a.jpg`, `b.mov`, `notes.txt`, misleading `clip.mp4.txt`, folder named `folder.mp4`, fifo named `pipe.mp4`, hidden `._clip.mp4` + `.hidden.mp4` | media present; every non-conforming/junk entry absent "regardless of file name" |
| S12 boundary | as above | excluded entries appear in no item of the collection |
| S13 snapshot | collect, then add/remove files on disk | same collection unchanged; a fresh entry action re-collects (call-counting stub/repository spy verifies one call per action) |
| S14 order | entries created in known order | `items` order equals the scan's enumeration order; no alphabetical sorting |
| Fail-open | broken symlink + one entry whose resource values fail | folder's other media still collected |
| Unreadable folder | nonexistent/derelict path | `nil` (welcome) |

### 9.2 View-model state machine (S5–S7)

`FeedViewModelTests` with an injected repository double: starts `welcome`; media entry →
`folderOpen` with correct `startIndex`; no-media entry while open → `welcome` with no folder (S7);
no-media entry while welcome → stays `welcome` (S5); rapid successive actions → last wins and one
repository call per action.

### 9.3 Entry-derivation matrix

The S1–S4 matrix above is exercised through the seam only (S15: no UI, no running app) —
file/folder/unsupported/empty are four seam calls with four expected results, plus the starting-item
edge case (entered media file excluded, e.g. hidden → `startIndex` = 0).

### 9.4 UI tests and the mandate (R14 of E1-S2)

Converge runs `./scripts/validate.sh --uitests`. Findings on the template: `InstantPlayerUITests`
and `InstantPlayerUITestsLaunchTests` assert **no UI text** (they launch and attach a screenshot),
so the welcome state replacing the placeholder breaks nothing. Task work nonetheless: give the
welcome surface an accessibility identifier and add **one** UI assertion that a plain launch shows
the drop-target welcome state (making the launch tests meaningful), keep `testLaunchPerformance` as
the launch-budget guard (§7.3). Open With and drag & drop remain host-driven flows UI tests cannot
drive — unit tests (§9.1–9.3) plus stakeholder functional review carry them (spec's honest caveat).
Entitlement reality is verified once in tasks: `codesign -d --entitlements` on the built app shows
the four keys (§8.2).

## 10 · ADR plan (continuing from D17)

Three ADRs, cut along independent review axes — routing, access, classification — each mapping to
distinct requirements; recorded in [docs/decisions.md](../../decisions.md) by the implementing
tasks:

- **D18 — Entry convergence: one entry action, one open session, one window.** Open With, Dock drop
  and window drop converge on a single routed `EntryAction` (S1–S4); the scene is `Window` so one
  state machine owns the session (S5–S7); multi-item gestures resolve last-wins. → S1–S7.
- **D19 — Per-entry security-scoped access without bookmark persistence; entitlement posture.**
  Access is granted by the user's action and held per open session behind the seam (S8); nothing —
  and no bookmark store — survives a launch (S9); minimal read-only entitlement adjustment
  (home-relative temporary exception + removable media) because file-entry derivation cannot work
  under `user-selected.read-only` alone (§0, §8.2). → S8, S9, product R6.
- **D20 — Media classification by system UTType conformance with junk exclusions.** Declared-type
  conformance to the system video/image families (S11), enforced at the collection boundary (S12);
  hidden/packages/symlinks/non-regular files excluded; no extension lists (spec-forbidden), no
  content sniffing (perf). → S11, S12.

## 11 · Alternatives considered

- **Hardcoded filename-extension list for media** — rejected: the spec forbids it and it is spoofable
  and stale (S11's "why"). UTType conformance chosen.
- **Content sniffing (AVFoundation/ImageIO probes) at collection** — rejected: per-file probing blows
  the entry budget and D12's cheap-re-scan property; declared-type contract documented instead (§5.2).
- **Recursive scan of subfolders** — foreclosed by D12/product non-goal (S10).
- **Eager folder watching (`DispatchSource`, FSEvents) at open** — rejected: S13 makes this story
  snapshot-only; live sync is E4-S2.
- **Info.plist: generated-only build settings** — impossible: `CFBundleDocumentTypes` has no
  `INFOPLIST_KEY_*` spelling. **Full plist with `GENERATE_INFOPLIST_FILE = NO`** — rejected: loses
  generated values (`INFOPLIST_KEY_*`, version keys) for one custom section. Partial-plist merge
  chosen (§1.2).
- **Drop API: `.dropDestination(for: URL.self)`** — rejected: no `isTargeted` hover state, which the
  drop-target welcome needs (US3). **AppKit `NSDraggingDestination`** — rejected: SwiftUI-first (D1)
  and more code. `.onDrop(of:isTargeted:)` chosen.
- **Entry routing inside the Feed feature (view/view model as drop target)** — rejected: entry
  events are scene/launch-services concerns; App owns them (D10 composition root) and the feature
  stays free of scene wiring. **NSApplicationDelegateAdaptor as the primary route** — reserved as
  fallback only (§3.1).
- **`WindowGroup` + app-scoped shared state** — rejected: opens a window per document and mirrors
  one state across them (§3.4). `Window` scene chosen.
- **Include hidden files in the collection** — rejected: `.DS_Store`/AppleDouble junk enters the
  feed (US4, S12). **Resolve symlinks and include their targets** — rejected: untrusted boundary
  escape + non-determinism (§5.2, §8.3).
- **Sort the collection (name/date) in this story** — rejected: S14 is ordering-neutral; E4-S1 owns
  orderings.
- **Stop scoped access at the end of `prepareCollection`** — rejected: playback (E2-S3) reads the
  same files later; the session must outlive the call (§8.1).
- **Entitlement options** — `user-selected.read-only` alone (rejected: S1/S2/S4 impossible, §0);
  absolute-path temporary exception `["/"]` (rejected: broader than home + removable media);
  standard-folder entitlements only (rejected: holes — arbitrary folders, e.g. `~/Work/dumps`;
  TCC prompts undercut "zero setup"); sandbox off (rejected: R6/RNF-04). Chosen posture in §8.2.
- **Stateless struct + locks for the repository** — rejected: this story introduces mutable session
  state shared across isolation domains, which is D8's actor trigger; the actor is documented as
  such (§12).
- **Bookmarks for later re-open (recents)** — foreclosed: S9/product non-goal.

## 12 · Consequences & required follow-ups (same story, task-phase)

- `docs/architecture.md` updates are required in this story (its §1 rule: structure changes update
  the reference in the same story): §3 source tree gains the files of §1; §4 check (3) gets the URL
  wording refinement of §1.1; §8 records this story as the D8 actor trigger (session state) and the
  composition root walkthrough step 6 becomes "host in `RootView` (which owns entry modifiers)".
- E2-S2 inherits: `FeedState.folderOpen(MediaCollection)` with `startIndex` (its feed starts there),
  the interim placeholder to replace, the `Window` scene, and the snapshot-staleness contract of §6.
- E2-S3 inherits the open session's scoped access (§8.1) — it must not re-derive or re-scan.
- Distribution-channel assumption recorded: the §8.2 posture targets direct/notarized distribution
  (hardened runtime is already on); MAS would revisit D19 (§8.2).
