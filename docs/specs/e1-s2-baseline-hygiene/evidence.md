# E1-S2 · Baseline hygiene — Evidence & traceability

All evidence below is quoted verbatim from tooling output — never paraphrased, never
re-derived, never from memory (SDD conventions: [docs/specs/README.md](../README.md)).
Runs executed on branch `feat/e1-s2-baseline-hygiene` at the story's final
implementation state (implementation commits `1ab6499` T1, `6e466ed` T2, `a8ac524` T3,
`4571fe4` T4; tracked tree clean before the T5 evidence commit). Evidence JSONs were
captured with `--json` into the session temp dir
(`/private/var/folders/jc/h7sw5n3d0m1dkqfw00ymkh240000gn/T/opencode/`): `gate-t1.json`,
`gate-t2-default.json`, `gate-t2-uitests.json`, `gate-t2-staged-uitests.json`,
`gate-pre-staged-code.json`, `gate-pre-staged-docsonly.json`, `gate-t2-staged-docsonly.json`,
and the fresh Task-5 runs `gate.json` / `gate-uitests.json`.

## 1 · Traceability walk — design [§9](design.md) row by row (task 5.1)

| Requirement | Designed in | Verdict | Evidence (opened in the committed tree) |
|---|---|---|---|
| R1–R3 (config authority) | §1 / §2 | **PASS** | `.swiftlint.yml` (50 lines) and `.swiftformat` (22 lines) exist at the repo root and match the design §1–§2 fenced contents exactly. Auto-discovery with no `--config` flag is proven by the format step's own output (quoted in §2.3 below): `Reading config file at …/.swiftformat`. |
| R4–R5 (120 agreement) | §1 `line_length`; §2 `--max-width` | **PASS** | `.swiftlint.yml`: `line_length:` → `warning: 120` / `error: 120`. `.swiftformat`: `--max-width 120`. Both committed. |
| R6 (correctness/risk on) | §1 kept defaults | **PASS** | `disabled_rules` contains only the six formatter-owned style rules plus `file_length`/`type_body_length`; default risk rules (`force_cast`, `force_try`, `cyclomatic_complexity`, `function_body_length`, …) are absent from it, therefore on. |
| R7 (stylistic noise off) | §1 disabled list | **PASS** | `disabled_rules`: `trailing_whitespace`, `trailing_newline`, `vertical_whitespace`, `comma`, `colon`, `trailing_comma` (formatter-owned) + `file_length`, `type_body_length` (size opinion). |
| R8 (small opt-in set) | §1 opt-in list | **PASS** | `opt_in_rules`: `force_unwrapping`, `implicitly_unwrapped_optional`, `fatal_error_message` — each pinned at `error` severity (`force_unwrapping: error`, `implicitly_unwrapped_optional: error`, `fatal_error_message: error`). |
| R9–R10 (green, style-only) | §4 strategy | **PASS** | Fresh runs: `swiftlint lint --quiet` → exit 0, no output; `swiftformat --lint .` → `0/13 files require formatting, 21 files skipped.`; full gate → `all checks passed` (§2.1). Zero style fixes were made in the whole story (R10 satisfied trivially — design §4's "expected hand-fixes: zero" held). |
| R11 (default unchanged) | §3 matrix rows 1–3 | **PASS** | Pre-change baseline `gate-t1.json` (captured at Task 1, before the gate edit) and post-change `gate-t2-default.json` are byte-identical: same 7 steps, same order, same statuses, no UI step. Story-final default run (§2.1) shows the same 7 steps. |
| R12 (flagged additive) | §3 step placement + superset | **PASS** | Fresh flagged run (§2.2): the 7 default steps **plus** `UI tests (InstantPlayerUITests)` — exact superset, all ok, `all checks passed`. `--staged --uitests` (T2 capture `gate-t2-staged-uitests.json`): branch policy ran, docs-only shortcut never taken, UI step present — superset of matrix row 2. |
| R13 (UI failure fails gate) | §3 fail-closed via `run_step` | **PASS** (method deviation recorded, §3.1) | T2 capture `gate-t2-uitests.json`: `{ "name": "UI tests (InstantPlayerUITests)", "status": "fail" }`, `"result": "fail"`, console `1 check(s) FAILED`, exit code 1 — a failing UI step flows through `run_step` exactly like any other step. |
| R14 (mandate documented) | §5 item 3 | **PASS** | `docs/development.md` §3 "UI-test mandate (R14)": "When a story touches flows that UI tests cover, the validator/converge step must run `./scripts/validate.sh --uitests`; default per-commit runs stay UI-test-free (the [D4](../../decisions.md) speed promise)." |
| R15–R16 (CI runner checklist) | §5 items 4–5 | **PASS** | `docs/development.md` §4 (Xcode 26 pins incl. `LastUpgradeCheck = 2600`, destination `platform=macOS`, `.deriveddata/`, Homebrew tools) and §5 (checklist: Xcode 26 → Homebrew tools → checkout → the same single command `./scripts/validate.sh`; "There is no CI-specific variant of the gate (R16)"; GUI-session note for `--uitests`). |
| R17–R18 (ADR + rationale) | §6 (D17) | **PASS** | `docs/decisions.md` line 119: heading `## D17 — House style configs (SwiftLint/SwiftFormat) & gate `--uitests` formalization · 2026-10-09 · accepted`, accepted by the gate's ADR-format step (`ok:   17 ADRs well-formed`). The Decision bullet names all four decisions — (1) curated moderate lint, (2) 120 in both tools, (3) SwiftFormat defaults + minimal block, (4) `--uitests` flag — and links D4 ("formalizing D4's deferred UI-test promise"). AGENTS.md trigger-table row present: `| Gate usage, flags, or CI runner questions | read `docs/development.md` |`. |

## 2 · Gate runs — quoted verbatim from `--json` files (task 5.2)

### 2.1 Default run — R9 / R11 evidence (fresh, story-final tree)

Command: `./scripts/validate.sh --json <tmp>/gate.json` — console: `all checks passed`

```json
{
  "branch": "feat/e1-s2-baseline-hygiene",
  "staged": false,
  "result": "pass",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" }
  ]
}
```

### 2.2 Flagged run — R12 evidence (fresh, same tree)

Command: `./scripts/validate.sh --uitests --json <tmp>/gate-uitests.json` — console:
`ok:   xcodebuild test -only-testing:InstantPlayerUITests` then `all checks passed`

```json
{
  "branch": "feat/e1-s2-baseline-hygiene",
  "staged": false,
  "result": "pass",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" },
    { "name": "UI tests (InstantPlayerUITests)", "status": "ok" }
  ]
}
```

### 2.3 Task 1 green run — R9 excerpt (Task 1.4, house configs in, gate change not yet made)

`gate-t1.json` (full gate `all checks passed`; identical file to the post-change default
baseline `gate-t2-default.json`, which is the R11 comparison):

```json
{
  "branch": "feat/e1-s2-baseline-hygiene",
  "staged": false,
  "result": "pass",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" }
  ]
}
```

Tooling quotes captured alongside (fresh re-run at Task 5, identical result):

```
swiftlint lint --quiet          → (no output) exit code 0
swiftformat --lint .            → Running SwiftFormat...
(lint mode - no files will be changed.)
Reading config file at <repo>/.swiftformat
Reading swift-version file at <repo>/.swift-version (version 5.0)
SwiftFormat completed in 0.01s.
0/13 files require formatting, 21 files skipped.
```

### 2.4 T2 fail-closed captures — R13 evidence (UI failure fails the gate)

`gate-t2-uitests.json` (flagged run, UI step failing — recorded `fail`, gate exits 1):

```json
{
  "branch": "feat/e1-s2-baseline-hygiene",
  "staged": false,
  "result": "fail",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" },
    { "name": "UI tests (InstantPlayerUITests)", "status": "fail" }
  ]
}
```

`gate-t2-staged-uitests.json` (matrix row 5: docs-only shortcut never taken — the console
printed `# --uitests set — full run required (UI tests need the built app); docs-only
shortcut not applicable` — and every default step plus the (then failing) UI step ran):

```json
{
  "branch": "feat/e1-s2-baseline-hygiene",
  "staged": true,
  "result": "fail",
  "steps": [
    { "name": "ADR format (docs/decisions.md)", "status": "ok" },
    { "name": "Internal links (docs + AGENTS.md)", "status": "ok" },
    { "name": "Approved-spec hygiene (docs/specs/*/tasks.md)", "status": "ok" },
    { "name": "Branch policy (staged changes vs. 'main' allowlist)", "status": "ok" },
    { "name": "Lint (SwiftLint)", "status": "ok" },
    { "name": "Format check (SwiftFormat --lint)", "status": "ok" },
    { "name": "Build (InstantPlayer)", "status": "ok" },
    { "name": "Unit tests (InstantPlayerTests)", "status": "ok" },
    { "name": "UI tests (InstantPlayerUITests)", "status": "fail" }
  ]
}
```

Console tail of both runs: `** TEST FAILED **` / `1 check(s) FAILED`, exit code 1.

## 3 · Deviations — honest record (task 5.3)

### 3.1 R13 verification method: documented fallback exercised at Task 2; `XCTFail` probe still unexercised

The chosen method per tasks.md T2.4 — a transient `XCTFail("E1-S2 fail-closed probe")`
inside one `InstantPlayerUITests` test — was **not** exercised. At Task 2 time, both
flagged runs failed before any test method executed; the runner could not initialize:

```
2026-10-09 20:47:39.787717-0500 InstantPlayerUITests-Runner[26886:603757] [Default] Failed to initialize for UI testing: Error Domain=com.apple.LocalAuthentication Code=-2 "Canceled by user." UserInfo={NSDebugDescription=Canceled by user., NSLocalizedDescription=Authentication canceled., BiometryType=1}
InstantPlayerUITests-Runner (26886) encountered an error (The test runner failed to initialize for UI testing. (Underlying Error: Authentication canceled. Canceled by user.))
** TEST FAILED **
```

Per the documented fallback, R13 was then evidenced by fail-closed wiring equivalence —
and in fact something stronger: a **real** runner-level UI failure propagated through
`run_step` exactly as designed (`errors` increment → exit 1 → step recorded `fail` in
`--json`, quoted in §2.4). The probe was never introduced, never staged, never committed —
no probe JSON exists because no probe was run; nothing is faked.

**Update at Task 5 time:** the same invocation now runs green (§2.2 — runner initialized,
full `InstantPlayerUITests` target executed, `all checks passed`). The Task-2 environment
failure was therefore transient, not a permanent property of this environment; the
"runner cannot initialize" condition recorded at Task 2 no longer holds. Residual gap:
a failure raised **inside** a UI-test method (the probe path) has still never been
exercised end-to-end. The probe recipe stays documented in tasks.md T2.4 and can be run
in seconds by the validator/converge review if desired.

### 3.2 Design §4 apply pass replaced by a read-only `--lint` no-op proof

`swiftformat .` (the normalizing apply pass of design §4 step 2) was not executed: the
implementing agent's shell permissions allow only the read-only `swiftformat --lint`
form (edits go through the edit tool). Equivalent outcome proven instead: `0/13 files
require formatting` — zero files would have changed, so the apply pass is a no-op by
construction. No style fix of any kind was made in this story; the design §4 inspection
prediction ("Expected hand-fixes: zero") held exactly.

### 3.3 SwiftFormat legacy-spelling contingency not triggered

Design §2's contingency (fall back to `--maxwidth`/`--wraparguments`/`--wrapparameters`
if the installed SwiftFormat predates kebab-case spellings) did **not** occur: the
kebab-case config was accepted on first use (§2.3 quote — the tool reads the config and
exits 0). No substitution to record.

### 3.4 Commit subjects: coordinator briefs vs tasks.md verbatim strings

Commit subjects follow the coordinator briefs; tasks.md's "Commit:" lines differ. Both
mappings, so the record is exact:

| Task | tasks.md "Commit:" line | Actual subject (hash) |
|---|---|---|
| 1 | `chore(e1-s2): house style configs — SwiftLint/SwiftFormat single source of truth (120)` | `feat(e1-s2): task 1 — house style configs (.swiftlint.yml, .swiftformat)` (`1ab6499`) |
| 2 | `feat(e1-s2): gate --uitests flag — additive UI-test step, fail-closed` | `feat(e1-s2): task 2 — gate --uitests flag (fail-closed, additive)` (`6e466ed`) |
| 3 | `docs(e1-s2): development guide — gate usage, flag matrix, CI runner checklist` | `docs(e1-s2): task 3 — development guide (gate usage, UI-test mandate, CI checklist)` (`a8ac524`) |
| 4 | `docs(e1-s2): ADR D17 — house style configs & gate --uitests formalization` | `docs(e1-s2): task 4 — ADR D17 (house style & gate --uitests)` (`4571fe4`) |
| 5 | `docs(e1-s2): evidence & traceability — gate runs quoted verbatim` | `docs(e1-s2): task 5 — verification & evidence` (this commit) |

Every commit's file scope matches its task's scope check.

## 4 · Acceptance criteria closed (task 5.4)

The ticks in [spec.md](spec.md) are each backed by the tooling output quoted above:

- Configs single source (R1–R3) → §1 rows R1–R3; §2.3 auto-discovery quote.
- 120 agreement (R4–R5) → §1 row R4–R5.
- Curated set by constraint class (R6–R8) → §1 row R6–R8.
- Codebase green (R9–R10) → §2.1 (`result: "pass"`), §2.3 lint/format quotes, §1 row R9–R10.
- `--uitests` both ways (R11–R13) → §2.1 (default scope unchanged) vs §2.2 (flagged run executes `InstantPlayerUITests`, green) and §2.4 (a UI-test failure fails the gate); method deviation on the probe recorded in §3.1.
- Validator/converge mandate documented (R14) → §1 row R14.
- CI runner checklist (R15–R16) → §1 row R15–R16.
- ADR (R17–R18) → §1 row R17–R18.
- Evidence per SDD conventions → this file: every quote above is taken verbatim from tooling output files.
