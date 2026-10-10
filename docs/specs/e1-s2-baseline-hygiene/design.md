# E1-S2 · Baseline hygiene — Design

HOW for [the story spec](spec.md) (R1–R18). Product truth: [docs/spec.md](../../spec.md);
decisions: [docs/decisions.md](../../decisions.md) (D4 gate scope, D17 planned below);
structure reference: [docs/architecture.md](../../architecture.md); conventions:
[docs/specs/README.md](../README.md).

## 0 · Scope & components

Tooling-only story: no shipped code changes beyond style fixes (which are expected to be
zero — §5). The deliverables and where each spec requirement lands:

| Component | Purpose | Requirements |
|---|---|---|
| `.swiftlint.yml` (evolve existing stub) | single lint style source, curated rule set | R1–R8 |
| `.swiftformat` (new) | single format style source, 120-wrap agreement | R1–R5 |
| `scripts/validate.sh` (`--uitests` flag) | formalize D4's deferred UI-test run | R11–R13 |
| `docs/development.md` (new) | gate usage, flag matrix, UI-test mandate, CI runner checklist | R14–R16 |
| `docs/decisions.md` → D17 | house style + `--uitests` rationale | R17–R18 |
| codebase green under the configs | zero residual violations | R9–R10 |

Rule/tool facts below are grounded in SwiftLint 0.65 rule classification (default vs
opt-in sets verified against the official Rule Directory) and SwiftFormat's current rule
and option documentation (`trailingCommas`, `spaceAroundOperators`, `wrap`, `wrapArguments`,
config-file format). Where a rule's ownership matters, the owning SwiftFormat rule is named.

## 1 · `.swiftlint.yml` — exact contents (R1–R8)

The file already exists as a stub ("E1-S2 will tune rules with the team") and is **evolved
in place** — R1 requires exactly one committed source per tool, so the stub's comment is
replaced and the file becomes the authoritative config. Exact contents:

```yaml
# InstantPlayer — house SwiftLint configuration (E1-S2 · docs/decisions.md D17).
# Single source of style truth for lint (R1–R3). Rule-by-rule rationale:
# docs/specs/e1-s2-baseline-hygiene/design.md §1.
#
# Philosophy (R6–R8): sensible SwiftLint defaults stay on; rules whose exact
# concern SwiftFormat already enforces in the same gate run are disabled
# (duplicated verdicts are drift, not safety); purely opinionated size limits
# are off; a deliberately small opt-in set of correctness/risk rules is on,
# at error severity so the gate actually fails on them.

# Never lint build artifacts or vendored/generated code.
excluded:
  - .deriveddata
  - .build
  - .swiftpm

# Disabled — stylistic noise / formatter-owned style (R7).
disabled_rules:
  # Formatter-owned style: SwiftFormat's default rules enforce and auto-fix
  # these in the same gate run, so linting them again is duplicate enforcement
  # and can contradict the formatter (US1).
  - trailing_whitespace     # SwiftFormat `trailingSpace`
  - trailing_newline        # SwiftFormat `linebreakAtEndOfFile`
  - vertical_whitespace     # SwiftFormat `consecutiveBlankLines`, `blankLinesAtStartOfScope`, `blankLinesAtEndOfScope`
  - comma                   # SwiftFormat `spaceAroundOperators` (delimiters)
  - colon                   # SwiftFormat `spaceAroundOperators --type-delimiter space-after`
  - trailing_comma          # SwiftFormat `trailingCommas` (default "always") — the tools contradict by default
  # Opinionated size limits: no defect signal at this codebase's shape (all
  # tracked files < 70 lines); decomposition is governed by D7 layering and
  # review, not line counts.
  - file_length
  - type_body_length

# Opt-in — high-value correctness/risk rules (R8). Small on purpose.
opt_in_rules:
  - force_unwrapping               # `!` is a crash on unexpected input (R6)
  - implicitly_unwrapped_optional  # hidden force unwraps in declarations (R6)
  - fatal_error_message            # fatalError without a message is undebuggable (R6)

# Line length 120 in both tools (R4–R5). warning == error on purpose: only
# error-severity violations fail `swiftlint lint`, so a higher error threshold
# would make the "limit" advisory. SwiftFormat wraps at the same 120 (R5).
line_length:
  warning: 120
  error: 120

# Chosen rules are enforced, not advisory (R6): error severity = gate failure.
force_unwrapping: error
implicitly_unwrapped_optional: error
fatal_error_message: error
```

### Rule-by-rule justification

**Disabled — formatter-owned style (R7: "duplicates style the formatter … already
settles").** Each of these is enforced by a default SwiftFormat rule that runs in the
same gate step (`swiftformat --lint .`), so disabling the SwiftLint copy removes no
enforcement — the format step still fails the gate on any violation (US1):

| Rule | SwiftFormat owner | Note |
|---|---|---|
| `trailing_whitespace` | `trailingSpace` | byte-level presentation |
| `trailing_newline` | `linebreakAtEndOfFile` | EOF newlines are the formatter's contract |
| `vertical_whitespace` | `consecutiveBlankLines`, `blankLinesAtStartOfScope`, `blankLinesAtEndOfScope` | blank-line style |
| `comma` | `spaceAroundOperators` (delimiters) | `a , b` → `a, b` |
| `colon` | `spaceAroundOperators --type-delimiter space-after` | same policy SwiftLint's rule encodes |
| `trailing_comma` | `trailingCommas` (`--trailing-commas always`) | **the two tools contradict by default** — SwiftFormat adds trailing commas, SwiftLint flags them; the formatter wins (comma-style is its job) |

**Disabled — opinionated size limits (R7: "purely stylistic opinion").**
`file_length` and `type_body_length` are arbitrary count thresholds with no defect
signal at this codebase's shape (largest tracked file ≈61 lines). Structural
decomposition is governed by the D7 layering and review, not line counts. Kept
instead: `function_body_length` and `cyclomatic_complexity` — per-function complexity
is a real risk class (R6), unlike whole-file/whole-type size.

**Opt-in (R8: "small curated set of high-value correctness/risk rules").** All three
are verified opt-in in SwiftLint's Rule Directory (off by default, R8 applies):

- `force_unwrapping` — explicit `!` is a crash on unexpected input; exactly the risky
  construct class R6 protects, and this product takes untrusted filenames/metadata at
  its Data edge (D7, RNF-04).
- `implicitly_unwrapped_optional` — the same family: `T!` declarations are hidden
  force unwraps that fail at use site, not declaration site.
- `fatal_error_message` — `fatalError()` without a message is undebuggable in the
  field; the XCTest-family equivalent `xctfail_message` is **already on by default**
  (Rule Directory) and stays at default severity, so the message discipline covers
  both app and test failure paths.

**Severity = error for all three.** `swiftlint lint` fails only on error-severity
violations (warnings need `--strict`, which D4's step does not use and the story's
non-goals forbid changing); an advisory-only risk rule would be noise, not a guard.

**`line_length` 120/120 (R4).** warning and error are both 120 because only errors fail
the gate — with the default error threshold of 200 the "120 limit" would be advisory.
With error at 120 and SwiftFormat wrapping at 120 (R5), the two tools agree exactly:
anything the formatter emits passes lint, and a line the formatter cannot wrap (e.g. a
long URL in a string) is flagged by lint as the backstop.

**`excluded`.** `.deriveddata`, `.build`, `.swiftpm` — build artifacts and vendored
checkouts must never be linted (verdicts come from committed config, R2; tool defaults
and per-invocation `--config` overrides are forbidden as the style source, R3).

**All other default rules stay at SwiftLint defaults** (`force_cast`, `force_try`,
`cyclomatic_complexity`, `function_body_length`, `identifier_name`, `type_name`,
`opening_brace`, `comment_spacing`, `superfluous_disable_command`, …) — the "sensible
defaults" half of the stakeholder decision. The disable-list boundary is: disable a
default rule only when the formatter provably owns the identical concern (each verified
against SwiftFormat's rule list above) or the rule is pure size opinion (R7).

## 2 · `.swiftformat` — exact contents (R1–R5)

Config-file format (`--option value` lines, `#` comments), auto-discovered from the
project root by both `swiftformat .` and `swiftformat --lint .` — R3's "pick up the
committed house configurations automatically" holds with no `--config` flags. Exact
contents:

```
# InstantPlayer — house SwiftFormat configuration (E1-S2 · docs/decisions.md D17).
# Single source of style truth for formatting (R1–R3). Rationale: design.md §2.
#
# Philosophy (spec decision 3): SwiftFormat defaults ARE the house style and are
# inherited, not re-declared — 4-space indent (`indent`), semicolon terminators
# removed (`semicolons`, default policy), trailing commas added (`trailingCommas`,
# default "always"), LF linebreaks (`linebreaks`), and the project's Swift version
# from `.swift-version` (5.0). This file only pins what defaults leave open: the
# 120-character agreement with SwiftLint (R4–R5) and the wrap style.

# Never format build artifacts or vendored/generated code (mirrors .swiftlint.yml).
--exclude .deriveddata,.build,.swiftpm

# Line-length agreement (R4–R5): wrap at 120 — the same limit SwiftLint enforces.
--max-width 120

# Wrap style: one argument/parameter per line after the opening paren, closing
# paren balanced on its own line — what the codebase already does
# (AppDependencies.init). Collection literals stay at the default "preserve"
# until multiline collections exist.
--wrap-arguments before-first
--wrap-parameters before-first
```

**House block size: 3 options on 3 lines (+2 comment lines and the exclude line).**
Justification per spec decision 3 ("SwiftFormat defaults plus a small explicit
house-style block"):

- `--max-width 120` (line 1 of the block) — R4/R5. The `wrap` rule's default is
  `none`; this is the single place the formatter's wrap limit is set, and it matches
  `line_length.error` exactly.
- `--wrap-arguments before-first` + `--wrap-parameters before-first` (lines 2–3) —
  when wrapping happens, its shape must be deterministic or the formatter's verdict
  drifts with its defaults. `before-first` is what the codebase already uses
  (`AppDependencies.init`); `--wrap-parameters` is stated explicitly for the same
  determinism (it falls back to `--wrap-arguments` when unset).
- **Inherited, not re-declared** (confirmed defaults): 4-space indent (`indent`),
  semicolon terminators stripped (`semicolons` default), trailing commas added
  (`trailingCommas` default `always` — the policy that made SwiftLint's
  `trailing_comma` a conflict, §1), LF linebreaks, `--closing-paren balanced`.
  Swift version comes from the existing `.swift-version` file (5.0), which takes
  precedence over any `--swift-version` flag — so it is not repeated here (single
  source of truth, R1).

**`--lint` interplay in the gate.** The gate step stays `swiftformat --lint .`
(D4 invocation, unchanged): lint mode runs the *same* rules and options as format
mode against this config, modifies nothing, and exits non-zero (code 1) when any file
would change — which `run_step` turns into a gate failure. Contributors apply with
`swiftformat .` (same config). So `--lint` is the enforcement side of this file and
the file is the only style input: R1–R3 hold for gate runs and local runs alike.

If the installed SwiftFormat release predates the kebab-case option spellings, the
legacy equivalents (`--maxwidth`, `--wraparguments`, `--wrapparameters`) carry the
same semantics; the gate's format step (exit code 70 on a bad option) surfaces the
spelling mismatch immediately and the implementation fixes the spelling only.

## 3 · Gate changes: the `--uitests` flag (R11–R13)

The flag is the only gate change (story non-goal: ordering and existing steps are
preserved). Exact behavior:

**Argument parsing** — one new case, one new variable; every unknown option still
exits 1:

```diff
 # Usage: ./scripts/validate.sh [--staged] [--json <path>] [--verbose]
+#   --uitests   also run the UI-test target (InstantPlayerUITests) — off by
+#               default; implies the full run (docs-only shortcut not taken)
```

```diff
 unit_test_target="InstantPlayerTests"
+ui_test_target="InstantPlayerUITests"
 ...
+uitests=0
 while [ "$#" -gt 0 ]; do
   case "$1" in
     --staged) staged=1 ;;
+    --uitests) uitests=1 ;;
     --verbose) verbose=1 ;;
```

**`--staged` interplay** — `--uitests` implies the full build run, because UI tests
need the built app; the docs-only shortcut is therefore never taken when the flag is
present (a `--uitests` run is a promise to run UI tests, so silently skipping them
would violate R12):

```diff
 docs_only=0
-if [ "$staged" -eq 1 ]; then
+if [ "$staged" -eq 1 ] && [ "$uitests" -eq 0 ]; then
   ...
 fi
+if [ "$staged" -eq 1 ] && [ "$uitests" -eq 1 ]; then
+  printf '%s\n' "# --uitests set — full run required (UI tests need the built app); docs-only shortcut not applicable"
+fi
```

**Step placement** — a new step at the end of the project-checks block, after
"Unit tests", using the identical `xcodebuild` conventions (project, scheme, `Debug`
configuration, `platform=macOS` destination — D1 —, pinned `-derivedDataPath`
`.deriveddata/`):

```bash
  if [ "$uitests" -eq 1 ]; then
    step "UI tests ($ui_test_target)"
    run_step "xcodebuild test -only-testing:$ui_test_target" \
      xcodebuild -project "$project" -scheme "$scheme" -configuration Debug \
        -destination 'platform=macOS' -derivedDataPath "$derived_data" \
        -only-testing:"$ui_test_target" test
  fi
```

**Fail-closed (R13).** `run_step` records a failing UI-test run like any other step:
`errors` increments and the script exits 1 — identical to the unit-test step's
behavior. The step also appears in `--json` evidence automatically (via `steps.tsv`).

**Guardrails (R11–R12).** The flag is purely additive: it appends one step inside a
new `if`, and the only existing condition it touches (`docs_only`) it makes *less*
restrictive. Invariant: every flagged run's step set is a superset of the same run
without the flag. Without `--uitests`, the step list, order, and `--staged` docs-only
semantics are byte-identical to D4. The pre-commit hook (`./scripts/validate.sh
--staged`) is untouched, so per-commit speed (D4's "fast enough to never tempt a
bypass") is preserved.

**Flag matrix (also published in `docs/development.md`, §4):**

| Invocation | Docs checks | Branch policy | Docs-only shortcut | Lint | Format | Build | Unit tests | UI tests |
|---|---|---|---|---|---|---|---|---|
| `./scripts/validate.sh` | ✔ | — | — | ✔ | ✔ | ✔ | ✔ | — |
| `./scripts/validate.sh --staged` (code staged) | ✔ | ✔ | — | ✔ | ✔ | ✔ | ✔ | — |
| `./scripts/validate.sh --staged` (docs/harness-only staged) | ✔ | ✔ | ✔ | — | — | — | — | — |
| `./scripts/validate.sh --uitests` | ✔ | — | — | ✔ | ✔ | ✔ | ✔ | ✔ |
| `./scripts/validate.sh --staged --uitests` (any staged set) | ✔ | ✔ | never taken | ✔ | ✔ | ✔ | ✔ | ✔ |
| `--json <path>` / `--verbose` | modifiers on any row (evidence file / full failing logs) | | | | | | | |

## 4 · Codebase-green strategy (R9–R10)

**Inspection evidence (all 13 tracked Swift files read):** longest line ≈95 characters
(`AppDependenciesTests.swift` probe assertions) — under 120 everywhere; **zero** force
unwraps, zero implicitly unwrapped optionals, zero `fatalError` calls — the opt-in set
adds no violations; no trailing commas in multiline literals; all multiline signatures
already use the `before-first` wrap shape (`AppDependencies.init`); the two
`// swiftformat:disable:next redundantThrows` directives in
`InstantPlayerUITests.swift` (lines 11, 23) are legitimate guards for `@objc` override
signatures and stay untouched (SwiftLint ignores SwiftFormat directives). **Expected
hand-fixes: zero.** If the apply pass below surfaces anything, it is a naming of the
actual file+line in story evidence — no invented fixes (R10).

**Order of operations:**

1. Land the two configs (`.swiftlint.yml` evolved, `.swiftformat` created) in one
   commit — config-first, so every subsequent verdict comes from them (R1–R3).
2. Run `swiftformat .` once to normalize the tree under the house block (expected
   no-op given the inspection above; if it rewraps anything, the diff is by
   construction style-only, R10).
3. Run `./scripts/validate.sh`; any lint residual is fixed **style-only** — no
   behavioral change, no refactor, no renaming beyond style (R10).
4. Verification loop: `./scripts/validate.sh --json <tmp>/gate.json` and quote the
   per-step results verbatim as R9 evidence (never from memory); rerun until the
   lint and format steps report clean on every tracked Swift file including the
   E1-S3 skeleton.

## 5 · Docs placement (R14–R16)

**Decision: a new `docs/development.md`** — "how to build and check this repo" — not a
section in `docs/architecture.md`. Justification: `architecture.md`'s charter and its
maintenance rule are scoped to *codebase structure* (D7–D10); gate/tooling/CI content
would dilute that charter and go stale against its update rule. `docs/specs/` is
per-story; `AGENTS.md` is the constitution, not a how-to. One pointer row is added to
the `AGENTS.md` trigger table (`Gate usage, flags, or CI runner questions →
docs/development.md`) so the doc is discoverable. The internal-links gate check covers
`docs/*.md`, so all links from and to the new file are validated.

**Exact content items of `docs/development.md`:**

1. **Gate usage** — the single command `./scripts/validate.sh` and its modifiers
   (`--staged`, `--json <path>`, `--verbose`); step order as in D4 plus the optional
   UI-tests step.
2. **Flag matrix table** — the full matrix from §3 verbatim.
3. **UI-test mandate (R14)** — "When a story touches flows that UI tests cover, the
   validator/converge step must run `./scripts/validate.sh --uitests`; default
   per-commit runs stay UI-test-free (D4 speed promise)."
4. **Tooling & pins (R15)** — Xcode **26** (the repo's pin: `LastUpgradeCheck = 2600`,
   `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0` / `.swift-version` = 5.0);
   macOS destination string `platform=macOS` (D1 — Mac app, no simulator); derived
   data pinned at `.deriveddata/`; SwiftLint + SwiftFormat installed via Homebrew
   (the gate is fail-closed without them).
5. **CI runner checklist (R15–R16)** — the runner must have: Xcode 26 selected;
   Homebrew `swiftlint` + `swiftformat`; the checkout; then run the **same single
   command** contributors run locally, `./scripts/validate.sh` (R16 — no CI-specific
   variant), optionally `--json <path>` for machine-readable evidence. One note:
   `--uitests` runs launch the real app and need a logged-in GUI session.

## 6 · ADR plan — D17 (R17–R18)

One ADR appended to [docs/decisions.md](../../decisions.md) (R17 asks for "an ADR"
covering all four decisions), continuing the log at D16 and completing the
[D4](../../decisions.md) formalization. Gate-format-compliant heading:

```
## D17 — House style configs (SwiftLint/SwiftFormat) & gate `--uitests` formalization · 2026-10-09 · accepted
```

Planned content (implementation writes it into `docs/decisions.md`):

- **Context:** the gate ran lint/format with tool defaults — "house style" was whatever
  the installed tools defaulted to, and the tools could contradict each other
  (trailing commas; line length). D4 deferred UI tests to "the validator/converge step
  runs them when the story touches flows UI tests cover" without a mechanism.
- **Decision:** committed configs are the single style source (R1–R3): curated moderate
  SwiftLint set — sensible defaults on, formatter-owned/style-noise rules off, three
  risk opt-ins at error severity (R6–R8); 120-character line length agreed by both
  tools with formatter wrapping at 120 (R4–R5); SwiftFormat defaults as house style
  plus a minimal explicit block (spec decision 3); `--uitests` gate flag, default-off
  and additive, formalizing D4's deferred UI-test promise (R11–R14); `docs/development.md`
  gate usage + CI runner checklist (R14–R16).
- **Alternatives:** summarized from §8 (whitelist vs disable-list; strict-mode vs
  per-rule severity; separate CI script vs flag; inline flags vs config files).
- **Consequences:** a formatter-clean edit cannot fail lint on style (US1); risky
  constructs fail the gate, not just warn; per-commit scope is unchanged (D4 speed
  preserved); tool upgrades can still shift default-rule verdicts — mitigated by the
  runner checklist's version pins and re-baselining through a story; future contributors
  inherit the rationale here instead of re-litigating rule choices (R18).

## 7 · Pillars (RNF-02 performance, RNF-04 security) — not engaged

Per the story spec's Pillars paragraph: this story changes no runtime behavior, data
handling, or shipped-code semantics (style-only edits at most, R10), so neither pillar
is engaged. **Performance (RNF-02):** nothing ships; the only performance-adjacent fact
is that D4's per-commit speed promise is preserved — `--uitests` is default-off. The
`swift-performance` skill is not loaded. **Security (RNF-04):** no data at rest,
network, permissions, secrets, or file handling is touched; the `force_unwrapping`
opt-in incidentally hardens code against untrusted input but is a lint rule, not a
runtime control. The `swift-security` skill is not loaded. *Convention deviation (one
line):* the mandatory "how the design satisfies each pillar" sections are reduced to
this explicit non-engagement statement because this is a tooling-only story that
provably engages neither pillar.

## 8 · Alternatives considered

1. **SwiftLint `only_rules` whitelist** (pin the exact rule set) vs curated
   `disabled_rules` + `opt_in_rules`. **Chosen: curated lists.** The whitelist pins
   against tool-upgrade drift but contradicts stakeholder decision 1 ("sensible
   defaults, noisy opinionated rules off, opt-ins in") and loses future useful default
   rules. Drift is mitigated instead by pinned tools in the runner checklist and
   gate-evidence re-baselining. (R6–R8)
2. **Linter-owned line length** (formatter `--max-width none`) or **formatter-owned**
   (lint silent on length) vs **both at 120**. **Chosen: both at 120** — R4 explicitly
   requires the limit in both tools and R5 requires the formatter to wrap at it;
   linter-only recreates US1's failure (format-clean edit fails lint); formatter-only
   leaves unwrappable long lines unflagged. (R4–R5)
3. **`swiftlint lint --strict`** (warnings fail) vs **per-rule error severity**.
   **Chosen: error severity on the curated rules only** — `--strict` would fail the
   gate on benign default warnings (`identifier_name`, `todo`, …), contradicting the
   moderate stance, and would change D4's lint step beyond the flag (story non-goal).
   (R6, R11)
4. **Separate `scripts/ci.sh` or `scripts/uitests.sh`** vs **`--uitests` flag on the
   gate**. **Chosen: flag** — R12 mandates "in addition to the standard gate steps"
   and R16 mandates one deterministic command; a second script invites a second,
   divergent copy of the step list. (R12, R16)
5. **Inline gate flags** (`swiftlint --config …`, `swiftformat --max-width 120 …` in
   `validate.sh`) vs **committed config files**. **Chosen: config files** — R1–R2 make
   local runs governed by the same source; inline flags would judge gate runs by
   something contributors' editors don't see, and R2 forbids per-invocation overrides
   as the style source. (R1–R3)
6. **UI tests always-on** vs **default-off flag**. **Chosen: default-off** — R11 keeps
   D4's per-commit scope and its speed promise exactly.
7. **`--staged --uitests` as a hard error** vs **docs-only shortcut suppressed (full
   run)**. **Chosen: full run** — the flag is a promise to execute UI tests; erroring
   would turn a legitimate combination into a trap, and running strictly more steps
   preserves the R12 superset invariant.
8. **"Gate & tooling" section in `docs/architecture.md`** vs **`docs/development.md`**.
   **Chosen: `docs/development.md`** — `architecture.md`'s charter/maintenance rule is
   codebase structure (D7–D10); gate usage and CI checklists belong in a how-to doc
   (§5).
9. **Keep `file_length`/`type_body_length` at defaults** vs **disable**. **Chosen:
   disable** — arbitrary size thresholds with no defect signal at this codebase's
   shape (R7's "noise that catches no defects"); per-function complexity guards
   (`function_body_length`, `cyclomatic_complexity`) are kept as the risk class (R6).

## 9 · Requirements traceability

| Requirement | Where designed |
|---|---|
| R1–R3 (config authority) | §1 (file + `excluded`), §2 (auto-discovery, no `--config`) |
| R4–R5 (120 agreement) | §1 `line_length` 120/120; §2 `--max-width 120` + wrap style |
| R6 (correctness/risk on) | §1 kept defaults (`force_cast`, `force_try`, complexity guards) |
| R7 (stylistic noise off) | §1 disabled list + justifications |
| R8 (small opt-in set) | §1 opt-in list (3 rules, error severity) |
| R9–R10 (codebase green, style-only) | §4 strategy + inspection evidence |
| R11 (default run unchanged) | §3 matrix rows 1–3; pre-commit untouched |
| R12 (`--uitests` additive) | §3 step placement + superset guardrail |
| R13 (UI failure fails gate) | §3 fail-closed via `run_step` |
| R14 (validator/converge mandate) | §5 item 3 |
| R15–R16 (CI runner checklist) | §5 items 4–5 |
| R17–R18 (ADR + rationale surfaced) | §6 (D17) |

## 10 · Open questions

None — the story spec is stakeholder-final and every design choice above traces to a
spec requirement or a recorded stakeholder decision.
