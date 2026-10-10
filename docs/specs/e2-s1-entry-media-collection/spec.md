# E2-S1 · Entry & media collection — Story Spec

## Story context

- **Why this story, why now.** This is the first feature story on the architecture skeleton ([docs/architecture.md](../../architecture.md), D7–D10): walking-skeleton leg 1. Until now the app is structure and wiring only. After this story the app can **open a folder and know its media** — nothing more. Feed presentation and paging are E2-S2; playback is E2-S3.
- **What "entry & collection" means end to end.** Media enters through Finder "Open With" on a file, or drag & drop of a file or folder onto the app icon or an open window (D11). The app derives the one folder to open, collects that folder's direct-children media per the native-format rule (D12), and prepares the feed data source — positioned at the entered file when there is one. When nothing is open or the target yields no media, the app presents the drop-target welcome state. "Positioned" in this story is a **data-level contract only**: the prepared collection names its starting item; showing it in a feed is E2-S2's business.
- **Product requirements carried.** product R1–R6 (entry, incl. sandbox R6) and product R34–R36 (formats & filtering) from [docs/spec.md](../../spec.md) — referenced below as `product R#`, never renumbered or restated as new normative text. Story-scoped requirements (derivations and refinements) are numbered **S1…S15** in this file only.
- **Pillars.** RNF-04 (security) is directly engaged: files arrive from outside the sandbox through user actions, and every entry path must stay within the granted access (product R6). RNF-02 (performance) is engaged at entry time: the collection runs when a folder is opened — no launch work is added, and the entry-time budget is set in this story's design, which loads the `swift-security` / `swift-performance` skills per the pillar rule (D5).
- **UI-test mandate (R14 of E1-S2) — decision: flows ARE affected.** This is the first story changing launch-visible UI (the placeholder root becomes the welcome state and entry surfaces) and adding entry flows — exactly the launch flow the existing `InstantPlayerUITests` template launch tests exercise. The validator/converge step therefore runs `./scripts/validate.sh --uitests` for this story ([docs/development.md](../../development.md) §3). Caveat recorded honestly: Open With and drag & drop are host-driven flows UI tests cannot drive directly; unit tests (S15) and stakeholder functional review carry those paths.
- **Structure.** The story lands per [docs/architecture.md](../../architecture.md): collection sits behind the published `MediaFolderRepository` seam (D7, D11, D12). Structure specifics are design-phase output, not this spec.

## User stories

- **US1** · As a Mac user reviewing a folder of clips and images, I want to open any file in it with InstantPlayer from Finder ("Open With"), so that viewing starts with zero setup and lands on the file I opened.
- **US2** · As a Mac user, I want to drop a file or a whole folder onto the app (its icon or an open window), so that the folder's media is collected without any dialog or picker.
- **US3** · As a user with the app open but nothing to view, I want a drop-target welcome state, so I always see how to bring media in — and it gives way the moment media arrives.
- **US4** · As a user with a folder of mixed content, I want only the real media (what macOS can play or display, directly in that folder) to be collected, so that clutter, subfolder surprises, and unsupported files never get in the way.
- **US5** · As a developer, I want collection behind the `MediaFolderRepository` seam, so its rules are unit-testable without any UI and its sandbox handling can evolve without changing callers (D7, RNF-04).

## Story requirements (EARS)

Numbering is story-local: **S1…S15** for this story only. Product requirements are cited as `product R#` ([docs/spec.md](../../spec.md)) and are never renumbered here. Requirements that merely anchor product text cite it; requirements that refine or derive add a short derivation note.

### Entry — Open With (product R1)

- **S1:** WHEN the user opens a supported media file with InstantPlayer from Finder ("Open With")
  THE SYSTEM SHALL open that file's containing folder with its media collection prepared and positioned at the opened file (product R1)

*Data contract:* "positioned at the opened file" means the prepared collection identifies that file as its starting item. Rendering the feed at a starting item is E2-S2.

### Entry — drag & drop (product R2, R3)

- **S2:** WHEN the user drops a supported media file onto the app icon or onto an open InstantPlayer window
  THE SYSTEM SHALL open that file's containing folder with its media collection prepared and positioned at the dropped file (product R2)

- **S3:** WHEN the user drops a folder onto the app icon or onto an open InstantPlayer window
  THE SYSTEM SHALL open that folder with its media collection prepared and positioned at the collection's first item (product R3)

*Derivation (S3):* product R3's "first item in the current ordering" is, in this story, the first item of the folder's own order — the only ordering that exists until E4-S1 (product R21's default; see S14).

### Entry — unsupported files (product R4)

- **S4:** WHEN the user opens or drops a file that is not supported media
  THE SYSTEM SHALL derive its containing folder, prepare that folder's media collection, and leave the unsupported file out of it (product R4), positioned at the collection's first item

*Derivation (S4):* the ignored file cannot be a starting item, and an ignored file entry is equivalent to product R3's folder entry — same folder, same starting position.

### Welcome state (product R5)

- **S5:** WHEN the app is launched with no media, or is given a file or folder that contains no supported media
  THE SYSTEM SHALL present a drop-target welcome state and open no folder (product R5)

- **S6:** WHEN the app is presenting the welcome state and an entry action yields a folder containing supported media
  THE SYSTEM SHALL leave the welcome state and open that folder's media collection

*Derivation (S6):* the transition when media arrives — product R5 holds the welcome state only while nothing is open; product R1–R3 govern what opens.

- **S7:** WHEN an entry action yields no supported media while a folder is already open
  THE SYSTEM SHALL present the drop-target welcome state and leave no folder open (product R5, applying equally mid-session)

*Note (S7):* presenting this in the app's single window follows product R38, delivered by E2-S2; this story's obligation is the state itself — welcome, no open folder.

### Sandbox-scoped access (product R6, RNF-04)

- **S8:** WHEN InstantPlayer accesses the media files of a folder entered through Finder or drag & drop — on any entry path
  THE SYSTEM SHALL access them only through the access the user's action grants, within the macOS sandbox (product R6, RNF-04)

- **S9:** WHEN the app is relaunched
  THE SYSTEM SHALL hold no access to previously opened folders until the user enters them again through a fresh user action

*Derivation (S9):* product R6 grants access per user action; persistence of recents or security-scoped bookmarks across launches is a v1 non-goal (see Non-goals), so no access — and no bookmark store — survives a launch. This bounds the security-scoped design explicitly.

### Collection — direct children only (product R34)

- **S10:** WHEN the app collects the opened folder's media
  THE SYSTEM SHALL include only the folder's direct children, never descending into subfolders (product R34)

### Collection — native formats (product R35)

- **S11:** WHEN the app decides which of the folder's files are media
  THE SYSTEM SHALL include only files macOS can play or display natively out of the box (product R35 — e.g. the MP4/MOV family of videos, the JPEG/PNG/HEIC family of still images), decided by **system type conformance** — the file's declared uniform type identifier (UTType) conforming to the system's native video or image type categories — never by a hardcoded filename-extension list, and never by trusting the file name alone (untrusted input, RNF-04)

*Why (S11):* "macOS-native" is a moving, system-defined set; a conformance rule tracks it automatically and cannot be spoofed by renaming a file, while an extension list would do both wrong.

### Collection — non-media invisibility (product R36)

- **S12:** WHEN the opened folder contains files that are not supported media
  THE SYSTEM SHALL exclude them from every view and function of the app (product R36) by enforcing the exclusion at the collection boundary itself — the single input boundary (D12) — so that every view and function consuming the collection inherits it

### Collection — freshness and order (derivations)

- **S13:** WHEN a folder is opened
  THE SYSTEM SHALL collect its media as a snapshot of the folder at that moment and SHALL NOT observe later changes to the folder

*Derivation (S13):* live folder tracking is product R23–R26, delivered by E4-S2 and explicitly out of scope here. Stated so no one assumes watching: after open, the collection is stale until the next entry action.

- **S14:** WHEN the media collection is produced
  THE SYSTEM SHALL return it in the folder's own order and apply no other ordering

*Derivation (S14):* the ordering-neutral contract — product R21's default is the folder's own order; filename and date-added ordering modes (product R22) arrive with E4-S1 and must not shape this story's collection contract.

### Verification contract (US5, D7)

- **S15:** WHEN the media-collection behavior is implemented
  THE SYSTEM SHALL make it exercisable through the architecture's published `MediaFolderRepository` seam, so the entry contracts (S1–S4) and collection rules (S10–S14) are verifiable by unit tests with no UI and no running app (D7)

## Non-goals

Out of scope for this story; each belongs to the story named (product non-goals in [docs/spec.md](../../spec.md) apply unchanged):

- **Feed presentation & navigation** (E2-S2) — the vertical feed, current-item display, scroll/arrow paging (product R7–R10) and window behavior (product R37–R40). This story prepares the data-level collection and its starting item only.
- **Playback** (E2-S3) — auto-play, play/pause, loop-in-place (product R11, R12, R15, R17).
- **Ordering modes** (E4-S1) — filename and date-added ordering (product R22); the collection is ordering-neutral (S14).
- **Live folder watching** (E4-S2) — additions, removals, renames reflected live (product R23–R26); the collection is a per-entry snapshot (S13).
- **List view & file operations** (E5-S1 / E5-S2) — product R27–R33.
- **Persistence of recents or bookmarks across launches** — not in v1 scope. It directly shapes this story's security-scoped design: access is per-entry-action and per-session only, with no bookmark store (S9).
- **In-app folder picker** — v1 non-goal; entry is Finder "Open With" and drag & drop only (D11).
- **Network** — excluded from v1 entirely (D9); this story touches local files only.

## Acceptance criteria

Product-requirement coverage map — each product requirement assigned to this story (the nine of [docs/backlog.md](../../backlog.md): R1–R6, R34–R36) maps to a verifiable story outcome:

| Product requirement | Story outcome | Verified by |
|---|---|---|
| R1 (Open With) | S1 — containing folder collected, positioned at the opened file | unit tests on the seam (S15) + stakeholder functional review |
| R2 (drop file) | S2 — containing folder collected, positioned at the dropped file | unit tests (S15) + functional review |
| R3 (drop folder) | S3 — that folder collected, positioned at its first item (folder's own order) | unit tests (S15) + functional review |
| R4 (unsupported file) | S4 — folder derived and collected, the file itself ignored | unit tests (S15) + functional review |
| R5 (welcome state) | S5–S7 — welcome when nothing open or no media; both transitions correct | functional review (welcome at launch, both transitions) + unit tests for the empty collection |
| R6 (sandbox) | S8–S9 — access only what the user action grants, on every entry path; nothing survives relaunch | validator security review (`swift-security` checklist, RNF-04) + functional review that entries work inside the sandbox |
| R34 (direct children) | S10 — subfolder content never appears | unit tests (S15) |
| R35 (native formats) | S11 — type-conformance rule: conforming video/image accepted, non-conforming rejected regardless of file name | unit tests (S15) |
| R36 (non-media invisible) | S12 — non-media never enters the collection, hence no view or function | unit tests (S15) + functional review |

- [ ] Every product requirement assigned to this story maps to at least one story requirement; no other product requirement is claimed here.
- [ ] The entry contracts (S1–S4) and collection rules (S10–S14) are covered by unit tests through the `MediaFolderRepository` seam, with no UI and no running app (S15).
- [ ] Snapshot semantics are explicit in tests and review: no folder watching exists after open (S13).
- [ ] Gate evidence is recorded from tooling per conventions: `./scripts/validate.sh --json <tmp>/gate.json`, quoted verbatim in the story's evidence; the converge run includes `--uitests` (UI-test mandate, R14 of E1-S2 — decision in Story context).
- [ ] Stakeholder functional review in the running app (`./scripts/app.sh run`) covers: Open With on a file, drop of a file, drop of a folder, an unsupported file, and both welcome-state transitions (this is a UI story — functional review is part of the done gate).
- [ ] This spec passes the stakeholder approval gate.

## References

- [docs/spec.md](../../spec.md) — product source of truth (product R1–R6, R34–R36; RNF-02 / RNF-04)
- [docs/decisions.md](../../decisions.md) — D7 (layering & seams), D9 (no networking), D10 (composition root), D11 (entry points), D12 (media collection), D17 (gate `--uitests`)
- [docs/architecture.md](../../architecture.md) — `MediaFolderRepository` seam, security-scoped seam guidance
- [docs/development.md](../../development.md) — gate usage and the UI-test mandate (§3)
- [docs/backlog.md](../../backlog.md) — story entry (E2-S1) and the E2–E5 coverage note
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
