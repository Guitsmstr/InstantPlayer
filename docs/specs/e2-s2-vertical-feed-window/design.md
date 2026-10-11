# E2-S2 · Vertical feed & window — Design

How the app shows an open folder's media as one vertical feed — current item filling the viewport,
magnetic scroll/arrow paging, single-window behavior complete — with static posters standing in for
playback until E2-S3. Story spec: [spec.md](spec.md) (S1–S16 over product R7–R10, R37–R40).
Structure follows [docs/architecture.md](../../architecture.md) (D7–D10); window policy follows D18;
access and classification contracts follow D19–D20 ([docs/decisions.md](../../decisions.md)).
Pillars: RNF-02 and RNF-04 — mandatory sections below (§7, §8); the design was written against the
`swift-performance` and `swift-security` skills (`.opencode/skills/swift-performance`,
`.opencode/skills/swift-security`), and every implementer and the validator load them before touching
this code (D5).

Scope reminder: this story ends at "the feed shows the media and pages it; the window behaves".
Nothing plays — posters are static (S3). Playback/auto-play/loop/audio are E2-S3; scrub/speed/volume
are E3; ordering is E4-S1; live sync is E4-S2; the list is E5-S1; chrome is none (S14); zoom is none.
No `[NEEDS CLARIFICATION]` markers exist in this design — every decision below is made and traceable
to S-/product-R numbers.

## 0 · Platform and toolchain facts this design is built on

1. **The deployment target is macOS 26** (`MACOSX_DEPLOYMENT_TARGET = 26.0`, verified in the
   project): the full modern SwiftUI paging stack is available and first-party —
   `ScrollView` + `.scrollTargetLayout()` + `.scrollTargetBehavior(.paging)` + `scrollPosition(id:)`
   (magnetic paging and a programmatic position), `.containerRelativeFrame` (viewport-sized pages),
   `onScrollPhaseChange` (gesture onset/settle detection), and `onKeyPress` (arrow keys). No AppKit
   scroll machinery is needed; SwiftUI-first (D1) holds without compromise.
2. **A SwiftUI `Window` scene does not quit the app when its window closes** — the app stays running
   with no windows and no reopen path. S8 (close = quit) therefore needs an explicit, minimal
   lifecycle policy (§6). The canonical hook is `NSApplication.applicationShouldTerminateAfterLastWindowClosed`.
3. **First-frame extraction is a solved platform problem:** `AVAssetImageGenerator` (with the modern
   async API, cancellation-aware) yields the first frame of a video; `CGImageSource` thumbnails
   downsample stills to display size. Both are media *operations* and belong only in a Data
   conformance (architecture §4).
4. **`NSCache` bounds memory but requires object values** — the preview cache wraps its entries
   accordingly (§5.4); the cache itself is conformance-internal.

## 1 · Architecture mapping & component inventory

All new code lands per the D7 walkthrough: Presentation → Domain ← Data, framework types behind
seams, composition wired only in `App/`. Files (names + responsibilities; member names are
contract-level):

| File | Layer | Responsibility | Requirements |
|---|---|---|---|
| `InstantPlayer/Features/Feed/Domain/MediaPreviewService.swift` (new) | Feed Domain seam | The preview seam: one item's display-ready preview or `nil`; cache discard; wiring probe (§3) | S3, S12, S13 (D7, R11) |
| `InstantPlayer/Features/Feed/Domain/MediaPreview.swift` (new) | Feed Domain | The seam's output value: display-ready image bytes + intrinsic pixel size. Foundation-only | S2, S3 |
| `InstantPlayer/Features/Feed/Data/AVMediaPreviewService.swift` (new) | Feed Data | Real conformance, an `actor`: first-frame extraction (AVAssetImageGenerator), image downsample (ImageIO), bounded cache, request coalescing + cancellation, fail-`nil` contract | S3, S12, S13 |
| `InstantPlayer/Features/Feed/Data/StubMediaPreviewService.swift` (new) | Feed Data | Stub conformance for wiring tests (house pattern) | — |
| `InstantPlayer/Features/Feed/Presentation/FeedViewModel.swift` (exists) | Feed Presentation | `@MainActor @Observable` owner of the paging state: current index, per-item display states, prefetch window, gesture guard, replace-in-place reset | S1, S4–S6, S9, S12, S13 |
| `InstantPlayer/Features/Feed/Presentation/FeedView.swift` (exists) | Feed Presentation | Dumb binder: welcome (S16) vs. the paging feed; the interim placeholder is replaced outright (S1) | S1, S4–S6, S14 |
| `InstantPlayer/Features/Feed/Presentation/FeedItemView.swift` (new) | Feed Presentation | One feed page: aspect-fit poster (S2, S3) or the neutral unavailable state (S12, S13); chrome-free (S14) | S2, S3, S12–S14 |
| `InstantPlayer/Features/Feed/Presentation/FeedState.swift` (exists) | Feed Presentation | Unchanged — `welcome` ↔ `folderOpen(MediaCollection)` | S16 |
| `InstantPlayer/App/AppDelegate.swift` (new) | App | Close-quits policy: `applicationShouldTerminateAfterLastWindowClosed` → `true` (§6.1) | S8 |
| `InstantPlayer/App/InstantPlayerApp.swift` (exists) | App | Registers the delegate adaptor; the `Window` scene is unchanged (D18) | S7, S8 |
| `InstantPlayer/App/AppDependencies.swift` (exists) | App | Binds `AVMediaPreviewService`; passes the preview seam into the view model factory; init stays allocation-only | R13 of E1-S3 |
| `InstantPlayer/App/RootView.swift` (exists) | App | Unchanged — entry routing (E2-S1) already replaces the collection in place (S9's host) | S9 |
| `InstantPlayer/Features/Feed/Domain/MediaPlayerService.swift` (exists) | Feed Domain seam | **Untouched** — E2-S3's playback seam; the poster is deliberately not a player concern (§4.1) | — |

### 1.1 Placement justifications (architecture reviewer checks)

- **A new seam, not an extension of `MediaPlayerService` (§3):** `MediaPlayerService` is the
  *playback* seam E2-S3 replaces with an AVPlayer-backed wrapper. Static preview extraction has a
  different lifecycle (per-item, cacheable, alive even after E2-S3 — neighbors still show posters
  while the current item plays) and a different failure contract (S13). Mixing them would force E2-S3
  to inherit or re-implement poster logic to get a player. The seam-placement rule (architecture §4)
  keeps it in Feed/Domain: one v1 consumer (Feed Presentation). Rejected alternatives in §10.
- **`MediaPreview` is `Data`-valued — domain purity without loopholes (architecture §4 check 3):**
  Domain imports Foundation only (R10), so the seam cannot return `NSImage`/`CGImage`. The seam
  returns **display-ready image bytes (`Data`) plus intrinsic pixel size** — values, exactly like the
  `URL` precedent of E2-S1's refinement. This story extends that wording again (§12): *operations*
  (decode, extract, downsample) live only in Data conformances; `URL` and display-ready `Data` may
  travel as opaque values; Presentation wraps display bytes into a platform image for rendering — a
  wrap, not processing. The bytes are already downsampled (§5), so the wrap is cheap.
- **Paging state in `FeedViewModel` (D8):** the current index, per-item display states, and the
  gesture guard are presentation state; the view model is the only holder and the only place the
  spec's paging semantics live — which is what makes S4–S6 unit-testable without scroll hardware
  (spec AC). The views are dumb binders; the `scrollPosition(id:)` binding is a projection of view
  model state (`Binding(get:set:)` calling view model methods), not view state.
- **No `Core/` promotions:** `MediaPreview` has one consumer (Feed) — per the Core placement rule it
  stays in its feature's Domain. `MediaItem`/`MediaCollection` remain the seam input (already Core).
- **Project config: explicitly nothing.** No entitlements, no Info.plist keys, no build settings —
  the poster pipeline needs no new grant (§8) and new source files join the target through
  synchronized groups automatically (D21). **No pbxproj change is required in this story** (stated
  for the D21 audit).

## 2 · Feed presentation (S1–S3, S14)

- **S1 — one vertical feed:** `FeedView`'s `folderOpen` branch renders a single vertical paging
  surface over `collection.items`, in array order (the snapshot order — no sorting, ever; E4-S1 owns
  ordering). Videos and images share the one sequence; `MediaItemKind` makes no difference to the
  layout in this story (both render as a static aspect-fit preview).
- **S2 — letterboxed fill:** every page is a viewport-sized cell whose content is the item's preview
  rendered **aspect-fit** and centered; the letterbox is the window background. The intrinsic pixel
  size in `MediaPreview` (§3) is the only geometry input.
- **S3 — video poster:** a video item's preview is its first frame as static display bytes (§5). No
  motion, no transport, no audio — the poster is honestly the whole visible contract of video until
  E2-S3.
- **S14 — clean viewport:** no file-name overlay, no position counter, no scrollbar
  (`.scrollIndicators(.hidden)`); the cell contains only the item or the unavailable state (§7).

## 3 · Seam contract (`Features/Feed/Domain/MediaPreviewService`)

Members (async/await only — no completion handlers, architecture §5):

- `preview(for item: MediaItem) async -> MediaPreview?` — returns the item's display-ready preview
  or **`nil`**, which is the single unified failure answer: vanished/unreadable file (S12) and
  undecodable/mislabeled content (S13, D20's honest declared-type contract) both surface as `nil`.
  Contract: idempotent per item; concurrent calls for one item coalesce into a single extraction;
  the call is cancellation-aware (a cancelled task never completes its extraction); results are
  display-sized (§5), never full-resolution.
- `discardPreviews() async` — drops all cached previews and in-flight work. Called on
  replace-in-place (S9) and on returning to welcome (E2-S1 S7), so derived data has exactly the
  open session's lifetime (§8).
- `wiringProbe() async -> String` — unchanged house pattern; proves binding in wiring tests.

Value shape (`MediaPreview`, Feed Domain, Foundation-only):

- `imageData: Data` — display-ready encoded image bytes (ImageIO-produced PNG/JPEG at display size).
- `pixelWidth` / `pixelHeight: Int` — the preview's intrinsic size, aspect-preserving; the sole
  input to aspect-fit letterboxing (S2).

There are deliberately **no** cache-control or lifecycle members beyond `discardPreviews()`: the
cache's sizing and eviction are conformance-internal (§5.4), and callers cannot misuse the session
or the cache.

## 4 · Poster & image pipeline (S3, S12, S13)

### 4.1 Why a preview seam at all (and why not a player)

E2-S3 will put a live player under the **current** item; the **neighbors** (and every item before
playback exists) still need static representations. That split — live player for the current item,
static preview for the rest — is exactly the seam boundary: `MediaPreviewService` keeps serving
previews after E2-S3, while `MediaPlayerService` grows its real members and nothing else changes.
The current item's cell representation is a display state (§6) that E2-S3 extends with a `.player`
case — the poster is the case it replaces, cleanly.

### 4.2 Extraction (`AVMediaPreviewService`, Feed Data — the D8 actor)

- **Video (`.video`):** `AVAssetImageGenerator` — `appliesPreferredTrackTransform = true`, frame
  requested at `CMTime.zero` with zero tolerance (the first frame, honestly; frame 0 is the first
  keyframe of typical MP4/MOV so extraction is one decode step). The modern async API (macOS 15+)
  is used natively — the house async/await rule needs no callback bridge — and is
  cancellation-aware. Exact-frame failure → `nil` (S13): no silent fallback to a nearby frame, no
  generic icon.
- **Image (`.image`):** `CGImageSourceCreateThumbnailAtIndex` with
  `kCGImageSourceCreateThumbnailFromImageAlways` and a max-pixel-size bound of **2× the viewport's
  larger axis** (points × screen scale) — ImageIO downsamples during decode (skill §4: never decode
  full-resolution media for display). The produced aspect ratio is the source's (S2).
- Both paths end in one ImageIO encode to display bytes + intrinsic size → `MediaPreview`.
- **Untrusted bytes (RNF-04):** decoding is the only thing that ever touches file content; corrupt
  or mislabeled files (D20: `fake.mp4` holding text) can only fail to decode → `nil` → S13's
  unavailable state. Nothing executes file content (no WebKit, no dynamic loading).
- **Off-main always:** extraction, decode, downsample and encode run on the actor's executor; the
  `@MainActor` view model receives only the finished `MediaPreview` (the E2-S1 D8 actor pattern,
  architecture §8). The preview service does **no** security-scoped start/stop — it reads items of
  the currently open collection inside the session D19 already holds (§8).

### 4.3 Failures are display-time only (S12, S13)

No pre-check, no re-scan, no retry: `nil` is recorded as the item's sticky display state for the
session (§7). A vanished file (snapshot drift, E2-S1 design §6) and an undecodable one are the same
honest outcome — the feed stays navigable either way. Live removal semantics (product R24/R26) are
E4-S2; playback-side failure handling of the same D20 contract is E2-S3. Neither is claimed here.

## 5 · Paging mechanism, caching & layout (S2, S4–S6, S9–S11)

### 5.1 The paging surface (S1, S2, S4)

One `ScrollView(.vertical)` with a `LazyVStack` (lazy per skill §2 — a 1,000-item folder instantiates
only near-viewport cells) inside `.scrollTargetLayout()`. Each page uses
`.containerRelativeFrame([.horizontal, .vertical])` — **the page is exactly the viewport**, which is
also the whole resize/fullscreen story (§5.3). `.scrollTargetBehavior(.paging)` gives the magnetic
snap: the resting state is always one full item (S4). `scrollPosition(id:)` binds two-way to the
view model's current item (§1.1).

### 5.2 One gesture = one item (S4) — the guard

The spec's contract is exact ("any scroll gesture moves exactly one item in its direction; no
momentum multi-page"), and undocumented flick/momentum behavior is not a contract. The view model
therefore enforces it with pure, unit-testable logic over scroll-phase signals from the view edge
(`onScrollPhaseChange`, macOS 15+ — available per §0):

1. **Gesture onset** (scroll leaves rest): record the settled index as `gestureStart`.
2. **Settle** (scroll returns to rest): compute the gesture's net direction from the index delta
   (forward = toward later items in `collection.items`). If the direction is nonzero, the final
   index **must be exactly `gestureStart ± 1`**, clamped at the ends (S6); any other landing
   (multi-page momentum, snap-back to start) is corrected by setting the current item — the
   two-way binding animates the scroll to that full page (magnetic snap preserved). A zero-net
   gesture (rubber-band at an end) does not page (S6).
3. A new touch during deceleration starts a new gesture from the then-visible index.

If functional review shows the platform's paging never multi-pages on macOS trackpads, the guard is
a proven no-op safety net — the spec's guarantee still rests on our logic, not on hope.

### 5.3 Arrows, resize, fullscreen (S5, S6, S10, S11)

- **Arrows (S5):** `.onKeyPress(.downArrow/.upArrow)` on the feed calls
  `viewModel.pageForward()/pageBackward()` — one item per press, clamped at both ends with no wrap
  (S6); the binding animates the page. The same clamp guards gesture paging (S6 covers both
  mechanisms).
- **Resize (S10) and native fullscreen (S11, green button / ⌃⌘F):** no special-case code at all —
  pages derive their size from the container (`containerRelativeFrame`), so when the window or the
  screen changes geometry the current page re-fills and the poster re-fits (S2) automatically.
  Letterboxing tracks the new aspect ratio. Native fullscreen is the system's mode; we add nothing.

### 5.4 Preview cache (RNF-02, S9)

The cache lives inside `AVMediaPreviewService` (Data owns byte caches; the `@MainActor` view model
holds only per-item display states):

- **`NSCache`**, keyed by the item's resolved URL; entries are `MediaPreview` boxes (class wrapper —
  `NSCache` requires objects). **Cost limit 64 MB** (cost = `imageData` byte count), **count limit
  32** — automatic eviction under pressure (skill §4: caches need an eviction policy). With the
  §5.5 prefetch window this holds roughly a screen-and-a-half of previews.
- **Request coalescing + concurrency gate:** at most **2 concurrent extractions**; N concurrent
  `preview(for:)` calls for one item produce one extraction and one shared result; tasks that get
  cancelled (superseded prefetch) are dropped, not completed.
- **Replace-in-place (S9):** `discardPreviews()` — cache and in-flight work for the superseded
  collection are discarded exactly when the collection is (plus a generation counter in the view
  model, the E2-S1 last-wins pattern, so a late result for the old collection can never paint).

### 5.5 Prefetch window (RNF-02)

Load order: **current item first, then its two immediate neighbors** (current ± 1). S4 makes
anything farther unreachable in one gesture, so nothing beyond the window is ever extracted
eagerly — paging through a 1,000-item folder touches at most three items per settle. As the current
index moves, the window slides: new edge items load, dropped-edge items lose their in-flight work
(cache entries linger only until pressure or discard).

### 5.6 Window frame (minor, S7)

System defaults: the `Window` scene's frame persistence (autosave) and no custom minimum size.
Aspect-fit letterboxing works at any size, so there is nothing to enforce. Rejected minimalism
alternatives in §10; revisit only if functional review shows a pathological case.

## 6 · Window lifecycle (S7–S9)

### 6.1 Close = quit (S8)

The one `Window` scene (D18) already gives S7 its single resizable window. For S8: an `AppDelegate`
registered via `NSApplicationDelegateAdaptor` (App-owned — scene/lifecycle policy is the composition
root's business, D10) implementing **`applicationShouldTerminateAfterLastWindowClosed → true`** —
the canonical AppKit policy hook, three lines, no window hunting. With exactly one window (D18) this
is precisely S8's contract, and the absent reopen path (in-app picker is a v1 non-goal) makes quit
the honest behavior. This does not touch D18's `NSApplicationDelegateAdaptor` reservation for
*entry routing* (a different concern, still not built).

### 6.2 Replace-in-place (S9)

E2-S1's entry flow already swaps `.folderOpen` state in the same window. This story adds the two
reset obligations, both in the view model: on every state change to `folderOpen`, the current item
is set to `collection.startIndex` (the inherited contract — file entry lands on the file, folder
entry on the first item), and the preview seam is discarded + pending loads dropped (§5.4). The
previous collection's position and display states are gone. The welcome transition (E2-S1 S7)
discards the same display state (S16: no feed, no paging in welcome).

## 7 · Unavailable state (S12, S13)

- **Detection:** display-time only (§4.3) — `preview(for:)` → `nil`. No pre-check, no folder
  re-scan (E4-S2's business), no auto-retry and no retry affordance (the spec's "no implied retry
  semantics": the state is sticky for the session; a fresh entry action is the way out).
- **Presentation:** a neutral placeholder — one system symbol and one neutral English word
  ("Unavailable", D6). **No file name** (S14), no error codes, no path. The page keeps the same
  viewport-sized aspect-fit cell, so paging, resize, and fullscreen behave identically (S2, S10,
  S11) and the feed stays navigable in both directions (S12).
- **State model:** the view model holds per-item display states
  (`.loading` / `.preview(MediaPreview)` / `.unavailable`) keyed by item id — presentation state in
  the one holder (D8); the cell is a pure function of one state.

## 8 · Performance (RNF-02) — mandatory

Loaded skill: `swift-performance`. The performance-relevant surfaces are feed rendering, paging, and
the poster pipeline (images + SwiftUI views — exactly what the skill gates). Per-story budgets
(following E2-S1's measured-evidence precedent):

1. **Display budget (the "instant" contract for this story):** from a page **settle** to the current
   item **fully displayed** (correctly letterboxed poster on screen): **≤ 300 ms p95** for typical
   media (≤ 1080p clips, ≤ 24 MP stills) on Apple-silicon reference hardware; **≤ 1 s p95** for
   atypical heavy media (4K+ video, very large stills). Cached previews redisplay within one frame
   (< 16 ms). Measurement: a unit performance test through the seam (XCTest `measure` block) over
   generated fixtures — a tiny real MP4 written by `AVAssetWriter` in fixture setup plus small
   PNG/JPEG constants — recorded as story evidence from tooling. Unknown-media slowness degrades to
   `.loading`, never to a stall (S15).
2. **No main-thread I/O or processing, ever (skill §1):** extraction, decode, downsample, encode all
   run on the `AVMediaPreviewService` actor's executor (§4.2); `body` stays cheap — the cell renders
   precomputed display state, no decoding in `body` (skill §2); the wrap `Data` → platform image
   happens once per state change, not per frame.
3. **Paging responsiveness (S15, product R16):** page transitions, resize, and fullscreen must not
   stall the UI — the only synchronous work per settle is view-tree layout and one image wrap. The
   gesture guard (§5.2) is pure arithmetic on the main actor, O(1). No dropped-frame regression
   target: the `testLaunchPerformance`/UI run plus the unit perf test are the deterministic guards;
   an Instruments trace is the escalation if functional review disagrees (skill §6 — measurement,
   not vibes).
4. **Bounded work and memory (skill §4):** prefetch window current ± 1, ≤ 2 concurrent extractions,
   coalesced per item (§5.5); cache capped at 64 MB / 32 entries with automatic eviction (§5.4);
   full-resolution media is never decoded (ImageIO downsample to ≤ 2× viewport per axis); the
   replace-in-place discard (S9) prevents cross-collection accumulation. Snapshot memory stays at
   E2-S1's bound (URLs + names + kind only).
5. **Zero added launch cost (R13 of E1-S3 must survive):** nothing new on the launch path —
   `AppDependencies` gains one binding allocation and `AppDelegate` is three lines of policy; no
   extraction, no media touched at launch (welcome shows no media; previews begin only when a folder
   opens). `testLaunchPerformance` remains the guard.
6. **Measured evidence (skill §6):** the perf claims of (1) and (5) are carried by tooling output
   (gate JSON, XCTest `measure`) recorded in the story's evidence — never "it feels fast".

## 9 · Security (RNF-04) — mandatory

Loaded skill: `swift-security`. This story reads media bytes for display — the security posture of
D19/D20 is inherited, not extended:

- **Reads inside the open session only (D19):** previews are extracted only for items of the
  currently open collection, whose security-scoped session is already active (E2-S1 design §8.1).
  The preview seam performs **no** `start/stopAccessingSecurityScopedResource`, holds no session of
  its own, and adds **no entitlements** — the four read-only keys of D19 stand unchanged. Stated
  explicitly for the D21 audit: **no entitlement, Info.plist, or pbxproj change in this story.**
- **In-memory derived data only:** previews live in the in-process `NSCache` and are discarded with
  the open session (S9) — **nothing is written to disk**: no thumbnail caches in `Caches`/`tmp`/
  `Application Support`, no bookmark data (D19's "no bookmark store" holds), no persisted display
  state.
- **File names display-only (D20):** never parsed, never logged; the unavailable state deliberately
  carries no name (S14).
- **Logging:** none planned. If diagnostics are added, `os.Logger` with `privacy: .private`, never
  paths or names of user media (skill §5).
- **Untrusted media bytes (skill §4):** file content is only ever decoded — never executed, never
  rendered as code (no WebKit, no dynamic loading); corrupt/mislabeled files can only fail to decode
  (S13); decode allocation is bounded by the downsample (§5.4 — a decompression bomb hits the
  display-size bound, not RAM); URLs travel as values, no path-string handling (architecture §4).
- **Dependencies:** none added — AVFoundation/ImageIO are system frameworks (skill §6: no new SPM
  surface).
- **Privacy manifest:** no required-reason API is added (no `UserDefaults`, no file-timestamp APIs;
  `NSCache` and reading the user-selected files are not on the list) — **no `PrivacyInfo.xcprivacy`
  change**, consistent with E2-S1 §8.

### 9.1 Sandbox/media-read review table (validator hook)

| Concern | Design answer |
|---|---|
| Entitlements | Unchanged — D19's four read-only keys; no new grant (§9) |
| User files access pattern | Reads only inside the already-open scoped session; the seam does no start/stop (D19) |
| Derived data at rest | None — in-memory cache only, discarded at session end (S9) |
| Bookmarks | None — no `bookmarkData` call exists anywhere (D19) |
| Untrusted input | Media bytes decode-only; mislabeled/corrupt → `nil` → unavailable (S13); no path strings (§9) |
| File names | Display-only; absent from the unavailable state and from logs (S14, D20) |
| ATS / network | Untouched — no networking in v1 (D9) |
| Privacy manifest / required-reason | No triggering API used (§9) |
| Dependencies | None added |

## 10 · Testing strategy

### 10.1 Paging & display state machine (unit, `InstantPlayerTests` — the spec's AC)

`FeedViewModelTests` with injected `MediaFolderRepository` + `MediaPreviewService` doubles — no UI,
no scroll hardware, no running app (the E2-S1 S15 precedent, generalized):

| Case (requirements) | Expected |
|---|---|
| Folder opens | current item = `collection.startIndex` (S1, S9's inherited contract) |
| `pageForward` / `pageBackward` | index ± 1 (S5); state change observable |
| Clamping | at first/last item, further pages are no-ops — no wrap, both mechanisms (S6) |
| Gesture guard | multi-page landing → corrected to `gestureStart ± 1` in the net direction; snap-back → `gestureStart + direction`; zero-net at an end → no page (S4) — pure-logic tests |
| Replace-in-place | new collection at its `startIndex`; `discardPreviews()` invoked; a late result for the old collection never paints (S9, generation counter) |
| Preview success | item display state → `.preview` (S3) |
| Preview `nil` | item display state → `.unavailable`, sticky, no auto-retry (S12, S13) |
| Prefetch window | loads requested for current ± 1 only; the current item first; dropped-edge requests cancelled (spy counts calls + cancellations) (RNF-02) |
| Welcome | no paging/display state presented; unchanged behavior (S16) |

### 10.2 Preview seam (unit, Feed Data)

Fixtures (test helper, throwaway temp folders per E2-S1 §9.1's pattern): a tiny **real** decodable
MP4 written by `AVAssetWriter` in setup (one frame — honest extraction needs real bytes, unlike
E2-S1's `ftyp` stub), small PNG/JPEG constants of known aspect ratio, and junk cases. Cases: video →
first-frame preview; image → downsampled preview with the source's aspect (S2); text bytes named
`fake.mp4` → `nil` (S13 — D20's honest contract, pinned); nonexistent URL → `nil` (S12); output
pixel size bounded by the display bound (downsample proof); concurrent calls for one item → one
extraction (coalescing); cancelled task → no completed extraction; `discardPreviews()` empties the
cache. Perf case: the `measure` block of §8(1).

### 10.3 UI tests and the mandate (R14 of E1-S2)

Converge runs `./scripts/validate.sh --uitests`. The launch tests keep asserting the welcome state
on plain launch (S16 — this story must not break them) and `testLaunchPerformance` keeps guarding
launch cost (§8(5)). No new UI tests are planned for the feed itself: entry flows are host-driven
(Open With / drag & drop cannot be driven by UI tests) and the feed is unreachable without them —
the spec's honest caveat stands: unit tests (§10.1–10.2) plus stakeholder functional review carry
feed presentation.

### 10.4 Functional review (stakeholder — the spec AC list)

`./scripts/app.sh run` covers: a mixed video+image feed with letterboxing (S1, S2); a video shown as
a static first-frame poster (S3); scroll paging with magnetic snap — one item per gesture, always a
full item (S4); arrow-key paging (S5); stopping at the first and last item (S6); resize keeping the
current item filled (S10); native fullscreen in and out (S11); a new open replacing the collection
in place at its starting item (S9); window close quitting the app (S8); and the unavailable state
for a vanished file and for a mislabeled video (`fake.mp4`) — feed navigable throughout (S12, S13).

## 11 · ADR plan (continuing from D21)

Three ADRs, cut along independent review axes — paging, media rendering, window lifecycle — each
mapping to distinct requirements; recorded in [docs/decisions.md](../../decisions.md) by the
implementing tasks:

- **D22 — Feed paging: SwiftUI paging `ScrollView` with a view-model-owned index.** Viewport-sized
  lazy pages + `.scrollTargetBehavior(.paging)` + `scrollPosition(id:)` binding; the one-gesture-
  one-item guarantee rests on a pure view-model guard over scroll-phase signals, not on momentum
  behavior (S4); arrows and gestures share one clamped index (S6); layout is container-derived so
  resize/fullscreen need no code (S10, S11). → S1, S2, S4–S6, S10, S11, S14.
- **D23 — Media previews behind a Feed-owned `MediaPreviewService`; `Data`-valued display bytes.**
  First frame via `AVAssetImageGenerator`, stills via ImageIO downsample — all off-main in a Data
  actor; unified `nil` failure contract feeds the unavailable state (S12, S13); bounded in-memory
  cache discarded with the session; separate from `MediaPlayerService` so E2-S3 swaps the current
  item's representation for a live player and keeps previews for neighbors. → S3, S12, S13.
- **D24 — Close-quits via `applicationShouldTerminateAfterLastWindowClosed`.** The single `Window`
  (D18) plus an App-owned delegate shim: closing the window terminates the app (S8); no reopen path
  exists (picker is a v1 non-goal). → S8.

## 12 · Alternatives considered

- **`TabView` + `.tabViewStyle(.page)`** — rejected: the page style is not a macOS paging surface
  (iOS-oriented), gives up `LazyVStack` loading and the `scrollPosition` contract, and would still
  need the same guard. **Custom drag gesture with manual offset paging** — rejected: fights the
  system (accessibility, scroll expectations), heavy code, contradicts SwiftUI-first (D1).
  **`NSScrollView`/AppKit paging** — rejected: D1.
- **Trust `.scrollTargetBehavior(.paging)` alone for S4's exact contract** — rejected: "one gesture =
  one item, no momentum multi-page" is a spec guarantee that must not rest on undocumented flick
  behavior; the guard is cheap pure logic and unit-testable (§5.2).
- **Extend `MediaPlayerService` with `firstFrame(for:)`** — rejected: couples the poster lifecycle to
  the playback seam E2-S3 will replace wholesale; previews outlive the swap (neighbors) and have a
  different failure contract (S13). **Per-item `AVPlayer` to grab a frame** — rejected: player
  creation is expensive (skill §3) and overkill versus `AVAssetImageGenerator`.
  **`QLThumbnailGenerator` (Finder-style thumbnails)** — rejected: it answers with generic icons for
  uncooperative files, which would silently break S13's honest unavailable contract and S3's
  first-frame contract; its caching is system-controlled (unbounded for our purposes).
- **Full-resolution decode, scaled in the view** — rejected: memory blow-up and main-thread decode
  (skill §4); ImageIO downsample chosen (§5.4). **Preview cache in the view model** — rejected: byte
  caches with eviction policy are Data-layer concerns; the `@MainActor` holder would pay eviction
  cost on main. **Cache in `Core/`** — rejected: single consumer (Core placement rule).
- **Pre-check the file (stat/quick-open) before display** — rejected: extra I/O per item for a
  question display-time failure already answers; the snapshot contract (E2-S1 design §6) makes
  pre-checks stale on arrival. Display-time `nil` → unavailable chosen (§4.3).
- **`RootView.onDisappear { NSApp.terminate(nil) }` for close-quits** — rejected: disappearance
  fires on any root teardown, not just window close — fragile policy for S8. **`NSWindowDelegate`
  `windowWillClose`** — rejected: requires finding/hooking the AppKit window behind the SwiftUI
  scene — more code and a worse D1 compromise than the app-level policy hook. **`exit(0)` on
  close** — rejected: skips the normal termination lifecycle. `applicationShouldTerminateAfterLastWindowClosed`
  chosen (§6.1).
- **Custom window minimum size / fixed default size** — rejected as unneeded: aspect-fit works at
  any size (§5.6); system-default frame persistence accepted. **App-defined "fullscreen" overlay**
  — rejected: S11 mandates *native* macOS fullscreen; the container-derived layout needs no code.
- **Separate strips for videos and images** — foreclosed: S1 mandates one combined feed (product
  R7).
- **Unavailable-state retry button / file-name label** — rejected: the spec's neutral state forbids
  both (S12's note, S14); retry semantics are not v1.

## 13 · Consequences & required follow-ups

- **`docs/architecture.md` updates are required in this story** (its §1 rule) — **not committed with
  this design: writing that file is outside this author's permissions (the update tool was
  permission-denied; reported to the coordinator rather than bypassed).** The exact updates, to be
  applied by an agent with write access in this story's task phase: §3's tree gains
  `MediaPreviewService.swift`, `MediaPreview.swift`, `AVMediaPreviewService.swift`,
  `StubMediaPreviewService.swift`, `FeedItemView.swift`, `App/AppDelegate.swift` and re-annotates
  `FeedViewModel`/`FeedView`; §4 check (3) gains the display-bytes wording of §1.1; §8's actor note
  names `AVMediaPreviewService` as the second D8 actor (preview cache + coalescing state).
- **E2-S3 inherits** the poster pipeline, cache, and cell states: it adds the `.player` display
  state under the current item (`MediaPlayerService` grows real members) and keeps
  `MediaPreviewService` for neighbors; its playback failure handling extends S13's contract (D20).
  It must not re-scan the folder (E2-S1 §6) or re-derive the session (D19).
- **E3** places controls into the chrome-free viewport (S14) — the cell contract anticipates an
  overlay layer but ships none here.
- **E4-S2** supersedes S12's stale-item fail-safe with live removal semantics (product R24/R26); the
  unavailable state remains for genuinely unreadable files.
- **No project-config work** in this story (§1.1): no entitlements, no plist keys, no build
  settings, no pbxproj diff — the D21 audit should find none.
