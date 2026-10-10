# E1-S2 · Baseline hygiene — Tasks

Executable plan for [the approved spec](spec.md) (R1–R18) under [the approved design](design.md)
(§1–§10). Conventions: [docs/specs/README.md](../README.md).

- **One task = one commit.** `[P]` marks tasks that can run in parallel (same wave). Order below is
  the default; Tasks 3 and 4 may execute in either order or concurrently.
- **Every task ends with the gate** at its stated mode — code tasks: full `./scripts/validate.sh`;
  docs-only tasks: `./scripts/validate.sh --staged`. Fix before moving on. Never `--no-verify`.
- **Gate evidence is recorded from tooling, never from memory:** `./scripts/validate.sh --json
  <tmp>/gate.json` per run; outputs are quoted verbatim in `evidence.md` (created by Task 5).
- **Guardrails (all tasks):** the gate change never weakens existing behavior (AGENTS.md hard
  rule 3); `--staged` semantics are byte-identical for every existing invocation; style fixes are
  style-only (R10). Everything in English (D6).
- **Skill loading:** `swift-security` / `swift-performance` are **NOT required** for Tasks 1–2 —
  style tooling and gate wiring only, no runtime, data, network, or threading surfaces are touched
  (design §7, tooling-only non-engagement). No code task in this story ships runtime behavior.
- **House configs apply from Task 1 onward:** once `.swiftlint.yml` / `.swiftformat` land, every
  later gate run and every edit is judged by them (R1–R3).

## Task 1 — House configs: `.swiftlint.yml` + `.swiftformat` (code task)

- [ ] **1.1** Evolve `.swiftlint.yml` in place (the existing stub's comment is replaced; the file
      becomes the authoritative config) with the **exact contents of design §1** — `excluded`
      (`.deriveddata`, `.build`, `.swiftpm`), `disabled_rules` (formatter-owned set + `file_length`,
      `type_body_length`), `opt_in_rules` (`force_unwrapping`, `implicitly_unwrapped_optional`,
      `fatal_error_message`), `line_length` 120/120, and error severity for the three opt-ins.
- [ ] **1.2** Create `.swiftformat` with the **exact contents of design §2** — `--exclude
      .deriveddata,.build,.swiftpm`, `--max-width 120`, `--wrap-arguments before-first`,
      `--wrap-parameters before-first`, philosophy comment (defaults inherited, not re-declared).
      *Contingency (design §2):* if the installed SwiftFormat predates the kebab-case spellings,
      use the legacy equivalents (`--maxwidth`, `--wraparguments`, `--wrapparameters`) — spelling
      fix only, same semantics; record the substitution in Task 5's deviations.
- [ ] **1.3** Run `swiftformat .` once to normalize the tree under the house block (expected no-op
      per design §4 inspection; any rewrap diff is by construction style-only, R10).
- [ ] **1.4** Run the **full** `./scripts/validate.sh`. Expected: green with **zero** hand-fixes
      (design §4 inspection evidence: longest line ≈95 chars, zero force unwraps / IUOs /
      `fatalError`, `before-first` wraps already in place). If any violation appears, fix
      **style-only** — no behavioral change, no refactor, no renaming beyond style (R10) — and
      name the exact file+line in the commit body and in Task 5's deviations (no invented fixes).
- [ ] **1.5** Confirm both tools pick the configs up with no `--config` flags (R2–R3): the gate's
      "Lint (SwiftLint)" and "Format check (SwiftFormat --lint)" steps pass from the committed
      files alone.

Commit: `chore(e1-s2): house style configs — SwiftLint/SwiftFormat single source of truth (120)`
Scope check: only `.swiftlint.yml`, `.swiftformat`, and (only if 1.4 forced it) style-only diffs in
tracked Swift files. **Skills not required** (style tooling only, design §7).

## Task 2 — Gate `--uitests` flag (code task)

- [ ] **2.1** Edit `scripts/validate.sh` per **design §3** (the exact diffs; anchors verified against
      the current file: `unit_test_target="InstantPlayerTests"`, `staged=0`, the arg `while` loop,
      `docs_only=0` / `if [ "$staged" -eq 1 ]; then`): usage line + `ui_test_target` variable +
      `uitests=0` + `--uitests) uitests=1 ;;` case (unknown options still exit 1); `docs_only`
      shortcut suppressed when `uitests=1` with the explanatory message; the new "UI tests
      ($ui_test_target)" step at the end of the project-checks block (after "Unit tests"), using
      the identical `xcodebuild` conventions (project, scheme, `Debug`, `platform=macOS`,
      `-derivedDataPath .deriveddata/`) via `run_step` (fail-closed, R13; step flows into
      `--json` evidence via `steps.tsv`).
- [ ] **2.2** R11 — default run unchanged. Run `./scripts/validate.sh --json <tmp>/gate-default.json`
      and verify the step set and order match the pre-change default exactly (docs checks, lint,
      format, build, unit tests; no UI step). Also verify `--staged` docs/harness-only runs still
      take the docs-only shortcut byte-identically (matrix rows 1–3 of design §3).
- [ ] **2.3** R12 — flagged run is additive. Run `./scripts/validate.sh --uitests --json
      <tmp>/gate-uitests.json` and verify `InstantPlayerUITests` executes **in addition to** every
      default step (superset invariant), and that `./scripts/validate.sh --staged --uitests` runs
      the full matrix row (docs-only shortcut never taken).
- [ ] **2.4** R13 — UI failure fails the gate. **Chosen verification method (documented, per the
      design's fail-closed claim):** transient failing-UI-expectation probe, then revert. Add one
      deliberate failure (e.g. `XCTFail("E1-S2 fail-closed probe")`) inside one
      `InstantPlayerUITests` test in the working tree only; run `./scripts/validate.sh --uitests
      --json <tmp>/gate-failprobe.json`; observe exit status 1 and the failing "UI tests" step in
      the JSON evidence; then remove the probe and confirm via `git diff` that
      `InstantPlayerUITests.swift` is identical to HEAD **before staging anything**. Safeguards:
      the probe is never `git add`ed (the commit contains only `scripts/validate.sh`), and the
      pre-commit gate runs on the staged set regardless. *Fallback (recorded honestly, never
      faked):* if the UI-test run cannot execute in this environment (it needs a logged-in GUI
      session), fall back to `run_step`-wiring equivalence with the unit-test step and flag the
      unexercised path as a deviation in Task 5's evidence.

Commit: `feat(e1-s2): gate --uitests flag — additive UI-test step, fail-closed`
Scope check: only `scripts/validate.sh`. **Skills not required** (gate wiring only, design §7).
Guardrails: the diff is purely additive; the only existing condition touched (`docs_only`) becomes
*less* restrictive; `--staged` semantics byte-identical for existing invocations; pre-commit hook
untouched.

## Task 3 — Docs: `docs/development.md` + AGENTS.md pointer `[P]`

- [x] **3.1** Create `docs/development.md` per **design §5** with the five content items: (1) gate
      usage — `./scripts/validate.sh` plus modifiers (`--staged`, `--uitests`, `--json <path>`,
      `--verbose`) and step order (D4 + optional UI-tests step); (2) the **flag matrix from design
      §3 verbatim**; (3) the UI-test mandate (R14) — "when a story touches flows that UI tests
      cover, the validator/converge step must run `./scripts/validate.sh --uitests`; default
      per-commit runs stay UI-test-free (D4 speed promise)"; (4) tooling & pins (R15) — Xcode 26
      (`LastUpgradeCheck = 2600`, `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0` /
      `.swift-version` 5.0), destination `platform=macOS` (D1), derived data `.deriveddata/`,
      Homebrew `swiftlint` + `swiftformat` (gate is fail-closed without them); (5) CI runner
      checklist (R15–R16) — Xcode 26 selected, Homebrew tools, checkout, then the **same single
      command** `./scripts/validate.sh` (optionally `--json <path>`), plus the note that `--uitests`
      launches the real app and needs a logged-in GUI session. No CI-service files (story non-goal).
- [x] **3.2** Add one pointer row to the `AGENTS.md` trigger table: gate usage / flags / CI runner
      questions → `docs/development.md` (design §5). One row only; no other AGENTS.md changes.
- [x] **3.3** Run `./scripts/validate.sh --staged` (internal-links check covers `docs/*.md`, so all
      links from and to the new file are validated).

Commit: `docs(e1-s2): development guide — gate usage, flag matrix, CI runner checklist`
`[P]` — independent of Task 4 (different files: `docs/development.md` + `AGENTS.md` row vs
`docs/decisions.md`). Docs-only → `--staged` gate.

## Task 4 — ADR D17 in `docs/decisions.md` `[P]`

- [x] **4.1** Append D17 to `docs/decisions.md` per **design §6**, continuing the log at D16, with
      the gate-format-compliant heading exactly as specified:

      ```
      ## D17 — House style configs (SwiftLint/SwiftFormat) & gate `--uitests` formalization · 2026-10-09 · accepted
      ```

      Content: Context (tool-default style, tool contradiction on trailing
      commas/line length, D4's mechanism-less UI-test promise), Decision (committed configs as
      single style source; curated moderate SwiftLint set; 120-char agreement; SwiftFormat defaults
      + minimal block; default-off additive `--uitests` formalizing D4; `docs/development.md`), 
      Alternatives (summarized from design §8), Consequences (US1 agreement, risky constructs fail
      the gate, D4 speed preserved, tool-upgrade drift mitigated via runner-checklist pins and
      re-baselining, rationale inherited per R18).
- [x] **4.2** Verify R17–R18: the ADR names all four decisions (lint philosophy, line-length
      agreement, format style, `--uitests` formalization) and links back to D4 so the rationale is
      surfaced for future contributors.
- [x] **4.3** Run `./scripts/validate.sh --staged` (the "ADR format (docs/decisions.md)" step must
      accept the new heading; the internal-links check validates any links added).

Commit: `docs(e1-s2): ADR D17 — house style configs & gate --uitests formalization`
`[P]` — independent of Task 3. Docs-only → `--staged` gate.

## Task 5 — Verification & evidence (last)

- [ ] **5.1** Walk the **design §9 traceability table row by row against real files** (R1–R18 →
      §1/§2 config contents, §3 gate diffs + matrix, §4 green state, §5 docs items, §6 D17): open
      each named artifact and confirm the designed element is present in the committed tree; note
      any row that does not hold as a deviation.
- [ ] **5.2** Run the **full** `./scripts/validate.sh --json <tmp>/gate.json` and the **flagged**
      `./scripts/validate.sh --uitests --json <tmp>/gate-uitests.json`; quote both per-step results
      **verbatim** (never paraphrased, never re-derived) into `docs/specs/e1-s2-baseline-hygiene/evidence.md`,
      together with the R13 fail-probe JSON excerpt from Task 2.4 and the R9 green-run excerpt from
      Task 1.4 (SDD conventions: evidence from tooling output only).
- [ ] **5.3** In `evidence.md`, record deviations honestly: any style fix from Task 1 (file+line),
      the legacy SwiftFormat option spelling if used (1.2), the R13 verification method actually
      exercised vs the fallback (2.4), and anything the design predicted that did not hold.
- [ ] **5.4** Tick the story's acceptance criteria in [spec.md](spec.md) that this evidence closes —
      R1–R3 configs authority, R4–R5 120 agreement, R6–R8 curated set, R9–R10 green codebase,
      R11–R13 `--uitests` both ways, R14 mandate documented, R15–R16 CI checklist, R17–R18 ADR, and
      the evidence-convention criterion — each backed by the tooling output quoted in `evidence.md`.

Commit: `docs(e1-s2): evidence & traceability — gate runs quoted verbatim`

## Converge (coordinator note — not a subagent task)

1. **Stakeholder gate** — the stakeholder reviews the story artifacts + evidence and explicitly
   approves (this story ships no app-visible behavior, so no functional review run is required).
2. **Validator review** — adversarial `validator` pass over spec + gate-integrity guardrails
   (hard rule 3: nothing weakened; `--staged` byte-identical).
3. **Backlog + merge** — set E1-S2 to `done` in `docs/backlog.md`, then merge `feat/e1-s2-baseline-hygiene`
   into `main` with `git merge --no-ff` and delete the branch (AGENTS.md hard rule 7).
