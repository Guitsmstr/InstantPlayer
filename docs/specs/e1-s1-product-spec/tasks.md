# E1-S1 · Product spec authoring — story tasks

> **Parked (stakeholder decision, 2026-10-09):** implementation paused before Task 1 ran — story **E1-S3 · Architecture foundation** runs first (establish Clean Architecture + MVVM + Swift Concurrency before any implementation). Resume note for Task 2 (ADR batch D7–D12): those numbers may be taken by E1-S3's ADRs; renumber the batch to continue from the last ADR in `docs/decisions.md` at execution time.

- **Story:** E1-S1 · Product spec authoring — E1 (Product foundation), `in progress` ([docs/backlog.md](../../backlog.md))
- **Branch:** `feat/e1-s1-product-spec`
- **Phase:** Implement — carry the approved [spec](spec.md) and [design](design.md) to done. Docs-only story: three documentation deliverables plus verification; no app code is written.
- **Deliverables:** (1) rewritten [docs/spec.md](../../spec.md) — design §1; (2) ADR batch D7–D12 in [docs/decisions.md](../../decisions.md) — design §2; (3) epic skeleton E2–E5 in [docs/backlog.md](../../backlog.md) — design §3; (4) verification + evidence in this story dir — design §4.
- **Inputs:** approved [story spec](spec.md) (R1–R40, nine capability groups, non-goals, acceptance criteria); approved [story design](design.md) (§1–§4); [docs/specs/README.md](../README.md) — tasks and evidence conventions.

## How to run these tasks

- **One task = one commit.** Each task names its deliverable file(s), the design section it executes, its steps, its in-task verification, its gate step, and its commit message. Tick the task's checkbox in this file as part of the same commit.
- **Docs-only gate — never the full build.** This story ships markdown only. Every task's gate step is `./scripts/validate.sh --staged`: stage the task's file(s) first (`git add …`), so the gate sees a docs-only staged set and auto-skips the build-heavy steps (SwiftLint, SwiftFormat, `xcodebuild` build, unit tests). Do **not** run the full-gate build for this story — nothing it touches compiles. The pre-commit hook runs the same `--staged` gate on every commit; the explicit run before committing is the same command.
- Fix any gate failure in the deliverable before committing; never bypass the gate.
- **Waves.** Tasks 1–3 are mutually independent — different files, no link or content dependencies — so all three carry `[P]` (same wave; any order, or in parallel). Task 4 verifies all three deliverables and depends on Tasks 1–3; it runs last, alone.
- **Evidence rule** ([docs/specs/README.md](../README.md)): evidence is recorded from tooling, never from memory. Tasks 1–3 perform the in-task checks stated in each task; Task 4 records the story's evidence file from the gate's `--json` output.

## Tasks

- [ ] **Task 1 `[P]` — Promote the v1 product spec into `docs/spec.md`**
  *Deliverable:* `docs/spec.md` (rewritten in place) · *design:* §1 — layout §1.1, promotion rules §1.2, numbering §1.3, RNF set §1.4, bootstrap-note removal §1.5 · *wave:* 1 (independent)

  Rewrite `docs/spec.md` to the §1.1 layout, applying the §1.2 promotion rules — normative content verbatim, narrative summarized, story-artifact material not promoted:

  1. Keep the `#` title line unchanged (§1.5).
  2. Replace the tagline with the §1.2 proposed copy — "An instant viewer for a folder of videos and images on macOS — open it from Finder, flip through a vertical feed, act on what you just watched. Zero setup, no waiting." — final polish allowed at implementation, meaning unchanged.
  3. Delete the bootstrap blockquote entirely; keep its one durable fact as the single precedence line under the tagline, per the §1.1 layout: this file is the product source of truth, overridden only by ADRs in [docs/decisions.md](../../decisions.md) (§1.5).
  4. Rewrite the Product outline as the four compact bullets of §1.2 — the label widens from "Sources of video" to "Sources of media" (R7 includes images) — each bullet pointing at R-numbers for detail, never restating requirement text: target user and main job-to-be-done (persona summarized in ≤3 sentences: who, the folders they review, the two meanings of "instant"); sources of media (local folders via Finder "Open With" or drag & drop; exclusions referenced via Non-goals); minimum playback experience; scope boundaries (the eight non-goals referenced, not restated).
  5. Replace the empty Functional-requirements section with a one-line provenance bullet linking the derivation record — [this story's spec](spec.md), written as the relative link `specs/e1-s1-product-spec/spec.md` from `docs/` so the gate's internal-link check resolves it — followed by R1–R40 promoted **verbatim** from the story spec: the nine group headings in order (Entry, Feed navigation, Playback, Volume, Ordering, Live sync, List view & operations, Formats & filtering, Window), numbers, order, and grouping unchanged (§1.3), including the clarifying note under List view & operations ("Zip, move, and trash relocate or package files…") verbatim. Paste; never retype.
  6. Non-functional requirements: carry the RNF-02 and RNF-04 bullets **byte-identical** from the current file (§1.4); append the §1.4 one-line note — RNF-01 and RNF-03 are intentionally unassigned in v1; the two pillars (RNF-02/RNF-04, D5) are the complete NFR set.
  7. Non-goals: promote the preamble and eight items verbatim from the story spec (§1.1).
  8. No invention (§1.2): add nothing beyond the approved spec — subtitles, picture-in-picture, and background audio stay absent (v1 is exactly R1–R40), and no new non-goal entries are created for them; user stories 1–6, the persona paragraph beyond the outline summary, story context, and acceptance criteria are not promoted.

  In-task verification (before the gate):
  - the two pillar bullets are byte-identical to the pre-rewrite file — verify by diff: `git diff` on the rewritten file shows those lines untouched, or compare against `git show HEAD:docs/spec.md` (design §1.4's diff check);
  - the four outline placeholders (target user, sources of video, minimum playback experience, scope boundaries) are gone, and a search for the bracketed open-question marker named in acceptance criterion 3 of [the story spec](spec.md) returns zero hits in `docs/spec.md`;
  - R1–R40 appear exactly once each, grouped and numbered as in the story spec, the nine group blocks character-identical to the story spec's EARS section.

  Gate & commit: `git add docs/spec.md` + tick this task's checkbox here → `./scripts/validate.sh --staged` → fix any failure → commit as `docs(e1-s1): promote v1 product spec into docs/spec.md`.

- [ ] **Task 2 `[P]` — Append ADR batch D7–D12 to `docs/decisions.md`**
  *Deliverable:* `docs/decisions.md` (append-only) · *design:* §2 — coverage §2.1, planned entries §2.2, exclusions §2.3 · *wave:* 1 (independent)

  Append six ADRs after D6 — one per genuinely decision-shaped topic, absorbing the twelve stakeholder interview decisions:

  1. House format, gate-checked: `## D# — title · <commit date> · accepted` with Context / Decision / Alternatives / Consequences bullets (§2.2 per-entry outline); all six are `accepted` because the decisions came from the stakeholder; date = commit date.
  2. Titles, one-line decisions, and grounds exactly per the §2.2 planned-entries table:
     - **D7** — Entry points: Finder Open With + drag & drop, local files only (R1–R5; non-goals: in-app picker, network streams, camera imports);
     - **D8** — Media collection: native formats, direct children only (R34–R36; non-goals: subfolder recursion, exotic codecs);
     - **D9** — Playback semantics: auto-play, full transport, loop in place (R11–R15);
     - **D10** — Volume: app-level, keyboard-driven, persisted (R18–R20);
     - **D11** — Ordering & live sync: three orderings over a live-tracked folder (R21–R26);
     - **D12** — File operations: zip/move/reveal/trash on ephemeral groups, never rewrite (R27–R33 + R17; non-goals: albums/tags, editing/export).
  3. Per entry: Context states the E1-S1 interview choice and cites the interview and [the story spec](spec.md) as source (§2.1); Decision expands the one-liner only where it is ambiguous; Alternatives name the options the decision forecloses, with each relevant non-goal as a pointer; Consequences name scope effects, the pillar touchpoints (D7 → security-scoped access; D9 → playback-start budget; D12 → read-only file handling), and the implementing epics/stories (E2–E5 per design §3).
  4. Nothing from §2.3 gets an entry: product-concept statements (the combined feed R7–R8, single window R37–R40), topics already decided elsewhere (D5, D6), and this design's documentation-process choices.
  5. Coverage self-check (§2.1): each of the twelve interview decisions lands in exactly one ADR, per the §2.1 coverage table.

  Gate & commit: `git add docs/decisions.md` + tick this task's checkbox here → `./scripts/validate.sh --staged` (the ADR-format step validates the six new headings) → fix any failure → commit as `docs(e1-s1): record product decisions D7–D12`.

- [ ] **Task 3 `[P]` — Add the epic skeleton E2–E5 to `docs/backlog.md`**
  *Deliverable:* `docs/backlog.md` (append-only below E1) · *design:* §3 — structure §3.1, story skeleton §3.2, cross-cutting §3.3, edit mechanics §3.4 · *wave:* 1 (independent)

  Append the feature-epic skeleton below E1. The E1-S1 and E1-S2 entries stay untouched — E1-S1's `done` transition is converge work, not this task's (§3.4):

  1. Four epic sections after E1, mirroring the existing header style (`## E0 — Agent harness (SDD bootstrap)`), parenthetical one-line goals per §3.1: `## E2 — Walking skeleton (open a folder, see the feed, play it)`, `## E3 — Playback controls (inspect footage precisely without leaving the feed)`, `## E4 — Ordering & live sync (feed and list always match the folder)`, `## E5 — List view & operations (act on what you just watched)`.
  2. Under each epic, add the ten story entries of the §3.2 skeleton table, all `draft`, mirroring the existing story-line style plus one sub-bullet for the requirement range, exactly per the §3.4 example — entry line: title, short parenthetical scope condensed from the §3.2 one-line scope, `draft`; sub-bullet: `Requirements: <range> (<capability groups absorbed>)`. No acceptance criteria, no estimates (draft state per the backlog header):
     - E2-S1 · Entry & media collection — R1–R6, R34–R36;
     - E2-S2 · Vertical feed & window — R7–R10, R37–R40;
     - E2-S3 · Basic playback — R11, R12, R15, R17;
     - E3-S1 · Scrub & seek — R13;
     - E3-S2 · Playback speed — R14;
     - E3-S3 · Volume & mute — R18–R20;
     - E4-S1 · Ordering modes — R21–R22;
     - E4-S2 · Live folder sync — R23–R26;
     - E5-S1 · List view & selection — R27–R29;
     - E5-S2 · File operations — R30–R33.
  3. Coverage self-check (§3.2): the ten ranges place R1–R15 and R17–R40 exactly once each (E2-S1: 9, E2-S2: 8, E2-S3: 4, E3: 5, E4: 6, E5: 7). R16 is deliberately not assigned to a single story — it is the cross-cutting responsiveness requirement spanning every UI story (§3.3), and each story's own design carries its share.

  Gate & commit: `git add docs/backlog.md` + tick this task's checkbox here → `./scripts/validate.sh --staged` → fix any failure → commit as `docs(e1-s1): add feature-epic skeleton E2–E5 to backlog`.

- [ ] **Task 4 — Verify the deliverables and record evidence**
  *Deliverable:* `evidence.md` (new file in this story dir) + acceptance-criteria ticks in [spec.md](spec.md) · *design:* §4 verification map + [docs/specs/README.md](../README.md) evidence conventions · *wave:* 2 — depends on Tasks 1–3

  1. Walk the design §4 verification map row by row and verify each row against the landed files — from the files and tooling, never from memory:
     - criterion 2, "docs/spec.md is filled from this artifact": four outline placeholders replaced, functional requirements carry R1–R40 → check the promoted file from Task 1;
     - criterion 3, no open-question marker remains in `docs/spec.md` and the pillar wording is preserved verbatim → re-run Task 1's diff and grep checks against the committed file;
     - criterion 4, each of the twelve interview decisions is represented by ≥1 EARS requirement → check every row of the §2.1 coverage table against the landed D7–D12 groundings from Task 2 and the story spec's EARS section;
     - criterion 5, each capability area is coherent and small enough to break out as a feature epic → check the landed E2–E5 skeleton from Task 3: all nine groups mapped, all 40 requirements placed per §3.2.
  2. Gate evidence from tooling: stage this task's files, then run `./scripts/validate.sh --staged --json "$TMPDIR/gate.json"` and quote the JSON (branch, staged, result, per-step name/status) **verbatim** in the evidence file — never paraphrased or re-derived. The gate's docs checks (ADR format, internal links, task hygiene) run on the working tree, so this one run evidences the whole story's docs surface.
  3. Record the evidence file `docs/specs/e1-s1-product-spec/evidence.md`: the per-criterion verification results (§4 map — what was checked, what was observed), the verbatim gate JSON, and the four task commit hashes from `git log` on the story branch. No functional/app evidence exists for this story — it ships no app behavior, so there is nothing to exercise via `./scripts/app.sh run`.
  4. Tick the story acceptance criteria in [spec.md](spec.md): criteria 2–5 → `[x]`, each backed by its evidence entry. Criterion 1 (the stakeholder approval gate) stays `[ ]` — stakeholder approval of the deliverables and the story's `done` state are set at converge, not by this task. The E1-S1 entry in [docs/backlog.md](../../backlog.md) is not touched (Task 3 rule).

  Gate & commit: `git add docs/specs/e1-s1-product-spec/evidence.md docs/specs/e1-s1-product-spec/spec.md` + tick this task's checkbox here → `./scripts/validate.sh --staged` → fix any failure → commit as `docs(e1-s1): verify deliverables and record evidence`.

## Converge (coordinator — implementers stop after Task 4)

Task 4 is the last implementer work. From there the coordinator runs the story's converge per AGENTS.md: **stakeholder gate** (review of the promoted `docs/spec.md`, the D7–D12 batch, and the E2–E5 skeleton) → **validator review** (adversarial, spec + pillars, re-checking the design §4 map) → **backlog `done`**: tick the remaining acceptance criterion, set E1-S1 to `done` in `docs/backlog.md` → merge the story branch into `main` with `git merge --no-ff` and delete it.
