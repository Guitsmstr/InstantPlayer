# E1-S2 · Baseline hygiene — Story Spec

## Story context

- **Why this story, why now.** The deterministic gate (`scripts/validate.sh`) runs SwiftLint and SwiftFormat **with tool defaults** — the "house style" is whatever the installed tool versions happen to default to. That is not a style decision, and it will drift: a tool upgrade silently changes verdicts, and the linter and formatter can disagree (e.g. on line length), so a formatter-clean edit can still fail lint. Hygiene means the team's style lives in **committed configuration** — `.swiftlint.yml` and `.swiftformat` — as the single source of truth that every contributor and every gate run inherits.
- **What this story delivers.** Not product behavior: two committed tool configurations embodying an agreed, moderate house style; a codebase that is green under them; a formalized `--uitests` flag on the gate (the deferred part of [D4](../../decisions.md)); a tiny CI runner checklist; and an ADR recording the style decisions so future contributors inherit them instead of re-litigating them.
- **Stakeholder decisions (final, from the interview).** (1) Curated moderate lint set — sensible defaults, noisy opinionated rules off, a handful of high-value rules opted in; the existing codebase (the E1-S3 architecture skeleton) is brought to green within this story. (2) Line length **120 characters** for both SwiftLint and SwiftFormat, with formatter wrapping at the same limit so the tools agree. (3) SwiftFormat defaults plus a small explicit house-style block. (4) CI shape, not CI service config — a documented runner checklist only. (5) `--uitests` flag formalized on the gate, mandated at validator/converge for stories touching covered flows.
- **Gate integrity.** The flag **extends** the gate, never weakens it (AGENTS.md hard rule 3): the default per-commit behavior stays exactly as [D4](../../decisions.md) defined it, and D4's promise — "the validator/converge step runs UI tests when the story touches flows UI tests cover" — is what this story formalizes. Nothing here contradicts D4.
- **Pillars.** RNF-02 (performance) and RNF-04 (security) in [docs/spec.md](../../spec.md) are **not directly engaged** by tooling configuration: this story changes no runtime behavior, data handling, or shipped code semantics (style-only edits at most). The default-OFF `--uitests` behavior does preserve D4's per-commit speed concern, which was itself set so the gate "stays fast enough to never tempt a bypass".
- All requirements below are stakeholder-final; this spec has no open questions. Exact rule-by-rule selection is deliberately left to the design phase.

## User stories

- **US1** · As a contributor, I want the linter and the formatter to agree — same style source, same line-length limit — so that the gate never fails on style after a format-clean edit and no machine or tool default can drift the verdict.
- **US2** · As a contributor, I want a curated moderate rule set — correctness and risk rules on, stylistic noise off — so the gate flags real problems without nagging about settled style.
- **US3** · As a validator/converge reviewer, I want a formalized `--uitests` gate flag that is off by default, so I can prove covered UI flows without slowing every commit — completing what D4 promised.
- **US4** · As a maintainer setting up CI later, I want a short runner checklist (Xcode version, macOS destination, one gate command), so a CI runner reproduces the local gate with zero invention.

## Requirements (EARS)

Tooling constraints — guarantees on the style gate and its documentation, not user-facing product behavior. WHAT and WHY only: the exact rule selection and configuration contents are design-phase output (`design.md`).

### Config existence & authority

- **R1:** WHEN the repository's Swift style is defined
  THE SYSTEM SHALL provide exactly one committed source of style truth per tool — a SwiftLint configuration and a SwiftFormat configuration in the repository — that both gate runs and local developer runs are governed by
- **R2:** WHEN any lint or format check runs — inside the gate or in a contributor's local run
  THE SYSTEM SHALL judge code by those committed configurations, not by tool defaults or per-invocation overrides
- **R3:** WHEN the gate runs its lint and format steps
  THE SYSTEM SHALL run both tools so they pick up the committed house configurations automatically, making gate verdicts reflect the team style

### Lint/format agreement (line length)

- **R4:** WHEN a maximum line length is enforced
  THE SYSTEM SHALL use 120 characters as the limit in both SwiftLint and SwiftFormat
- **R5:** WHEN the formatter wraps or breaks lines
  THE SYSTEM SHALL wrap at the same 120-character limit the linter enforces, so the two tools never disagree and a format-clean edit cannot fail the linter on line length

### Curated rule set (moderate)

- **R6:** WHEN the SwiftLint rule set is assembled
  THE SYSTEM SHALL keep enabled the rule classes that catch correctness and risk problems — bugs, undefined or dangerous behavior, risky constructs
- **R7:** WHEN the SwiftLint rule set is assembled
  THE SYSTEM SHALL disable the rule classes that are purely stylistic opinion — noise that catches no defects and duplicates style the formatter or the house style already settles
- **R8:** WHEN a valuable rule is off by default
  THE SYSTEM SHALL opt in to a small curated set of high-value correctness/risk rules, keeping the set deliberately small (constraint classes only here — the exact rule selection is design-phase output)

### Codebase green under the house configs

- **R9:** WHEN the gate's lint and format checks run over the story's codebase
  THE SYSTEM SHALL pass on every tracked Swift file — including the E1-S3 architecture skeleton — under the house configurations, with no residual style violations
- **R10:** WHEN existing code must change to reach that green state
  THE SYSTEM SHALL limit changes to style fixes only — no behavioral changes, refactors, or feature work

### UI-test flag (`--uitests`)

- **R11:** WHEN the gate runs without the UI-test flag (the default, as on every commit)
  THE SYSTEM SHALL keep D4's per-commit scope exactly as-is — docs checks, lint, format, build, unit tests — with UI tests excluded
- **R12:** WHEN the gate is invoked with the `--uitests` flag
  THE SYSTEM SHALL run the UI-test target (`InstantPlayerUITests`) in addition to the standard gate steps — the flag extends the run, it does not replace or skip anything
- **R13:** WHEN a UI test fails in a `--uitests` run
  THE SYSTEM SHALL fail the gate run, keeping the gate fail-closed
- **R14:** WHEN a story touches flows that UI tests cover
  THE SYSTEM SHALL mandate a `--uitests` gate run in the validator/converge step, and this mandate SHALL be documented with the gate's usage

### CI shape (runner checklist)

- **R15:** WHEN a CI runner is prepared to run the gate
  THE SYSTEM SHALL provide a documented runner checklist covering what the runner must have — the pinned Xcode version, the macOS destination, and the single-command gate invocation
- **R16:** WHEN the checklist names the gate invocation
  THE SYSTEM SHALL name the same single deterministic command contributors run locally, so a conforming runner reproduces local verdicts with no CI-specific variant

### ADR & traceability

- **R17:** WHEN this story completes
  THE SYSTEM SHALL record the house style decisions — lint philosophy, line-length agreement, format style, and the `--uitests` formalization of D4 — as an ADR in [docs/decisions.md](../../decisions.md), continuing the log's numbering (currently through D16)
- **R18:** WHEN a future contributor or story needs the house style rationale
  THE SYSTEM SHALL surface it in that ADR so the decisions are inherited, not re-litigated

## Non-goals

- **CI service configuration** — no `.github/` or any CI-provider files; the repo has no remote yet, and the CI deliverable is a documented runner checklist only.
- **Changing gate ordering or steps beyond the flag** — the step order (docs checks, branch policy, lint, format check, build, unit tests) and the `--staged` docs-only semantics are preserved exactly; the only gate change in this story is the `--uitests` flag.
- **Rule-by-rule listings in the spec** — constraint classes only; the exact SwiftLint rule selection and `.swiftformat` block contents are design-phase output (`design.md`).
- **Rewriting application code beyond style fixes** — no behavioral changes, refactors, renaming beyond style, or feature work in the codebase.
- **Localization / String Catalogs** — out of scope (D6 governs language; localization is future work).
- **Product behavior** — this story touches tooling configuration and documentation only; no app-visible change ships.

## Acceptance criteria

- [ ] `.swiftlint.yml` and `.swiftformat` exist in the repository and are the single style source: gate runs and local runs judge by them (R1–R3).
- [ ] Lint and format agree on a 120-character limit, formatter wrapping included (R4–R5).
- [ ] The curated set is in place by constraint class: correctness/risk rules on, stylistic noise off, a small opt-in set (R6–R8).
- [ ] Codebase green: every tracked Swift file passes the gate's lint and format checks under the house configs (R9–R10); evidence via `./scripts/validate.sh --json <tmp>/gate.json`, quoted verbatim.
- [ ] `--uitests` works both ways: a default run matches D4's scope exactly, and a flagged run executes `InstantPlayerUITests` and fails the gate on UI-test failure (R11–R13).
- [ ] The validator/converge UI-test mandate is documented (R14).
- [ ] The CI runner checklist is documented — Xcode version pin, macOS destination, single gate command (R15–R16).
- [ ] The house style is recorded as an ADR in `docs/decisions.md` (R17–R18).
- [ ] Evidence recorded per [SDD conventions](../README.md) — gate evidence from tooling output, never from memory.

## References

- [docs/spec.md](../../spec.md) — product source of truth (RNF-02 / RNF-04 quoted context above)
- [docs/decisions.md](../../decisions.md) — D4 (gate scope; this story formalizes its deferred UI-test part), D5 (pillars), D6 (English)
- [docs/backlog.md](../../backlog.md) — story entry (E1-S2) with the stakeholder decision set
- [docs/architecture.md](../../architecture.md) — the E1-S3 skeleton this story must keep green
- [SDD conventions](../README.md) — spec/design/tasks artifact rules
