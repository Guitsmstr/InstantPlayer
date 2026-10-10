# Development — building and checking this repo

How to build InstantPlayer and run the deterministic gate. The gate is law
([AGENTS.md](../AGENTS.md) hard rule 3): it must pass before every commit and is
enforced by the pre-commit hook. Never bypass it (`--no-verify` is forbidden).

## 1 · Gate usage

The single command, from the repo root:

```sh
./scripts/validate.sh
```

Step order ([D4](decisions.md)):

1. Docs checks — ADR format ([decisions.md](decisions.md)), internal links, approved-spec hygiene
2. Branch policy (only with `--staged`)
3. Lint (SwiftLint)
4. Format check (SwiftFormat `--lint`)
5. Build (`InstantPlayer` scheme)
6. Unit tests (`InstantPlayerTests`)
7. UI tests (`InstantPlayerUITests`) — only when `--uitests` is passed (E1-S2)

Modifiers:

- `--staged` — skip build-heavy steps when only docs/harness files are staged (this is
  what the pre-commit hook runs); with code staged it still runs the full project checks.
- `--uitests` — also run the UI-test target (`InstantPlayerUITests`); implies the full
  run — the docs-only shortcut is never taken when the flag is present.
- `--json <path>` — write a machine-readable per-step evidence summary; record evidence
  from it, never from memory.
- `--verbose` — print failing step output in full (default: tail + full log path).

## 2 · Flag matrix

Every invocation and what it runs (verbatim from
[the story design](specs/e1-s2-baseline-hygiene/design.md), matching the implemented
gate in [scripts/validate.sh](../scripts/validate.sh)):

| Invocation | Docs checks | Branch policy | Docs-only shortcut | Lint | Format | Build | Unit tests | UI tests |
|---|---|---|---|---|---|---|---|---|
| `./scripts/validate.sh` | ✔ | — | — | ✔ | ✔ | ✔ | ✔ | — |
| `./scripts/validate.sh --staged` (code staged) | ✔ | ✔ | — | ✔ | ✔ | ✔ | ✔ | — |
| `./scripts/validate.sh --staged` (docs/harness-only staged) | ✔ | ✔ | ✔ | — | — | — | — | — |
| `./scripts/validate.sh --uitests` | ✔ | — | — | ✔ | ✔ | ✔ | ✔ | ✔ |
| `./scripts/validate.sh --staged --uitests` (any staged set) | ✔ | ✔ | never taken | ✔ | ✔ | ✔ | ✔ | ✔ |
| `--json <path>` / `--verbose` | modifiers on any row (evidence file / full failing logs) | | | | | | | |

## 3 · UI-test mandate (R14)

When a story touches flows that UI tests cover, the validator/converge step must run
`./scripts/validate.sh --uitests`; default per-commit runs stay UI-test-free (the
[D4](decisions.md) speed promise). A failing UI test fails the gate run — the flag is
additive and fail-closed, it never skips or weakens a step.

## 4 · Tooling & pins (R15)

- **Xcode 26** — the repo's pins: `LastUpgradeCheck = 2600`,
  `MACOSX_DEPLOYMENT_TARGET = 26.0`, `SWIFT_VERSION = 5.0` (and `.swift-version` = 5.0).
- **Destination** `platform=macOS` ([D1](decisions.md) — this is a Mac app; no simulator).
- **Derived data** pinned at `.deriveddata/` (gitignored; build artifacts are excluded
  from lint/format via the house configs).
- **SwiftLint + SwiftFormat** installed via Homebrew (`brew install swiftlint
  swiftformat`) — the gate is fail-closed without them: a missing tool is a failing step.
- **Style source**: the committed `.swiftlint.yml` and `.swiftformat` are picked up
  automatically (no `--config` flags anywhere); rationale in [D17](decisions.md) and
  [the E1-S2 design](specs/e1-s2-baseline-hygiene/design.md).

## 5 · CI runner checklist (R15–R16)

A CI runner needs, in order:

1. **Xcode 26 selected** (the version pin above).
2. **Homebrew `swiftlint` + `swiftformat`** installed.
3. **The checkout** of this repository.

Then run the **same single command contributors run locally**:

```sh
./scripts/validate.sh
```

optionally with `--json <path>` for machine-readable evidence. There is no CI-specific
variant of the gate (R16) — a conforming runner reproduces local verdicts exactly. Note:
`--uitests` runs launch the real app and need a logged-in GUI session; a headless runner
must either provide one or stay on the default gate scope. The repo deliberately contains
no CI-service configuration (story non-goal) — this checklist is the entire CI contract.
