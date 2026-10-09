# E1-S1 · Product spec authoring — evidence

- **Story:** E1-S1 · Product spec authoring — E1 · branch `feat/e1-s1-product-spec`
- **Recorded:** 2026-10-09, by Task 4 (verification & evidence), per the evidence rule in `docs/specs/README.md`: from tooling, never from memory; tooling output quoted verbatim, never paraphrased or re-derived.
- **Scope note:** this story ships markdown only — no app behavior exists to exercise, so there is **no functional/app evidence**; `./scripts/app.sh run` was not used (nothing to observe).

## Story events — park and renumber (recorded for the validator)

- The story was **parked before Task 1 ran** (stakeholder decision, 2026-10-09, recorded in the banner of `tasks.md`): story **E1-S3 · Architecture foundation** ran first and its `main` work was merged into this parked branch (merge commit `01be500`), adding code skeleton, `docs/architecture.md`, and ADRs **D7–D10**.
- Consequence per the park banner and the standing ADR rule (numbers never reused): Task 2's ADR batch was **renumbered D7–D12 → D11–D16** (+2). Design §2 references map as: D7→D11, D8→D12, D9→D13, D10→D14, D11→D15, D12→D16. Landed as commit `f182ff1` ("docs(e1-s1): task 2 — ADR batch D11–D16 (v1 product decisions)").
- Task 3 landed `f999848` — backlog epic skeleton E2–E5 with the architecture preambles referencing D7–D10.

## Design §4 verification map — row by row

### Row 1 — "Spec passes the stakeholder approval gate" (acceptance criterion 1)

- **Verdict: inherited input — converge-owned, left unticked by Task 4** (tasks.md step 4: criterion 1 stays `[ ]`; the converge stakeholder gate sets it). No tooling check applies; the approved story spec is this story's input artifact.

### Row 2 — "docs/spec.md is filled from this artifact: four outline placeholders replaced; functional requirements carry R1–R40" (criterion 2)

- **Verdict: PASS.**
- Open-question marker search — tool output verbatim (`grep`, literal `[NEEDS CLARIFICATION`, over `docs/spec.md`):

  ```
  No matches found
  ```

- R-count — tool output verbatim (`grep`, `^R[0-9]+:`, over `docs/spec.md`):

  ```
  Found 40 matches
  ```

  with each of R1–R40 present exactly once, in order (line index of the same output): R1:L20, R2:L23, R3:L26, R4:L29, R5:L32, R6:L35, R7:L40, R8:L43, R9:L46, R10:L49, R11:L54, R12:L57, R13:L60, R14:L63, R15:L66, R16:L69, R17:L72, R18:L77, R19:L80, R20:L83, R21:L88, R22:L91, R23:L96, R24:L99, R25:L102, R26:L105, R27:L110, R28:L113, R29:L116, R30:L119, R31:L122, R32:L125, R33:L128, R34:L135, R35:L138, R36:L141, R37:L146, R38:L149, R39:L152, R40:L155.
- Group-block character identity (Task 1 in-task check, tooling): `tail -n +31 docs/specs/e1-s1-product-spec/spec.md | head -n 139` (story-spec EARS section, lines 31–169) and `tail -n +18 docs/spec.md | head -n 139` produced **identical 139-line outputs**, including the clarifying note under List view & operations; the file is unchanged since commit `c7757bf` (working tree clean at Task 4 start).
- Placeholders replaced: the four `[NEEDS CLARIFICATION: …]` outline bullets of the skeleton are gone (marker search above returns zero) and the outline carries the four §1.2 bullets with the label widened to "Sources of media".

### Row 3 — "No `[NEEDS CLARIFICATION]` remains; RNF-02/RNF-04 pillar wording preserved verbatim" (criterion 3)

- **Verdict: PASS.**
- Marker search: `No matches found` (verbatim output quoted in Row 2).
- Pillar byte-identity — pre-rewrite skeleton (commit `01be500`, before Task 1), verbatim tool output of `git show 01be500:docs/spec.md | tail -n 2`:

  ```
  - **RNF-02 (performance — pillar):** "Instant" is the product promise. Playback must start with no perceptible wait on the happy path; the UI stays smooth (no main-thread stalls); launch is minimal. See the `swift-performance` skill. Per-story budgets are set in story designs.
  - **RNF-04 (security — pillar):** user media and any credentials are handled as private data: Keychain for secrets, sandbox + security-scoped access for files, validated external input, ATS intact, no undocumented tracking. See the `swift-security` skill.
  ```

- Same bullets in the committed promoted file, verbatim tool output (`grep`, `^- \*\*RNF-0`, over `docs/spec.md`):

  ```
  Line 160: - **RNF-02 (performance — pillar):** "Instant" is the product promise. Playback must start with no perceptible wait on the happy path; the UI stays smooth (no main-thread stalls); launch is minimal. See the `swift-performance` skill. Per-story budgets are set in story designs.

  Line 161: - **RNF-04 (security — pillar):** user media and any credentials are handled as private data: Keychain for secrets, sandbox + security-scoped access for files, validated external input, ATS intact, no undocumented tracking. See the `swift-security` skill.
  ```

  The two lines are identical to the skeleton's (Task 1's `git diff docs/spec.md` additionally showed both bullets as unchanged context lines — no `-`/`+`).

### Row 4 — "Every one of the twelve interview decisions is represented by ≥1 EARS requirement" (criterion 4)

- **Verdict: PASS** — walked against the landed ADRs (D11–D16, renumbered per the park banner) and the promoted requirements in `docs/spec.md`.
- ADR headings — verbatim tool output (`grep`, `^## D[0-9]`, over `docs/decisions.md`):

  ```
  Line 7: ## D1 — Stack: SwiftUI + Swift, Xcode 26, macOS · 2026-10-09 · accepted
  Line 14: ## D2 — SDD harness adoption (mirrors an earlier project) · 2026-10-09 · accepted
  Line 21: ## D3 — No routing model; coordinator assigns batches · 2026-10-09 · accepted
  Line 28: ## D4 — Gate scope: build + unit tests + lint on every commit · 2026-10-09 · accepted
  Line 35: ## D5 — Pillars: security (RNF-04) and performance (RNF-02) via macOS skills · 2026-10-09 · accepted
  Line 42: ## D6 — Language: English everywhere · 2026-10-09 · accepted
  Line 49: ## D7 — Clean Architecture layering & dependency rule · 2026-10-09 · accepted
  Line 56: ## D8 — Presentation & concurrency model: MVVM `@Observable` + async/await · 2026-10-09 · accepted
  Line 63: ## D9 — Module organization: single target, folder groups, Core, no networking · 2026-10-09 · accepted
  Line 70: ## D10 — Hand-wired composition root in App · 2026-10-09 · accepted
  Line 77: ## D11 — Entry points: Finder Open With + drag & drop, local files only · 2026-10-09 · accepted
  Line 84: ## D12 — Media collection: native formats, direct children only · 2026-10-09 · accepted
  Line 91: ## D13 — Playback semantics: auto-play, full transport, loop in place · 2026-10-09 · accepted
  Line 98: ## D14 — Volume: app-level, keyboard-driven, persisted · 2026-10-09 · accepted
  Line 105: ## D15 — Ordering & live sync: three orderings over a live-tracked folder · 2026-10-09 · accepted
  Line 112: ## D16 — File operations: zip/move/reveal/trash on ephemeral groups, never rewrite · 2026-10-09 · accepted
  ```

  16 headings; the gate's ADR-format step reports them all well-formed (see gate JSON below).
- Coverage walk (design §2.1 rows → landed ADR Decision/Alternatives bullets → grounding requirements, all present in `docs/spec.md` per the Row-2 grep):

  | §2.1 # | Interview decision | Landed ADR | Grounding requirements (verified present) |
  |---|---|---|---|
  | 1 | Entry via Finder "Open With" + drag & drop; no in-app picker | **D11** (was D7) | R1–R5; picker foreclosed in D11 Alternatives |
  | 2 | Local files only — no streams, no camera imports | **D11** (was D7) | network streams + camera imports foreclosed in D11 Alternatives |
  | 3 | Native macOS formats only | **D12** (was D8) | R35; exotic codecs foreclosed in D12 Alternatives |
  | 4 | Direct children only — no subfolder recursion | **D12** (was D8) | R34; recursion foreclosed in D12 Alternatives |
  | 5 | Full transport control incl. playback speed | **D13** (was D9) | R12, R13, R14 |
  | 6 | Loop in place at end; no auto-advance | **D13** (was D9) | R15 |
  | 7 | App-level volume and mute, keyboard-driven, persisted | **D14** (was D10) | R18, R19, R20 |
  | 8 | Ordering: folder's own / filename / date-added | **D15** (was D11) | R21, R22 |
  | 9 | Feed and list track the folder live | **D15** (was D11) | R23, R24, R25, R26 |
  | 10 | List operations: zip / move / reveal / trash (confirmed, recoverable) | **D16** (was D12) | R30, R31, R32, R33 |
  | 11 | Ephemeral grouping only — no persistent albums/tags | **D16** (was D12) | R29; albums/tags foreclosed in D16 Alternatives |
  | 12 | Never rewrite, re-encode, or modify media contents | **D16** (was D12) | R17 |

  Each of the twelve decisions lands in exactly one ADR, and every cited requirement exists in `docs/spec.md`.

### Row 5 — "Each capability area is coherent and small enough to break out as a feature epic" (criterion 5)

- **Verdict: PASS** — all nine capability groups mapped, all 40 requirements placed.
- Epic headers — verbatim tool output (`grep`, `^## E[0-9]`, over `docs/backlog.md`): E0 (L9), E1 (L14), **E2 — Walking skeleton (open a folder, see the feed, play it)** (L25), **E3 — Playback controls (inspect footage precisely without leaving the feed)** (L36), **E4 — Ordering & live sync (feed and list always match the folder)** (L47), **E5 — List view & operations (act on what you just watched)** (L56) — matching design §3.1's four headers after E1.
- Story requirement ranges — verbatim tool output (`grep`, `Requirements: R`, over `docs/backlog.md`):

  ```
  Line 30:   - Requirements: R1–R6, R34–R36 (entry, formats & filtering)
  Line 32:   - Requirements: R7–R10, R37–R40 (feed navigation, window)
  Line 34:   - Requirements: R11, R12, R15, R17 (playback)
  Line 41:   - Requirements: R13 (playback)
  Line 43:   - Requirements: R14 (playback)
  Line 45:   - Requirements: R18–R20 (volume)
  Line 52:   - Requirements: R21–R22 (ordering)
  Line 54:   - Requirements: R23–R26 (live sync)
  Line 61:   - Requirements: R27–R29 (list view & operations)
  Line 63:   - Requirements: R30–R33 (list view & operations)
  ```

- Coverage arithmetic over the ten landed ranges: E2-S1 = 6+3 = 9, E2-S2 = 4+4 = 8, E2-S3 = 4, E3 = 1+1+3 = 5, E4 = 2+4 = 6, E5 = 3+4 = 7 → 39 placed, each of R1–R15 and R17–R40 exactly once; R16 is cross-cutting per the backlog's own coverage line (L65) and design §3.3 — all 40 accounted for. All nine group labels appear in the sub-bullets: entry, formats & filtering, feed navigation, window, playback, volume, ordering, live sync, list view & operations.

## Gate evidence (from tooling)

Run per tasks.md step 2: task files staged (`docs/specs/e1-s1-product-spec/evidence.md`, `docs/specs/e1-s1-product-spec/spec.md`, `docs/specs/e1-s1-product-spec/tasks.md`), then `./scripts/validate.sh --staged --json <tmp>/gate.json`. The gate's docs checks run on the working tree, so this run evidences the whole story's docs surface. JSON quoted verbatim from the run's output file:

```json
{
  "branch": "feat/e1-s1-product-spec",
  "staged": true,
  "result": "pass",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Branch policy (staged changes vs. 'main' allowlist)", "status": "ok" }
  ]
}
```

The commit carrying this evidence file re-runs the same gate via the pre-commit hook; its `== Result ==` block is quoted in the session report.

## Task commit hashes (`git log --oneline` on the story branch, verbatim)

```
f999848 docs(e1-s1): task 3 — backlog epic skeleton E2–E5
f182ff1 docs(e1-s1): task 2 — ADR batch D11–D16 (v1 product decisions)
c7757bf docs(e1-s1): task 1 — promote v1 product spec into docs/spec.md
```

Task 4 is the commit that adds this evidence file (a file cannot contain its own commit hash).

## Functional / app evidence

**N/A — explicitly none.** E1-S1 ships no app behavior (docs-only story); there is nothing to exercise via `./scripts/app.sh run`, and none was run.
