# E1-S1 · Product spec authoring — story design

- **Story:** E1-S1 · Product spec authoring — E1 (Product foundation), `in progress` ([docs/backlog.md](../../backlog.md))
- **Branch:** `feat/e1-s1-product-spec`
- **Phase:** Plan — the HOW for this story's deliverables. E1-S1 is a docs-authoring story: it ships no software, so this design specifies the **structure and production strategy of the documentation deliverables**, not app architecture, data model, or runtime. Sequencing the deliverables into one-commit tasks is the next artifact (tasks.md).
- **Deliverables:** (1) the rewritten [docs/spec.md](../../spec.md) — product source of truth; (2) ADR batch **D7–D12** appended to [docs/decisions.md](../../decisions.md); (3) feature-epic skeleton **E2–E5** appended to [docs/backlog.md](../../backlog.md).
- **Inputs:** the approved [story spec](spec.md) (R1–R40, nine capability groups, non-goals, acceptance criteria); the current [docs/spec.md](../../spec.md) bootstrap skeleton (RNF-02/RNF-04 wording preserved verbatim); D1–D6 in [docs/decisions.md](../../decisions.md); [docs/specs/README.md](../README.md) design conventions.

## Design overview

One approved artifact fans out into three deliverables, each with a fixed target structure. Each fact lives in exactly one place and is cross-referenced:

```
approved story spec (docs/specs/e1-s1-product-spec/spec.md — untouched; becomes the derivation record)
      │
      ├─(1) promote ─→ docs/spec.md       compact product source of truth        (§1)
      ├─(2) decide ─→ docs/decisions.md   twelve interview decisions → six ADRs  (§2)
      └─(3) break out → docs/backlog.md   nine capability groups → four epics    (§3)
```

- **docs/spec.md** carries the normative content (requirements, non-goals, pillars) and summarizes narrative.
- **docs/decisions.md** carries the decision-shaped subset, with alternatives and consequences.
- **docs/backlog.md** carries the work breakdown: every capability group maps onto story-sized work.
- The **story spec** remains the permanent derivation record (persona, user stories 1–6, interview provenance) and is linked from docs/spec.md.

## 1. Deliverable 1 — rewritten docs/spec.md

### 1.1 Target section layout

```
# InstantPlayer — Product Spec (source of truth)

<tagline> — one line, rewritten (§1.2)

> Product source of truth; overridden only by ADRs in docs/decisions.md.

## Product outline
  - Target user and main job-to-be-done
  - Sources of media            (label widened from "Sources of video" — R7 includes images)
  - Minimum playback experience
  - Scope boundaries

## Functional requirements
  (one-line provenance + link to the derivation record)
  ### Entry (opening media)       R1–R6
  ### Feed navigation             R7–R10
  ### Playback                    R11–R17
  ### Volume                      R18–R20
  ### Ordering                    R21–R22
  ### Live sync                   R23–R26
  ### List view & operations      R27–R33 (+ clarifying note)
  ### Formats & filtering         R34–R36
  ### Window                      R37–R40

## Non-functional requirements
  - RNF-02 (performance — pillar)   verbatim
  - RNF-04 (security — pillar)      verbatim
  - one-line note: RNF-01/RNF-03 intentionally unassigned in v1 (§1.4)

## Non-goals
  (eight items + preamble, verbatim from the story spec)
```

### 1.2 Promotion rules — verbatim vs. summarized

| Story-spec element | Disposition in docs/spec.md |
|---|---|
| EARS requirements R1–R40, group headings, group order | **Verbatim**, numbers unchanged (§1.3) |
| Clarifying note under list operations ("Zip, move, and trash relocate or package files…") | **Verbatim** — it disambiguates R30–R33 |
| Non-goals list (eight items + preamble) | **Verbatim** |
| RNF-02 / RNF-04 pillars | **Originals stay verbatim** in docs/spec.md — the story spec's copies are quotes of them |
| Persona paragraph | **Summarized** into the target-user bullet (≤3 sentences: who, the folders they review, the two "instant" meanings) |
| User stories 1–6 | **Not promoted** — fully subsumed by R1–R40; remain in the story spec as derivation record |
| Story context, acceptance criteria, interview provenance | **Not promoted** — story-artifact material |
| Tagline | **Rewritten** — the current line ("pick a video, it plays") describes a single-file player; the approved product is a folder feed. Proposed copy, final polish at implementation: "An instant viewer for a folder of videos and images on macOS — open it from Finder, flip through a vertical feed, act on what you just watched. Zero setup, no waiting." |

Outline bullet content (each compact, pointing at R-numbers for detail):

- **Target user and main job-to-be-done** — the persona (a Mac user reviewing downloaded clips, screen recordings, camera dumps, saved photos) and why "instant" matters twice: zero steps from folder to viewing, and no perceptible wait before a clip plays.
- **Sources of media** — local folders only, entered via Finder "Open With" or drag & drop of a file or folder; no network streams, no camera imports, no in-app folder picker (→ Non-goals).
- **Minimum playback experience** — native-format videos and images in one feed; auto-play on arrival; play/pause, scrub, speed; app-level volume and mute, persisted; loop at end, never auto-advance; keyboard-first navigation; a list view with zip/move/reveal/trash.
- **Scope boundaries** — one opened folder at a time, read-only media handling, ephemeral grouping; the eight non-goals referenced, not restated.

Two standing rules:

- **No invention:** anything the approved spec does not mention is not added. The skeleton placeholder's side questions (subtitles, picture-in-picture, background audio) are resolved by the exhaustive-requirements principle — v1 is exactly what R1–R40 requires; none of the three is required, so none is in scope, and no new non-goal entries are created for them.
- **No duplication:** the outline summarizes and points at R-numbers; it never restates requirement text.

### 1.3 Requirement numbering — standing rules

- R1–R40 are promoted with numbers, order, and grouping unchanged; ADRs D7–D12, the epic skeleton, and all future stories reference these numbers.
- Future requirements **append** from R41; existing numbers are never renumbered or reused. A requirement changed by a later decision is edited in place, with that ADR referenced from its section.
- RNF numbering stays reserved as-is: RNF-02 performance, RNF-04 security (D5).

### 1.4 Non-functional requirements — the RNF set

- RNF-02 and RNF-04 are carried **byte-identical** into the rewritten file (story acceptance criterion; the implementing task verifies by diffing the two bullets against the current file).
- **RNF-01 (usability) and RNF-03 (compatibility) are explicitly skipped for v1.** Justification:
  1. The stakeholder-approved requirement set authors exactly two product-level NFRs; adding more would introduce scope nobody approved (SDD rule: never invent).
  2. Usability substance is already normative as functional requirements — R9/R10 (gesture + keyboard paging), R16 (responsiveness), R18 (keyboard volume), R40 (native fullscreen) — and D1 binds the app to macOS platform idioms as the baseline.
  3. Compatibility is already decided, not open: D1 (macOS-only), R34 (direct children), R35 (native formats). An RNF-03 would restate D1.
  4. The numbering gap is deliberate and documented: one line under the two pillars — "RNF-01 and RNF-03 are intentionally unassigned in v1; the two pillars (RNF-02/RNF-04, D5) are the complete NFR set" — so future readers do not read it as an omission. A future story can add them if the stakeholder wants.
- The skip is a documentation-level choice recorded here and in that one-line note; no ADR — the governing decision for the pillar set already exists (D5).

### 1.5 Bootstrap-note removal

- The skeleton blockquote is **deleted entirely** — the file is no longer a skeleton, and its explanation of the SDD flow already lives in `AGENTS.md` and [docs/specs/README.md](../README.md).
- The note's one durable fact — override precedence — is kept as a single line under the tagline, plus the provenance line under Functional requirements linking the derivation record (`specs/e1-s1-product-spec/spec.md`, relative link, gate-checked).
- The `#` title line is unchanged.

## 2. Deliverable 2 — ADR batch D7–D12

### 2.1 Grouping principle and coverage

One ADR per genuinely decision-shaped topic — a choice with live alternatives and lasting consequences — absorbing the interview decisions that share context and fate. The stakeholder's twelve interview decisions (all final) group into **six ADRs**; all six are created as **`accepted`** because the decisions came from the stakeholder. Entries follow the log's house format (`## D# — title · date · accepted`, with Context / Decision / Alternatives / Consequences bullets) and must pass the gate's ADR check.

Coverage — every interview decision lands in exactly one ADR (decision topics are reconstructed from the approved requirement set; each entry cites the interview and the story spec as its source):

| # | Interview decision (topic) | ADR | Grounded in |
|---|---|---|---|
| 1 | Entry via Finder "Open With" + drag & drop; no in-app folder picker | D7 | R1–R5; non-goal (in-app folder picker) |
| 2 | Local files only — no network streams, no camera imports | D7 | non-goals (network streams, camera imports); R1–R5 are local-file-based |
| 3 | Native macOS formats only | D8 | R35–R36; non-goal (exotic codecs) |
| 4 | Direct children only — no subfolder recursion | D8 | R34; non-goal (subfolder recursion) |
| 5 | Full transport control incl. playback speed | D9 | R12–R14 |
| 6 | Loop in place at end; no auto-advance | D9 | R15 |
| 7 | App-level volume and mute, keyboard-driven, persisted across relaunch | D10 | R18–R20 |
| 8 | Ordering: folder's own / filename / date-added | D11 | R21–R22 |
| 9 | Feed and list track the folder live | D11 | R23–R26 |
| 10 | List operations: zip / move / reveal / trash (confirmed, recoverable) | D12 | R30–R33 |
| 11 | Ephemeral grouping only — no persistent albums/tags | D12 | R29; non-goals (albums/tags) |
| 12 | Never rewrite, re-encode, or modify media file contents | D12 | R17 |

### 2.2 Planned entries

| ADR | Title | Decision (one line) | Grounds |
|---|---|---|---|
| **D7** | Entry points: Finder Open With + drag & drop, local files only | Media enters exclusively through Finder "Open With" on a file in the folder, or drag & drop of a file or folder onto the app or an open window; no in-app picker, no streams, no camera; every entry resolves to one folder's feed. | R1–R5; non-goals (picker, network, camera) |
| **D8** | Media collection: native formats, direct children only | A folder's media is exactly its direct children that macOS plays or displays natively out of the box; no subfolder recursion, no codec work in v1. | R34–R36; non-goals (recursion, exotic codecs) |
| **D9** | Playback semantics: auto-play, full transport, loop in place | The current video starts on arrival with no perceptible wait; play/pause, scrub, and speed are app-provided; at its end it loops in place and never auto-advances. | R11–R15 |
| **D10** | Volume: app-level, keyboard-driven, persisted | Volume and mute act on the app's own playback audio from the keyboard — not the system output — and are restored on relaunch. | R18–R20 |
| **D11** | Ordering & live sync: three orderings over a live-tracked folder | Feed and list share one ordering — the folder's own by default, switchable to filename or date-added — and both track the folder live, keeping the viewer on a neighbor when the current item disappears. | R21–R26 |
| **D12** | File operations: zip/move/reveal/trash on ephemeral groups, never rewrite | The list supports ad-hoc multi-select (nothing persisted) with zip, move, reveal, and confirmed, recoverable trash; no v1 feature rewrites, re-encodes, or modifies media contents. | R27–R33 + R17; non-goals (albums/tags, editing/export) |

Per-entry content outline (entries stay compact, house style, ~4 bullets):

- **Context:** the choice the stakeholder faced in the E1-S1 interview, linking the story spec.
- **Decision:** the one-liner above, expanded only where the one-liner is ambiguous.
- **Alternatives:** the options the decision forecloses — each relevant non-goal is a pointer (e.g. the in-app folder picker for D7).
- **Consequences:** scope effects, pillar touchpoints (D7 → security-scoped access; D9 → playback-start budget; D12 → read-only file handling), and the epics/stories that implement it (§3).
- Date: commit date; status `accepted`.

### 2.3 What is deliberately not ADR'd

- **Product-concept statements** — the combined vertical feed of videos and images (R7–R8) and the single-window presentation (R37–R40) are the product's shape, not choices between live alternatives; they are normative in docs/spec.md. If either is ever revisited, that change brings its own ADR.
- **Already decided elsewhere** — English-only (D6); the pillar set (D5 — R6 operationalizes RNF-04 for entry and adds no new decision).
- **Documentation-process choices made by this design** — promotion strategy (§1.2), the RNF skip (§1.4), the epic structure (§3): recorded here as the story's trace, not product decisions; no ADRs.

## 3. Deliverable 3 — backlog epic skeleton E2–E5

### 3.1 Structure and sequencing

Four epics below E1, phase-shaped and ordered by risk: the walking skeleton first (it proves the product's two core risks — instant start and sandbox entry — before any breadth), then controls that deepen the same surface, then the ordering/sync state both views consume, then the list surface that consumes it and adds operations.

| Epic | One-line goal | Capability groups absorbed |
|---|---|---|
| **E2** — Walking skeleton | Open a folder, see the feed, play it — thinnest end-to-end slice | entry, formats & filtering, feed navigation, window, basic playback |
| **E3** — Playback controls | Inspect footage precisely without leaving the feed | playback (transport), volume |
| **E4** — Ordering & live sync | Feed and list always match the folder | ordering, live sync |
| **E5** — List view & operations | Act on what you just watched | list view & operations |

### 3.2 Story skeleton (all `draft`)

| Story | One-line scope | Requirements |
|---|---|---|
| **E2-S1** · Entry & media collection | Open a folder via Finder "Open With" or drag & drop of a file/folder; resolve to the containing folder positioned at the opened item; unsupported files ignored; empty → welcome drop target; collect direct children of native formats only; access stays sandbox-scoped | R1–R6, R34–R36 |
| **E2-S2** · Vertical feed & window | One feed mixing videos and images; current item fills the viewport with aspect preserved; scroll/arrow paging; single resizable window; a new open replaces in place; resize and fullscreen keep the item filling | R7–R10, R37–R40 |
| **E2-S3** · Basic playback | Auto-play the current video with no perceptible wait; play/pause; loop at end without auto-advancing; media files never rewritten | R11, R12, R15, R17 |
| **E3-S1** · Scrub & seek | Move playback to the indicated point in the current video | R13 |
| **E3-S2** · Playback speed | Apply the selected speed to the current video | R14 |
| **E3-S3** · Volume & mute | App-level volume from the keyboard, mute toggle, state restored on relaunch | R18–R20 |
| **E4-S1** · Ordering modes | Folder's own order by default; filename / date-added switch re-orders the active view(s) | R21–R22 |
| **E4-S2** · Live folder sync | Additions, removals, and renames reflected live; removal of the current item keeps the viewer on a neighbor | R23–R26 |
| **E5-S1** · List view & selection | Every media item listed by file name per current ordering; multi-select treated as one ad-hoc group; nothing persisted | R27–R29 |
| **E5-S2** · File operations | Zip the selection; move to a user-chosen destination; reveal in Finder; trash after confirmation, recoverably | R30–R33 |

Coverage check: all 40 requirements placed — E2-S1: 9, E2-S2: 8, E2-S3: 4, E3: 5, E4: 6, E5: 7, plus cross-cutting R16 (§3.3). All nine capability groups map onto story-sized work, satisfying the story's final acceptance criterion.

Sequencing and dependency notes:

- E2's stories are effectively sequential (S1 gives S2 something to show; S2 gives S3 something to play); E3's three stories are independent of each other; E4 needs only E2; E5-S1 needs E4 (it consumes the ordering/sync state); E5-S2 needs E5-S1.
- **R21–R26 are phrased over "feed and list":** with E4 before E5, E4 lands the shared ordering/sync state over the feed, and E5-S1's list consumes the same state — full "both views" satisfaction completes at E5-S1. Refinement cuts each story's acceptance criteria to its own surface accordingly.
- The skeleton fixes IDs, one-line scopes, ordering, and coverage. Stories stay `draft` — acceptance criteria, dependencies, estimates, and possible splits (new IDs continue the sequence; existing IDs are never renumbered or reused) are refinement work, not this story.

### 3.3 Cross-cutting requirements and pillars

- **R16** (no stalls across browsing, transport, ordering, view switches) spans every UI story; each story's design carries its share of the responsiveness budget.
- **R17** is established as a standing guarantee in E2-S3 and re-asserted by every story that touches files (E5-S2 above all).
- The pillars apply per the AGENTS.md trigger table: every E2–E5 brief touching playback, feed, lists, images, or threading must load `swift-performance`; every brief touching files, sandbox, or persisted state must load `swift-security`. Per-story budgets are set in those stories' designs — deliberately not here (see pillar sections).

### 3.4 Backlog edit mechanics

- Four new epic sections appended after E1, mirroring the existing header style (`## E0 — Agent harness (SDD bootstrap)`): `## E2 — Walking skeleton (open a folder, see the feed, play it)`, etc.
- Each story entry mirrors the existing story-line style, plus one sub-bullet for the requirement range — no acceptance criteria, no estimates (draft state per the backlog header):

  ```
  - [ ] **E2-S1 · Entry & media collection** (open a folder via Finder or drag & drop; native formats, direct children; welcome state) · `draft`
    - Requirements: R1–R6, R34–R36 (entry, formats & filtering)
  ```

- E1-S1's own entry and state are untouched (its `done` transition happens at converge, not in this story's tasks); E1-S2 is untouched.

## 4. Deliverable verification map

How this design satisfies the story's acceptance criteria (re-checked by the validator at review):

| Story acceptance criterion | Satisfied by |
|---|---|
| Spec passes the stakeholder approval gate | Already met — the spec is approved; this design inherits it as input |
| docs/spec.md filled: four outline placeholders replaced; functional requirements carry R1–R40 | §1.1 layout, §1.2 promotion rules |
| No `[NEEDS CLARIFICATION]` remains; RNF-02/RNF-04 pillar wording preserved verbatim | §1.2 (verbatim rule), §1.4 (byte-identical + diff check), pillar sections |
| Every one of the twelve interview decisions represented by ≥1 EARS requirement | §2.1 coverage table (decision → ADR → grounding) |
| Each capability area coherent and small enough for a feature epic | §3.1–3.2 (nine groups → four epics → ten stories; all 40 requirements placed) |

## Performance (RNF-02)

This story ships documents, not runtime — there is no code to budget. The design's performance job is to keep the pillar **authoritative and traceable** into the work that will carry budgets:

1. **Wording preserved verbatim.** The RNF-02 bullet is carried byte-identical into the rewritten docs/spec.md (§1.4); the implementing task verifies by diff, and the story's acceptance criterion enforces it.
2. **Performance obligations are normative requirements, not prose.** R11 (auto-play with no perceptible wait) and R16 (no stalls) are EARS requirements in the source of truth, so every implementation story that inherits them has testable obligations; R9/R10 carry the feed-paging expectation.
3. **Risk-first sequencing.** The epic skeleton puts the highest performance risk earliest: E2 proves instant start (R11) and smooth paging (R9/R10) before any breadth is added (§3.1).
4. **Per-story budgets live in the stories.** Each E2–E5 story's design loads the `swift-performance` skill (per AGENTS.md: playback, lists, images, threading, SwiftUI views) and sets its own budgets. This design sets none — nothing measurable exists yet, and premature budgets would be invented numbers.
5. **Process.** This story's commits are docs-only and gated by `./scripts/validate.sh --staged` (docs checks, no build-heavy steps); no gate bypass.

## Security (RNF-04)

Same posture — preserve authority and traceability. The deliverables themselves touch no secrets, network, permissions, or persisted user data; the only persisted artifacts are markdown files in-repo.

1. **Wording preserved verbatim.** The RNF-04 bullet is carried byte-identical into the rewritten docs/spec.md (§1.4).
2. **Security obligations are normative requirements.** R6 (access only through the user's grant, within the sandbox), R17 (never rewrite or re-encode user media), R33 (trash only after confirmation, recoverable), R35/R36 (native formats only; unsupported files excluded from every view and function — bounding the input the app will ever handle).
3. **Decisions carry their obligations forward.** The ADR consequences name pillar touchpoints (§2.2): D7's entry strategy is where security-scoped access begins (→ E2-S1); D12's operations are move/package-only with recoverable trash (→ E5-S2). Future briefs for those stories must load the `swift-security` skill (sandbox & permissions, file handling) per the AGENTS.md trigger table; their designs set the concrete measures.
4. **No security surface in this story's own work** — no code, no credentials, no network; the deterministic gate runs on every commit.

## Alternatives considered

1. **docs/spec.md content strategy.** (a) Promote the entire approved story spec verbatim — discarded: docs/spec.md would duplicate the story artifact's narrative, double the drift surface, and stop being the compact file read on every product question. (b) **Compact source of truth + derivation record (chosen, §1.2):** normative content verbatim, narrative summarized, story spec linked as the permanent derivation record. (c) Summarize the requirements too (capability bullets instead of full EARS text) — discarded: requirements are the normative core; paraphrasing them creates a second, weaker truth and renumbering risk; the EARS text is already minimal.
2. **ADR granularity.** (a) One ADR per interview decision (~12 entries) — discarded: micro-entries sharing one context; superseding a topic would touch many entries; the log loses signal. (b) One umbrella "v1 product scope" ADR — discarded: too coarse to supersede partially (the volume model could not change without reopening entry points) and unsearchable. (c) **Six topic-grouped ADRs (chosen, §2):** one per genuinely decision-shaped topic; D7–D12 are authored by this story's tasks.
3. **Epic granularity.** (a) One epic per capability group (nine epics) — discarded: fragments the walking skeleton (entry, feed, playback belong to one end-to-end slice) and adds ceremony without sequencing signal. (b) A single "E2 — features" epic — discarded: no ordering, no risk-first sequence. (c) **Four phase-shaped epics E2–E5 (chosen, §3).** (d) List view first (independent of playback, quick win) — discarded: delays pillar proof at the product's core risk.
4. **RNF set.** Adding RNF-01 (usability) / RNF-03 (compatibility) vs. pillars only — **explicitly skipped** (§1.4): no stakeholder decision covers them; their substance is already normative (R9/R10, R16, R40; R34/R35) or already decided (D1, D5).
5. **Bootstrap note.** Delete the blockquote entirely vs. keep a trimmed version — chosen middle path (§1.5): delete the skeleton note, keep a one-line precedence statement plus the derivation-record link; the SDD-flow explanation already lives in `AGENTS.md` and [docs/specs/README.md](../README.md).

**ADR pointers:** D1 (stack), D5 (pillars), D6 (language) are existing inputs this design builds on; **D7–D12 are planned here (§2) and authored by this story's implementation tasks** — references to them are forward references until those tasks land.
